@echo off
setlocal EnableExtensions

REM Creates android\upload-keystore.jks and prints key.properties template.
REM Run once before publishing to Play Store, then copy key.properties.example to key.properties.

cd /d "%~dp0.."

set "KEYSTORE=android\upload-keystore.jks"
set "PROPS=android\key.properties"

where keytool >nul 2>&1
if errorlevel 1 (
    echo ERROR: keytool not found. Use JDK from Android Studio:
    echo   "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
    exit /b 1
)

if exist "%KEYSTORE%" (
    echo Keystore already exists: %CD%\%KEYSTORE%
    echo Delete it first if you want to create a new one.
    exit /b 1
)

echo Creating release keystore...
echo You will be asked for a keystore password and your name/organization.
echo.
keytool -genkeypair -v ^
  -keystore "%KEYSTORE%" ^
  -storetype JKS ^
  -keyalg RSA ^
  -keysize 2048 ^
  -validity 10000 ^
  -alias upload

if errorlevel 1 exit /b 1

echo.
echo Keystore created: %CD%\%KEYSTORE%
echo.
echo Next steps:
echo   1. Copy android\key.properties.example to android\key.properties
echo   2. Fill in storePassword, keyPassword, keyAlias=upload, storeFile=upload-keystore.jks
echo   3. Run: tool\build_apk.bat release
echo.
echo For Google Sign-In on release builds, add the release SHA-1 to Google Cloud Console:
keytool -list -v -keystore "%KEYSTORE%" -alias upload | findstr /I "SHA1:"
exit /b 0
