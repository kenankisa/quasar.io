@echo off
setlocal EnableExtensions

REM Quasar.io APK build helper (works without PowerShell execution policy changes).
REM Usage:
REM   tool\build_apk.bat           -> universal release APK
REM   tool\build_apk.bat release   -> same as default
REM   tool\build_apk.bat arm64     -> arm64-v8a release APK (most phones)
REM   tool\build_apk.bat debug     -> universal debug APK
REM   tool\build_apk.bat split     -> per-ABI release APKs (smaller downloads)
REM
REM Always embeds dart_defines.dev.json so the APK does not show
REM "Uygulama yapılandırması eksik".

cd /d "%~dp0.."
set "GRADLE_USER_HOME=%USERPROFILE%\.gradle"

where flutter >nul 2>&1
if errorlevel 1 (
    echo ERROR: flutter not found in PATH. Install Flutter SDK and reopen the terminal.
    exit /b 1
)

if not exist "dart_defines.dev.json" (
    echo ERROR: Missing dart_defines.dev.json — APK would show config error on launch.
    echo Copy dart_defines.dev.json.example to dart_defines.dev.json and fill required keys.
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$j = Get-Content 'dart_defines.dev.json' -Raw -Encoding UTF8 | ConvertFrom-Json; $req = 'SUPABASE_URL','SUPABASE_ANON_KEY','GOOGLE_WEB_CLIENT_ID'; $bad = @(); foreach ($k in $req) { $v = [string]$j.$k; if ([string]::IsNullOrWhiteSpace($v) -or $v -match 'YOUR_|XXXX|example\.com|placeholder') { $bad += $k } }; if ($bad.Count) { Write-Host ('ERROR: dart_defines.dev.json incomplete: ' + ($bad -join ', ')); exit 1 }; Write-Host 'dart_defines.dev.json OK.'"
if errorlevel 1 exit /b 1

set "MODE=%~1"
if /I "%MODE%"=="" set "MODE=release"
if /I "%MODE%"=="debug" goto :debug
if /I "%MODE%"=="arm64" goto :arm64
if /I "%MODE%"=="split" goto :split
goto :release

:debug
echo Building universal debug APK (all ABIs)...
call flutter build apk --debug --dart-define-from-file=dart_defines.dev.json
if errorlevel 1 exit /b 1
set "APK=build\app\outputs\flutter-apk\app-debug.apk"
goto :done

:release
echo Building universal release APK (all ABIs)...
call flutter pub get
if errorlevel 1 exit /b 1
call flutter build apk --release --dart-define-from-file=dart_defines.dev.json
if errorlevel 1 exit /b 1
set "APK=build\app\outputs\flutter-apk\app-release.apk"
goto :done

:arm64
echo Building arm64-v8a release APK...
call flutter pub get
if errorlevel 1 exit /b 1
call flutter build apk --release --target-platform android-arm64 --dart-define-from-file=dart_defines.dev.json
if errorlevel 1 exit /b 1
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" >nul
set "APK=build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
goto :done

:split
echo Building split release APKs (per ABI)...
call flutter pub get
if errorlevel 1 exit /b 1
call flutter build apk --release --split-per-abi --dart-define-from-file=dart_defines.dev.json
if errorlevel 1 exit /b 1
set "APK=build\app\outputs\flutter-apk"
goto :done_split

:done
if not exist "%APK%" (
    echo ERROR: APK not found at %CD%\%APK%
    exit /b 1
)
for %%A in ("%APK%") do set "SIZE_MB=%%~zA"
set /a SIZE_MB=%SIZE_MB% / 1048576
echo.
echo Done: %CD%\%APK% (~%SIZE_MB% MB)
echo Phone tip: uninstall old Quasar.io first, then install this APK.
exit /b 0

:done_split
echo.
echo Done. APKs in: %CD%\%APK%
dir /b "%APK%\*.apk"
echo Install the matching ABI (arm64-v8a for most phones).
exit /b 0
