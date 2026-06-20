"""inbody_extractor.py — Orchestrator for the 4-stage dynamic InBody OCR pipeline.

Public interface (unchanged from the previous engine):

    extractor = InBodyExtractor()
    result = extractor.extract(blocks, image_width, image_height)

Internally the method delegates to four independent stages:

    Stage 1 — OcrEngine         (ocr_engine.py)
    Stage 2 — DocumentAnalyser  (document_analyser.py)
    Stage 3 — FieldExtractor    (field_extractor.py)
    Stage 4 — ResponseBuilder   (response_builder.py)

This file intentionally contains NO field-specific logic, NO hardcoded
values, and NO per-model branching.  Those concerns live in the stage
modules above.

Note: ``FIELD_SPECS`` / ``FIELD_DESCRIPTORS`` are exported from this module
for backward-compatibility with ``test_ocr_accuracy.py`` (which imports the
field metadata list by name).
"""
from __future__ import annotations

import logging
from typing import Any

from document_analyser import DocumentAnalyser
from field_extractor import FIELD_DESCRIPTORS, FieldExtractor  # noqa: F401  (re-export)
from ocr_engine import OcrEngine
from ocr_types import OcrBlock
from response_builder import ResponseBuilder

logger = logging.getLogger("smart_fit_backend.ocr.extractor")

# ── Back-compat alias so any code that does ``from inbody_extractor import FIELD_SPECS``
# still works.  The test script, for example, iterates over this list.
FIELD_SPECS = FIELD_DESCRIPTORS  # type: ignore[assignment]


class InBodyExtractor:
    """
    Thin orchestrator: receives raw ``OcrBlock`` objects from ``PaddleOcrEngine``
    and runs the four-stage pipeline to produce the structured extraction dict.

    The public ``extract()`` signature is **identical** to the previous engine
    so that ``OcrService`` needs zero changes.
    """

    def __init__(self) -> None:
        self._analyser   = DocumentAnalyser()
        self._extractor  = FieldExtractor()
        self._builder    = ResponseBuilder()

    def extract(
        self,
        blocks: list[OcrBlock],
        image_width: int,
        image_height: int,
    ) -> dict[str, Any]:
        """
        Run the four-stage OCR extraction pipeline.

        Parameters
        ----------
        blocks:
            Raw ``OcrBlock`` list from ``PaddleOcrEngine.extract_blocks()``.
        image_width, image_height:
            Dimensions of the preprocessed image in pixels.

        Returns
        -------
        Extraction dict with keys:
            ``layout``, ``fields``, ``missing_fields``, ``warnings``, ``ocr``.
        """

        # ── Stage 1: Convert blocks → normalised OcrTokens ──────────────────
        tokens, full_text = OcrEngine.from_blocks(blocks, image_width, image_height)

        if not tokens:
            logger.warning("No OCR tokens produced — returning empty extraction")
            return _empty_extraction()

        logger.info(
            "Stage 1 complete: %d tokens from %d blocks (%.0f×%.0f px)",
            len(tokens), len(blocks), image_width, image_height,
        )

        # ── Stage 2: Understand document structure ───────────────────────────
        layout = self._analyser.analyse(tokens, full_text)

        logger.info(
            "Stage 2 complete: model=%s units=%s sections=%s",
            layout.model, layout.units, list(layout.sections.keys()),
        )

        # ── Stage 3: Extract field values (raw / unconverted units) ──────────
        raw_fields = self._extractor.extract_all(layout)

        found_count = sum(
            1 for f in raw_fields.values() if f.get("value") is not None
        )
        logger.info(
            "Stage 3 complete: %d/%d fields extracted",
            found_count, len(raw_fields),
        )

        # ── Stage 4: Convert units + validate + build response ───────────────
        extraction = self._builder.build(
            raw_fields=raw_fields,
            layout=layout,
            block_count=len(blocks),
        )

        logger.info(
            "Stage 4 complete: %d missing fields, %d warnings",
            len(extraction["missing_fields"]),
            len(extraction["warnings"]),
        )

        return extraction


# ─────────────────────────────────────────────────────────────────────────────
# Helper
# ─────────────────────────────────────────────────────────────────────────────

def _empty_extraction() -> dict[str, Any]:
    """Return a well-formed extraction dict when OCR produces no tokens."""
    from field_extractor import FIELD_DESCRIPTORS as _FD
    fields = {
        d.key: {
            "value": None,
            "unit": d.unit_in_output,
            "confidence": 0.0,
            "source_region": d.section_hint,
            "extraction_method": "none",
            "validation_status": "missing",
            "review_action": "mark_uncertain",
        }
        for d in _FD
    }
    missing = list(fields.keys())
    return {
        "report_type": "InBodyUnknown",
        "scan_datetime": None,
        "extraction_confidence": 0.0,
        "layout": {
            "template":   "InBodyUnknown",
            "units":      "metric",
            "confidence": 0.0,
        },
        "fields":         fields,
        "canonical_fields": {},
        "missing_fields": missing,
        "fields_needing_verification": missing,
        "warnings":       ["OCR produced no readable text from this image"],
        "ocr": {
            "engine":             "easyocr",
            "block_count":        0,
            "average_confidence": 0.0,
        },
    }
