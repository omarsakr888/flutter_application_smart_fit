"""template_loader.py — Load editable InBody report templates."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from core import TEMPLATES_DIR

_TEMPLATE_CACHE: dict[str, dict[str, Any]] = {}


def list_template_ids() -> list[str]:
    return ["InBody120", "InBody270", "InBody570"]


def template_path(report_type: str) -> Path:
    mapping = {
        "InBody120": "120_template.json",
        "InBody270": "270_template.json",
        "InBody570": "570_template.json",
    }
    key = report_type.replace("-class", "").replace(" ", "")
    if key not in mapping:
        # Normalise variants like InBody270-class
        if "570" in key:
            key = "InBody570"
        elif "270" in key:
            key = "InBody270"
        elif "120" in key:
            key = "InBody120"
        else:
            raise ValueError(f"Unknown report type: {report_type}")
    return TEMPLATES_DIR / mapping[key]


def load_template(report_type: str) -> dict[str, Any]:
    key = report_type.replace("-class", "").replace(" ", "")
    if "570" in key:
        key = "InBody570"
    elif "270" in key:
        key = "InBody270"
    elif "120" in key:
        key = "InBody120"

    if key in _TEMPLATE_CACHE:
        return _TEMPLATE_CACHE[key]

    path = template_path(key)
    if not path.exists():
        raise FileNotFoundError(f"Template not found: {path}")

    with path.open(encoding="utf-8") as fh:
        template = json.load(fh)
    _TEMPLATE_CACHE[key] = template
    return template


def load_all_templates() -> dict[str, dict[str, Any]]:
    return {tid: load_template(tid) for tid in list_template_ids()}
