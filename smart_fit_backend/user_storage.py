"""user_storage.py — User auth, profile, preferences, plan, activity logs, and achievements.

All data lives in the same SQLite database as the scan pipeline.
"""
from __future__ import annotations

import hashlib  # kept for backward-compat SHA-256 check only
import json
import sqlite3
import uuid
from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from typing import Any

import bcrypt as _bcrypt

from core import DATABASE_PATH

# Achievement definitions ─────────────────────────────────────────────────────

_ACHIEVEMENT_META: dict[str, dict[str, str]] = {
    "first_scan": {
        "name": "First Scan",
        "description": "Completed your first InBody scan",
        "icon": "document_scanner",
    },
    "7_day_streak": {
        "name": "7-Day Streak",
        "description": "Logged workouts for 7 consecutive days",
        "icon": "local_fire_department",
    },
    "30_day_streak": {
        "name": "30-Day Streak",
        "description": "Logged workouts for 30 consecutive days",
        "icon": "emoji_events",
    },
    "muscle_gainer_2kg": {
        "name": "Muscle Gainer",
        "description": "Gained 2 kg or more of skeletal muscle",
        "icon": "fitness_center",
    },
    "fat_burner_5_percent": {
        "name": "Fat Burner",
        "description": "Reduced body fat percentage by 5 % or more",
        "icon": "whatshot",
    },
}

# SQL migrations — applied once on startup; errors (column exists) are swallowed
_COLUMN_MIGRATIONS = [
    "ALTER TABLE users ADD COLUMN last_login_date TEXT",
    "ALTER TABLE users ADD COLUMN daily_streak INTEGER DEFAULT 0",
    "ALTER TABLE workout_logs ADD COLUMN exercises_completed TEXT DEFAULT '[]'",
    "ALTER TABLE workout_logs ADD COLUMN duration_minutes INTEGER DEFAULT 0",
    "ALTER TABLE meal_logs ADD COLUMN calories_consumed REAL DEFAULT 0",
]


class UserStorage:
    def __init__(self, database_path: Path = DATABASE_PATH) -> None:
        self.database_path = database_path

    # ── Schema ────────────────────────────────────────────────────────────────

    def initialize(self) -> None:
        with self._connect() as db:
            db.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id               TEXT PRIMARY KEY,
                    email            TEXT UNIQUE NOT NULL,
                    password_hash    TEXT NOT NULL,
                    name             TEXT DEFAULT '',
                    last_login_date  TEXT,
                    daily_streak     INTEGER DEFAULT 0,
                    created_at       TEXT NOT NULL
                )
            """)
            db.execute("""
                CREATE TABLE IF NOT EXISTS user_profiles (
                    user_id       TEXT PRIMARY KEY,
                    age           REAL,
                    gender        TEXT,
                    height        REAL,
                    weight        REAL,
                    target_weight REAL,
                    goal          TEXT,
                    updated_at    TEXT NOT NULL
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
                    id                   TEXT PRIMARY KEY,
                    user_id              TEXT NOT NULL,
                    plan_id              TEXT,
                    day_number           INTEGER,
                    rpe                  INTEGER,
                    exercises_completed  TEXT DEFAULT '[]',
                    duration_minutes     INTEGER DEFAULT 0,
                    logged_at            TEXT NOT NULL
                )
            """)
            db.execute("""
                CREATE TABLE IF NOT EXISTS meal_logs (
                    id               TEXT PRIMARY KEY,
                    user_id          TEXT NOT NULL,
                    plan_id          TEXT,
                    slot_name        TEXT,
                    calories_consumed REAL DEFAULT 0,
                    logged_at        TEXT NOT NULL
                )
            """)
            db.execute("""
                CREATE TABLE IF NOT EXISTS user_achievements (
                    id               TEXT PRIMARY KEY,
                    user_id          TEXT NOT NULL,
                    achievement_type TEXT NOT NULL,
                    earned_at        TEXT NOT NULL,
                    UNIQUE(user_id, achievement_type)
                )
            """)
            db.execute("""
                CREATE TABLE IF NOT EXISTS hydration_logs (
                    id        TEXT PRIMARY KEY,
                    user_id   TEXT NOT NULL,
                    cups      INTEGER NOT NULL DEFAULT 1,
                    logged_at TEXT NOT NULL
                )
            """)

        # Run column migrations for databases created before this schema version
        with self._connect() as db:
            for sql in _COLUMN_MIGRATIONS:
                try:
                    db.execute(sql)
                except sqlite3.OperationalError:
                    pass  # column already exists

    # ── Authentication ────────────────────────────────────────────────────────

    def register_user(self, email: str, password: str, name: str = "") -> dict[str, str] | None:
        user_id = uuid.uuid4().hex
        pwd_hash = _bcrypt.hashpw(password.encode(), _bcrypt.gensalt()).decode()
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
        with self._connect() as db:
            row = db.execute(
                "SELECT id, email, name, password_hash FROM users WHERE email = ?",
                (email.lower().strip(),),
            ).fetchone()
        if row is None:
            return None

        stored_hash: str = row["password_hash"]
        if not _verify_password(password, stored_hash):
            return None

        # If the stored hash is a legacy SHA-256 hex, upgrade it to bcrypt now.
        if len(stored_hash) == 64 and not stored_hash.startswith("$2"):
            new_hash = _bcrypt.hashpw(password.encode(), _bcrypt.gensalt()).decode()
            with self._connect() as db:
                db.execute(
                    "UPDATE users SET password_hash = ? WHERE id = ?",
                    (new_hash, row["id"]),
                )

        self._record_login(row["id"])
        return {"user_id": row["id"], "email": row["email"], "name": row["name"] or ""}

    def social_login_or_create(self, email: str, name: str, provider: str) -> dict[str, str]:
        """Find an existing account by email or create one for a social provider."""
        email = email.lower().strip()
        with self._connect() as db:
            row = db.execute(
                "SELECT id, email, name FROM users WHERE email = ?", (email,)
            ).fetchone()
        if row:
            self._record_login(row["id"])
            return {"user_id": row["id"], "email": row["email"], "name": row["name"] or ""}
        user_id = uuid.uuid4().hex
        sentinel = f"SOCIAL:{provider}:{user_id}"
        pwd_hash = _bcrypt.hashpw(sentinel.encode(), _bcrypt.gensalt()).decode()
        with self._connect() as db:
            db.execute(
                "INSERT INTO users (id, email, password_hash, name, created_at) VALUES (?, ?, ?, ?, ?)",
                (user_id, email, pwd_hash, name.strip(), _now()),
            )
        self._record_login(user_id)
        return {"user_id": user_id, "email": email, "name": name.strip()}

    def _record_login(self, user_id: str) -> None:
        today = date.today().isoformat()
        with self._connect() as db:
            row = db.execute(
                "SELECT last_login_date, daily_streak FROM users WHERE id = ?", (user_id,)
            ).fetchone()
            if row is None:
                return
            last = row["last_login_date"]
            streak = row["daily_streak"] or 0
            if last == today:
                return  # already logged in today
            yesterday = (date.today() - timedelta(days=1)).isoformat()
            new_streak = (streak + 1) if last == yesterday else 1
            db.execute(
                "UPDATE users SET last_login_date = ?, daily_streak = ? WHERE id = ?",
                (today, new_streak, user_id),
            )

    def get_user_name(self, user_id: str) -> str:
        with self._connect() as db:
            row = db.execute("SELECT name FROM users WHERE id = ?", (user_id,)).fetchone()
        return (row["name"] or "") if row else ""

    def get_user_streak(self, user_id: str) -> int:
        with self._connect() as db:
            row = db.execute(
                "SELECT daily_streak FROM users WHERE id = ?", (user_id,)
            ).fetchone()
        return (row["daily_streak"] or 0) if row else 0

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
                (user_id, age, gender, height, weight, target_weight, goal, _now()),
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
                (user_id, diet_type, preferred_days, int(hydration), int(sleep), int(recovery), _now()),
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
        with self._connect() as db:
            db.execute(
                "INSERT INTO user_plans (id, user_id, plan_json, scan_id, created_at) VALUES (?, ?, ?, ?, ?)",
                (plan_id, user_id, json.dumps(plan), scan_id, _now()),
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
        exercises_completed: list[str] | None = None,
        duration_minutes: int = 0,
    ) -> str:
        log_id = uuid.uuid4().hex
        with self._connect() as db:
            db.execute(
                """INSERT INTO workout_logs
                    (id, user_id, plan_id, day_number, rpe, exercises_completed, duration_minutes, logged_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    log_id, user_id, plan_id, day_number, rpe,
                    json.dumps(exercises_completed or []),
                    duration_minutes, _now(),
                ),
            )
        return log_id

    def log_meal(
        self,
        user_id: str,
        plan_id: str | None,
        slot_name: str,
        calories_consumed: float = 0,
    ) -> str:
        log_id = uuid.uuid4().hex
        with self._connect() as db:
            db.execute(
                """INSERT INTO meal_logs
                    (id, user_id, plan_id, slot_name, calories_consumed, logged_at)
                    VALUES (?, ?, ?, ?, ?, ?)""",
                (log_id, user_id, plan_id, slot_name, calories_consumed, _now()),
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

    def get_today_meal_calories(self, user_id: str) -> float:
        today = date.today().isoformat()
        with self._connect() as db:
            row = db.execute(
                """SELECT COALESCE(SUM(calories_consumed), 0) AS total
                   FROM meal_logs WHERE user_id = ? AND logged_at LIKE ?""",
                (user_id, f"{today}%"),
            ).fetchone()
        return float(row["total"]) if row else 0.0

    def get_today_workout_logs(self, user_id: str) -> list[dict[str, Any]]:
        today = date.today().isoformat()
        with self._connect() as db:
            rows = db.execute(
                "SELECT day_number, rpe, duration_minutes FROM workout_logs WHERE user_id = ? AND logged_at LIKE ?",
                (user_id, f"{today}%"),
            ).fetchall()
        return [
            {"day_number": r["day_number"], "rpe": r["rpe"], "duration_minutes": r["duration_minutes"]}
            for r in rows
        ]

    def get_daily_progress(self, user_id: str, target_date: str) -> dict[str, Any]:
        """Return calorie and workout summary for a specific date (YYYY-MM-DD)."""
        with self._connect() as db:
            meal_row = db.execute(
                """SELECT COALESCE(SUM(calories_consumed), 0) AS consumed,
                          COUNT(*) AS meal_count
                   FROM meal_logs WHERE user_id = ? AND logged_at LIKE ?""",
                (user_id, f"{target_date}%"),
            ).fetchone()
            workout_row = db.execute(
                """SELECT COUNT(*) AS completed FROM workout_logs
                   WHERE user_id = ? AND logged_at LIKE ?""",
                (user_id, f"{target_date}%"),
            ).fetchone()

        # Pull calorie target from latest plan
        plan = self.get_latest_plan(user_id)
        calories_target = 0.0
        workouts_total = 0
        if plan:
            calories_target = float(
                plan.get("nutrition", {}).get("target_calories_kcal", 0)
            )
            workouts_total = len(plan.get("training", {}).get("workout_split", []))

        return {
            "date": target_date,
            "calories_consumed": float(meal_row["consumed"]) if meal_row else 0.0,
            "calories_target": calories_target,
            "meals_logged": int(meal_row["meal_count"]) if meal_row else 0,
            "workouts_completed": int(workout_row["completed"]) if workout_row else 0,
            "workouts_total": workouts_total,
        }

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

    # ── Achievements ──────────────────────────────────────────────────────────

    def get_achievements(self, user_id: str) -> list[dict[str, Any]]:
        with self._connect() as db:
            rows = db.execute(
                "SELECT achievement_type, earned_at FROM user_achievements WHERE user_id = ?",
                (user_id,),
            ).fetchall()
        earned_map = {r["achievement_type"]: r["earned_at"] for r in rows}

        result = []
        for atype, meta in _ACHIEVEMENT_META.items():
            result.append({
                "type": atype,
                "name": meta["name"],
                "description": meta["description"],
                "icon": meta["icon"],
                "earned": atype in earned_map,
                "earned_at": earned_map.get(atype),
            })
        return result

    def check_and_award_achievements(self, user_id: str) -> list[dict[str, Any]]:
        """Evaluate all achievement conditions and insert newly earned ones.
        Returns list of newly awarded achievement dicts."""
        from scan_storage import ScanStorage  # avoid circular import

        scans = ScanStorage(self.database_path).list_history(user_id=user_id, limit=50)
        streak = self.get_streak(user_id)

        # Build PBF and SMM history (oldest → newest)
        pbf_list: list[float] = []
        smm_list: list[float] = []
        for scan in reversed(scans):
            features: dict[str, Any] = scan.get("features") or {}
            pbf = _safe_float(features.get("PBF_(Percent_Body_Fat)"))
            smm = _safe_float(features.get("SMM_(Skeletal_Muscle_Mass)"))
            if pbf is not None:
                pbf_list.append(pbf)
            if smm is not None:
                smm_list.append(smm)

        conditions: dict[str, bool] = {
            "first_scan": len(scans) >= 1,
            "7_day_streak": streak >= 7,
            "30_day_streak": streak >= 30,
            "muscle_gainer_2kg": (
                len(smm_list) >= 2 and (smm_list[-1] - smm_list[0]) >= 2.0
            ),
            "fat_burner_5_percent": (
                len(pbf_list) >= 2 and (pbf_list[0] - pbf_list[-1]) >= 5.0
            ),
        }

        newly_awarded: list[dict[str, Any]] = []
        now = _now()
        with self._connect() as db:
            for atype, earned in conditions.items():
                if not earned:
                    continue
                try:
                    db.execute(
                        "INSERT INTO user_achievements (id, user_id, achievement_type, earned_at) VALUES (?, ?, ?, ?)",
                        (uuid.uuid4().hex, user_id, atype, now),
                    )
                    meta = _ACHIEVEMENT_META[atype]
                    newly_awarded.append({
                        "type": atype,
                        "name": meta["name"],
                        "description": meta["description"],
                        "icon": meta["icon"],
                        "earned_at": now,
                    })
                except sqlite3.IntegrityError:
                    pass  # already earned
        return newly_awarded

    # ── Progress ──────────────────────────────────────────────────────────────

    def get_progress(self, user_id: str) -> dict[str, Any]:
        """Aggregate progress stats from confirmed scan history."""
        from scan_storage import ScanStorage  # avoid circular import at module level
        scans = ScanStorage(self.database_path).list_history(user_id=user_id, limit=50)

        weights: list[float] = []
        pbf_values: list[float] = []
        smm_values: list[float] = []
        scan_dates: list[str] = []

        for scan in reversed(scans):  # oldest first
            features: dict[str, Any] = scan.get("features") or {}
            w = _safe_float(features.get("Weight"))
            pbf = _safe_float(features.get("PBF_(Percent_Body_Fat)"))
            smm = _safe_float(features.get("SMM_(Skeletal_Muscle_Mass)"))
            bfm = _safe_float(features.get("BFM_(Body_Fat_Mass)"))

            if w is not None:
                weights.append(w)
                scan_dates.append(scan["created_at"][:10])
            if pbf is not None:
                pbf_values.append(pbf)
            if smm is not None:
                smm_values.append(smm)

        fat_lost = 0.0
        muscle_gained = 0.0
        if len(pbf_values) >= 2:
            fat_lost = round(pbf_values[0] - pbf_values[-1], 1)
        if len(smm_values) >= 2:
            muscle_gained = round(smm_values[-1] - smm_values[0], 1)

        return {
            "total_scans": len(scans),
            "fat_lost_kg": fat_lost,
            "muscle_gained_kg": muscle_gained,
            "weight_history": weights,
            "pbf_history": pbf_values,
            "smm_history": smm_values,
            "scan_dates": scan_dates,
        }

    # ── Hydration ─────────────────────────────────────────────────────────────

    def log_hydration(self, user_id: str, cups: int = 1) -> str:
        log_id = uuid.uuid4().hex
        with self._connect() as db:
            db.execute(
                "INSERT INTO hydration_logs (id, user_id, cups, logged_at) VALUES (?, ?, ?, ?)",
                (log_id, user_id, cups, _now()),
            )
        return log_id

    def get_today_hydration_cups(self, user_id: str) -> int:
        today = date.today().isoformat()
        with self._connect() as db:
            row = db.execute(
                "SELECT COALESCE(SUM(cups), 0) AS total FROM hydration_logs WHERE user_id = ? AND logged_at LIKE ?",
                (user_id, f"{today}%"),
            ).fetchone()
        return int(row["total"]) if row else 0

    # ── Internals ─────────────────────────────────────────────────────────────

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.database_path)
        conn.row_factory = sqlite3.Row
        return conn


# ── Private helpers ───────────────────────────────────────────────────────────

def _verify_password(plain: str, stored_hash: str) -> bool:
    """Verify *plain* against *stored_hash*.

    Accepts both modern bcrypt hashes (prefix ``$2``) and legacy SHA-256 hex
    strings so that existing local accounts continue to work after the upgrade.
    """
    if stored_hash.startswith("$2"):
        return _bcrypt.checkpw(plain.encode(), stored_hash.encode())
    # Legacy SHA-256 comparison (constant-time via hmac).
    import hmac
    legacy = hashlib.sha256(plain.encode("utf-8")).hexdigest()
    return hmac.compare_digest(legacy, stored_hash)


def _now() -> str:
    return datetime.now(UTC).isoformat()


def _safe_float(value: Any) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None
