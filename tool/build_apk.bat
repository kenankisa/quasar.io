@echo off
setlocal EnableExtensions

REM Quasar.io APK build helper (works without PowerShell execution policy changes).
REM Usage:
REM   tool\build_apk.bat           -> arm64 debug APK (fast phone test)
REM   tool\build_apk.bat release   -> release APK (Play Store / distribution)
REM   tool\build_apk.bat split     -> per-ABI release APKs (smaller downloads)

cd /d "%~dp0.."
set "GRADLE_USER_HOME=%USERPROFILE%\.gradle"

where flutter >nul 2>&1
if errorlevel 1 (
    echo ERROR: flutter not found in PATH. Install Flutter SDK and reopen the terminal.
    exit /b 1
)

set "MODE=%~1"
if /I "%MODE%"=="release" goto :release
if /I "%MODE%"=="split" goto :split
goto :debug

:debug
echo Building arm64 debug APK...
call flutter build apk --debug --target-platform android-arm64 --dart-define-from-file=dart_defines.dev.json
if errorlevel 1 exit /b 1
set "APK_DIR=build\app\outputs\flutter-apk"
if exist "%APK_DIR%\app-arm64-v8a-debug.apk" (
    set "APK=%APK_DIR%\app-arm64-v8a-debug.apk"
) else if exist "%APK_DIR%\app-debug.apk" (
    set "APK=%APK_DIR%\app-debug.apk"
) else (
    echo ERROR: Debug APK not found in %CD%\%APK_DIR%
    exit /b 1
)
goto :done

:release
echo Building release APK...
call flutter pub get
if errorlevel 1 exit /b 1
call flutter build apk --release --dart-define-from-file=dart_defines.dev.json
if errorlevel 1 exit /b 1
set "APK=build\app\outputs\flutter-apk\app-release.apk"
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
exit /b 0

:done_split
echo.
echo Done. APKs in: %CD%\%APK%
dir /b "%APK%\*.apk"
exit /b 0
