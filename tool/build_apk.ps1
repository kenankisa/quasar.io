# Quasar.io APK build helper.
# If execution policy blocks this script, use tool\build_apk.bat instead.
param(
    [ValidateSet("debug", "release", "split")]
    [string]$Mode = "debug"
)

$ErrorActionPreference = "Stop"
$env:GRADLE_USER_HOME = "$env:USERPROFILE\.gradle"

Set-Location (Join-Path $PSScriptRoot "..")

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "flutter not found in PATH. Install Flutter SDK and reopen the terminal."
}

switch ($Mode) {
    "release" {
        Write-Host "Building release APK..."
        flutter pub get
        flutter build apk --release --dart-define-from-file=dart_defines.dev.json
        $apk = Join-Path (Get-Location) "build\app\outputs\flutter-apk\app-release.apk"
    }
    "split" {
        Write-Host "Building split release APKs (per ABI)..."
        flutter pub get
        flutter build apk --release --split-per-abi --dart-define-from-file=dart_defines.dev.json
        $apkDir = Join-Path (Get-Location) "build\app\outputs\flutter-apk"
        Write-Host ""
        Write-Host "Done. APKs in: $apkDir"
        Get-ChildItem $apkDir -Filter "*.apk" | ForEach-Object { Write-Host "  $($_.FullName)" }
        return
    }
    default {
        Write-Host "Building arm64 debug APK..."
        flutter build apk --debug --target-platform android-arm64 --dart-define-from-file=dart_defines.dev.json
        $apkDir = Join-Path (Get-Location) "build\app\outputs\flutter-apk"
        $arm64Apk = Join-Path $apkDir "app-arm64-v8a-debug.apk"
        $debugApk = Join-Path $apkDir "app-debug.apk"
        if (Test-Path $arm64Apk) {
            $apk = $arm64Apk
        } elseif (Test-Path $debugApk) {
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
} else {
    throw "APK not found at expected path: $apk"
}
