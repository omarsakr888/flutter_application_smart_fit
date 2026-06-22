"""debug_logger.py — Generates OCR debug artifacts for the latest run."""

import os
import json
import shutil
import cv2
import numpy as np
from typing import Any, Dict, List

DEBUG_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "debug", "latest")

def is_debug_enabled() -> bool:
    return os.environ.get("SMARTFIT_DEBUG_OCR", "False").lower() in ("true", "1", "yes")

def init_debug_dir() -> None:
    """Clear and recreate the debug/latest/ directory."""
    if not is_debug_enabled():
        return
        
    if os.path.exists(DEBUG_DIR):
        try:
            shutil.rmtree(DEBUG_DIR)
        except Exception as e:
            print(f"Warning: could not clear debug dir: {e}")
    os.makedirs(DEBUG_DIR, exist_ok=True)
    
    # Initialize empty blocks file
    with open(os.path.join(DEBUG_DIR, "ocr_blocks.json"), "w", encoding="utf-8") as f:
        json.dump([], f)

def save_roi_crop(name: str, image_crop: np.ndarray) -> None:
    """Save an ROI crop image."""
    if not is_debug_enabled() or image_crop is None or image_crop.size == 0:
        return
    # Replace slashes and unsafe characters in name
    safe_name = name.replace("/", "_").replace("\\", "_").replace(" ", "_").lower()
    path = os.path.join(DEBUG_DIR, f"{safe_name}.png")
    cv2.imwrite(path, image_crop)

def save_ocr_blocks(blocks: List[Any], section: str) -> None:
    """Append OCR blocks to ocr_blocks.json."""
    if not is_debug_enabled():
        return
    path = os.path.join(DEBUG_DIR, "ocr_blocks.json")
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        data = []
        
    for b in blocks:
        data.append({
            "text": b.text,
            "confidence": round(b.confidence, 4),
            "bounding_box": {
                "x1": round(b.x1, 1),
                "y1": round(b.y1, 1),
                "x2": round(b.x2, 1),
                "y2": round(b.y2, 1)
            },
            "section": section
        })
        
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)

def save_extraction_report(canonical_fields: Dict[str, dict]) -> None:
    """Save the final extraction report."""
    if not is_debug_enabled():
        return
    path = os.path.join(DEBUG_DIR, "extraction_report.json")
    
    # Restructure canonical fields into the requested array format
    report = []
    for field, data in canonical_fields.items():
        report.append({
            "field": field,
            "value": data.get("value"),
            "confidence": data.get("confidence"),
            "source": data.get("source"),
            "needs_review": data.get("needs_review")
        })
        
    with open(path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
