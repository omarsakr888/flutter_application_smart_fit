from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class OcrBlock:
    text: str
    confidence: float
    bbox: list[list[float]]

    @property
    def left(self) -> float:
        return min(point[0] for point in self.bbox)

    @property
    def right(self) -> float:
        return max(point[0] for point in self.bbox)

    @property
    def top(self) -> float:
        return min(point[1] for point in self.bbox)

    @property
    def bottom(self) -> float:
        return max(point[1] for point in self.bbox)

    @property
    def center_x(self) -> float:
        return (self.left + self.right) / 2

    @property
    def center_y(self) -> float:
        return (self.top + self.bottom) / 2

    @property
    def height(self) -> float:
        return max(1.0, self.bottom - self.top)

    def to_json(self) -> dict[str, Any]:
        return {
            "text": self.text,
            "confidence": round(self.confidence, 4),
            "bbox": self.bbox,
        }


@dataclass(frozen=True)
class ExtractedField:
    key: str
    label: str
    value: float
    raw_text: str
    unit: str
    confidence: float
    source: str
    bbox: list[list[float]] | None = None

    def to_json(self) -> dict[str, Any]:
        return {
            "key": self.key,
            "label": self.label,
            "value": self.value,
            "raw_text": self.raw_text,
            "unit": self.unit,
            "confidence": round(self.confidence, 4),
            "source": self.source,
            "bbox": self.bbox,
        }
