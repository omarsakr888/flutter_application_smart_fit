"""easyocr_router.py — Production EasyOCR route for InBody scan extraction."""
from __future__ import annotations

import logging
from collections.abc import Callable
from typing import TYPE_CHECKING, Any

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile

if TYPE_CHECKING:
    from ocr_service import OcrService
    from scan_storage import ScanStorage

logger = logging.getLogger(__name__)


def build_easyocr_router(
    get_current_user: Callable[..., str],
    storage: ScanStorage,
    ocr_service: OcrService,
) -> APIRouter:
    """Return an APIRouter exposing ``POST /api/v3/ocr/easyocr``."""
    router = APIRouter(tags=["easyocr"])

    @router.post("/api/v3/ocr/easyocr")
    async def extract_easyocr_scan(
        file: UploadFile = File(...),
        include_blocks: bool = Form(False),
        user_id: str = Depends(get_current_user),
    ) -> dict[str, Any]:
        try:
            image_bytes = await file.read()
            return ocr_service.extract_scan(
                image_bytes=image_bytes,
                filename=file.filename,
                content_type=file.content_type,
                user_id=user_id,
                include_blocks=include_blocks,
            )
        except RuntimeError as exc:
            raise HTTPException(status_code=503, detail=str(exc)) from exc
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc
        except Exception as exc:
            logger.exception("EasyOCR extraction pipeline failed")
            raise HTTPException(
                status_code=500,
                detail="Unable to extract InBody scan using EasyOCR.",
            ) from exc

    return router
