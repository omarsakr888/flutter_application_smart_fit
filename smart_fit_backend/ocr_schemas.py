from __future__ import annotations

from pydantic import BaseModel, ConfigDict

from core import REQUIRED_INPUT_FEATURES


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
