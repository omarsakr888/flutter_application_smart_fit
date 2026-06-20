"""scan_preprocess.py — Minimal image prep for template ROI OCR."""
from __future__ import annotations

from dataclasses import dataclass

import cv2
import numpy as np


@dataclass(frozen=True)
class ScanImage:
    image: np.ndarray
    width: int
    height: int
    steps: list[str]


def load_scan_image(image_bytes: bytes) -> ScanImage:
    """Decode image with minimal changes — heavy preprocessing hurts EasyOCR on InBody scans."""
    array = np.frombuffer(image_bytes, dtype=np.uint8)
    image = cv2.imdecode(array, cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("Uploaded file is not a readable image.")

    steps: list[str] = ["decode"]
    h, w = image.shape[:2]
    longest = max(w, h)

    # Upscale small scans so ROI crops have enough pixels
    if longest < 1200:
        scale = 1200 / longest
        image = cv2.resize(image, None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC)
        steps.append(f"upscale_{scale:.2f}x")

    height, width = image.shape[:2]
    return ScanImage(image=image, width=width, height=height, steps=steps)
