"""easyocr_router.py — Standalone FastAPI route for the parallel EasyOCR pipeline."""
from __future__ import annotations

import logging
from collections.abc import Callable
from typing import Any

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from easyocr_engine import EasyOcrEngine
from scan_storage import ScanStorage

logger = logging.getLogger(__name__)

_engine = EasyOcrEngine()


def build_easyocr_router(
    get_current_user: Callable[..., str],
    storage: ScanStorage,
) -> APIRouter:
    """Return an APIRouter exposing ``POST /api/v3/ocr/easyocr``."""
    router = APIRouter(tags=["easyocr"])

    @router.post("/api/v3/ocr/easyocr")
    async def extract_easyocr_scan(
        file: UploadFile = File(...),
        user_id: str = Depends(get_current_user),
    ) -> dict[str, Any]:
        try:
            import asyncio
            logger.info("Demo Mode active (default): Sleeping for 12 seconds to simulate scan...")
            await asyncio.sleep(12.0)
            
            # The 12 metrics exactly as requested by user
            extraction = {
                "layout": {
                    "template": "InBody 270",
                    "units": "metric",
                    "confidence": 0.95
                },
                "fields": {
                    "Age": {
                        "value": 51.0,
                        "unit": "yrs",
                        "confidence": 1.0,
                        "is_imputed": False
                    },
                    "Gender": {
                        "value": 0.0,  # 0.0 for Female
                        "unit": "0/1",
                        "confidence": 1.0,
                        "is_imputed": False
                    },
                    "Height": {
                        "value": 156.0,
                        "unit": "cm",
                        "confidence": 1.0,
                        "is_imputed": False
                    },
                    "Weight": {
                        "value": 59.1,
                        "unit": "kg",
                        "confidence": 1.0,
                        "is_imputed": False
                    },
                    "SMM_(Skeletal_Muscle_Mass)": {
                        "value": 19.6,
                        "unit": "kg",
                        "confidence": 1.0,
                        "is_imputed": False
                    },
                    "BMR_(Basal_Metabolic_Rate)": {
                        "value": 1154.0,
                        "unit": "kcal",
                        "confidence": 1.0,
                        "is_imputed": False
                    },
                    "FFM_of_Trunk": {
                        "value": 36.0,
                        "unit": "kg",
                        "confidence": 1.0,
                        "is_imputed": False
                    },
                    "TBW_(Total_Body_Water)": {
                        "value": 29.1,
                        "unit": "L",
                        "confidence": 1.0,
                        "is_imputed": False
                    },
                    "ECW/TBW": {
                        "value": 0.376,
                        "unit": "ratio",
                        "confidence": 1.0,
                        "is_imputed": False
                    },
                    "50kHz-Whole_Body_Phase_Angle": {
                        "value": 0.7,
                        "unit": "deg",
                        "confidence": 1.0,
                        "is_imputed": False
                    },
                    "BFM_(Body_Fat_Mass)": {
                        "value": 22.8,  # BFM_kg: 22,8
                        "unit": "kg",
                        "confidence": 1.0,
                        "is_imputed": False
                    },
                    "PBF_(Percent_Body_Fat)": {
                        "value": 38.6,
                        "unit": "%",
                        "confidence": 1.0,
                        "is_imputed": False
                    }
                },
                "missing_fields": [],
                "warnings": ["DEMO MODE: Returned hardcoded InBody 270 data"],
                "ocr": {
                    "engine": "easyocr_demo",
                    "block_count": 12,
                    "average_confidence": 1.0
                }
            }

            image_bytes = await file.read()
            image_path = storage.save_upload(image_bytes, file.filename)
            extraction_id = storage.create_extraction(
                user_id=user_id,
                image_path=image_path,
                filename=file.filename,
                content_type=file.content_type,
                extraction=extraction,
            )

            logger.info("Demo EasyOCR extraction %s completed successfully", extraction_id)
            return {
                "status": "success",
                "extraction_id": extraction_id,
                **extraction,
            }
        except Exception as exc:
            logger.exception("EasyOCR Demo pipeline failed")
            raise HTTPException(
                status_code=500,
                detail="Unable to extract InBody scan using EasyOCR Demo.",
            ) from exc

    return router


def process_easyocr_image(
    *,
    image_bytes: bytes,
    filename: str | None,
    content_type: str | None,
    user_id: str,
    storage: ScanStorage,
) -> dict[str, Any]:
    """Run the EasyOCR pipeline and persist the extraction."""
    from core import MAX_UPLOAD_BYTES
    from easyocr_extractor import EasyOcrExtractor
    from image_preprocessing import preprocess_image

    _validate_upload(image_bytes, content_type, MAX_UPLOAD_BYTES)
    preprocessed = preprocess_image(image_bytes)

    rows = _engine.extract_clustered_rows(preprocessed.processed, y_tolerance=15.0)
    blocks = [block for row in rows for block in row]
    avg_conf = (
        round(sum(block.confidence for block in blocks) / len(blocks), 4)
        if blocks
        else 0.0
    )

    extraction = EasyOcrExtractor(
        rows,
        image_width=preprocessed.width,
        image_height=preprocessed.height,
        block_count=len(blocks),
        average_confidence=avg_conf,
    ).extract()

    extraction["preprocessing"] = {"steps": preprocessed.steps}
    extraction["image"] = {
        "filename": filename,
        "content_type": content_type,
        "width": preprocessed.width,
        "height": preprocessed.height,
    }

    image_path = storage.save_upload(image_bytes, filename)
    extraction_id = storage.create_extraction(
        user_id=user_id,
        image_path=image_path,
        filename=filename,
        content_type=content_type,
        extraction=extraction,
    )

    logger.info(
        "EasyOCR extraction %s created for user=%s with %d/%d fields",
        extraction_id,
        user_id,
        sum(1 for f in extraction["fields"].values() if f.get("value") is not None),
        len(extraction["fields"]),
    )

    return {
        "status": "success",
        "extraction_id": extraction_id,
        **extraction,
    }


def _validate_upload(
    image_bytes: bytes,
    content_type: str | None,
    max_bytes: int,
) -> None:
    if not image_bytes:
        raise ValueError("Uploaded image is empty.")
    if len(image_bytes) > max_bytes:
        raise ValueError("Uploaded image is too large. Maximum size is 10 MB.")
    allowed = {"image/jpeg", "image/png", "image/webp", "image/jpg"}
    if content_type and content_type.lower() not in allowed:
        raise ValueError("Unsupported upload type. Use JPEG, PNG, or WebP.")
