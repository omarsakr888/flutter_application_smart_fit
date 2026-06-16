#!/usr/bin/env python3
"""test_ocr_accuracy.py — Isolated OCR accuracy benchmark for SmartFit.

Usage
-----
    cd smart_fit_backend
    python ../test_ocr_accuracy.py

The script is completely standalone — it does NOT touch the production
database, API server, or any live data.  It only reads the 3 test images
and prints a detailed accuracy report.

HOW TO USE
----------
1.  Run the script ONCE with empty ground_truth dicts (leave the values as {})
    to see what the OCR *actually* extracts from each image.
2.  Fill in the GROUND_TRUTH dictionary below with the real values printed
    from the InBody machine for each image.
3.  Run the script again.  It will calculate per-field accuracy and a
    summary report.

TOLERANCE
---------
A field is counted as "correct" if the extracted value is within ±TOLERANCE
of the ground-truth value.  Default is 2% (0.02) — tune per field if needed.
Gender is checked for exact match (0.0 = female, 1.0 = male).
"""

from __future__ import annotations

# ── PaddleX / PaddleOCR v3 — Windows CPU oneDNN crash fix ────────────────────
# Root cause: PaddleX reads PADDLE_PDX_ENABLE_MKLDNN_BYDEFAULT at *import time*
# (paddlex/utils/flags.py).  When True (default), get_default_run_mode() returns
# 'mkldnn' on Intel CPUs → static_infer.py calls config.enable_mkldnn() →
# Windows PIR executor crashes:
#   NotImplementedError: ConvertPirAttribute2RuntimeAttribute not support
#   pir::ArrayAttribute<pir::DoubleAttribute>  (onednn_instruction.cc:118)
#
# MUST be set BEFORE any paddlex/paddleocr/paddle import.
import os
os.environ["PADDLE_PDX_ENABLE_MKLDNN_BYDEFAULT"]       = "0"
os.environ.setdefault("PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK", "True")
# ─────────────────────────────────────────────────────────────────────────────

import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

# ── Add backend directory to path so we can import existing modules ──────────
BACKEND_DIR = Path(__file__).resolve().parent / "smart_fit_backend"
sys.path.insert(0, str(BACKEND_DIR))

# ── Import production OCR stack (no changes needed here) ─────────────────────
try:
    from image_preprocessing import preprocess_image
    from inbody_extractor import FIELD_SPECS, InBodyExtractor
    from easyocr_engine import EasyOcrEngine
except ImportError as exc:
    print(
        f"\nERROR: Could not import backend modules.\n"
        f"Make sure you run this script from the workspace root:\n"
        f"  cd c:\\Users\\zash0\\Downloads\\flutter_application_smart_fit\n"
        f"  python test_ocr_accuracy.py\n"
        f"\nOriginal error: {exc}\n"
    )
    sys.exit(1)

# ═══════════════════════════════════════════════════════════════════════════════
#  CONFIGURATION — Edit this section before running
# ═══════════════════════════════════════════════════════════════════════════════

TEST_IMAGES_DIR = Path(__file__).resolve().parent / "test_inbody_versions"

# Paths to each test image (relative to TEST_IMAGES_DIR)
TEST_IMAGES: dict[str, str] = {
    "InBody120": "inbody120.png",
    "InBody270": "inbody270.png",
    "InBody570": "inbody570.png",
}

# ── GROUND TRUTH ─────────────────────────────────────────────────────────────
# Fill in the real values from the physical InBody printout for each image.
# Keys must match the REQUIRED_INPUT_FEATURES exactly.
# Leave a field as None if it does not appear on that machine model.
#
# Gender encoding: 1.0 = Male, 0.0 = Female
#
GROUND_TRUTH: dict[str, dict[str, float | None]] = {
    "InBody120": {
        "Age":                          None,   # <- fill in e.g. 28
        "Gender":                       None,   # <- fill in 1.0 or 0.0
        "Height":                       None,   # <- fill in e.g. 176.0
        "Weight":                       None,   # <- fill in e.g. 74.5
        "SMM_(Skeletal_Muscle_Mass)":   None,
        "BMR_(Basal_Metabolic_Rate)":   None,
        "FFM_of_Trunk":                 None,
        "TBW_(Total_Body_Water)":       None,
        "ECW/TBW":                      None,
        "50kHz-Whole_Body_Phase_Angle": None,
        "BFM_(Body_Fat_Mass)":          None,
        "PBF_(Percent_Body_Fat)":       None,
    },
    "InBody270": {
        "Age":                          None,
        "Gender":                       None,
        "Height":                       None,
        "Weight":                       None,
        "SMM_(Skeletal_Muscle_Mass)":   None,
        "BMR_(Basal_Metabolic_Rate)":   None,
        "FFM_of_Trunk":                 None,
        "TBW_(Total_Body_Water)":       None,
        "ECW/TBW":                      None,
        "50kHz-Whole_Body_Phase_Angle": None,
        "BFM_(Body_Fat_Mass)":          None,
        "PBF_(Percent_Body_Fat)":       None,
    },
    "InBody570": {
        "Age":                          None,
        "Gender":                       None,
        "Height":                       None,
        "Weight":                       None,
        "SMM_(Skeletal_Muscle_Mass)":   None,
        "BMR_(Basal_Metabolic_Rate)":   None,
        "FFM_of_Trunk":                 None,
        "TBW_(Total_Body_Water)":       None,
        "ECW/TBW":                      None,
        "50kHz-Whole_Body_Phase_Angle": None,
        "BFM_(Body_Fat_Mass)":          None,
        "PBF_(Percent_Body_Fat)":       None,
    },
}

# Relative tolerance for numeric fields (2% = 0.02).
# A value is "correct" if abs(extracted - truth) / truth <= TOLERANCE
DEFAULT_TOLERANCE = 0.02

# Override tolerance for specific fields if needed
FIELD_TOLERANCES: dict[str, float] = {
    "ECW/TBW":                      0.005,  # ratio — tighter (±0.005 absolute)
    "50kHz-Whole_Body_Phase_Angle": 0.05,   # allow ±0.1 deg on phase angle
    "BMR_(Basal_Metabolic_Rate)":   0.03,   # ±3% on BMR
    "PBF_(Percent_Body_Fat)":       0.03,   # ±3% on body fat %
}

# Whether to use absolute tolerance for ECW/TBW (ratio fields are small)
ABSOLUTE_FIELDS: set[str] = {"ECW/TBW", "50kHz-Whole_Body_Phase_Angle"}


# ═══════════════════════════════════════════════════════════════════════════════
#  DATA CONTAINERS
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class FieldResult:
    key: str
    label: str
    truth: float | None
    extracted: float | None
    extracted_confidence: float
    extracted_raw_text: str
    extracted_source: str
    is_correct: bool | None    # None if no ground truth provided
    error_abs: float | None
    error_pct: float | None


@dataclass
class ImageResult:
    name: str
    image_path: Path
    elapsed_seconds: float
    layout_template: str
    layout_confidence: float
    ocr_block_count: int
    average_ocr_confidence: float
    fields: list[FieldResult] = field(default_factory=list)
    missing_fields: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    @property
    def total_fields(self) -> int:
        return len(GROUND_TRUTH.get(self.name, {}))

    @property
    def extracted_count(self) -> int:
        return sum(1 for f in self.fields if f.extracted is not None)

    @property
    def correct_count(self) -> int:
        return sum(1 for f in self.fields if f.is_correct is True)

    @property
    def has_ground_truth(self) -> bool:
        gt = GROUND_TRUTH.get(self.name, {})
        return any(v is not None for v in gt.values())

    @property
    def applicable_fields(self) -> int:
        """Number of fields where ground truth was provided."""
        gt = GROUND_TRUTH.get(self.name, {})
        return sum(1 for v in gt.values() if v is not None)


# ═══════════════════════════════════════════════════════════════════════════════
#  OCR RUNNER
# ═══════════════════════════════════════════════════════════════════════════════

def run_ocr_on_image(
    engine: EasyOcrEngine,
    extractor: InBodyExtractor,
    image_path: Path,
    image_name: str,
) -> ImageResult:
    """Run the full production OCR pipeline on a single image."""
    print(f"\n  Loading: {image_path.name} ...", end="", flush=True)
    image_bytes = image_path.read_bytes()

    start = time.perf_counter()
    preprocessed = preprocess_image(image_bytes)
    blocks = engine.extract_blocks(preprocessed.processed)
    extraction = extractor.extract(
        blocks=blocks,
        image_width=preprocessed.width,
        image_height=preprocessed.height,
    )
    elapsed = time.perf_counter() - start

    print(f" done ({elapsed:.1f}s, {len(blocks)} OCR blocks)")

    layout = extraction.get("layout", {})
    ocr_meta = extraction.get("ocr", {})
    raw_fields: dict[str, Any] = extraction.get("fields", {})

    gt = GROUND_TRUTH.get(image_name, {})
    field_results: list[FieldResult] = []

    for spec in FIELD_SPECS:
        key = spec.key
        truth = gt.get(key)
        extracted_field = raw_fields.get(key)

        extracted_value: float | None = None
        extracted_conf: float = 0.0
        extracted_raw: str = ""
        extracted_source: str = ""

        if extracted_field is not None:
            extracted_value = extracted_field.get("value")
            extracted_conf  = extracted_field.get("confidence", 0.0)
            extracted_raw   = extracted_field.get("raw_text", "")
            extracted_source = extracted_field.get("source", "")

        is_correct: bool | None = None
        error_abs: float | None = None
        error_pct: float | None = None

        if truth is not None and extracted_value is not None:
            error_abs = abs(extracted_value - truth)
            tol = FIELD_TOLERANCES.get(key, DEFAULT_TOLERANCE)

            if key in ABSOLUTE_FIELDS:
                # Use absolute tolerance for ratio/small-number fields
                is_correct = error_abs <= tol
            elif truth == 0.0:
                is_correct = error_abs <= 0.01
            else:
                error_pct = error_abs / abs(truth)
                is_correct = error_pct <= tol
        elif truth is not None and extracted_value is None:
            is_correct = False  # missed entirely

        field_results.append(
            FieldResult(
                key=key,
                label=spec.label,
                truth=truth,
                extracted=extracted_value,
                extracted_confidence=extracted_conf,
                extracted_raw_text=extracted_raw,
                extracted_source=extracted_source,
                is_correct=is_correct,
                error_abs=error_abs,
                error_pct=error_pct,
            )
        )

    return ImageResult(
        name=image_name,
        image_path=image_path,
        elapsed_seconds=elapsed,
        layout_template=layout.get("template", "Unknown"),
        layout_confidence=layout.get("confidence", 0.0),
        ocr_block_count=ocr_meta.get("block_count", 0),
        average_ocr_confidence=ocr_meta.get("average_confidence", 0.0),
        fields=field_results,
        missing_fields=extraction.get("missing_fields", []),
        warnings=extraction.get("warnings", []),
    )


# ═══════════════════════════════════════════════════════════════════════════════
#  REPORT PRINTER
# ═══════════════════════════════════════════════════════════════════════════════

PASS  = "PASS"
FAIL  = "FAIL"
MISS  = "MISS"   # not extracted at all
SKIP  = "----"   # no ground truth provided


def _status(fr: FieldResult) -> str:
    if fr.is_correct is True:
        return PASS
    if fr.is_correct is False and fr.extracted is None:
        return MISS
    if fr.is_correct is False:
        return FAIL
    return SKIP


def print_image_report(result: ImageResult) -> None:
    width = 90
    print("\n" + "=" * width)
    print(f"  IMAGE: {result.name}  |  {result.image_path.name}")
    print("=" * width)
    print(f"  Layout detected : {result.layout_template}  "
          f"(confidence={result.layout_confidence:.2%})")
    print(f"  OCR blocks      : {result.ocr_block_count}  |  "
          f"avg OCR confidence: {result.average_ocr_confidence:.2%}")
    print(f"  Elapsed time    : {result.elapsed_seconds:.1f}s")
    if result.warnings:
        for w in result.warnings:
            print(f"  WARNING: {w}")
    print()

    # Header
    col_w = [30, 10, 10, 10, 7, 7, 6]
    header = (
        f"  {'Field':<{col_w[0]}} "
        f"{'Truth':>{col_w[1]}} "
        f"{'Extracted':>{col_w[2]}} "
        f"{'RawConf':>{col_w[3]}} "
        f"{'ErrAbs':>{col_w[4]}} "
        f"{'Err%':>{col_w[5]}} "
        f"{'Status':>{col_w[6]}}"
    )
    print(header)
    print("  " + "-" * (width - 2))

    for fr in result.fields:
        status = _status(fr)
        truth_str     = f"{fr.truth:.4g}"     if fr.truth is not None else "N/A"
        ext_str       = f"{fr.extracted:.4g}" if fr.extracted is not None else "(missed)"
        conf_str      = f"{fr.extracted_confidence:.2%}" if fr.extracted is not None else ""
        err_abs_str   = f"{fr.error_abs:.4g}"  if fr.error_abs is not None else ""
        err_pct_str   = f"{fr.error_pct:.2%}"  if fr.error_pct is not None else ""

        status_label = {PASS: "[PASS]", FAIL: "[FAIL]", MISS: "[MISS]", SKIP: "[----]"}[status]

        print(
            f"  {fr.label:<{col_w[0]}} "
            f"{truth_str:>{col_w[1]}} "
            f"{ext_str:>{col_w[2]}} "
            f"{conf_str:>{col_w[3]}} "
            f"{err_abs_str:>{col_w[4]}} "
            f"{err_pct_str:>{col_w[5]}} "
            f"{status_label:>{col_w[6]+2}}"
        )

    # Summary
    print()
    print("  " + "-" * (width - 2))
    if result.has_ground_truth:
        acc = (result.correct_count / result.applicable_fields * 100
               if result.applicable_fields > 0 else 0.0)
        print(
            f"  ACCURACY: {result.correct_count}/{result.applicable_fields} fields correct "
            f"({acc:.1f}%)   |   "
            f"Extracted {result.extracted_count}/{result.total_fields} total fields"
        )
    else:
        print(
            f"  No ground truth provided.  "
            f"OCR extracted {result.extracted_count}/{result.total_fields} fields."
        )
        print()
        print("  *** Fill in GROUND_TRUTH dict and re-run to see accuracy ***")
        print()
        print("  RAW EXTRACTED VALUES (copy these to verify against the printout):")
        for fr in result.fields:
            v = f"{fr.extracted:.4g}" if fr.extracted is not None else "(not found)"
            print(f"    {fr.label:<32} -> {v}   [raw: {fr.extracted_raw_text!r}]")


def print_summary(results: list[ImageResult]) -> None:
    print("\n" + "#" * 90)
    print("  OVERALL ACCURACY SUMMARY")
    print("#" * 90)
    total_correct = 0
    total_applicable = 0
    has_any_gt = any(r.has_ground_truth for r in results)

    for r in results:
        if r.has_ground_truth:
            acc = (r.correct_count / r.applicable_fields * 100
                   if r.applicable_fields > 0 else 0.0)
            total_correct += r.correct_count
            total_applicable += r.applicable_fields
            bar_filled = int(acc / 5)
            bar = "[" + "#" * bar_filled + "-" * (20 - bar_filled) + "]"
            print(
                f"  {r.name:<14} {bar}  "
                f"{r.correct_count}/{r.applicable_fields} correct  "
                f"({acc:.1f}%)  —  {r.elapsed_seconds:.1f}s"
            )
        else:
            print(
                f"  {r.name:<14} [no ground truth]  "
                f"extracted {r.extracted_count}/{r.total_fields} fields  "
                f"—  {r.elapsed_seconds:.1f}s"
            )

    if has_any_gt and total_applicable > 0:
        overall_acc = total_correct / total_applicable * 100
        print()
        print(f"  COMBINED: {total_correct}/{total_applicable} correct  ({overall_acc:.1f}%)")
    print("#" * 90 + "\n")


# ═══════════════════════════════════════════════════════════════════════════════
#  MAIN
# ═══════════════════════════════════════════════════════════════════════════════

def main() -> None:
    print("\n" + "=" * 90)
    print("  SmartFit — OCR Accuracy Benchmark")
    print("=" * 90)

    # Validate paths
    for name, filename in TEST_IMAGES.items():
        path = TEST_IMAGES_DIR / filename
        if not path.exists():
            print(f"\nERROR: Test image not found: {path}")
            print(f"  Expected at: {TEST_IMAGES_DIR}")
            sys.exit(1)

    # Initialise OCR engine
    print("\nInitialising EasyOCR engine (first load may take ~15-30s)...")
    engine = EasyOcrEngine()
    engine.load()
    extractor = InBodyExtractor()
    print("Engine ready.\n")

    results: list[ImageResult] = []
    for name, filename in TEST_IMAGES.items():
        image_path = TEST_IMAGES_DIR / filename
        result = run_ocr_on_image(engine, extractor, image_path, name)
        print_image_report(result)
        results.append(result)

    print_summary(results)


if __name__ == "__main__":
    main()
