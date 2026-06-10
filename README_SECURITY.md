# Smart Fit — Security Guide

This document explains how to run Smart Fit securely on your local machine.
The app is a **local prototype** — it is not production-hardened.

---

## 1. Generate a JWT Secret Key

The FastAPI backend signs JWTs with a `SECRET_KEY`. Without one in `.env` a
random key is generated at startup (tokens invalidate on every restart).

Create a stable key:

```bash
# Option A — Python
python -c "import secrets; print(secrets.token_hex(32))"

# Option B — OpenSSL
openssl rand -hex 32
```

---

## 2. Backend: Create the `.env` File

```bash
cd smart_fit_backend
cp .env.example .env
```

Edit `.env` and fill in `SECRET_KEY` (and optionally `GEMINI_API_KEY` if the
backend calls Gemini directly):

```
SECRET_KEY=paste_your_generated_key_here
GEMINI_API_KEY=your_gemini_api_key_here
```

> `.env` is listed in `.gitignore` and must **never** be committed to Git.

---

## 3. Frontend: Pass the Gemini API Key at Runtime

The Flutter app reads the Gemini key from a Dart compile-time constant.
It is **never** stored in source code.

```bash
# Development
flutter run --dart-define=GEMINI_API_KEY=your_key_here

# Release build
flutter build apk --dart-define=GEMINI_API_KEY=your_key_here
```

Get a free key at <https://aistudio.google.com/app/apikey>.

---

## 4. Get a Free Gemini API Key

1. Visit <https://aistudio.google.com/app/apikey>
2. Sign in with a Google account
3. Click **Create API key**
4. Copy the key and use it via `--dart-define` as shown above

---

## 5. Authentication Flow

| Step | What happens |
|------|-------------|
| Register / Login | Backend returns a signed JWT (`access_token`) |
| App stores token | Saved in OS keychain via `flutter_secure_storage` |
| Every API request | Flutter adds `Authorization: Bearer <token>` header |
| Backend verifies | `get_current_user` dependency decodes the JWT and extracts `user_id` |
| Token expires | After 7 days — user must log in again |

---

## 6. Password Security

Passwords are hashed with **bcrypt** (directly via the `bcrypt` package). SHA-256 hashes created
before this upgrade are automatically re-hashed to bcrypt on the user's next
successful login.

---

## 7. What Is and Is Not Secured

| ✅ Secured | ❌ Not production-ready |
|---|---|
| Passwords hashed with bcrypt | HTTP only (no TLS) |
| JWT authentication on all API routes | CORS allows all origins (`*`) |
| Gemini key via `--dart-define` only | SQLite (no row-level ACL) |
| Credentials in OS keychain | No rate limiting |
| `.env` excluded from Git | No audit logging |

For a production deployment add HTTPS (reverse proxy such as nginx + Let's
Encrypt), tighten CORS origins, add rate limiting, and use PostgreSQL.

---

## 8. Running Both Together (Recommended)

Two launch scripts start the backend **and** the Flutter app in one command.
Both scripts auto-read `GEMINI_API_KEY` from `smart_fit_backend/.env`.

**Windows (PowerShell):**

```powershell
.\run.ps1                          # auto-detect device
.\run.ps1 -Device windows          # force Windows target
.\run.ps1 -GeminiKey "AIza..."     # pass key directly (skips .env lookup)
```

**Linux / macOS:**

```bash
chmod +x run.sh
./run.sh                           # auto-detect device
./run.sh -d chrome                 # flutter run -d chrome
GEMINI_API_KEY=AIza... ./run.sh    # pass key directly
```

The Flutter app runs in the **current** terminal (hot-reload works normally).
The backend runs in a separate window (`run.ps1`) or background process (`run.sh`)
and is killed automatically when Flutter exits.

---

## 9. Running the Backend Alone

```bash
cd smart_fit_backend
pip install -r requirements.txt
# Copy and fill in .env before starting
cp .env.example .env && nano .env
python -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```
