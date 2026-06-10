# run.ps1 — Start Smart Fit backend + Flutter app together.
#
# Usage:
#   .\run.ps1                      # uses GEMINI_API_KEY from smart_fit_backend/.env
#   .\run.ps1 -GeminiKey "AIza..."  # pass key directly
#   .\run.ps1 -Device "windows"     # target a specific device
#
# Prerequisites:
#   1. Copy smart_fit_backend/.env.example → smart_fit_backend/.env and fill in values.
#   2. pip install -r smart_fit_backend/requirements.txt
#   3. flutter pub get

param(
    [string]$GeminiKey = "",
    [string]$Device    = ""
)

$Root       = $PSScriptRoot
$BackendDir = Join-Path $Root "smart_fit_backend"
$EnvFile    = Join-Path $BackendDir ".env"
$Python     = "C:\Users\omart\AppData\Local\Python\bin\python3.14-64.exe"

# ── 0. Sanity checks ──────────────────────────────────────────────────────────

if (-not (Test-Path $BackendDir)) {
    Write-Error "smart_fit_backend/ not found. Run this script from the project root."
    exit 1
}

# ── 1. Load .env (backend secrets + optional Gemini key) ─────────────────────

$envVars = @{}
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | Where-Object { $_ -match "^\s*[^#=\s]+=.+" } | ForEach-Object {
        $parts = $_ -split "=", 2
        $envVars[$parts[0].Trim()] = $parts[1].Trim()
    }
    Write-Host "[.env] Loaded from $EnvFile" -ForegroundColor DarkGray
} else {
    Write-Host "[warn] $EnvFile not found. Copy .env.example → .env and fill in SECRET_KEY." -ForegroundColor Yellow
}

# Resolve Gemini key: flag > .env > env var
if ($GeminiKey -eq "" ) { $GeminiKey = $envVars["GEMINI_API_KEY"] }
if ($GeminiKey -eq "" ) { $GeminiKey = $env:GEMINI_API_KEY }
if ($GeminiKey -eq "" -or $GeminiKey -eq "your_gemini_api_key_here") {
    Write-Host "[warn] GEMINI_API_KEY not set — AI Coach will show an error in-app." -ForegroundColor Yellow
    $GeminiKey = ""
}

# ── 2. Start FastAPI backend in a new terminal window ─────────────────────────

Write-Host ""
Write-Host "Starting Smart Fit backend..." -ForegroundColor Cyan

$backendCmd = "Write-Host 'Smart Fit Backend' -ForegroundColor Cyan; " +
              "Set-Location '$BackendDir'; " +
              "& '$Python' -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload; " +
              "Write-Host 'Backend stopped.' -ForegroundColor Red; " +
              "Read-Host 'Press Enter to close'"

$backendProc = Start-Process powershell `
    -ArgumentList "-NoExit", "-Command", $backendCmd `
    -PassThru

Write-Host "[backend] PID $($backendProc.Id) — http://127.0.0.1:8000" -ForegroundColor DarkGray

# ── 3. Wait for backend to become healthy ─────────────────────────────────────

Write-Host "Waiting for backend to be ready..." -ForegroundColor Cyan
$ready   = $false
$timeout = 30   # seconds

for ($i = 0; $i -lt $timeout; $i++) {
    try {
        $resp = Invoke-WebRequest -Uri "http://127.0.0.1:8000/health" `
                                  -TimeoutSec 2 -ErrorAction Stop
        if ($resp.StatusCode -eq 200) { $ready = $true; break }
    } catch { }
    Start-Sleep 1
    Write-Host "  [$i/$timeout] waiting..." -ForegroundColor DarkGray
}

if (-not $ready) {
    Write-Host "[error] Backend did not start within $timeout seconds." -ForegroundColor Red
    Write-Host "        Check the backend window for errors." -ForegroundColor Red
    $backendProc | Stop-Process -ErrorAction SilentlyContinue
    exit 1
}

Write-Host "[backend] Ready!" -ForegroundColor Green

# ── 4. Start Flutter ──────────────────────────────────────────────────────────

$dartDefines = "--dart-define=BACKEND_URL=http://127.0.0.1:8000"
if ($GeminiKey -ne "") {
    $dartDefines += " --dart-define=GEMINI_API_KEY=$GeminiKey"
    Write-Host "[flutter] Gemini API key: configured" -ForegroundColor DarkGray
} else {
    Write-Host "[flutter] Gemini API key: not set (AI Coach disabled)" -ForegroundColor DarkGray
}

$flutterArgs = "run $dartDefines"
if ($Device -ne "") { $flutterArgs += " -d $Device" }

Write-Host ""
Write-Host "Starting Flutter app..." -ForegroundColor Cyan
Write-Host "  Command: flutter $flutterArgs" -ForegroundColor DarkGray
Write-Host ""

Set-Location $Root

# Run Flutter in the current window so the user sees hot-reload output.
$flutterArgsList = $flutterArgs -split " "
& flutter @flutterArgsList

# ── 5. Cleanup — kill backend when Flutter exits ──────────────────────────────

Write-Host ""
Write-Host "Flutter exited. Stopping backend (PID $($backendProc.Id))..." -ForegroundColor Cyan
$backendProc | Stop-Process -ErrorAction SilentlyContinue
Write-Host "Done." -ForegroundColor Green
