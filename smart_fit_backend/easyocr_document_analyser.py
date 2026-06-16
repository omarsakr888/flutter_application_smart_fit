"""easyocr_document_analyser.py — Stage 2: Layout & Unit Detection

This module scans the raw text payload to determine:
1. The InBody model layout (120, 270, 570)
2. The unit system (Imperial vs Metric)
"""
from __future__ import annotations

import re

class EasyOcrDocumentAnalyser:
    def __init__(self, full_text: str):
        self.full_text = full_text.upper()

    def detect_layout(self) -> str:
        """
        Scans the text for specific InBody model numbers.
        Returns 'InBody 120', 'InBody 270', or 'InBody 570'.
        Defaults to 'InBody 570' if unknown or ambiguous.
        """
        if "120" in self.full_text:
            return "InBody 120"
        if "270" in self.full_text:
            return "InBody 270"
        if "570" in self.full_text:
            return "InBody 570"
            
        return "InBody 570"  # Safe fallback

    def detect_units(self) -> str:
        """
        Checks for imperial indicators like 'LBS' or 'FT'.
        Returns 'Imperial' or 'Metric'.
        """
        # We look for explicit 'lbs' or 'ft' / 'in' standalone tokens
        if re.search(r'\b(LBS|FT|IN)\b', self.full_text):
            return "Imperial"
        return "Metric"
