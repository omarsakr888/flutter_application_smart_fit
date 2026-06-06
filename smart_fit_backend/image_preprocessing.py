from __future__ import annotations

from dataclasses import dataclass

import cv2
import numpy as np


@dataclass(frozen=True)
class PreprocessedImage:
    original: np.ndarray
    processed: np.ndarray
    width: int
    height: int
    steps: list[str]


def preprocess_image(image_bytes: bytes) -> PreprocessedImage:
    array = np.frombuffer(image_bytes, dtype=np.uint8)
    image = cv2.imdecode(array, cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("Uploaded file is not a readable image.")

    steps: list[str] = []
    image = _resize_for_ocr(image, steps)
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    steps.append("grayscale")

    denoised = cv2.fastNlMeansDenoising(gray, None, h=8, templateWindowSize=7, searchWindowSize=21)
    steps.append("denoise")

    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    contrasted = clahe.apply(denoised)
    steps.append("contrast_enhancement")

    sharpened = _sharpen(contrasted)
    steps.append("sharpen")

    thresholded = cv2.adaptiveThreshold(
        sharpened,
        255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY,
        31,
        7,
    )
    steps.append("adaptive_threshold")

    processed = cv2.cvtColor(thresholded, cv2.COLOR_GRAY2BGR)
    height, width = processed.shape[:2]
    return PreprocessedImage(
        original=image,
        processed=processed,
        width=width,
        height=height,
        steps=steps,
    )


def _resize_for_ocr(image: np.ndarray, steps: list[str]) -> np.ndarray:
    height, width = image.shape[:2]
    longest = max(width, height)
    if longest < 1600:
        scale = 1600 / longest
        steps.append(f"resize_{scale:.2f}x")
        return cv2.resize(image, None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC)
    if longest > 2600:
        scale = 2600 / longest
        steps.append(f"resize_{scale:.2f}x")
        return cv2.resize(image, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA)
    return image


def _sharpen(gray: np.ndarray) -> np.ndarray:
    blurred = cv2.GaussianBlur(gray, (0, 0), sigmaX=1.0)
    return cv2.addWeighted(gray, 1.5, blurred, -0.5, 0)
