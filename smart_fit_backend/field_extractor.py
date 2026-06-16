"""field_extractor.py — Stage 3 of the dynamic InBody OCR pipeline.

Contains:
  ``FieldDescriptor``  — declarative description of ONE target field (no hardcoded values).
  ``FIELD_DESCRIPTORS`` — the 12 descriptors for the fields Flutter expects.
  ``FieldExtractor``   — extraction engine (3 strategies per field).

Extraction strategies (tried in order per field):
  A. Spatial  — find label token → nearest valid numeric token in expected direction.
  B. Semantic — regex search on the plain-text string anchored to the label synonym.
  C. Structural — field-specific structural rules for difficult cases.

All returned values are in RAW units (imperial if the scan is imperial).
Unit conversion happens in Stage 4 (ResponseBuilder).
"""
from __future__ import annotations

import math
import re
from dataclasses import dataclass
from difflib import SequenceMatcher
from typing import Dict, List, Optional, Set, Tuple

from document_analyser import DocumentLayout
from ocr_engine import OcrToken


# ─────────────────────────────────────────────────────────────────────────────
# FieldDescriptor — declarative spec for one target field
# ─────────────────────────────────────────────────────────────────────────────

@dataclass
class FieldDescriptor:
    """
    Describes one target field without hardcoding any value.

    Parameters
    ----------
    key:
        The ``featureKey`` string Flutter uses (must match exactly).
    label_synonyms:
        All text strings that could label this field across InBody models.
    section_hint:
        Primary document section to search (canonical name from DocumentAnalyser).
    search_direction:
        Where the value sits relative to the label token:
        ``'right'``  — same row, to the right.
        ``'below'``  — directly below the label.
        ``'after'``  — in reading order after the label.
    value_type:
        ``'float'``, ``'int'``, or ``'gender_word'``.
    valid_range:
        ``(min, max)`` after unit conversion.  Used for final sanity check.
    unit_in_output:
        Unit string in the JSON response.
    may_be_absent:
        ``True`` if legitimately missing on some InBody models.
    secondary_section_hint:
        Fall-back section if ``section_hint`` not found.
    """

    key: str
    label_synonyms: List[str]
    section_hint: str
    search_direction: str               # 'right' | 'below' | 'after'
    value_type: str                     # 'float' | 'int' | 'gender_word'
    valid_range: Tuple[float, float]
    unit_in_output: str
    may_be_absent: bool = False
    secondary_section_hint: Optional[str] = None

    @property
    def label(self) -> str:
        """Primary human-readable label (first synonym). Used by the test script."""
        return self.label_synonyms[0] if self.label_synonyms else self.key


# ─────────────────────────────────────────────────────────────────────────────
# The 12 field descriptors — NO hardcoded values, only search metadata
# ─────────────────────────────────────────────────────────────────────────────

FIELD_DESCRIPTORS: List[FieldDescriptor] = [
    FieldDescriptor(
        key="Age",
        label_synonyms=["Age", "AGE"],
        section_hint="header",
        search_direction="right",
        value_type="int",
        valid_range=(10.0, 110.0),
        unit_in_output="yrs",
    ),
    FieldDescriptor(
        key="Gender",
        label_synonyms=["Gender", "GENDER", "Sex"],
        section_hint="header",
        search_direction="right",
        value_type="gender_word",
        valid_range=(0.0, 1.0),
        unit_in_output="0/1",
    ),
    FieldDescriptor(
        key="Height",
        label_synonyms=["Height", "HEIGHT", "Stature"],
        section_hint="header",
        search_direction="right",
        value_type="float",
        valid_range=(100.0, 230.0),   # cm after conversion
        unit_in_output="cm",
    ),
    FieldDescriptor(
        key="Weight",
        label_synonyms=["Weight", "WEIGHT", "Body Weight"],
        section_hint="body_composition",
        secondary_section_hint="muscle_fat",
        search_direction="right",
        value_type="float",
        valid_range=(25.0, 300.0),    # kg after conversion
        unit_in_output="kg",
    ),
    FieldDescriptor(
        key="SMM_(Skeletal_Muscle_Mass)",
        label_synonyms=[
            "Skeletal Muscle Mass",
            "SMM",
            "Skeletal Muscle",
            "For building muscles",
        ],
        section_hint="muscle_fat",
        secondary_section_hint="body_composition",
        search_direction="right",
        value_type="float",
        valid_range=(5.0, 80.0),      # kg after conversion
        unit_in_output="kg",
    ),
    FieldDescriptor(
        key="BMR_(Basal_Metabolic_Rate)",
        label_synonyms=[
            "Basal Metabolic Rate",
            "BMR",
            "Basal Metabolism",
            "Recommended calorie intake",
        ],
        section_hint="research_params",
        secondary_section_hint="basal_metabolic",
        search_direction="after",
        value_type="float",
        valid_range=(500.0, 5000.0),
        unit_in_output="kcal",
    ),
    FieldDescriptor(
        key="FFM_of_Trunk",
        label_synonyms=["Trunk", "TRUNK", "Torso", "Trunk FFM"],
        section_hint="segmental_lean",
        search_direction="right",
        value_type="float",
        valid_range=(5.0, 60.0),      # kg after conversion
        unit_in_output="kg",
        may_be_absent=True,
    ),
    FieldDescriptor(
        key="TBW_(Total_Body_Water)",
        label_synonyms=[
            "Total Body Water",
            "TBW",
            "Total amount of water",
            "Total Body Water (L)",
        ],
        section_hint="body_composition",
        search_direction="right",
        value_type="float",
        valid_range=(10.0, 60.0),     # litres after conversion
        unit_in_output="L",
    ),
    FieldDescriptor(
        key="ECW/TBW",
        label_synonyms=[
            "ECW/TBW",
            "ECW TBW",
            "Extracellular Water/Total Body Water",
            "ECW/TBW Ratio",
        ],
        section_hint="ecw_tbw",
        search_direction="after",
        value_type="float",
        valid_range=(0.300, 0.450),
        unit_in_output="ratio",
        may_be_absent=True,
    ),
    FieldDescriptor(
        key="50kHz-Whole_Body_Phase_Angle",
        label_synonyms=[
            "Phase Angle",
            "Whole Body Phase Angle",
            "50kHz Phase",
            "PhaseAngle",
            "PA",
        ],
        section_hint="impedance",
        secondary_section_hint="research_params",
        search_direction="right",
        value_type="float",
        valid_range=(2.0, 10.0),
        unit_in_output="deg",
        may_be_absent=True,
    ),
    FieldDescriptor(
        key="BFM_(Body_Fat_Mass)",
        label_synonyms=[
            "Body Fat Mass",
            "BFM",
            "Fat Mass",
            "For storing excess energy",
        ],
        section_hint="body_composition",
        secondary_section_hint="muscle_fat",
        search_direction="right",
        value_type="float",
        valid_range=(2.0, 150.0),     # kg after conversion
        unit_in_output="kg",
    ),
    FieldDescriptor(
        key="PBF_(Percent_Body_Fat)",
        label_synonyms=[
            "Percent Body Fat",
            "PBF",
            "% Body Fat",
            "Body Fat Percentage",
            "Percent Body Fat (%)",
            "Body Fat Percent",
        ],
        section_hint="obesity",
        secondary_section_hint="muscle_fat",
        search_direction="right",
        value_type="float",
        valid_range=(3.0, 70.0),
        unit_in_output="%",
    ),
]


# ─────────────────────────────────────────────────────────────────────────────
# FieldExtractor
# ─────────────────────────────────────────────────────────────────────────────

class FieldExtractor:
    """
    Extracts all 12 target field values from OCR tokens using three strategies.

    All returned values are in RAW document units (imperial if applicable).
    Unit conversion is handled in Stage 4 (ResponseBuilder).
    """

    # Maximum normalised distance (0–1) to search for a value near a label
    SPATIAL_SEARCH_RADIUS: float = 0.14

    # ─────────────────────────────────────────────────────────────────────────

    def extract_all(self, layout: DocumentLayout) -> Dict[str, dict]:
        """
        Returns a dict mapping ``featureKey`` ->
        ``{"value": float | None, "unit": str, "confidence": float}``.
        """
        # Pre-compute set of token values that appear >= 3 times (scale markers)
        self._scale_value_set: Set[float] = self._find_global_scale_values(layout.raw_tokens)

        results: Dict[str, dict] = {}
        for desc in FIELD_DESCRIPTORS:
            raw_val, confidence = self._extract_field(desc, layout)
            results[desc.key] = {
                "value": raw_val,
                "unit": desc.unit_in_output,
                "confidence": round(float(confidence), 4),
            }
        return results

    @staticmethod
    def _find_global_scale_values(tokens: List[OcrToken]) -> Set[float]:
        """
        Count how many times each numeric value appears across all OCR tokens.
        Values that appear 3+ times are almost certainly scale/axis markers,
        not real biomarker readings.
        Excludes very small values (< 5) and very common integers like 1/2/3.
        """
        from collections import Counter
        counts: Counter = Counter()
        for tok in tokens:
            val = None
            try:
                cleaned = re.sub(r"[^\d.\-]", "", tok.text.replace(",", "."))
                if cleaned and cleaned.count(".") <= 1:
                    val = float(cleaned)
            except (ValueError, TypeError):
                pass
            if val is not None and val >= 5.0:
                counts[val] += 1
        # Return values appearing 3+ times (scale markers)
        return {v for v, c in counts.items() if c >= 3}

    # ── Main extraction dispatch ──────────────────────────────────────────────

    def _extract_field(
        self,
        desc: FieldDescriptor,
        layout: DocumentLayout,
    ) -> Tuple[Optional[float], float]:
        """Tries Strategy A → B → C in order. Returns (raw_value, confidence)."""

        # For Height specifically: always try structural first since spatial
        # confuses it with adjacent Weight/Age values on the header table.
        if desc.key == "Height":
            val_c, conf_c = self._structural_search(desc, layout)
            if val_c is not None and self._in_range_loose(val_c, desc, layout.units):
                return val_c, conf_c
            return None, 0.0

        # For Age: structural is more reliable (avoids grabbing height values)
        if desc.key == "Age":
            val_c, conf_c = self._structural_search(desc, layout)
            if val_c is not None and self._in_range_loose(val_c, desc, layout.units):
                return val_c, conf_c
            # Fall through to spatial/semantic if structural fails

        # Strategy A — Spatial
        val_a, conf_a = self._spatial_search(desc, layout)
        if val_a is not None and self._in_range_loose(val_a, desc, layout.units):
            return val_a, conf_a

        # Strategy B — Semantic
        val_b, conf_b = self._semantic_search(desc, layout)
        if val_b is not None and self._in_range_loose(val_b, desc, layout.units):
            # Slight confidence penalty vs spatial
            return val_b, conf_b * 0.92

        # Strategy C — Structural rules for hard cases
        val_c, conf_c = self._structural_search(desc, layout)
        if val_c is not None and self._in_range_loose(val_c, desc, layout.units):
            return val_c, conf_c * 0.85

        return None, 0.0

    # ─────────────────────────────────────────────────────────────────────────
    # Strategy A — Spatial search
    # ─────────────────────────────────────────────────────────────────────────

    def _spatial_search(
        self,
        desc: FieldDescriptor,
        layout: DocumentLayout,
    ) -> Tuple[Optional[float], float]:
        """
        Find the label token in the OCR bounding boxes, then search for the
        nearest numeric token in the expected direction.
        """
        label_tokens = self._find_label_tokens(desc.label_synonyms, layout.raw_tokens)
        if not label_tokens:
            return None, 0.0

        best_val: Optional[float] = None
        best_conf: float = 0.0

        for label_tok in label_tokens:
            result = self._find_value_near_label(
                label_tok,
                layout.raw_tokens,
                desc.search_direction,
                desc.value_type,
            )
            if result is None:
                continue
            val, val_conf = result
            if not self._in_range_loose(val, desc, layout.units):
                continue
            combined = label_tok.confidence * 0.4 + val_conf * 0.6
            if combined > best_conf:
                best_val = val
                best_conf = combined

        return best_val, best_conf

    def _find_label_tokens(
        self,
        synonyms: List[str],
        tokens: List[OcrToken],
    ) -> List[OcrToken]:
        """Return tokens that match any synonym (substring or fuzzy)."""
        results: List[OcrToken] = []
        seen_ids: set[int] = set()

        for tok in tokens:
            tok_id = id(tok)
            if tok_id in seen_ids:
                continue
            t_lower = tok.text.lower().strip()
            for syn in synonyms:
                s_lower = syn.lower().strip()
                # Exact substring match (most reliable)
                if s_lower in t_lower or t_lower in s_lower:
                    results.append(tok)
                    seen_ids.add(tok_id)
                    break
                # Starts-with match for long multi-word labels
                if len(s_lower) >= 6 and t_lower.startswith(s_lower[:6]):
                    results.append(tok)
                    seen_ids.add(tok_id)
                    break
                # Fuzzy SequenceMatcher for OCR noise tolerance
                if len(s_lower) >= 4:
                    ratio = SequenceMatcher(None, t_lower, s_lower).ratio()
                    if ratio >= 0.82:
                        results.append(tok)
                        seen_ids.add(tok_id)
                        break

        return results

    def _find_value_near_label(
        self,
        label: OcrToken,
        all_tokens: List[OcrToken],
        direction: str,
        value_type: str,
    ) -> Optional[Tuple[float, float]]:
        """
        Search for a numeric value token near the label.

        direction:
          'right'  — same row (y within ±3%), to the right of label.
          'below'  — directly below label, similar x-band.
          'after'  — reading-order after label within 2× radius.
        """
        r = self.SPATIAL_SEARCH_RADIUS
        candidates: List[Tuple[float, OcrToken]] = []  # (distance, token)

        for tok in all_tokens:
            if tok is label:
                continue

            dist = label.distance_to(tok)

            if direction == "right":
                if (
                    abs(tok.y - label.y) < 0.08
                    and tok.x > label.x2
                    and (tok.x1 - label.x2) < r
                ):
                    candidates.append((dist, tok))

            elif direction == "below":
                if (
                    tok.y1 > label.y2 - 0.035
                    and (tok.y1 - label.y2) < r
                    and abs(tok.x - label.x) < r * 1.5
                ):
                    candidates.append((dist, tok))

            elif direction == "after":
                # In reading order after the label
                is_later = tok.y > label.y + 0.005 or (
                    abs(tok.y - label.y) < 0.04 and tok.x > label.x2
                )
                if is_later and dist < r * 2.5:
                    candidates.append((dist, tok))

        # Sort by proximity to the label
        candidates.sort(key=lambda x: x[0])

        for _, tok in candidates:
            parsed = self._parse_token(tok.text, value_type)
            if parsed is None:
                continue
            # Reject if this value is a known global scale marker
            if hasattr(self, '_scale_value_set') and parsed in self._scale_value_set:
                # Only skip integers / half-integers — decimals are real values
                frac = parsed - int(parsed)
                if frac in {0.0, 0.5}:
                    continue
            return parsed, tok.confidence

        return None

    # ─────────────────────────────────────────────────────────────────────────
    # Strategy B — Semantic (regex on plain text)
    # ─────────────────────────────────────────────────────────────────────────

    def _semantic_search(
        self,
        desc: FieldDescriptor,
        layout: DocumentLayout,
    ) -> Tuple[Optional[float], float]:
        """
        Search the plain-text string for label synonyms as anchors, then
        capture the first valid number following the anchor.

        Key rules:
        - Captures the number BEFORE any parenthesis (range annotation).
          e.g. "26.5 (26.4 ~ 32.2)" → captures 26.5, ignores 26.4/32.2.
        - Skips numbers that look like bar-chart scale markers.
        - For ECW/TBW: only accepts numbers in [0.30, 0.45].
        """
        text = layout.full_text

        for synonym in desc.label_synonyms:
            idx = text.lower().find(synonym.lower())
            if idx == -1:
                continue

            # Extract a window of text after the label
            window = text[idx: idx + 250]

            if desc.value_type == "gender_word":
                val = self._parse_gender_in_text(window)
                if val is not None:
                    return val, 0.88

            # Pattern: the number, then optional unit, then NOT followed by
            # another digit (to avoid slurping a date like 26.5.2024)
            number_re = re.compile(
                r"(?:^|[\s:|\n])([+-]?\d{1,4}\.?\d{0,3})"
                r"(?:\s*(?:kg|lb|lbs|kcal|cm|L|%|°|deg|yrs?))?"
                r"(?=\s*[\(\n\r]|\s*$|\s+[A-Za-z(])",
                re.MULTILINE,
            )

            for match in number_re.finditer(window):
                raw = match.group(1)
                val = self._safe_float(raw)
                if val is None:
                    continue
                if self._is_likely_scale_marker(val, window):
                    continue
                if self._in_range_loose(val, desc, layout.units):
                    return val, 0.88

        return None, 0.0

    # ─────────────────────────────────────────────────────────────────────────
    # Strategy C — Structural rules for hard cases
    # ─────────────────────────────────────────────────────────────────────────

    def _structural_search(
        self,
        desc: FieldDescriptor,
        layout: DocumentLayout,
    ) -> Tuple[Optional[float], float]:
        """Field-specific structural extraction rules."""

        key = desc.key

        if key == "Gender":
            return self._extract_gender(layout)

        if key == "Height":
            if layout.units == "imperial":
                return self._extract_height_imperial(layout)
            return self._extract_height_metric(layout)

        if key == "TBW_(Total_Body_Water)" and layout.units == "imperial":
            return self._extract_tbw_imperial(layout)

        if key == "FFM_of_Trunk" and not layout.has_segmental_rows:
            return self._extract_ffm_trunk_figure(layout)

        if key == "ECW/TBW" and layout.has_ecw_tbw_section:
            return self._extract_ecwtbw_section(layout)

        if key == "BMR_(Basal_Metabolic_Rate)":
            return self._extract_bmr_standalone(layout)

        if key == "50kHz-Whole_Body_Phase_Angle":
            return self._extract_phase_angle(layout)

        if key == "Age":
            return self._extract_age(layout)

        return None, 0.0

    # ── Structural sub-extractors ─────────────────────────────────────────────

    def _extract_gender(self, layout: DocumentLayout) -> Tuple[Optional[float], float]:
        """Gender is always a word — map Female→0, Male→1."""
        # First: look near a gender/sex label token
        label_tokens = self._find_label_tokens(
            ["Gender", "Sex", "GENDER"], layout.raw_tokens
        )
        for label_tok in label_tokens:
            # Find nearest token to the right or below
            nearby = sorted(
                [
                    t for t in layout.raw_tokens
                    if t is not label_tok
                    and (
                        (abs(t.y - label_tok.y) < 0.04 and t.x > label_tok.x)
                        or (t.y > label_tok.y and t.y - label_tok.y < 0.08
                            and abs(t.x - label_tok.x) < 0.25)
                    )
                ],
                key=lambda t: label_tok.distance_to(t),
            )
            for tok in nearby:
                val = self._parse_gender_token(tok.text)
                if val is not None:
                    return val, tok.confidence * 0.95

        # Fallback: scan full text
        val = self._parse_gender_in_text(layout.full_text)
        if val is not None:
            return val, 0.88
        return None, 0.0

    def _extract_height_metric(
        self, layout: DocumentLayout
    ) -> Tuple[Optional[float], float]:
        """
        Metric height: search for a number in [100, 230] near 'Height' label.

        Key constraint: The height value must appear on the SAME LINE or the
        line immediately following the 'Height' label token.  This prevents
        grabbing the Weight value, which is often a similar distance away
        but on a different row.
        """
        # 1. Spatial approach: find 'Height' label token, look right on same row
        for tok in layout.raw_tokens:
            t_low = tok.text.lower().strip()
            if t_low not in ("height", "height:") and not t_low.startswith("height"):
                continue
            # Search tokens to the right on the same row (y within 3%)
            same_row = [
                t for t in layout.raw_tokens
                if t is not tok
                and abs(t.y - tok.y) < 0.035
                and t.x > tok.x2
                and (t.x1 - tok.x2) < 0.30  # within 30% of image width
            ]
            same_row.sort(key=lambda t: t.x)
            for cand in same_row:
                val = self._safe_float(cand.text)
                if val is not None and 100.0 <= val <= 230.0:
                    return val, cand.confidence * 0.95

        # 2. Text-window fallback — find first valid cm value after 'Height'
        text = layout.full_text
        for synonym in ["Height", "height"]:
            idx = text.lower().find(synonym.lower())
            if idx == -1:
                continue
            # Only look in the next 80 characters (same or next line)
            window = text[idx: idx + 80]
            for m in re.finditer(r"\b(1\d{2}(?:\.\d)?|2[0-2]\d(?:\.\d)?)\b", window):
                val = self._safe_float(m.group(1))
                if val is not None and 100.0 <= val <= 230.0:
                    return val, 0.88
        return None, 0.0

    def _extract_height_imperial(
        self, layout: DocumentLayout
    ) -> Tuple[Optional[float], float]:
        """Imperial height: '5 ft 05.0 in' -> convert to cm."""
        text = layout.full_text

        # Pattern 1: "5 ft 05.0 in" or "5 ft 5.0 in" (with any whitespace/newlines)
        m = re.search(
            r"(\d{1,2})\s*ft[\s\-]*(\d{1,2}\.?\d*)\s*in",
            text,
            re.IGNORECASE | re.MULTILINE,
        )
        if m:
            feet = int(m.group(1))
            inches = float(m.group(2))
            if 1 <= feet <= 8 and 0 <= inches < 12:
                cm = feet * 30.48 + inches * 2.54
                return cm, 0.97

        # Pattern 2: "5' 5.0\"" or "5'05\""
        m2 = re.search(r"(\d{1,2})'\s*(\d{1,2}\.?\d*)(?:\"|'')?", text, re.MULTILINE)
        if m2:
            feet = int(m2.group(1))
            inches = float(m2.group(2))
            if 1 <= feet <= 8 and 0 <= inches < 12:
                cm = feet * 30.48 + inches * 2.54
                return cm, 0.93

        # Pattern 3 (Spatial Trap): The numbers '5' and '8.0' are separate tokens near 'Height'
        for tok in layout.raw_tokens:
            t_low = tok.text.lower().strip()
            if t_low not in ("height", "height:") and not t_low.startswith("height"):
                continue
            same_row = [
                t for t in layout.raw_tokens
                if t is not tok and abs(t.y - tok.y) < 0.04 and t.x > tok.x2
            ]
            same_row.sort(key=lambda t: t.x)
            
            # Find the first integer (feet) and the next float (inches)
            nums = []
            for cand in same_row[:4]:  # look at nearest 4 tokens
                val = self._safe_float(cand.text)
                if val is not None:
                    nums.append((val, cand.confidence))
            
            if len(nums) >= 2:
                feet, conf1 = nums[0]
                inches, conf2 = nums[1]
                if 1 <= feet <= 8 and feet == int(feet) and 0 <= inches < 12:
                    cm = feet * 30.48 + inches * 2.54
                    return cm, min(conf1, conf2) * 0.90

        return None, 0.0

    def _extract_tbw_imperial(
        self, layout: DocumentLayout
    ) -> Tuple[Optional[float], float]:
        """
        On imperial 570-class: TBW is in a merged table cell.
        Find the numeric token with the widest bounding box in the
        body_composition section that is in the lb-equivalent water range.
        """
        section_y = layout.sections.get("body_composition", (0.0, 0.4))
        y_lo, y_hi = section_y

        candidates: List[Tuple[float, float, float]] = []  # (box_height, val, conf)
        for tok in layout.raw_tokens:
            if not (y_lo <= tok.y <= y_hi):
                continue
            val = self._safe_float(tok.text.replace("lb", "").replace("L", "").strip())
            if val is None:
                continue
            # TBW in lbs is roughly 22–132 lb for a human (10–60 L × 2.205)
            if 22.0 <= val <= 132.0:
                box_h = tok.y2 - tok.y1
                candidates.append((box_h, val, tok.confidence))

        if candidates:
            candidates.sort(reverse=True)
            _, val, conf = candidates[0]
            return val, conf * 0.88

        return None, 0.0

    def _extract_ffm_trunk_figure(
        self, layout: DocumentLayout
    ) -> Tuple[Optional[float], float]:
        """
        On 120/270-class: body figure shows lean mass per segment.
        Trunk value is in the centre-left of the segmental_lean section.

        Strategy:
        - Scan ALL numeric tokens in the segmental_lean section.
        - Restrict to x-range 0.05–0.55 (body figure occupies left half).
        - Trunk lean is the LARGEST single-decimal value (it's the torso,
          always bigger than any limb segment).
        - Reject values that look like bar-chart scale markers.
        - Fall back to the whole page if no segmental_lean section detected.
        """
        section_y = layout.sections.get("segmental_lean")
        # If section not found, use a generous default for 120/270-class
        if section_y is None:
            # Search bottom 60% of page where segmental data usually sits
            section_y = (0.30, 1.0)
        y_lo, y_hi = section_y

        # Body figure is in left half of page
        X_MIN, X_MAX = 0.04, 0.55
        VALID_RANGE = (5.0, 60.0)

        candidates: List[Tuple[float, float, float]] = []  # (val, conf, y)
        for tok in layout.raw_tokens:
            if not (y_lo <= tok.y <= y_hi):
                continue
            if not (X_MIN <= tok.x <= X_MAX):
                continue
            clean = tok.text.replace("kg", "").replace("lb", "").strip()
            val = self._safe_float(clean)
            if val is None:
                continue
            # Must be a plausible mass with at most one decimal place
            if not (VALID_RANGE[0] <= val <= VALID_RANGE[1]):
                continue
            # Reject bare integers that look like scale markers (5, 10, 15…)
            if val == float(int(val)) and val % 5 == 0:
                continue
            candidates.append((val, tok.confidence, tok.y))

        if candidates:
            # Trunk lean is the LARGEST segment — take max
            candidates.sort(key=lambda c: c[0], reverse=True)
            val, conf, _ = candidates[0]
            return val, conf * 0.88

        return None, 0.0

    def _extract_ecwtbw_section(
        self, layout: DocumentLayout
    ) -> Tuple[Optional[float], float]:
        """
        On 570-class: ECW/TBW ratio is printed below a bar scale
        in the dedicated ECW/TBW Analysis section.
        First valid number in [0.300, 0.450] found in that section.
        """
        section_y = layout.sections.get("ecw_tbw")
        if not section_y:
            return None, 0.0

        y_lo, y_hi = section_y
        # The ratio value appears in the lower portion of the section
        y_search_from = y_lo + (y_hi - y_lo) * 0.25

        for tok in sorted(layout.raw_tokens, key=lambda t: t.y):
            if tok.y < y_search_from or tok.y > y_hi:
                continue
            val = self._safe_float(tok.text)
            if val is not None and 0.300 <= val <= 0.450:
                return val, tok.confidence * 0.96

        # Fallback: search full text for ECW/TBW followed by a valid ratio
        for synonym in ["ECW/TBW", "ECW TBW"]:
            idx = layout.full_text.lower().find(synonym.lower())
            if idx == -1:
                continue
            window = layout.full_text[idx: idx + 150]
            for m in re.finditer(r"0\.\d{3}", window):
                val = self._safe_float(m.group())
                if val is not None and 0.300 <= val <= 0.450:
                    return val, 0.85

        return None, 0.0

    def _extract_bmr_standalone(
        self, layout: DocumentLayout
    ) -> Tuple[Optional[float], float]:
        """
        BMR is sometimes a large standalone number below the section header.
        Search the research_params or basal_metabolic section for a number
        in the kcal range [500, 5000].
        """
        for section_name in ("research_params", "basal_metabolic"):
            section_y = layout.sections.get(section_name)
            if not section_y:
                continue
            y_lo, y_hi = section_y
            for tok in layout.raw_tokens:
                if not (y_lo <= tok.y <= y_hi):
                    continue
                clean = tok.text.replace("kcal", "").replace("Cal", "").strip()
                val = self._safe_float(clean)
                if val is not None and 500.0 <= val <= 5000.0:
                    return val, tok.confidence * 0.92

        # Full-text fallback: first 4-digit number after "Basal Metabolic Rate"
        for synonym in ["Basal Metabolic Rate", "BMR", "Basal Metabolism"]:
            idx = layout.full_text.lower().find(synonym.lower())
            if idx == -1:
                continue
            window = layout.full_text[idx: idx + 200]
            for m in re.finditer(r"\b(\d{3,4})\b", window):
                val = self._safe_float(m.group(1))
                if val is not None and 500.0 <= val <= 5000.0:
                    return val, 0.88

        return None, 0.0

    def _extract_phase_angle(
        self, layout: DocumentLayout
    ) -> Tuple[Optional[float], float]:
        """
        Phase angle: always a decimal like 6.4 or 7.2 — never a bare integer.
        Searches for the label spatially first, then falls back to text window.
        """
        for synonym in [
            "Phase Angle", "Whole Body Phase Angle",
            "50kHz Phase", "PhaseAngle",
        ]:
            # Spatial: find label token, get nearest decimal on same row
            for tok in layout.raw_tokens:
                if synonym.lower() not in tok.text.lower():
                    continue
                same_row = [
                    t for t in layout.raw_tokens
                    if t is not tok
                    and abs(t.y - tok.y) < 0.04
                    and t.x > tok.x2
                    and (t.x1 - tok.x2) < 0.25
                ]
                same_row.sort(key=lambda t: t.x)
                for cand in same_row:
                    val = self._safe_float(cand.text)
                    # Phase angle MUST have a decimal component — never a bare int
                    if val is not None and 2.0 <= val <= 9.9 and '.' in cand.text:
                        return val, cand.confidence * 0.95

            # Text-window fallback: require decimal notation
            idx = layout.full_text.lower().find(synonym.lower())
            if idx == -1:
                continue
            window = layout.full_text[idx: idx + 150]
            for m in re.finditer(r"\b([2-9]\.[0-9])\b", window):
                val = self._safe_float(m.group(1))
                if val is not None and 2.0 <= val <= 9.9:
                    return val, 0.90
        return None, 0.0

    def _extract_age(
        self, layout: DocumentLayout
    ) -> Tuple[Optional[float], float]:
        """
        Age extractor.

        Searches for the 'Age' label token spatially, then picks the nearest
        integer in [10, 110] that is NOT in [100, 230] (avoid grabbing height).
        Falls back to regex if spatial fails.
        """
        # 1. Spatial: find Age label, look to the right on same row
        for tok in layout.raw_tokens:
            t_low = tok.text.lower().strip().rstrip(":")
            if t_low not in ("age",):
                continue
            same_row = [
                t for t in layout.raw_tokens
                if t is not tok
                and abs(t.y - tok.y) < 0.04
                and t.x > tok.x2
                and (t.x1 - tok.x2) < 0.25
            ]
            same_row.sort(key=lambda t: t.x)
            for cand in same_row:
                val = self._safe_float(cand.text)
                # Must be a plausible age: integer, NOT in height range
                if val is not None and 10.0 <= val <= 110.0 and val != int(val) % 100:
                    if not (100.0 <= val <= 230.0):  # exclude height range
                        return val, cand.confidence * 0.95

        # 2. Regex fallback — "Age : 35" or "Age 35" pattern
        for m in re.finditer(
            r"(?:^|\s)Age\s*[:\|]?\s*(\d{1,3})(?:\s|$)",
            layout.full_text,
            re.IGNORECASE | re.MULTILINE,
        ):
            val = self._safe_float(m.group(1))
            if val is not None and 10.0 <= val <= 110.0:
                return val, 0.85
        return None, 0.0

    # ─────────────────────────────────────────────────────────────────────────
    # Range helpers
    # ─────────────────────────────────────────────────────────────────────────

    def _in_range_loose(
        self,
        value: float,
        desc: FieldDescriptor,
        units: str,
    ) -> bool:
        """
        Allow 2.5× margin on valid_range to catch values that still need
        unit conversion (done in Stage 4).  Imperial mass values are larger
        than metric equivalents (1 lb ≈ 0.454 kg), so for mass/water fields
        we expand the upper bound by × 2.5 and contract the lower by ÷ 2.5.
        """
        lo, hi = desc.valid_range

        # Imperial mass fields: their raw value is in lb (≈ 2.2× metric)
        mass_keys = {
            "Weight", "SMM_(Skeletal_Muscle_Mass)",
            "BFM_(Body_Fat_Mass)", "FFM_of_Trunk", "TBW_(Total_Body_Water)",
        }
        if units == "imperial" and desc.key in mass_keys:
            lo_loose = max(0.0, lo / 2.5)
            hi_loose = hi * 2.5  # absorb lb→kg factor
        else:
            lo_loose = max(0.0, lo / 2.5)
            hi_loose = hi * 2.5

        return lo_loose <= value <= hi_loose

    # ─────────────────────────────────────────────────────────────────────────
    # Parsing helpers
    # ─────────────────────────────────────────────────────────────────────────

    @staticmethod
    def _safe_float(text: str) -> Optional[float]:
        """Parse a float from text, returning None on failure."""
        try:
            # Replace comma-as-decimal-separator
            cleaned = re.sub(r"[^\d.\-]", "", text.replace(",", "."))
            if not cleaned or cleaned.count(".") > 1:
                return None
            val = float(cleaned)
            return None if (math.isnan(val) or math.isinf(val)) else val
        except (ValueError, TypeError):
            return None

    def _parse_token(self, text: str, value_type: str) -> Optional[float]:
        """Parse a single OCR token as the target value type."""
        if value_type == "gender_word":
            return self._parse_gender_token(text)
        val = self._safe_float(text)
        if val is None:
            return None
        if value_type == "int":
            # Must be close to an integer
            if abs(val - round(val)) > 0.4:
                return None
            return float(round(val))
        return val

    @staticmethod
    def _parse_gender_token(text: str) -> Optional[float]:
        """Map gender word token to 0 (Female) or 1 (Male)."""
        low = text.lower().strip()
        if "female" in low or low == "f":
            return 0.0
        if "male" in low or low == "m":
            return 1.0
        return None

    @staticmethod
    def _parse_gender_in_text(text: str) -> Optional[float]:
        """Search a text window for a gender word."""
        text_low = text.lower()
        if "female" in text_low:
            return 0.0
        if re.search(r"\bmale\b", text_low):
            return 1.0
        return None

    @staticmethod
    def _is_likely_scale_marker(value: float, window: str) -> bool:
        """
        Detect bar-chart scale markers (e.g. 55, 70, 85, 100, 115).
        These are evenly-spaced integers/half-integers printed along a bar.

        Also flags the exact value 0 and single-digit numbers followed by
        many similar neighbours as scale candidates.
        """
        frac = value - int(value)
        if frac not in {0.0, 0.5}:
            return False  # non-round fraction -> almost certainly a real value

        # Look for 3+ round numbers in the same short window
        raw_nums = re.findall(r"\b(\d+(?:\.0|\.5)?)\b", window[:150])
        floats = [float(n) for n in raw_nums if float(n) > 0]
        if len(floats) < 3:
            return False

        diffs = [floats[i + 1] - floats[i] for i in range(len(floats) - 1)]
        if not diffs:
            return False
        # If all diffs are roughly equal (within 2 units), it's a scale
        diff_set = {round(d) for d in diffs if d != 0}
        return len(diff_set) <= 2 and len(diff_set) > 0
