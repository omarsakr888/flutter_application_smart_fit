"""document_analyser.py — Stage 2 of the dynamic InBody OCR pipeline.

Reads raw OCR tokens and infers the STRUCTURE of the InBody report without
extracting any field values.  Output is a ``DocumentLayout`` dataclass that
all downstream stages use to narrow their searches.

Design contract
---------------
- ONLY reads tokens; never modifies them.
- NEVER extracts numeric field values — that is Stage 3's job.
- Fuzzy-matches section headers to tolerate OCR noise.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from difflib import SequenceMatcher
from typing import Dict, List, Optional, Tuple

from ocr_engine import OcrToken
from inbody_regions import merge_sections, normalise_model_name, VERSION_ANCHORS


# ─────────────────────────────────────────────────────────────────────────────
# Output type
# ─────────────────────────────────────────────────────────────────────────────

@dataclass
class DocumentLayout:
    """Structural description of one InBody report page."""

    model: str                          # e.g. 'InBody270'
    units: str                          # 'metric' or 'imperial'
    sections: Dict[str, Tuple[float, float]]  # canonical_name → (y_start, y_end)
    has_ecw_tbw_section: bool           # True only on 570-class and above
    has_phase_angle: bool               # True only on 570-class and above
    has_segmental_rows: bool            # True on 570 (row labels), False on 120/270 (body figure)
    raw_tokens: List[OcrToken]
    full_text: str
    average_ocr_confidence: float = 0.0


# ─────────────────────────────────────────────────────────────────────────────
# Analyser
# ─────────────────────────────────────────────────────────────────────────────

class DocumentAnalyser:
    """
    Reads OCR output and infers document structure.

    Call ``analyse(tokens, full_text)`` once per image.  The result is passed
    to ``FieldExtractor`` and ``ResponseBuilder``.
    """

    # ── Section headers ───────────────────────────────────────────────────────
    # Each entry: (canonical_name, [possible OCR strings for that header])
    # Listed approximately top-to-bottom as they appear on most models.
    SECTION_HEADERS: List[Tuple[str, List[str]]] = [
        ("body_composition", [
            "Body Composition Analysis",
            "BODY COMPOSITION ANALYSIS",
            "Body Composition",
        ]),
        ("muscle_fat", [
            "Muscle-Fat Analysis",
            "Muscle Fat Analysis",
            "MUSCLE-FAT ANALYSIS",
            "Muscle-Fat",
        ]),
        ("obesity", [
            "Obesity Analysis",
            "OBESITY ANALYSIS",
        ]),
        ("segmental_lean", [
            "Segmental Lean Analysis",
            "SEGMENTAL LEAN ANALYSIS",
            "Segmental Lean",
            "Lean Mass Segments",
        ]),
        ("segmental_fat", [
            "Segmental Fat Analysis",
            "SEGMENTAL FAT ANALYSIS",
            "Segmental Fat",
        ]),
        ("ecw_tbw", [
            "ECW/TBW Analysis",
            "ECW/TBW ANALYSIS",
            "ECW TBW Analysis",
            "ECW/TBW",
        ]),
        ("research_params", [
            "Research Parameters",
            "Reasearch Parameters",  # common OCR typo
            "RESEARCH PARAMETERS",
            "Research Param",
        ]),
        ("impedance", [
            "Impedance",
            "IMPEDANCE",
        ]),
        ("bmi_lbm_control", [
            "Body Fat - Lean Body Mass Control",
            "Body Fat Lean Body Mass Control",
            "Body Fat Lean",
        ]),
        ("basal_metabolic", [
            "Basal Metabolic Rate",
            "Basal Metabolism",
        ]),
        ("visceral_fat", [
            "Visceral Fat Level",
            "Visceral Fat",
        ]),
        ("inbody_score", [
            "InBody Score",
            "INBODY SCORE",
        ]),
    ]

    # ── Model detection patterns ──────────────────────────────────────────────
    MODEL_PATTERNS: List[str] = [
        r"\[InBody(\d+)\]",
        r"InBody\s*(\d+)",
        r"inbody[\s\-_]?(\d+)",
    ]

    # ── Fuzzy-match threshold (0–1) ───────────────────────────────────────────
    # A token must achieve this similarity to count as a section header.
    SECTION_MATCH_THRESHOLD: float = 0.72

    # ─────────────────────────────────────────────────────────────────────────

    def analyse(
        self,
        tokens: List[OcrToken],
        full_text: str,
    ) -> DocumentLayout:
        """Main entry point.  Returns a ``DocumentLayout`` describing the page."""

        model   = self._detect_model(full_text)
        units   = self._detect_units(tokens, full_text)
        detected_sections = self._locate_sections(tokens)
        sections = merge_sections(detected_sections, normalise_model_name(model))

        has_ecw = (
            "ecw_tbw" in sections
            or self._text_contains_any(full_text, ["ECW/TBW Analysis", "ECW TBW Analysis"])
        )
        has_pa = self._text_contains_any(
            full_text,
            ["Phase Angle", "PhaseAngle", "phase angle"],
        )
        # 570-class has labelled rows (Right Arm, Left Arm, …) in Segmental section
        has_rows = self._text_contains_any(
            full_text,
            ["Right Arm", "Left Arm", "Right Leg", "Left Leg"],
        )

        avg_conf = (
            sum(t.confidence for t in tokens) / len(tokens)
            if tokens else 0.0
        )

        return DocumentLayout(
            model=model,
            units=units,
            sections=sections,
            has_ecw_tbw_section=has_ecw,
            has_phase_angle=has_pa,
            has_segmental_rows=has_rows,
            raw_tokens=tokens,
            full_text=full_text,
            average_ocr_confidence=round(avg_conf, 4),
        )

    # ── Private helpers ───────────────────────────────────────────────────────

    def _detect_model(self, text: str) -> str:
        """Extract the InBody model number from the OCR text."""
        lowered = text.lower()
        for model_name, anchors in VERSION_ANCHORS.items():
            if any(anchor in lowered for anchor in anchors):
                return model_name

        for pattern in self.MODEL_PATTERNS:
            m = re.search(pattern, text, re.IGNORECASE)
            if m:
                return f"InBody{m.group(1)}"

        # Structural fallback when the model tag is absent or garbled
        if self._text_contains_any(text, ["ECW/TBW Analysis", "ECW TBW Analysis"]):
            return "InBody570"
        if self._text_contains_any(text, ["Results Interpretation", "QR Code"]):
            return "InBody120"
        if self._text_contains_any(text, ["Waist-Hip Ratio", "Visceral Fat Level"]):
            return "InBody270"
        return "InBodyUnknown"

    def _detect_units(self, tokens: List[OcrToken], text: str) -> str:
        """
        Determine metric vs imperial.

        Checks for:
        - standalone 'lb' or 'lbs' tokens
        - '(lb)' or '(lbs)' unit annotations in text
        - 'X ft Y in' height format
        """
        # Check individual tokens for bare 'lb' / 'lbs'
        for tok in tokens:
            normalised = tok.text.lower().strip().strip("()./,|")
            if normalised in {"lb", "lbs"}:
                return "imperial"

        # Check parenthetical unit annotations in the raw text
        if re.search(r"\(\s*lbs?\s*\)", text, re.IGNORECASE):
            return "imperial"

        # Check for imperial height format "N ft M" or "N' M\""
        if re.search(r"\d\s*ft\s+\d", text, re.IGNORECASE):
            return "imperial"
        if re.search(r"\d\s*'\s*\d{1,2}\s*\"", text):
            return "imperial"

        return "metric"

    def _locate_sections(
        self,
        tokens: List[OcrToken],
    ) -> Dict[str, Tuple[float, float]]:
        """
        For each known section header, find its y-position in the document.

        Returns a mapping: canonical_name → (y_start, y_end)
        where y_end is either the start of the next section or y_start + 0.18.

        Strategy:
        1. Try exact substring match (fast path).
        2. Try token-level fuzzy match using SequenceMatcher.
        3. Avoid duplicate matches for the same canonical section.
        """
        found: List[Tuple[float, str]] = []  # (y_pos, canonical_name)
        matched_canonicals: set[str] = set()

        # Build a single-pass token scan
        for tok in tokens:
            tok_lower = tok.text.lower().strip()
            if len(tok_lower) < 4:
                continue  # skip very short tokens — can't be section headers

            for canonical, phrases in self.SECTION_HEADERS:
                if canonical in matched_canonicals:
                    continue

                for phrase in phrases:
                    phrase_lower = phrase.lower()

                    # Fast path: exact substring
                    if phrase_lower in tok_lower or tok_lower in phrase_lower:
                        found.append((tok.y, canonical))
                        matched_canonicals.add(canonical)
                        break

                    # Fuzzy path: SequenceMatcher ratio
                    ratio = SequenceMatcher(
                        None, tok_lower, phrase_lower
                    ).ratio()
                    if ratio >= self.SECTION_MATCH_THRESHOLD:
                        found.append((tok.y, canonical))
                        matched_canonicals.add(canonical)
                        break

        # Also try multi-token section headers by scanning consecutive lines
        # (some headers span two OCR tokens, e.g. "Segmental Lean" + "Analysis")
        found = self._scan_multi_token_headers(tokens, found, matched_canonicals)

        found.sort(key=lambda x: x[0])

        sections: Dict[str, Tuple[float, float]] = {}
        for i, (y_start, name) in enumerate(found):
            y_end = found[i + 1][0] if i + 1 < len(found) else 1.0
            sections[name] = (y_start, y_end)

        return sections

    def _scan_multi_token_headers(
        self,
        tokens: List[OcrToken],
        existing_found: List[Tuple[float, str]],
        matched_canonicals: set[str],
    ) -> List[Tuple[float, str]]:
        """
        Try to match section headers that are split across adjacent tokens.
        Groups nearby tokens on the same horizontal band and checks
        their combined text against the header phrase list.
        """
        found = list(existing_found)

        # Build lines: group tokens within 2% of image height of each other
        lines: List[List[OcrToken]] = []
        for tok in tokens:
            placed = False
            for line in lines:
                rep = line[0]
                if abs(tok.y - rep.y) < 0.025:
                    line.append(tok)
                    placed = True
                    break
            if not placed:
                lines.append([tok])

        for line in lines:
            # Sort tokens in the line left-to-right
            line_sorted = sorted(line, key=lambda t: t.x)
            line_text = " ".join(t.text for t in line_sorted).lower().strip()

            for canonical, phrases in self.SECTION_HEADERS:
                if canonical in matched_canonicals:
                    continue
                for phrase in phrases:
                    phrase_lower = phrase.lower()
                    if phrase_lower in line_text:
                        y_pos = line_sorted[0].y
                        found.append((y_pos, canonical))
                        matched_canonicals.add(canonical)
                        break

        return found

    # ── Static helpers ────────────────────────────────────────────────────────

    @staticmethod
    def _text_contains_any(text: str, phrases: List[str]) -> bool:
        text_lower = text.lower()
        return any(p.lower() in text_lower for p in phrases)
