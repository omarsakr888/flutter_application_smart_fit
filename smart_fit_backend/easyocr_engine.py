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

    logger.info("Initializing EasyOCR CPU engine (gpu=False) — model cached in RAM")
    _GLOBAL_READER = easyocr.Reader(["en"], gpu=False)
    return _GLOBAL_READER


def cluster_blocks_into_rows(
    blocks: list[OcrBlock],
    y_tolerance: float = 15.0,
) -> list[list[OcrBlock]]:
    """Group OCR blocks that share close Y-centres into left-to-right rows."""
    if not blocks:
        return []

    sorted_blocks = sorted(blocks, key=lambda b: b.center_y)
    rows: list[list[OcrBlock]] = []
    current_row: list[OcrBlock] = [sorted_blocks[0]]

    for block in sorted_blocks[1:]:
        if abs(block.center_y - current_row[-1].center_y) <= y_tolerance:
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

        raw_results = reader.readtext(image, width_ths=0.1, text_threshold=0.6)

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
        y_tolerance: float = 15.0,
    ) -> list[list[OcrBlock]]:
        blocks = self.extract_blocks(image)
        return cluster_blocks_into_rows(blocks, y_tolerance=y_tolerance)
