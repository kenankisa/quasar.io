# Quasar.io APK build helper.
# If execution policy blocks this script, use tool\build_apk.bat instead.
param(
    [ValidateSet("debug", "release", "split", "arm64")]
    [string]$Mode = "release"
)

$ErrorActionPreference = "Stop"
$env:GRADLE_USER_HOME = "$env:USERPROFILE\.gradle"

Set-Location (Join-Path $PSScriptRoot "..")

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "flutter not found in PATH. Install Flutter SDK and reopen the terminal."
}

function Assert-DartDefines {
    $definesPath = Join-Path (Get-Location) "dart_defines.dev.json"
    if (-not (Test-Path $definesPath)) {
        throw @"
Missing dart_defines.dev.json — APK would show 'Uygulama yapılandırması eksik'.
Copy dart_defines.dev.json.example to dart_defines.dev.json and fill SUPABASE_URL, SUPABASE_ANON_KEY, GOOGLE_WEB_CLIENT_ID.
"@
    }

    try {
        $json = Get-Content $definesPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        throw "dart_defines.dev.json is not valid JSON: $_"
    }

    $required = @('SUPABASE_URL', 'SUPABASE_ANON_KEY', 'GOOGLE_WEB_CLIENT_ID')
    $missing = @()
    foreach ($key in $required) {
        $val = [string]$json.$key
        if ([string]::IsNullOrWhiteSpace($val) -or
            $val -match 'YOUR_|XXXX|example\.com|placeholder') {
            $missing += $key
        }
    }
    if ($missing.Count -gt 0) {
        throw ("dart_defines.dev.json incomplete (would cause startup config error): " + ($missing -join ', '))
    }

    Write-Host "dart_defines.dev.json OK (required keys present)."
}

Assert-DartDefines

$defineArgs = @('--dart-define-from-file=dart_defines.dev.json')

switch ($Mode) {
    "release" {
        Write-Host "Building universal release APK (all ABIs)..."
        flutter pub get
        flutter build apk --release @defineArgs
        $apk = Join-Path (Get-Location) "build\app\outputs\flutter-apk\app-release.apk"
    }
    "arm64" {
        Write-Host "Building arm64-v8a release APK..."
        flutter pub get
        flutter build apk --release --target-platform android-arm64 @defineArgs
        $src = Join-Path (Get-Location) "build\app\outputs\flutter-apk\app-release.apk"
        $apk = Join-Path (Get-Location) "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
        if (Test-Path $src) {
            Copy-Item $src $apk -Force
        }
    }
    "split" {
        Write-Host "Building split release APKs (per ABI)..."
        flutter pub get
        flutter build apk --release --split-per-abi @defineArgs
        $apkDir = Join-Path (Get-Location) "build\app\outputs\flutter-apk"
        Write-Host ""
        Write-Host "Done. APKs in: $apkDir"
        Get-ChildItem $apkDir -Filter "*.apk" | ForEach-Object { Write-Host "  $($_.FullName)" }
        Write-Host ""
        Write-Host "Install the matching ABI (arm64-v8a for most phones, armeabi-v7a for older 32-bit)."
        return
    }
    default {
        Write-Host "Building universal debug APK (all ABIs)..."
        flutter build apk --debug @defineArgs
        $apkDir = Join-Path (Get-Location) "build\app\outputs\flutter-apk"
        $debugApk = Join-Path $apkDir "app-debug.apk"
        if (Test-Path $debugApk) {
            $apk = $debugApk
        } else {
            throw "Debug APK not found in $apkDir"
        }
    }
}

if (Test-Path $apk) {
    $sizeMb = [math]::Round((Get-Item $apk).Length / 1MB, 1)
    Write-Host ""
    Write-Host "Done: $apk ($sizeMb MB)"
    Write-Host "Phone tip: uninstall old Quasar.io first, then install this APK."
} else {
    throw "APK not found at expected path: $apk"
}
