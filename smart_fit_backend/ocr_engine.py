"""ocr_engine.py — Stage 1 of the dynamic InBody OCR pipeline.

Converts the raw ``OcrBlock`` objects produced by ``PaddleOcrEngine`` into
``OcrToken`` dataclasses whose bounding-box coordinates are normalised to the
range [0, 1] relative to the image dimensions.  All downstream stages work
with normalised coordinates so they are completely resolution-independent.

This module does NOT run OCR itself — ``PaddleOcrEngine`` (paddle_ocr_engine.py)
is the low-level OCR driver; this module is a pure transformation layer.
"""
from __future__ import annotations

import math
from dataclasses import dataclass
from typing import List, Tuple

from ocr_types import OcrBlock


@dataclass
class OcrToken:
    """Single OCR token with normalised bounding-box coordinates."""

    text: str
    x: float   # centre x  (0–1 relative to image width)
    y: float   # centre y  (0–1 relative to image height)
    x1: float  # left edge  (normalised)
    y1: float  # top edge   (normalised)
    x2: float  # right edge (normalised)
    y2: float  # bottom edge (normalised)
    confidence: float

    # ── Derived geometry helpers ──────────────────────────────────────────────

    @property
    def width_norm(self) -> float:
        return max(0.0, self.x2 - self.x1)

    @property
    def height_norm(self) -> float:
        return max(0.0, self.y2 - self.y1)

    def distance_to(self, other: "OcrToken") -> float:
        return math.sqrt((self.x - other.x) ** 2 + (self.y - other.y) ** 2)


class OcrEngine:
    """
    Converts a list of ``OcrBlock`` objects into ``OcrToken`` objects with
    coordinates normalised to [0, 1] and produces a plain concatenated text
    string for semantic (regex) fallback searches.

    Usage::

        tokens, full_text = OcrEngine.from_blocks(blocks, image_width, image_height)
    """

    @staticmethod
    def from_blocks(
        blocks: List[OcrBlock],
        image_width: int,
        image_height: int,
    ) -> Tuple[List[OcrToken], str]:
        """
        Parameters
        ----------
        blocks:
            Raw ``OcrBlock`` list from ``PaddleOcrEngine.extract_blocks()``.
        image_width:
            Width of the preprocessed image in pixels.
        image_height:
            Height of the preprocessed image in pixels.

        Returns
        -------
        tokens:
            ``OcrToken`` list sorted in reading order (top→bottom, left→right).
        full_text:
            All token texts joined with ``\\n`` — used for regex fallback.
        """
        if not blocks or image_width <= 0 or image_height <= 0:
            return [], ""

        w = float(image_width)
        h = float(image_height)

        tokens: List[OcrToken] = []
        for block in blocks:
            if not block.text:
                continue

            # OcrBlock.bbox is [[x1,y1],[x2,y1],[x2,y2],[x1,y2]] in pixels
            x1 = block.left / w
            x2 = block.right / w
            y1 = block.top / h
            y2 = block.bottom / h

            # Clamp to [0, 1] to guard against tiny out-of-bounds float errors
            x1, x2 = max(0.0, min(1.0, x1)), max(0.0, min(1.0, x2))
            y1, y2 = max(0.0, min(1.0, y1)), max(0.0, min(1.0, y2))

            tokens.append(OcrToken(
                text=block.text.strip(),
                x=(x1 + x2) / 2.0,
                y=(y1 + y2) / 2.0,
                x1=x1,
                y1=y1,
                x2=x2,
                y2=y2,
                confidence=float(block.confidence),
            ))

        # Sort by reading order: bucket into horizontal bands (±1% of image
        # height), then sort left-to-right within each band.
        tokens.sort(key=lambda t: (round(t.y * 40), t.x))

        full_text = "\n".join(t.text for t in tokens)
        return tokens, full_text
