"""roi_utils.py — Crop and upscale normalized ROIs on preprocessed images."""
from __future__ import annotations

from dataclasses import dataclass

import cv2
import numpy as np


@dataclass(frozen=True)
class PixelRoi:
    x: int
    y: int
    w: int
    h: int

    def clamp(self, img_w: int, img_h: int) -> PixelRoi:
        x = max(0, min(self.x, img_w - 1))
        y = max(0, min(self.y, img_h - 1))
        w = max(1, min(self.w, img_w - x))
        h = max(1, min(self.h, img_h - y))
        return PixelRoi(x, y, w, h)


def normalized_to_pixel(
    roi: dict[str, float],
    img_w: int,
    img_h: int,
    *,
    pad_frac: float = 0.15,
) -> PixelRoi:
    """Convert template ROI {x,y,w,h} (0–1) to pixel crop with optional padding."""
    x = int(roi["x"] * img_w)
    y = int(roi["y"] * img_h)
    w = max(1, int(roi["w"] * img_w))
    h = max(1, int(roi["h"] * img_h))

    pad_x = int(w * pad_frac)
    pad_y = int(h * pad_frac)
    return PixelRoi(x - pad_x, y - pad_y, w + 2 * pad_x, h + 2 * pad_y).clamp(img_w, img_h)


def crop_roi(image: np.ndarray, roi: PixelRoi) -> np.ndarray:
    r = roi.clamp(image.shape[1], image.shape[0])
    return image[r.y : r.y + r.h, r.x : r.x + r.w].copy()


def upscale_for_ocr(crop: np.ndarray, min_height: int = 48) -> np.ndarray:
    """Upscale small crops so EasyOCR can read digits reliably."""
    h, w = crop.shape[:2]
    if h >= min_height:
        return crop
    factor = min_height / max(h, 1)
    return cv2.resize(
        crop,
        None,
        fx=factor,
        fy=factor,
        interpolation=cv2.INTER_CUBIC,
    )
