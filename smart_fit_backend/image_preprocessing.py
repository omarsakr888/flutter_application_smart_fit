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
    """InBody-specific preprocessing optimised for EasyOCR numerical accuracy."""
    array = np.frombuffer(image_bytes, dtype=np.uint8)
    image = cv2.imdecode(array, cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("Uploaded file is not a readable image.")

    steps: list[str] = []
    image = _resize_for_ocr(image, steps)
    image = _remove_borders(image, steps)
    image = _correct_rotation(image, steps)
    image = _deskew(image, steps)

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    steps.append("grayscale")

    gray = _reduce_shadows(gray, steps)
    gray = _normalize_brightness(gray, steps)

    denoised = cv2.fastNlMeansDenoising(gray, None, h=6, templateWindowSize=7, searchWindowSize=21)
    steps.append("denoise")

    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    contrasted = clahe.apply(denoised)
    steps.append("contrast_enhancement")

    sharpened = _sharpen(contrasted)
    steps.append("sharpness_enhancement")

    # EasyOCR reads grayscale BGR — avoid binary thresholding which destroys decimals.
    processed = cv2.cvtColor(sharpened, cv2.COLOR_GRAY2BGR)
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


def _remove_borders(image: np.ndarray, steps: list[str]) -> np.ndarray:
    """Crop uniform white/near-white margins from phone-camera captures."""
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    _, thresh = cv2.threshold(gray, 240, 255, cv2.THRESH_BINARY_INV)
    coords = cv2.findNonZero(thresh)
    if coords is None:
        return image
    x, y, w, h = cv2.boundingRect(coords)
    pad = 8
    x = max(0, x - pad)
    y = max(0, y - pad)
    w = min(image.shape[1] - x, w + 2 * pad)
    h = min(image.shape[0] - y, h + 2 * pad)
    if w < 100 or h < 100:
        return image
    cropped = image[y : y + h, x : x + w]
    if cropped.shape[0] < image.shape[0] * 0.85 or cropped.shape[1] < image.shape[1] * 0.85:
        steps.append("border_removal")
        return cropped
    return image


def _correct_rotation(image: np.ndarray, steps: list[str]) -> np.ndarray:
    """Rotate 90/180/270 when the page is clearly sideways."""
    height, width = image.shape[:2]
    if width > height * 1.25:
        steps.append("rotation_90cw")
        return cv2.rotate(image, cv2.ROTATE_90_CLOCKWISE)
    if height > width * 1.8:
        steps.append("rotation_90ccw")
        return cv2.rotate(image, cv2.ROTATE_90_COUNTERCLOCKWISE)
    return image


def _deskew(image: np.ndarray, steps: list[str]) -> np.ndarray:
    """Correct small skew angles using text-line orientation."""
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    edges = cv2.Canny(gray, 50, 150, apertureSize=3)
    lines = cv2.HoughLinesP(
        edges, 1, np.pi / 180, threshold=120, minLineLength=80, maxLineGap=10
    )
    if lines is None:
        return image

    angles: list[float] = []
    for line in lines[:40]:
        x1, y1, x2, y2 = line[0]
        if x2 - x1 == 0:
            continue
        angle = np.degrees(np.arctan2(y2 - y1, x2 - x1))
        if -15.0 <= angle <= 15.0:
            angles.append(angle)

    if not angles:
        return image

    median_angle = float(np.median(angles))
    if abs(median_angle) < 0.4:
        return image

    steps.append(f"deskew_{median_angle:.1f}deg")
    center = (image.shape[1] // 2, image.shape[0] // 2)
    matrix = cv2.getRotationMatrix2D(center, median_angle, 1.0)
    return cv2.warpAffine(
        image,
        matrix,
        (image.shape[1], image.shape[0]),
        flags=cv2.INTER_CUBIC,
        borderMode=cv2.BORDER_REPLICATE,
    )


def _reduce_shadows(gray: np.ndarray, steps: list[str]) -> np.ndarray:
    """Flatten uneven illumination from phone photos."""
    background = cv2.morphologyEx(gray, cv2.MORPH_OPEN, np.ones((25, 25), np.uint8))
    background = cv2.GaussianBlur(background, (25, 25), 0)
    normalized = cv2.divide(gray, background, scale=255)
    steps.append("shadow_reduction")
    return normalized


def _normalize_brightness(gray: np.ndarray, steps: list[str]) -> np.ndarray:
    """Stretch histogram to improve low-contrast prints."""
    steps.append("brightness_normalization")
    return cv2.normalize(gray, None, 0, 255, cv2.NORM_MINMAX)


def _sharpen(gray: np.ndarray) -> np.ndarray:
    blurred = cv2.GaussianBlur(gray, (0, 0), sigmaX=1.0)
    return cv2.addWeighted(gray, 1.5, blurred, -0.5, 0)
