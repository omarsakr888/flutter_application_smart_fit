from __future__ import annotations

import logging
import os
from typing import Any

# ── PaddleX / PaddleOCR v3 — Windows CPU oneDNN crash fix ────────────────────
# Root cause: PaddleX reads PADDLE_PDX_ENABLE_MKLDNN_BYDEFAULT at import time
# (paddlex/utils/flags.py line 61).  When True (the default), get_default_run_mode()
# returns 'mkldnn' on Intel CPUs, which causes static_infer.py to call
# config.enable_mkldnn().  The Windows PIR executor then crashes with:
#   NotImplementedError: ConvertPirAttribute2RuntimeAttribute not support
#   pir::ArrayAttribute<pir::DoubleAttribute>  (onednn_instruction.cc:118)
# Setting the env var to '0' BEFORE any paddlex import forces run_mode='paddle'.
os.environ.setdefault("PADDLE_PDX_ENABLE_MKLDNN_BYDEFAULT", "0")
os.environ.setdefault("PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK", "True")
# ─────────────────────────────────────────────────────────────────────────────

import numpy as np

from ocr_types import OcrBlock

logger = logging.getLogger("smart_fit_backend.ocr.engine")


class PaddleOcrEngine:
    def __init__(self) -> None:
        self._engine: Any | None = None

    @property
    def ready(self) -> bool:
        return self._engine is not None

    def load(self) -> None:
        if self._engine is not None:
            return

        # Re-assert the env var as a safety net (should already be set at module
        # level above, but guard against any edge case that clears it).
        os.environ["PADDLE_PDX_ENABLE_MKLDNN_BYDEFAULT"] = "0"

        try:
            from paddleocr import PaddleOCR
        except ImportError as exc:
            raise RuntimeError(
                "PaddleOCR is not installed. Install backend requirements before OCR extraction."
            ) from exc

        logger.info("Initializing PaddleOCR CPU engine (mkldnn disabled via PADDLE_PDX_ENABLE_MKLDNN_BYDEFAULT=0)")
        try:
            self._engine = PaddleOCR(
                lang="en",
                ocr_version="PP-OCRv4",
                use_doc_orientation_classify=False,
                use_doc_unwarping=False,
                use_angle_cls=False,
                text_det_box_thresh=0.45,
                text_det_unclip_ratio=1.7,
                device="cpu",
            )
        except TypeError:
            self._engine = PaddleOCR(
                lang="en",
                ocr_version="PP-OCRv4",
                use_angle_cls=False,
                show_log=False,
                use_gpu=False,
                det_db_box_thresh=0.45,
                det_db_unclip_ratio=1.7,
            )

    def extract_blocks(self, image: np.ndarray) -> list[OcrBlock]:
        self.load()
        try:
            result = self._engine.ocr(image)
        except TypeError:
            result = self._engine.ocr(image, cls=True)
        return _parse_paddle_result(result)


def _parse_paddle_result(result: Any) -> list[OcrBlock]:
    blocks: list[OcrBlock] = []
    pages = result or []
    for page in pages:
        if isinstance(page, dict):
            blocks.extend(_parse_paddle_v3_page(page))
    if blocks:
        return blocks

    if pages and isinstance(pages[0], list) and pages[0] and _looks_like_ocr_line(pages[0][0]):
        pages = pages[0]

    for item in pages:
        if not _looks_like_ocr_line(item):
            continue
        bbox = [[float(x), float(y)] for x, y in item[0]]
        text = str(item[1][0]).strip()
        confidence = float(item[1][1])
        if text:
            blocks.append(OcrBlock(text=text, confidence=confidence, bbox=bbox))
    return blocks


def _parse_paddle_v3_page(page: dict[str, Any]) -> list[OcrBlock]:
    texts = page.get("rec_texts") or page.get("texts") or []
    scores = page.get("rec_scores") or page.get("scores") or []
    boxes = (
        page.get("rec_polys")
        or page.get("dt_polys")
        or page.get("text_det_polys")
        or page.get("rec_boxes")
        or []
    )
    blocks: list[OcrBlock] = []
    for text, score, box in zip(texts, scores, boxes, strict=False):
        bbox = _coerce_bbox(box)
        if bbox is None:
            continue
        clean_text = str(text).strip()
        if clean_text:
            blocks.append(OcrBlock(text=clean_text, confidence=float(score), bbox=bbox))
    return blocks


def _coerce_bbox(box: Any) -> list[list[float]] | None:
    points = np.asarray(box, dtype=float)
    if points.shape == (4,):
        left, top, right, bottom = points.tolist()
        return [[left, top], [right, top], [right, bottom], [left, bottom]]
    if points.shape[0] >= 4 and points.shape[-1] == 2:
        return [[float(x), float(y)] for x, y in points[:4]]
    return None


def _looks_like_ocr_line(item: Any) -> bool:
    return (
        isinstance(item, list | tuple)
        and len(item) >= 2
        and isinstance(item[1], list | tuple)
        and len(item[1]) >= 2
    )
