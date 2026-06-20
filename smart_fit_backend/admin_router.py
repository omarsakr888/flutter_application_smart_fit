"""admin_router.py — Admin-only endpoints for the Smart Fit dashboard.

Authentication: every request must include the header
    X-Admin-Key: <value of ADMIN_SECRET_KEY env var>

These routes are intentionally kept separate from user-facing routes and
are NOT protected by the standard JWT flow so that an admin tool can call
them without needing a user account in the system.
"""
from __future__ import annotations

import json
import os
import sqlite3
from collections import Counter
from datetime import date
from typing import Any

from fastapi import APIRouter, Header, HTTPException, Query

from core import DATABASE_PATH

router = APIRouter(prefix="/admin", tags=["admin"])


# ── Auth helper ───────────────────────────────────────────────────────────────

def _require_admin(x_admin_key: str | None) -> None:
    expected = os.getenv("ADMIN_SECRET_KEY", "smartfit-admin-2024")
    if not x_admin_key or x_admin_key.strip() != expected:
        raise HTTPException(status_code=403, detail="Invalid or missing admin key.")


def _db() -> sqlite3.Connection:
    conn = sqlite3.connect(DATABASE_PATH)
    conn.row_factory = sqlite3.Row
    return conn


# ── /admin/stats ──────────────────────────────────────────────────────────────

@router.get("/stats")
def admin_stats(x_admin_key: str | None = Header(default=None)) -> dict[str, Any]:
    """High-level platform statistics for the admin overview card grid."""
    _require_admin(x_admin_key)
    today = date.today().isoformat()
    with _db() as db:
        total_users = db.execute("SELECT COUNT(*) AS n FROM users").fetchone()["n"]
        total_scans = db.execute(
            "SELECT COUNT(*) AS n FROM scan_extractions WHERE status = 'confirmed'"
        ).fetchone()["n"]
        total_plans = db.execute("SELECT COUNT(*) AS n FROM user_plans").fetchone()["n"]
        new_users_today = db.execute(
            "SELECT COUNT(*) AS n FROM users WHERE created_at LIKE ?",
            (f"{today}%",),
        ).fetchone()["n"]
        scans_today = db.execute(
            """SELECT COUNT(*) AS n FROM scan_extractions
               WHERE created_at LIKE ? AND status = 'confirmed'""",
            (f"{today}%",),
        ).fetchone()["n"]
        plans_today = db.execute(
            "SELECT COUNT(*) AS n FROM user_plans WHERE created_at LIKE ?",
            (f"{today}%",),
        ).fetchone()["n"]
        workout_logs_total = db.execute(
            "SELECT COUNT(*) AS n FROM workout_logs"
        ).fetchone()["n"]
        meal_logs_total = db.execute(
            "SELECT COUNT(*) AS n FROM meal_logs"
        ).fetchone()["n"]
        hydration_logs_total = db.execute(
            "SELECT COUNT(*) AS n FROM hydration_logs"
        ).fetchone()["n"]

    return {
        "total_users": total_users,
        "total_scans": total_scans,
        "total_plans": total_plans,
        "new_users_today": new_users_today,
        "scans_today": scans_today,
        "plans_today": plans_today,
        "workout_logs_total": workout_logs_total,
        "meal_logs_total": meal_logs_total,
        "hydration_logs_total": hydration_logs_total,
    }


# ── /admin/users ──────────────────────────────────────────────────────────────

@router.get("/users")
def admin_users(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    x_admin_key: str | None = Header(default=None),
) -> dict[str, Any]:
    """Paginated list of all users with profile summary and activity counts."""
    _require_admin(x_admin_key)
    with _db() as db:
        rows = db.execute(
            """
            SELECT
                u.id, u.email, u.name, u.created_at,
                u.last_login_date, u.daily_streak,
                p.age, p.gender, p.weight, p.goal,
                (SELECT COUNT(*) FROM scan_extractions s
                 WHERE s.user_id = u.id AND s.status = 'confirmed') AS scan_count,
                (SELECT COUNT(*) FROM user_plans pl
                 WHERE pl.user_id = u.id) AS plan_count,
                (SELECT COUNT(*) FROM workout_logs wl
                 WHERE wl.user_id = u.id) AS workout_count,
                (SELECT COUNT(*) FROM meal_logs ml
                 WHERE ml.user_id = u.id) AS meal_count
            FROM users u
            LEFT JOIN user_profiles p ON p.user_id = u.id
            ORDER BY u.created_at DESC
            LIMIT ? OFFSET ?
            """,
            (limit, offset),
        ).fetchall()
        total = db.execute("SELECT COUNT(*) AS n FROM users").fetchone()["n"]

    users = [
        {
            "id": r["id"],
            "email": r["email"],
            "name": r["name"] or "",
            "created_at": r["created_at"],
            "last_login_date": r["last_login_date"],
            "daily_streak": r["daily_streak"] or 0,
            "age": r["age"],
            "gender": r["gender"],
            "weight": r["weight"],
            "goal": r["goal"],
            "scan_count": r["scan_count"],
            "plan_count": r["plan_count"],
            "workout_count": r["workout_count"],
            "meal_count": r["meal_count"],
        }
        for r in rows
    ]
    return {"total": total, "users": users}


# ── /admin/ml-analytics ───────────────────────────────────────────────────────

@router.get("/ml-analytics")
def admin_ml_analytics(
    x_admin_key: str | None = Header(default=None),
) -> dict[str, Any]:
    """Aggregated ML statistics across all confirmed scans.

    Returns persona/focus-zone distribution, average confidence, and
    per-feature descriptive averages — useful for monitoring model drift.
    """
    _require_admin(x_admin_key)
    with _db() as db:
        rows = db.execute(
            """
            SELECT prediction_json, confirmed_features_json, extracted_json
            FROM scan_extractions
            WHERE status = 'confirmed' AND prediction_json IS NOT NULL
            ORDER BY created_at DESC
            LIMIT 1000
            """
        ).fetchall()

    persona_counts: Counter[str] = Counter()
    focus_zone_counts: Counter[str] = Counter()
    goal_counts: Counter[str] = Counter()
    confidences: list[float] = []
    intensity_reduced = 0

    feature_keys = [
        "Weight", "SMM_(Skeletal_Muscle_Mass)", "BFM_(Body_Fat_Mass)",
        "PBF_(Percent_Body_Fat)", "BMR_(Basal_Metabolic_Rate)",
        "ECW/TBW", "50kHz-Whole_Body_Phase_Angle",
    ]
    feature_sums: dict[str, float] = {k: 0.0 for k in feature_keys}
    feature_ns: dict[str, int] = {k: 0 for k in feature_keys}

    for row in rows:
        # ── prediction data ──────────────────────────────────────────────────
        try:
            pred = json.loads(row["prediction_json"] or "{}")
        except (json.JSONDecodeError, TypeError):
            pred = {}

        persona = str(pred.get("persona") or pred.get("focus_zone") or "Unknown")
        focus_zone = str(pred.get("focus_zone") or pred.get("persona") or "Unknown")
        confidence = _safe_float(pred.get("confidence") or pred.get("ml_confidence"), 0.0)
        persona_counts[persona] += 1
        focus_zone_counts[focus_zone] += 1
        confidences.append(confidence)
        if pred.get("intensity_reduced"):
            intensity_reduced += 1

        # ── feature averages ─────────────────────────────────────────────────
        try:
            feats = json.loads(row["confirmed_features_json"] or "{}")
            goal = feats.get("User_Goal")
            if goal:
                goal_counts[str(goal)] += 1
            for key in feature_keys:
                val = _safe_float(feats.get(key))
                if val is not None:
                    feature_sums[key] += val
                    feature_ns[key] += 1
        except (json.JSONDecodeError, TypeError):
            pass

    total = sum(persona_counts.values()) or 1

    feature_averages = [
        {
            "key": key,
            "label": _FEATURE_LABEL.get(key, key),
            "unit": _FEATURE_UNIT.get(key, ""),
            "avg": round(feature_sums[key] / feature_ns[key], 2) if feature_ns[key] else None,
            "n": feature_ns[key],
        }
        for key in feature_keys
    ]

    avg_conf = round(sum(confidences) / len(confidences) * 100, 1) if confidences else 0.0

    return {
        "total_analyzed": total,
        "avg_confidence_pct": avg_conf,
        "intensity_reduced_count": intensity_reduced,
        "persona_distribution": _dist_list(persona_counts, total),
        "focus_zone_distribution": _dist_list(focus_zone_counts, total),
        "goal_distribution": _dist_list(goal_counts, sum(goal_counts.values()) or 1),
        "feature_averages": feature_averages,
    }


# ── /admin/scans ──────────────────────────────────────────────────────────────

@router.get("/scans")
def admin_scans(
    limit: int = Query(40, ge=1, le=100),
    offset: int = Query(0, ge=0),
    x_admin_key: str | None = Header(default=None),
) -> dict[str, Any]:
    """Paginated list of all confirmed scans with prediction and user info."""
    _require_admin(x_admin_key)
    with _db() as db:
        rows = db.execute(
            """
            SELECT s.id, s.user_id, s.status, s.created_at, s.filename,
                   s.prediction_json, s.extracted_json,
                   u.email, u.name
            FROM scan_extractions s
            LEFT JOIN users u ON u.id = s.user_id
            ORDER BY s.created_at DESC
            LIMIT ? OFFSET ?
            """,
            (limit, offset),
        ).fetchall()
        total = db.execute(
            "SELECT COUNT(*) AS n FROM scan_extractions"
        ).fetchone()["n"]

    scans = []
    for r in rows:
        try:
            pred = json.loads(r["prediction_json"] or "{}")
        except (json.JSONDecodeError, TypeError):
            pred = {}
        try:
            extracted = json.loads(r["extracted_json"] or "{}")
        except (json.JSONDecodeError, TypeError):
            extracted = {}

        scans.append({
            "id": r["id"],
            "user_email": r["email"] or r["user_id"],
            "user_name": r["name"] or "",
            "status": r["status"],
            "created_at": r["created_at"],
            "filename": r["filename"],
            "report_type": extracted.get("report_type", ""),
            "extraction_confidence": _safe_float(extracted.get("extraction_confidence"), 0.0),
            "persona": str(pred.get("persona") or pred.get("focus_zone") or ""),
            "focus_zone": str(pred.get("focus_zone") or pred.get("persona") or ""),
            "ml_confidence": _safe_float(pred.get("confidence") or pred.get("ml_confidence"), 0.0),
            "intensity_reduced": bool(pred.get("intensity_reduced", False)),
            "target_calories": _safe_float(pred.get("target_calories")),
        })

    return {"total": total, "scans": scans}


# ── Helpers ───────────────────────────────────────────────────────────────────

_FEATURE_LABEL: dict[str, str] = {
    "Weight": "Body Weight",
    "SMM_(Skeletal_Muscle_Mass)": "Skeletal Muscle",
    "BFM_(Body_Fat_Mass)": "Body Fat Mass",
    "PBF_(Percent_Body_Fat)": "Body Fat %",
    "BMR_(Basal_Metabolic_Rate)": "Basal Metabolic Rate",
    "ECW/TBW": "ECW / TBW Ratio",
    "50kHz-Whole_Body_Phase_Angle": "Phase Angle",
}

_FEATURE_UNIT: dict[str, str] = {
    "Weight": "kg",
    "SMM_(Skeletal_Muscle_Mass)": "kg",
    "BFM_(Body_Fat_Mass)": "kg",
    "PBF_(Percent_Body_Fat)": "%",
    "BMR_(Basal_Metabolic_Rate)": "kcal",
    "ECW/TBW": "ratio",
    "50kHz-Whole_Body_Phase_Angle": "°",
}


def _dist_list(counter: Counter[str], total: int) -> list[dict[str, Any]]:
    return [
        {
            "label": k,
            "count": v,
            "pct": round(v / total * 100, 1) if total > 0 else 0.0,
        }
        for k, v in sorted(counter.items(), key=lambda x: -x[1])
    ]


def _safe_float(value: Any, default: float | None = None) -> float | None:
    if value is None:
        return default
    try:
        return float(value)
    except (TypeError, ValueError):
        return default
