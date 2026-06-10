#!/usr/bin/env bash
# run.sh — Start Smart Fit backend + Flutter app together (Linux / macOS).
#
# Usage:
#   ./run.sh                        # reads GEMINI_API_KEY from smart_fit_backend/.env
#   GEMINI_API_KEY=AIza... ./run.sh  # override from environment
#   ./run.sh -d chrome              # pass -d flag to flutter run
#
# Prerequisites:
#   1. cp smart_fit_backend/.env.example smart_fit_backend/.env  (fill in values)
#   2. pip install -r smart_fit_backend/requirements.txt
#   3. flutter pub get

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/smart_fit_backend"
ENV_FILE="$BACKEND_DIR/.env"
DEVICE=""

# Parse optional -d flag
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d) DEVICE="$2"; shift 2 ;;
        *)  echo "Unknown argument: $1"; exit 1 ;;
    esac
done

# ── 1. Load .env ──────────────────────────────────────────────────────────────

if [[ -f "$ENV_FILE" ]]; then
    # Export KEY=VALUE lines, skip comments and blanks.
    set -a
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set +a
    echo "[.env] Loaded from $ENV_FILE"
else
    echo "[warn] $ENV_FILE not found. Copy .env.example → .env and fill in SECRET_KEY."
fi

GEMINI_KEY="${GEMINI_API_KEY:-}"
if [[ "$GEMINI_KEY" == "your_gemini_api_key_here" ]]; then
    GEMINI_KEY=""
fi
if [[ -z "$GEMINI_KEY" ]]; then
    echo "[warn] GEMINI_API_KEY not set — AI Coach will show an error in-app."
fi

# ── 2. Start FastAPI backend in background ────────────────────────────────────

echo ""
echo "Starting Smart Fit backend..."

cd "$BACKEND_DIR"
python -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload &
BACKEND_PID=$!
cd "$SCRIPT_DIR"

echo "[backend] PID $BACKEND_PID — http://127.0.0.1:8000"

# Kill backend automatically when this script exits.
trap 'echo ""; echo "Stopping backend (PID $BACKEND_PID)..."; kill "$BACKEND_PID" 2>/dev/null; wait "$BACKEND_PID" 2>/dev/null; echo "Done."' EXIT

# ── 3. Wait for backend to become healthy ─────────────────────────────────────

echo "Waiting for backend to be ready..."
READY=false
for i in $(seq 1 30); do
    if curl -sf "http://127.0.0.1:8000/health" > /dev/null 2>&1; then
        READY=true
        break
    fi
    echo "  [$i/30] waiting..."
    sleep 1
done

if [[ "$READY" != "true" ]]; then
    echo "[error] Backend did not start within 30 seconds. Check for errors above."
    exit 1
fi

echo "[backend] Ready!"

# ── 4. Start Flutter ──────────────────────────────────────────────────────────

DART_DEFINES="--dart-define=BACKEND_URL=http://127.0.0.1:8000"
if [[ -n "$GEMINI_KEY" ]]; then
    DART_DEFINES="$DART_DEFINES --dart-define=GEMINI_API_KEY=$GEMINI_KEY"
    echo "[flutter] Gemini API key: configured"
else
    echo "[flutter] Gemini API key: not set (AI Coach disabled)"
fi

FLUTTER_ARGS="run $DART_DEFINES"
if [[ -n "$DEVICE" ]]; then
    FLUTTER_ARGS="$FLUTTER_ARGS -d $DEVICE"
fi

echo ""
echo "Starting Flutter app..."
echo "  Command: flutter $FLUTTER_ARGS"
echo ""

# Run Flutter in the foreground — hot-reload output stays visible.
# shellcheck disable=SC2086
flutter $FLUTTER_ARGS
