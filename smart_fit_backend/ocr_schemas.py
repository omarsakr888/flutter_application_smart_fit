from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field

from core import REQUIRED_INPUT_FEATURES


class OcrFieldSchema(BaseModel):
    value: float | str | None = None
    unit: str = ""
    confidence: float = 0.0
    is_imputed: bool = False
    source_region: str = ""
    extraction_method: str = "none"
    validation_status: Literal[
        "valid", "uncertain", "missing", "imputed", "failed_validation"
    ] = "missing"
    review_action: Literal[
        "auto_accept", "request_verification", "mark_uncertain"
    ] = "mark_uncertain"


class CanonicalFieldSchema(BaseModel):
    value: float | str | None = None
    confidence: float = 0.0
    source_region: str = ""
    extraction_method: str = "none"
    validation_status: str = "missing"


class OcrExtractionResponse(BaseModel):
    """PDF Step 10 output contract (with legacy Flutter compatibility)."""
    model_config = ConfigDict(extra="allow")

    status: Literal["success"] = "success"
    extraction_id: str
    report_type: str = "InBodyUnknown"
    scan_datetime: str | None = None
    extraction_confidence: float = 0.0
    layout: dict[str, Any] = Field(default_factory=dict)
    fields: dict[str, OcrFieldSchema] = Field(default_factory=dict)
    canonical_fields: dict[str, CanonicalFieldSchema] = Field(default_factory=dict)
    missing_fields: list[str] = Field(default_factory=list)
    fields_needing_verification: list[str] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list)
    ocr: dict[str, Any] = Field(default_factory=dict)


class ConfirmScanRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    extraction_id: str | None = None
    user_id: str = "local-user"
    features: dict[str, float | int | str]

    def normalized_features(self) -> dict[str, float | str]:
        missing = [key for key in REQUIRED_INPUT_FEATURES if key not in self.features]
        if missing:
            raise ValueError("Missing required confirmed fields: " + ", ".join(missing))
        normalized = {}
        for key in REQUIRED_INPUT_FEATURES:
            if key == "User_Goal":
                normalized[key] = str(self.features[key])
            else:
                normalized[key] = float(self.features[key])
        return normalized
