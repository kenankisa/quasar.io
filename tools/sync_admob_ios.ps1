# Syncs IOS_ADMOB_APP_ID from dart_defines.prod.json into ios/Flutter/Release.xcconfig.
# Usage (repo root):  powershell -File tools/sync_admob_ios.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$prod = Join-Path $root "dart_defines.prod.json"
$xcconfig = Join-Path $root "ios\Flutter\Release.xcconfig"

if (-not (Test-Path $prod)) {
    Write-Error "Missing dart_defines.prod.json — copy dart_defines.prod.json.example and fill real AdMob IDs."
}

$json = Get-Content $prod -Raw | ConvertFrom-Json
$appId = [string]$json.IOS_ADMOB_APP_ID
if ([string]::IsNullOrWhiteSpace($appId) -or $appId -match "XXXXXXXX|3940256099942544") {
    Write-Error "IOS_ADMOB_APP_ID in dart_defines.prod.json is missing or still a placeholder/test id."
}

if (-not (Test-Path $xcconfig)) {
    Write-Error "Missing $xcconfig"
}

$lines = Get-Content $xcconfig
$updated = $false
$out = foreach ($line in $lines) {
    if ($line -match '^\s*ADMOB_APP_ID\s*=') {
        $updated = $true
        "ADMOB_APP_ID=$appId"
    } else {
        $line
    }
}
if (-not $updated) {
    $out += "ADMOB_APP_ID=$appId"
}

$out | Set-Content -Path $xcconfig -Encoding utf8
Write-Host "Updated Release.xcconfig ADMOB_APP_ID → $appId"
