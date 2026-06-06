"""user_storage.py — User auth, profile, preferences, plan, and activity log storage.

All data lives in the same SQLite database as the scan pipeline so there is only
one database file to manage.
"""
from __future__ import annotations

import hashlib
import json
import sqlite3
import uuid
from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from typing import Any

from core import DATABASE_PATH


class UserStorage:
    def __init__(self, database_path: Path = DATABASE_PATH) -> None:
        self.database_path = database_path

    # ── Schema ────────────────────────────────────────────────────────────────

    def initialize(self) -> None:
        with self._connect() as db:
            db.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id           TEXT PRIMARY KEY,
                    email        TEXT UNIQUE NOT NULL,
                    password_hash TEXT NOT NULL,
                    name         TEXT DEFAULT '',
                    created_at   TEXT NOT NULL
                )
            """)
            db.execute("""
                CREATE TABLE IF NOT EXISTS user_profiles (
                    user_id      TEXT PRIMARY KEY,
                    age          REAL,
                    gender       TEXT,
                    height       REAL,
                    weight       REAL,
                    target_weight REAL,
                    goal         TEXT,
                    updated_at   TEXT NOT NULL
                )
            """)
            db.execute("""
                CREATE TABLE IF NOT EXISTS user_preferences (
                    user_id           TEXT PRIMARY KEY,
                    diet_type         TEXT DEFAULT 'Omnivore',
                    preferred_days    INTEGER DEFAULT 4,
                    hydration_enabled INTEGER DEFAULT 1,
                    sleep_enabled     INTEGER DEFAULT 0,
                    recovery_enabled  INTEGER DEFAULT 0,
                    updated_at        TEXT NOT NULL
                )
            """)
            db.execute("""
                CREATE TABLE IF NOT EXISTS user_plans (
                    id         TEXT PRIMARY KEY,
                    user_id    TEXT NOT NULL,
                    plan_json  TEXT NOT NULL,
                    scan_id    TEXT,
                    created_at TEXT NOT NULL
                )
            """)
            db.execute("""
                CREATE INDEX IF NOT EXISTS idx_user_plans_user_created
                ON user_plans(user_id, created_at DESC)
            """)
            db.execute("""
                CREATE TABLE IF NOT EXISTS workout_logs (
                    id         TEXT PRIMARY KEY,
                    user_id    TEXT NOT NULL,
                    plan_id    TEXT,
                    day_number INTEGER,
                    rpe        INTEGER,
                    logged_at  TEXT NOT NULL
                )
            """)
            db.execute("""
                CREATE TABLE IF NOT EXISTS meal_logs (
                    id        TEXT PRIMARY KEY,
                    user_id   TEXT NOT NULL,
                    plan_id   TEXT,
                    slot_name TEXT,
                    logged_at TEXT NOT NULL
                )
            """)

    # ── Authentication ────────────────────────────────────────────────────────

    def register_user(self, email: str, password: str, name: str = "") -> dict[str, str] | None:
        """Return user dict on success, None if email already exists."""
        user_id = uuid.uuid4().hex
        pwd_hash = _hash_password(password)
        now = _now()
        try:
            with self._connect() as db:
                db.execute(
                    "INSERT INTO users (id, email, password_hash, name, created_at) VALUES (?, ?, ?, ?, ?)",
                    (user_id, email.lower().strip(), pwd_hash, name.strip(), now),
                )
            return {"user_id": user_id, "email": email.lower().strip(), "name": name.strip()}
        except sqlite3.IntegrityError:
            return None

    def login_user(self, email: str, password: str) -> dict[str, str] | None:
        """Return user dict if credentials match, None otherwise."""
        pwd_hash = _hash_password(password)
        with self._connect() as db:
            row = db.execute(
                "SELECT id, email, name FROM users WHERE email = ? AND password_hash = ?",
                (email.lower().strip(), pwd_hash),
            ).fetchone()
        if row is None:
            return None
        return {"user_id": row["id"], "email": row["email"], "name": row["name"] or ""}

    def get_user_name(self, user_id: str) -> str:
        with self._connect() as db:
            row = db.execute("SELECT name FROM users WHERE id = ?", (user_id,)).fetchone()
        return (row["name"] or "") if row else ""

    # ── Profile ───────────────────────────────────────────────────────────────

    def save_profile(
        self,
        user_id: str,
        age: float | None,
        gender: str | None,
        height: float | None,
        weight: float | None,
        target_weight: float | None,
        goal: str | None,
    ) -> None:
        now = _now()
        with self._connect() as db:
            db.execute(
                """
                INSERT INTO user_profiles
                    (user_id, age, gender, height, weight, target_weight, goal, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(user_id) DO UPDATE SET
                    age=excluded.age, gender=excluded.gender,
                    height=excluded.height, weight=excluded.weight,
                    target_weight=excluded.target_weight,
                    goal=excluded.goal, updated_at=excluded.updated_at
                """,
                (user_id, age, gender, height, weight, target_weight, goal, now),
            )

    def get_profile(self, user_id: str) -> dict[str, Any] | None:
        with self._connect() as db:
            row = db.execute(
                "SELECT * FROM user_profiles WHERE user_id = ?", (user_id,)
            ).fetchone()
        return dict(row) if row else None

    # ── Preferences ───────────────────────────────────────────────────────────

    def save_preferences(
        self,
        user_id: str,
        diet_type: str,
        preferred_days: int,
        hydration: bool,
        sleep: bool,
        recovery: bool,
    ) -> None:
        now = _now()
        with self._connect() as db:
            db.execute(
                """
                INSERT INTO user_preferences
                    (user_id, diet_type, preferred_days, hydration_enabled,
                     sleep_enabled, recovery_enabled, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(user_id) DO UPDATE SET
                    diet_type=excluded.diet_type,
                    preferred_days=excluded.preferred_days,
                    hydration_enabled=excluded.hydration_enabled,
                    sleep_enabled=excluded.sleep_enabled,
                    recovery_enabled=excluded.recovery_enabled,
                    updated_at=excluded.updated_at
                """,
                (user_id, diet_type, preferred_days, int(hydration), int(sleep), int(recovery), now),
            )

    def get_preferences(self, user_id: str) -> dict[str, Any]:
        with self._connect() as db:
            row = db.execute(
                "SELECT * FROM user_preferences WHERE user_id = ?", (user_id,)
            ).fetchone()
        if row is None:
            return {
                "diet_type": "Omnivore",
                "preferred_days": 4,
                "hydration_enabled": True,
                "sleep_enabled": False,
                "recovery_enabled": False,
            }
        return {
            "diet_type": row["diet_type"],
            "preferred_days": row["preferred_days"],
            "hydration_enabled": bool(row["hydration_enabled"]),
            "sleep_enabled": bool(row["sleep_enabled"]),
            "recovery_enabled": bool(row["recovery_enabled"]),
        }

    # ── Plans ─────────────────────────────────────────────────────────────────

    def save_plan(
        self, user_id: str, plan: dict[str, Any], scan_id: str | None = None
    ) -> str:
        plan_id = uuid.uuid4().hex
        now = _now()
        with self._connect() as db:
            db.execute(
                "INSERT INTO user_plans (id, user_id, plan_json, scan_id, created_at) VALUES (?, ?, ?, ?, ?)",
                (plan_id, user_id, json.dumps(plan), scan_id, now),
            )
        return plan_id

    def get_latest_plan(self, user_id: str) -> dict[str, Any] | None:
        with self._connect() as db:
            row = db.execute(
                """
                SELECT id, plan_json, created_at FROM user_plans
                WHERE user_id = ? ORDER BY created_at DESC LIMIT 1
                """,
                (user_id,),
            ).fetchone()
        if row is None:
            return None
        plan = json.loads(row["plan_json"])
        plan["plan_id"] = row["id"]
        plan["generated_at"] = row["created_at"]
        return plan

    # ── Activity Logs ─────────────────────────────────────────────────────────

    def log_workout(
        self,
        user_id: str,
        plan_id: str | None,
        day_number: int,
        rpe: int,
    ) -> str:
        log_id = uuid.uuid4().hex
        with self._connect() as db:
            db.execute(
                "INSERT INTO workout_logs (id, user_id, plan_id, day_number, rpe, logged_at) VALUES (?, ?, ?, ?, ?, ?)",
                (log_id, user_id, plan_id, day_number, rpe, _now()),
            )
        return log_id

    def log_meal(self, user_id: str, plan_id: str | None, slot_name: str) -> str:
        log_id = uuid.uuid4().hex
        with self._connect() as db:
            db.execute(
                "INSERT INTO meal_logs (id, user_id, plan_id, slot_name, logged_at) VALUES (?, ?, ?, ?, ?)",
                (log_id, user_id, plan_id, slot_name, _now()),
            )
        return log_id

    def get_today_meal_logs(self, user_id: str) -> list[str]:
        today = date.today().isoformat()
        with self._connect() as db:
            rows = db.execute(
                "SELECT slot_name FROM meal_logs WHERE user_id = ? AND logged_at LIKE ?",
                (user_id, f"{today}%"),
            ).fetchall()
        return [row["slot_name"] for row in rows]

    def get_today_workout_logs(self, user_id: str) -> list[dict[str, Any]]:
        today = date.today().isoformat()
        with self._connect() as db:
            rows = db.execute(
                "SELECT day_number, rpe FROM workout_logs WHERE user_id = ? AND logged_at LIKE ?",
                (user_id, f"{today}%"),
            ).fetchall()
        return [{"day_number": row["day_number"], "rpe": row["rpe"]} for row in rows]

    def get_streak(self, user_id: str) -> int:
        """Count consecutive days (from today backwards) where user logged a workout."""
        with self._connect() as db:
            rows = db.execute(
                """
                SELECT DISTINCT DATE(logged_at) AS log_date
                FROM workout_logs WHERE user_id = ?
                ORDER BY log_date DESC
                """,
                (user_id,),
            ).fetchall()
        if not rows:
            return 0
        streak = 0
        check = date.today()
        for row in rows:
            row_date = date.fromisoformat(row["log_date"])
            if row_date == check:
                streak += 1
                check -= timedelta(days=1)
            else:
                break
        return streak

    # ── Progress ──────────────────────────────────────────────────────────────

    def get_progress(self, user_id: str) -> dict[str, Any]:
        """Aggregate progress stats from confirmed scan history."""
        from scan_storage import ScanStorage  # avoid circular import at module level
        scans = ScanStorage(self.database_path).list_history(user_id=user_id, limit=50)

        weights: list[float] = []
        scan_dates: list[str] = []
        fat_masses: list[float] = []
        muscle_masses: list[float] = []

        for scan in reversed(scans):  # oldest first
            features: dict[str, Any] = scan.get("features") or {}
            w = _safe_float(features.get("Weight"))
            bfm = _safe_float(features.get("BFM_(Body_Fat_Mass)"))
            smm = _safe_float(features.get("SMM_(Skeletal_Muscle_Mass)"))
            if w is not None:
                weights.append(w)
                scan_dates.append(scan["created_at"][:10])
            if bfm is not None:
                fat_masses.append(bfm)
            if smm is not None:
                muscle_masses.append(smm)

        fat_lost = round(fat_masses[-1] - fat_masses[0], 1) if len(fat_masses) >= 2 else 0.0
        muscle_gained = round(muscle_masses[-1] - muscle_masses[0], 1) if len(muscle_masses) >= 2 else 0.0

        return {
            "total_scans": len(scans),
            "fat_lost_kg": fat_lost,
            "muscle_gained_kg": muscle_gained,
            "weight_history": weights,
            "scan_dates": scan_dates,
        }

    # ── Internals ─────────────────────────────────────────────────────────────

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.database_path)
        conn.row_factory = sqlite3.Row
        return conn


# ── Private helpers ───────────────────────────────────────────────────────────

def _hash_password(password: str) -> str:
    return hashlib.sha256(password.encode("utf-8")).hexdigest()


def _now() -> str:
    return datetime.now(UTC).isoformat()


def _safe_float(value: Any) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None
