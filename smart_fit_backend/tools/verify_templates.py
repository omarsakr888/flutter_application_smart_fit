"""tools/verify_templates.py — Step 1: ROI overlay verification.

Draws every section ROI (blue) and every per-field ROI (green/red) on the
three reference scans and saves annotated PNGs to:

    debug/template_verification/
        120_overlay.png
        270_overlay.png
        570_overlay.png

Usage (from the project root):
    python smart_fit_backend/tools/verify_templates.py

Requires: opencv-python (already in requirements.txt)
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import cv2
import numpy as np

# ── Paths ─────────────────────────────────────────────────────────────────────
ROOT = Path(__file__).resolve().parents[2]
BACKEND = ROOT / "smart_fit_backend"
TEMPLATES_DIR = BACKEND / "templates"
SCANS_DIR = ROOT / "test_inbody_versions"
DEBUG_DIR = ROOT / "debug" / "template_verification"
ROI_DEBUG_DIR = ROOT / "debug" / "rois"
DEBUG_DIR.mkdir(parents=True, exist_ok=True)

# ── Colour palette (BGR) ──────────────────────────────────────────────────────
COL_SECTION   = (200, 160, 0)    # blue-ish for section boxes
COL_FIELD     = (0, 200, 60)     # green for field ROIs
COL_FIELD_ABS = (0, 100, 255)    # orange for absent fields
COL_EXCLUSION = (50, 50, 220)    # red for exclusion zones
COL_TEXT      = (0, 0, 0)        # black text
ALPHA         = 0.25             # overlay transparency

# ── Template ↔ scan mapping ───────────────────────────────────────────────────
VERSIONS = [
    ("InBody120", "120_template.json", "inbody120.png"),
    ("InBody270", "270_template.json", "inbody270.png"),
    ("InBody570", "570_template.json", "inbody570.png"),
]

# All per-field ROI keys in the template JSON
FIELD_ROI_KEYS = [
    "age_roi", "gender_roi", "height_roi",
    "weight_roi", "smm_roi", "bmr_roi",
    "tbw_roi", "segmental_ffm_roi",
    "ecw_tbw_roi", "phase_angle_roi",
    "bfm_roi", "pbf_roi",
]


def load_image(path: Path) -> np.ndarray:
    img = cv2.imread(str(path))
    if img is None:
        raise FileNotFoundError(f"Could not read image: {path}")
    return img


def draw_roi(
    overlay: np.ndarray,
    canvas: np.ndarray,
    roi: dict,
    img_w: int,
    img_h: int,
    colour: tuple,
    label: str,
    thickness: int = 2,
) -> None:
    """Draw a filled semi-transparent rectangle + border + label."""
    x = int(roi["x"] * img_w)
    y = int(roi["y"] * img_h)
    w = max(1, int(roi["w"] * img_w))
    h = max(1, int(roi["h"] * img_h))
    x2, y2 = min(x + w, img_w - 1), min(y + h, img_h - 1)

    # Semi-transparent fill on overlay
    cv2.rectangle(overlay, (x, y), (x2, y2), colour, -1)
    # Solid border on canvas
    cv2.rectangle(canvas, (x, y), (x2, y2), colour, thickness)

    # Label — small text above the box
    font = cv2.FONT_HERSHEY_SIMPLEX
    font_scale = 0.38
    (tw, th), _ = cv2.getTextSize(label, font, font_scale, 1)
    ty = max(y - 3, th + 2)
    cv2.rectangle(canvas, (x, ty - th - 2), (x + tw + 2, ty + 2), (255, 255, 255), -1)
    cv2.putText(canvas, label, (x + 1, ty), font, font_scale, COL_TEXT, 1, cv2.LINE_AA)


def process_version(version_id: str, tmpl_file: str, scan_file: str) -> None:
    tmpl_path = TEMPLATES_DIR / tmpl_file
    scan_path = SCANS_DIR / scan_file

    if not tmpl_path.exists():
        print(f"  [SKIP] Template not found: {tmpl_path}")
        return
    if not scan_path.exists():
        print(f"  [SKIP] Scan not found: {scan_path}")
        return

    with tmpl_path.open(encoding="utf-8") as fh:
        template = json.load(fh)

    img = load_image(scan_path)
    img_h, img_w = img.shape[:2]
    print(f"  {version_id}: {scan_file} ({img_w}×{img_h})")

    canvas = img.copy()
    overlay = img.copy()

    # ── Draw section ROIs ──────────────────────────────────────────────────
    for sec_name, sec_data in template.get("sections", {}).items():
        roi = sec_data.get("roi")
        if roi:
            draw_roi(overlay, canvas, roi, img_w, img_h,
                     COL_SECTION, f"§{sec_name}", thickness=1)

    # ── Draw exclusion zones ───────────────────────────────────────────────
    for zone in template.get("exclusion_zones", []):
        roi = zone.get("roi")
        if roi:
            draw_roi(overlay, canvas, roi, img_w, img_h,
                     COL_EXCLUSION, f"EXCL:{zone.get('name','?')}", thickness=1)

    # ── Draw per-field ROIs ────────────────────────────────────────────────
    for roi_key in FIELD_ROI_KEYS:
        field = template.get(roi_key)
        if field is None:
            continue

        absent = field.get("present") is False
        roi = field.get("roi")
        if roi is None:
            continue  # absent fields with no ROI

        colour = COL_FIELD_ABS if absent else COL_FIELD
        short = roi_key.replace("_roi", "").upper()
        draw_roi(overlay, canvas, roi, img_w, img_h, colour, short, thickness=2)

        # ── Save individual field crop for debugging ───────────────────────
        if not absent:
            field_dir = ROI_DEBUG_DIR / version_id
            field_dir.mkdir(parents=True, exist_ok=True)
            fx = max(0, int(roi["x"] * img_w) - 4)
            fy = max(0, int(roi["y"] * img_h) - 4)
            fw = min(int(roi["w"] * img_w) + 8, img_w - fx)
            fh = min(int(roi["h"] * img_h) + 8, img_h - fy)
            crop = img[fy:fy + fh, fx:fx + fw]
            out_path = field_dir / f"{roi_key}.png"
            cv2.imwrite(str(out_path), crop)

    # ── Blend overlay ──────────────────────────────────────────────────────
    final = cv2.addWeighted(overlay, ALPHA, canvas, 1 - ALPHA, 0)

    # ── Legend ────────────────────────────────────────────────────────────
    legend_items = [
        (COL_SECTION,   "Section ROI"),
        (COL_FIELD,     "Field ROI (active)"),
        (COL_FIELD_ABS, "Field ROI (absent)"),
        (COL_EXCLUSION, "Exclusion zone"),
    ]
    lx, ly = 5, img_h - 5 - len(legend_items) * 18
    for col, text in legend_items:
        cv2.rectangle(final, (lx, ly), (lx + 12, ly + 12), col, -1)
        cv2.putText(final, text, (lx + 16, ly + 11),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.38, (0, 0, 0), 1, cv2.LINE_AA)
        ly += 18

    out_path = DEBUG_DIR / f"{version_id.lower().replace('inbody', '')}_overlay.png"
    cv2.imwrite(str(out_path), final)
    print(f"    -> Saved overlay: {out_path.relative_to(ROOT)}")
    print(f"    -> Saved field crops: debug/rois/{version_id}/")


def main() -> None:
    print("\n" + "=" * 70)
    print("  SmartFit — Template ROI Verification (Step 1)")
    print("=" * 70)

    for version_id, tmpl_file, scan_file in VERSIONS:
        process_version(version_id, tmpl_file, scan_file)

    print("\nDone. Check debug/template_verification/ for overlay images.")
    print("Check debug/rois/<version>/ for individual field crops.\n")


if __name__ == "__main__":
    main()
