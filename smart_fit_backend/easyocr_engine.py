"""easyocr_engine.py — CPU-bound EasyOCR initialization and row clustering.

The EasyOCR reader is cached at module scope so the model stays in RAM across
requests and is not re-initialized on every upload.
"""
from __future__ import annotations

import logging
from typing import Any

import numpy as np

from ocr_types import OcrBlock

logger = logging.getLogger(__name__)

# Module-level singleton — survives for the lifetime of the worker process.
_GLOBAL_READER: Any | None = None


def get_easyocr_reader() -> Any:
    """Return the cached EasyOCR reader, loading it on first call."""
    global _GLOBAL_READER
    if _GLOBAL_READER is not None:
        return _GLOBAL_READER

    try:
        import easyocr
    except ImportError as exc:
        raise RuntimeError(
            "EasyOCR is not installed. Run `pip install easyocr`."
        ) from exc

    try:
        import torch
        _use_gpu = torch.cuda.is_available()
    except Exception:
        _use_gpu = False

    logger.info("Initializing EasyOCR engine (gpu=%s) — model cached in RAM", _use_gpu)
    _GLOBAL_READER = easyocr.Reader(["en"], gpu=_use_gpu)
    return _GLOBAL_READER


def cluster_blocks_into_rows(
    blocks: list[OcrBlock],
    y_tolerance: float = 15.0,
) -> list[list[OcrBlock]]:
    """Group OCR blocks that share close Y-centres into left-to-right rows.

    Each incoming block is compared to the *median* Y of the current row
    (not just the last block's Y) so that a single outlier cannot chain-link
    two visually distinct lines together.
    """
    if not blocks:
        return []

    sorted_blocks = sorted(blocks, key=lambda b: b.center_y)
    rows: list[list[OcrBlock]] = []
    current_row: list[OcrBlock] = [sorted_blocks[0]]

    for block in sorted_blocks[1:]:
        row_ys = [b.center_y for b in current_row]
        row_median_y = sorted(row_ys)[len(row_ys) // 2]
        if abs(block.center_y - row_median_y) <= y_tolerance:
            current_row.append(block)
        else:
            rows.append(current_row)
            current_row = [block]

    if current_row:
        rows.append(current_row)

    for row in rows:
        row.sort(key=lambda b: b.center_x)

    return rows


class EasyOcrEngine:
    """EasyOCR engine that produces ``OcrBlock`` lists and clustered rows."""

    def __init__(self) -> None:
        self._reader: Any | None = None

    @property
    def ready(self) -> bool:
        return self._reader is not None or _GLOBAL_READER is not None

    def load(self) -> None:
        self._reader = get_easyocr_reader()

    def extract_blocks(self, image: np.ndarray) -> list[OcrBlock]:
        self.load()
        reader = self._reader or get_easyocr_reader()

        raw_results = reader.readtext(
            image,
            paragraph=False,       # keep each text region as its own block
            text_threshold=0.7,    # was 0.6 — reduces false positives from scale bars
            low_text=0.4,          # detection sensitivity for faint characters
            link_threshold=0.4,    # horizontal link threshold for detection
            width_ths=0.3,         # was 0.1 (too tight, split words) — moderate merging
            height_ths=0.5,
            contrast_ths=0.1,      # auto-adjust contrast when image is low-contrast
            adjust_contrast=0.5,   # target contrast for auto-adjustment
            min_size=10,           # ignore very small artifacts
        )

        blocks: list[OcrBlock] = []
        for bbox, text, prob in raw_results:
            text = str(text).strip()
            if not text:
                continue
            clean_bbox = [[float(point[0]), float(point[1])] for point in bbox]
            blocks.append(
                OcrBlock(text=text, confidence=float(prob), bbox=clean_bbox)
            )
        return blocks

    def extract_clustered_rows(
        self,
        image: np.ndarray,
        y_tolerance: float | None = None,
    ) -> list[list[OcrBlock]]:
        blocks = self.extract_blocks(image)
        # Default tolerance: 1.5% of image height — scales with resolution
        if y_tolerance is None:
            h = image.shape[0] if hasattr(image, "shape") else 1
            y_tolerance = max(10.0, h * 0.015)
        return cluster_blocks_into_rows(blocks, y_tolerance=y_tolerance)

    def extract_region_text(
        self,
        image: np.ndarray,
        *,
        numeric_only: bool = True,
    ) -> tuple[str, float]:
        """OCR a small cropped region; return combined text and average confidence."""
        self.load()
        reader = self._reader or get_easyocr_reader()

        if image.size == 0:
            return "", 0.0

        kwargs: dict[str, Any] = {
            "detail": 1,
            "paragraph": False,
            "width_ths": 0.3,
            "text_threshold": 0.4,
        }
        if numeric_only:
            kwargs["allowlist"] = "0123456789.,/- "

        raw_results = reader.readtext(image, **kwargs)
        if not raw_results:
            # Retry without allowlist for alphanumeric fields
            if numeric_only:
                return self.extract_region_text(image, numeric_only=False)
            return "", 0.0

        texts: list[str] = []
        confs: list[float] = []
        for _bbox, text, prob in raw_results:
            cleaned = str(text).strip()
            if cleaned:
                texts.append(cleaned)
                confs.append(float(prob))

        combined = " ".join(texts)
        avg_conf = sum(confs) / len(confs) if confs else 0.0
        return combined, round(avg_conf, 4)
