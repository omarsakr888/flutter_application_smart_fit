"""auth/jwt.py — JWT creation and verification for the Smart Fit backend.

Usage
-----
  from auth.jwt import create_access_token, verify_token

Runtime secret
--------------
  Set SECRET_KEY in the .env file (copy .env.example → .env and fill in).
  If SECRET_KEY is not set, a random key is generated at startup — fine for
  local development but tokens will be invalidated on every server restart.

  Generate a stable key:
      python -c "import secrets; print(secrets.token_hex(32))"
      # or: openssl rand -hex 32
"""
from __future__ import annotations

import os
import secrets
from datetime import UTC, datetime, timedelta
from typing import Any

from jose import JWTError, jwt  # noqa: F401 (re-exported for callers)

# ── Configuration ─────────────────────────────────────────────────────────────

_SECRET_KEY: str = os.getenv("SECRET_KEY") or secrets.token_hex(32)
_ALGORITHM = "HS256"
# 7-day expiry is comfortable for a local prototype; shorten for production.
_ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7


# ── Public API ────────────────────────────────────────────────────────────────

def create_access_token(user_id: str) -> str:
    """Return a signed JWT that encodes *user_id* in the ``sub`` claim."""
    now = datetime.now(UTC)
    payload: dict[str, Any] = {
        "sub": user_id,
        "iat": now,
        "exp": now + timedelta(minutes=_ACCESS_TOKEN_EXPIRE_MINUTES),
    }
    return jwt.encode(payload, _SECRET_KEY, algorithm=_ALGORITHM)


def verify_token(token: str) -> str:
    """Decode *token* and return the ``sub`` (user_id) claim.

    Raises ``jose.JWTError`` if the token is invalid, expired, or tampered.
    """
    payload = jwt.decode(token, _SECRET_KEY, algorithms=[_ALGORITHM])
    user_id: str | None = payload.get("sub")
    if not user_id:
        raise JWTError("Token is missing the 'sub' claim.")
    return user_id
