"""easyocr_pipeline.py — Orchestrator

Wires together the 4-stage EasyOCR architecture.
"""
from __future__ import annotations

import logging
from typing import Any
import numpy as np

from easyocr_engine import EasyOcrEngine
from easyocr_document_analyser import EasyOcrDocumentAnalyser
from easyocr_field_extractor import EasyOcrFieldExtractor
from easyocr_response_builder import EasyOcrResponseBuilder

logger = logging.getLogger(__name__)

class EasyOcrPipeline:
    def __init__(self):
        self.engine = EasyOcrEngine()

    def process_image(self, image_np: np.ndarray) -> dict[str, Any]:
        logger.info("Stage 1: Running EasyOCR Engine & Clustering Rows...")
        # 1. Engine
        rows = self.engine.extract_clustered_rows(image_np, y_tolerance=15.0)
        
        # Flatten all text to send to the analyser
        full_text = " ".join([block.text for row in rows for block in row])
        
        logger.info("Stage 2: Analysing Document Layout and Units...")
        # 2. Analyser
        analyser = EasyOcrDocumentAnalyser(full_text)
        layout = analyser.detect_layout()
        units = analyser.detect_units()
        
        logger.info(f"Detected Layout: {layout} | Units: {units}")
        
        logger.info("Stage 3: Extracting Fields via Spatial Heuristics...")
        # 3. Extractor
        extractor = EasyOcrFieldExtractor(rows, layout)
        raw_metrics = extractor.extract_all()
        
        logger.info("Stage 4: Building Response (Conversion & Imputation)...")
        # 4. Response Builder
        builder = EasyOcrResponseBuilder(raw_metrics, layout, units)
        final_payload = builder.build()
        
        return final_payload
