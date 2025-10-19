@echo off
echo Fixing ADB connection issue...
echo.

echo Step 1: Killing ADB server...
call flutter doctor
echo.

echo Step 2: Checking connected devices...
call flutter devices
echo.

echo ========================================
echo TROUBLESHOOTING STEPS:
echo ========================================
echo 1. Unplug your phone from USB
echo 2. Plug it back in
echo 3. On your phone, check for "Allow USB debugging?" prompt
echo 4. Tap "Allow" (and optionally check "Always allow")
echo 5. Run: flutter devices
echo.
echo If device still not detected:
echo - Try a different USB cable
echo - Try a different USB port
echo - Enable "USB Debugging" in Developer Options
echo - Disable and re-enable "USB Debugging"
echo - Revoke USB debugging authorizations and reconnect
echo ========================================
echo.

pause
