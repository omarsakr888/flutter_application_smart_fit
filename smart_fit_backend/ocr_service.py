from __future__ import annotations

import logging
from typing import Any

from core import MAX_UPLOAD_BYTES
from scan_preprocess import load_scan_image
from easyocr_engine import EasyOcrEngine
from scan_storage import ScanStorage
from template_extractor import TemplateExtractor

logger = logging.getLogger("smart_fit_backend.ocr")


class OcrService:
    """Template-aware OCR service — ROI-first extraction only."""

    def __init__(
        self,
        engine: EasyOcrEngine,
        extractor: TemplateExtractor,
        storage: ScanStorage,
    ) -> None:
        self.engine = engine
        self.extractor = extractor
        self.storage = storage

    def extract_scan(
        self,
        *,
        image_bytes: bytes,
        filename: str | None,
        content_type: str | None,
        user_id: str,
        include_blocks: bool = False,
    ) -> dict[str, Any]:
        _validate_upload(image_bytes, content_type)
        scan = load_scan_image(image_bytes)
        extraction = self.extractor.extract(scan.image)
        extraction["preprocessing"] = {"steps": scan.steps}
        extraction["image"] = {
            "filename": filename,
            "content_type": content_type,
            "width": scan.width,
            "height": scan.height,
        }
        if include_blocks:
            extraction["ocr"]["blocks"] = []

        image_path = self.storage.save_upload(image_bytes, filename)
        extraction_id = self.storage.create_extraction(
            user_id=user_id,
            image_path=image_path,
            filename=filename,
            content_type=content_type,
            extraction=extraction,
        )
        logger.info(
            "Template OCR extraction %s created for user=%s template=%s",
            extraction_id,
            user_id,
            extraction.get("template", "unknown"),
        )
        return {
            "status": "success",
            "extraction_id": extraction_id,
            **extraction,
        }


def _validate_upload(image_bytes: bytes, content_type: str | None) -> None:
    if not image_bytes:
        raise ValueError("Uploaded image is empty.")
    if len(image_bytes) > MAX_UPLOAD_BYTES:
        raise ValueError("Uploaded image is too large. Maximum size is 10 MB.")
    allowed = {"image/jpeg", "image/png", "image/webp", "image/jpg"}
    if content_type and content_type.lower() not in allowed:
        raise ValueError("Unsupported upload type. Use JPEG, PNG, or WebP.")
