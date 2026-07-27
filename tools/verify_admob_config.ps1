# Verifies AdMob IDs are not Google test / placeholder IDs.
# Usage (repo root):  powershell -File tools/verify_admob_config.ps1

param(
    [switch]$AllowDevTest
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$testPublisher = "3940256099942544"
$file = Join-Path $root "dart_defines.prod.json"

Write-Host "Checking: $file"

if (-not (Test-Path $file)) {
    Write-Error "File not found. Copy dart_defines.prod.json.example to dart_defines.prod.json and paste real AdMob IDs."
}

$j = Get-Content $file -Raw | ConvertFrom-Json
$keys = @(
    "ANDROID_ADMOB_APP_ID",
    "IOS_ADMOB_APP_ID",
    "ANDROID_REWARDED_DOUBLE_AD_UNIT_ID",
    "IOS_REWARDED_DOUBLE_AD_UNIT_ID"
)

$failed = $false
foreach ($k in $keys) {
    $v = [string]$j.$k
    $status = "OK"
    if ([string]::IsNullOrWhiteSpace($v)) {
        $status = "MISSING"
        $failed = $true
    } elseif ($v -match "XXXXXXXX|YOUR_|placeholder") {
        $status = "PLACEHOLDER"
        $failed = $true
    } elseif ($v -match $testPublisher) {
        $status = "TEST_ID"
        if (-not $AllowDevTest) { $failed = $true }
    }
    if ([string]::IsNullOrWhiteSpace($v)) {
        $preview = "(empty)"
    } elseif ($v.Length -gt 28) {
        $preview = $v.Substring(0, 22) + "..." + $v.Substring($v.Length - 6)
    } else {
        $preview = $v
    }
    Write-Host ("  {0,-40} {1,-12} {2}" -f $k, $status, $preview)
}

if ($failed) {
    Write-Host ""
    Write-Host "FAIL - create real units in AdMob Console, then fill dart_defines.prod.json:"
    Write-Host "  [1] Apps: Android + iOS App IDs (ca-app-pub-...~...)"
    Write-Host "  [2] Ad units: Rewarded 2x match reward per platform (ca-app-pub-.../...)"
    Write-Host "  [3] SSV callback: https://PROJECT.supabase.co/functions/v1/admob-ssv"
    Write-Host "  [4] powershell -File tools/sync_admob_ios.ps1"
    Write-Host "  [5] flutter build appbundle --dart-define-from-file=dart_defines.prod.json"
    exit 1
}

Write-Host ""
Write-Host "PASS - AdMob IDs look production-ready."
Write-Host "Smoke test: finish a match, tap 2x, confirm non-test creative and diamond grant."
exit 0
