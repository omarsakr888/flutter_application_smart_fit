# setup_env.ps1 - One-time setup for Smart Fit.
# Run this ONCE, then restart VS Code, then just press the Run button (F5).
#
# What it does:
#   1. Creates smart_fit_backend/.env with a generated SECRET_KEY (if missing)
#   2. Reads GEMINI_API_KEY from .env and saves it as a permanent Windows env var

param()

$Root        = $PSScriptRoot
$BackendDir  = Join-Path $Root "smart_fit_backend"
$EnvFile     = Join-Path $BackendDir ".env"
$ExampleFile = Join-Path $BackendDir ".env.example"
$Python      = "C:\Users\omart\AppData\Local\Python\bin\python3.14-64.exe"

Write-Host ""
Write-Host "Smart Fit - One-Time Environment Setup" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# 1. Create .env from .env.example if it does not exist
if (-not (Test-Path $EnvFile)) {
    if (Test-Path $ExampleFile) {
        Copy-Item $ExampleFile $EnvFile
        Write-Host "[1/3] Created .env from .env.example" -ForegroundColor Green
    } else {
        Set-Content -Path $EnvFile -Value "SECRET_KEY=change_this_in_production`nGEMINI_API_KEY=your_gemini_api_key_here" -Encoding utf8
        Write-Host "[1/3] Created .env from scratch" -ForegroundColor Green
    }
} else {
    Write-Host "[1/3] .env already exists - skipping copy." -ForegroundColor DarkGray
}

# 2. Generate SECRET_KEY if it is still the placeholder
$envContent = Get-Content $EnvFile -Raw
if ($envContent -match "change_this_in_production" -or (-not ($envContent -match "SECRET_KEY=\S{16,}"))) {
    Write-Host "[2/3] Generating SECRET_KEY..." -ForegroundColor Cyan
    $secretKey = & $Python -c "import secrets; print(secrets.token_hex(32))"
    $envContent = $envContent -replace "(?m)^SECRET_KEY=.*$", "SECRET_KEY=$secretKey"
    Set-Content -Path $EnvFile -Value $envContent -Encoding utf8
    Write-Host "[2/3] SECRET_KEY generated and saved to .env" -ForegroundColor Green
} else {
    Write-Host "[2/3] SECRET_KEY already set - skipping." -ForegroundColor DarkGray
}

# 3. Read optional API keys and save as permanent Windows user env vars
function Save-EnvKey {
    param([string]$Key, [string]$Placeholder, [string]$Label, [string]$HowToGet)
    $value = ""
    foreach ($line in (Get-Content $EnvFile)) {
        if ($line -match "^\s*$Key\s*=\s*(.+)") { $value = $Matches[1].Trim(); break }
    }
    if ($value -eq "" -or $value -eq $Placeholder) {
        Write-Host "  $Label : not set (optional - $HowToGet)" -ForegroundColor Yellow
    } else {
        [System.Environment]::SetEnvironmentVariable($Key, $value, "User")
        Write-Host "  $Label : saved to Windows env vars" -ForegroundColor Green
    }
}

Write-Host "[3/3] Saving API keys..." -ForegroundColor Cyan
Save-EnvKey -Key "GEMINI_API_KEY"       -Placeholder "your_gemini_api_key_here"        -Label "GEMINI_API_KEY      " -HowToGet "aistudio.google.com/app/apikey"
Save-EnvKey -Key "GOOGLE_WEB_CLIENT_ID" -Placeholder "your_google_web_client_id_here"  -Label "GOOGLE_WEB_CLIENT_ID" -HowToGet "console.cloud.google.com -> Credentials"

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Restart VS Code (picks up the new env vars)." -ForegroundColor White
Write-Host "  2. Press F5 and select 'Smart Fit (Full Stack)'." -ForegroundColor White
Write-Host ""
