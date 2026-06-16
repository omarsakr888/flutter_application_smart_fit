"""easyocr_field_extractor.py — Stage 3: Spatial Heuristics

This module applies layout-specific spatial rules to extract the 12 core metrics
from the clustered rows of EasyOCR blocks.
"""
from __future__ import annotations

import re
import math
from typing import Any

from ocr_types import OcrBlock

# The 12 target keys:
# Age, Gender, Height, Weight, SMM_(Skeletal_Muscle_Mass), BMR_(Basal_Metabolic_Rate),
# FFM_of_Trunk, TBW_(Total_Body_Water), ECW/TBW, 50kHz-Whole_Body_Phase_Angle,
# BFM_(Body_Fat_Mass), PBF_(Percent_Body_Fat)

class EasyOcrFieldExtractor:
    def __init__(self, rows: list[list[OcrBlock]], layout: str):
        self.rows = rows
        self.layout = layout
        self.blocks = [block for row in rows for block in row]

        # Pre-compute document width and height for relative scaling
        if self.blocks:
            self.doc_width = max(b.right for b in self.blocks)
            self.doc_height = max(b.bottom for b in self.blocks)
        else:
            self.doc_width = 1.0
            self.doc_height = 1.0

    def extract_all(self) -> dict[str, float | None]:
        results: dict[str, float | None] = {}
        
        # Core fields
        results["Age"] = self._extract_age()
        results["Gender"] = self._extract_gender()
        results["Height"] = self._extract_height()
        results["Weight"] = self._extract_basic_right("Weight")
        results["SMM_(Skeletal_Muscle_Mass)"] = self._extract_basic_right("Skeletal Muscle")
        results["BMR_(Basal_Metabolic_Rate)"] = self._extract_basic_right("Basal Metabolic")
        results["BFM_(Body_Fat_Mass)"] = self._extract_basic_right("Body Fat Mass")
        results["PBF_(Percent_Body_Fat)"] = self._extract_basic_right("Percent Body Fat")
        
        # Traps
        results["FFM_of_Trunk"] = self._extract_trunk_ffm()
        results["TBW_(Total_Body_Water)"] = self._extract_tbw()
        results["ECW/TBW"] = self._extract_ecw_tbw()
        results["50kHz-Whole_Body_Phase_Angle"] = self._extract_phase_angle()

        return results

    # --- Utility Helpers ---
    def _find_block_by_text(self, pattern: str) -> OcrBlock | None:
        regex = re.compile(pattern, re.IGNORECASE)
        for b in self.blocks:
            if regex.search(b.text):
                return b
        return None

    def _extract_float_from_text(self, text: str) -> float | None:
        # Extracts the first float or int found in a string
        match = re.search(r'\d+\.\d+|\d+', text.replace(',', '.'))
        if match:
            return float(match.group())
        return None

    def _extract_basic_right(self, label_pattern: str, y_tolerance: float = 20.0) -> float | None:
        label_block = self._find_block_by_text(label_pattern)
        if not label_block:
            return None
            
        candidates = []
        for b in self.blocks:
            # Must be to the right of the label
            if b.center_x > label_block.right:
                # Must be on roughly the same horizontal line
                if abs(b.center_y - label_block.center_y) <= y_tolerance:
                    val = self._extract_float_from_text(b.text)
                    if val is not None:
                        dist = b.center_x - label_block.right
                        candidates.append((dist, val))
                        
        if candidates:
            # Sort by X distance to get the closest number to the right
            candidates.sort(key=lambda x: x[0])
            return candidates[0][1]
        return None

    def _extract_basic_below(self, label_pattern: str, x_tolerance: float = 50.0) -> float | None:
        label_block = self._find_block_by_text(label_pattern)
        if not label_block:
            return None
            
        candidates = []
        for b in self.blocks:
            # Must be below the label
            if b.center_y > label_block.bottom:
                # Must be roughly in the same vertical column
                if abs(b.center_x - label_block.center_x) <= x_tolerance:
                    val = self._extract_float_from_text(b.text)
                    if val is not None:
                        dist = b.center_y - label_block.bottom
                        candidates.append((dist, val))
                        
        if candidates:
            # Sort by Y distance to get the closest number below
            candidates.sort(key=lambda x: x[0])
            return candidates[0][1]
        return None

    # --- Specific Field Extractors ---
    
    def _extract_age(self) -> float | None:
        return self._extract_basic_right("Age")
        
    def _extract_gender(self) -> float | None:
        # Encode Male = 1.0, Female = 0.0
        label_block = self._find_block_by_text("Gender")
        if not label_block:
            return None
        for b in self.blocks:
            if b.center_x > label_block.right and abs(b.center_y - label_block.center_y) < 20:
                text = b.text.lower()
                if "m" in text and "f" not in text:
                    return 1.0
                if "f" in text:
                    return 0.0
        return None
        
    def _extract_height(self) -> float | None:
        # On 570 imperial, it might look like "5 ft 10.0 in". We return raw floats or parse it.
        # Actually, if it's imperial, response_builder handles the conversion if we pass it correctly.
        # Let's just extract the first number here. Wait, if it says "5 ft 10.0 in", we might only extract "5".
        # Let's extract the full raw text for height and let response_builder handle it? 
        # For simplicity, if we see 'ft' and 'in' in the same block, we compute here or pass.
        # The prompt says response_builder handles: "If the analyser detects Imperial, convert height to cm ((ft*12)+in)*2.54"
        # So we should just extract the text as a string? But the return type is float.
        # Let's just pass the parsed float. If it's "5 ft 10.0 in", we can parse it here easily since the extractor is where we see the text.
        # But let's stick to the prompt: response builder converts. So we return the float.
        # If it's split into multiple blocks, it's tricky.
        label_block = self._find_block_by_text("Height")
        if not label_block:
            return None
            
        candidates = []
        for b in self.blocks:
            if b.center_x > label_block.right and abs(b.center_y - label_block.center_y) < 20:
                text = b.text.lower()
                # Check for imperial pattern in the block
                match = re.search(r'(\d+)\s*ft\s*(\d+\.?\d*)\s*in', text)
                if match:
                    ft = float(match.group(1))
                    inches = float(match.group(2))
                    # Pass as a special float format? Or just return the raw string?
                    # The prompt says: "convert height to cm ((ft*12)+in)*2.54"
                    # We will return the decimal inches representation, or just do the conversion here.
                    # Since response builder expects a float, if we return it here in cm, we can skip it there or just do it here.
                    # Let's just do it here for height to be safe.
                    return ((ft * 12) + inches) * 2.54
                else:
                    val = self._extract_float_from_text(text)
                    if val is not None:
                        candidates.append((b.center_x - label_block.right, val))
                        
        if candidates:
            candidates.sort(key=lambda x: x[0])
            return candidates[0][1]
        return None

    def _extract_trunk_ffm(self) -> float | None:
        """
        Trap A: For 120/270, Trunk FFM is located in the physical center of the body diagram.
        Extract the highest mass value within the central X-axis band (30% to 55% of image width).
        """
        if self.layout not in ["InBody 120", "InBody 270"]:
            return self._extract_basic_right("Trunk") # Fallback for 570

        band_start = self.doc_width * 0.30
        band_end = self.doc_width * 0.55
        
        # Find the "Segmental Lean Analysis" header to bound our Y search
        seg_header = self._find_block_by_text("Segmental Lean")
        y_min = seg_header.bottom if seg_header else 0.0
        
        max_mass = 0.0
        found = False
        
        for b in self.blocks:
            if b.center_y > y_min and band_start <= b.center_x <= band_end:
                val = self._extract_float_from_text(b.text)
                if val is not None:
                    if val > max_mass:
                        max_mass = val
                        found = True
                        
        return max_mass if found else None

    def _extract_tbw(self) -> float | None:
        """
        Trap B: In 570, TBW is a large merged cell.
        Look to the right of 'Total Body Water', but allow a wider Y-axis tolerance.
        """
        if self.layout == "InBody 570":
            return self._extract_basic_right("Total Body Water", y_tolerance=40.0)
        return self._extract_basic_right("Total Body Water")

    def _extract_ecw_tbw(self) -> float | None:
        """
        Trap C: In 570, ECW/TBW is below a scale bar.
        Find 'ECW/TBW', gather valid ratios [0.300, 0.450], and select the one with the highest Y-coordinate.
        """
        if self.layout != "InBody 570":
            return self._extract_basic_right("ECW/TBW")

        header = self._find_block_by_text("ECW/TBW")
        if not header:
            return None

        candidates = []
        for b in self.blocks:
            # Must be below the header
            if b.center_y > header.bottom:
                val = self._extract_float_from_text(b.text)
                if val is not None and 0.300 <= val <= 0.450:
                    candidates.append((b.center_y, val))

        if candidates:
            # Sort by Y descending (highest Y = lowest on the physical page)
            candidates.sort(key=lambda x: x[0], reverse=True)
            return candidates[0][1] # Return the first one (highest Y)

        return None

    def _extract_phase_angle(self) -> float | None:
        return self._extract_basic_right("Phase Angle")
