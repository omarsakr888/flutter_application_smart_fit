from __future__ import annotations

import json
import sqlite3
import uuid
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from core import DATABASE_PATH, DATA_DIR, UPLOAD_DIR


class ScanStorage:
    def __init__(self, database_path: Path = DATABASE_PATH) -> None:
        self.database_path = database_path

    def initialize(self) -> None:
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
        with self._connect() as db:
            db.execute(
                """
                CREATE TABLE IF NOT EXISTS scan_extractions (
                    id TEXT PRIMARY KEY,
                    user_id TEXT NOT NULL,
                    status TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    image_path TEXT,
                    filename TEXT,
                    content_type TEXT,
                    extracted_json TEXT NOT NULL,
                    confirmed_features_json TEXT,
                    imputation_metadata_json TEXT,
                    prediction_json TEXT
                )
                """
            )
            _ensure_column(db, "scan_extractions", "imputation_metadata_json", "TEXT")
            db.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_scan_extractions_user_created
                ON scan_extractions(user_id, created_at DESC)
                """
            )

    def save_upload(self, image_bytes: bytes, filename: str | None) -> Path:
        safe_name = _safe_filename(filename or "inbody_scan.jpg")
        path = UPLOAD_DIR / f"{uuid.uuid4().hex}_{safe_name}"
        path.write_bytes(image_bytes)
        return path

    def create_extraction(
        self,
        *,
        user_id: str,
        image_path: Path,
        filename: str | None,
        content_type: str | None,
        extraction: dict[str, Any],
    ) -> str:
        extraction_id = uuid.uuid4().hex
        now = _now()
        with self._connect() as db:
            db.execute(
                """
                INSERT INTO scan_extractions (
                    id, user_id, status, created_at, updated_at, image_path,
                    filename, content_type, extracted_json
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    extraction_id,
                    user_id,
                    "pending_review",
                    now,
                    now,
                    str(image_path),
                    filename,
                    content_type,
                    json.dumps(extraction),
                ),
            )
        return extraction_id

    def confirm_scan(
        self,
        *,
        extraction_id: str | None,
        user_id: str,
        features: dict[str, float | str],
        prediction: dict[str, Any] | None,
        imputation_metadata: dict[str, Any] | None = None,
    ) -> str:
        now = _now()
        if extraction_id:
            with self._connect() as db:
                row = db.execute(
                    "SELECT id FROM scan_extractions WHERE id = ? AND user_id = ?",
                    (extraction_id, user_id),
                ).fetchone()
                if row is not None:
                    db.execute(
                        """
                        UPDATE scan_extractions
                        SET status = ?, updated_at = ?, confirmed_features_json = ?,
                            imputation_metadata_json = ?, prediction_json = ?
                        WHERE id = ? AND user_id = ?
                        """,
                        (
                            "confirmed",
                            now,
                            json.dumps(features),
                            json.dumps(imputation_metadata),
                            json.dumps(prediction),
                            extraction_id,
                            user_id,
                        ),
                    )
                    return extraction_id

        scan_id = uuid.uuid4().hex
        with self._connect() as db:
            db.execute(
                """
                INSERT INTO scan_extractions (
                    id, user_id, status, created_at, updated_at, extracted_json,
                    confirmed_features_json, imputation_metadata_json, prediction_json
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    scan_id,
                    user_id,
                    "confirmed",
                    now,
                    now,
                    "{}",
                    json.dumps(features),
                    json.dumps(imputation_metadata),
                    json.dumps(prediction),
                ),
            )
        return scan_id

    def list_history(self, user_id: str, limit: int = 20) -> list[dict[str, Any]]:
        with self._connect() as db:
            rows = db.execute(
                """
                SELECT * FROM scan_extractions
                WHERE user_id = ? AND status = 'confirmed'
                ORDER BY created_at DESC
                LIMIT ?
                """,
                (user_id, limit),
            ).fetchall()
        return [_row_to_scan(row) for row in rows]

    def get_scan(self, scan_id: str, user_id: str) -> dict[str, Any] | None:
        with self._connect() as db:
            row = db.execute(
                "SELECT * FROM scan_extractions WHERE id = ? AND user_id = ?",
                (scan_id, user_id),
            ).fetchone()
        return _row_to_scan(row) if row else None

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.database_path)
        conn.row_factory = sqlite3.Row
        return conn


def _row_to_scan(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "id": row["id"],
        "user_id": row["user_id"],
        "status": row["status"],
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
        "image_path": row["image_path"],
        "filename": row["filename"],
        "content_type": row["content_type"],
        "extraction": _json(row["extracted_json"]),
        "features": _json(row["confirmed_features_json"]),
        "imputation": _json(row["imputation_metadata_json"]),
        "prediction": _json(row["prediction_json"]),
    }


def _json(value: str | None) -> Any:
    if not value:
        return None
    return json.loads(value)


def _now() -> str:
    return datetime.now(UTC).isoformat()


def _ensure_column(db: sqlite3.Connection, table: str, column: str, definition: str) -> None:
    columns = {
        row["name"]
        for row in db.execute(f"PRAGMA table_info({table})").fetchall()
    }
    if column not in columns:
        db.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")


def _safe_filename(filename: str) -> str:
    cleaned = "".join(char if char.isalnum() or char in {".", "-", "_"} else "_" for char in filename)
    return cleaned[-120:] or "inbody_scan.jpg"
