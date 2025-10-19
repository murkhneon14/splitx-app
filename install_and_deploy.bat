@echo off
echo ========================================
echo   Installing Firebase CLI and Deploying
echo ========================================
echo.

echo Step 1: Checking if Node.js is installed...
where node >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Node.js is not installed!
    echo.
    echo Please install Node.js first from:
    echo https://nodejs.org/
    echo.
    echo After installing Node.js, run this script again.
    pause
    exit /b 1
)
echo ✓ Node.js is installed
node --version
npm --version
echo.

echo Step 2: Installing Firebase CLI globally...
echo This may take 2-3 minutes...
echo.
call npm install -g firebase-tools
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Failed to install Firebase CLI
    echo.
    echo Try running PowerShell as Administrator and run:
    echo npm install -g firebase-tools
    echo.
    pause
    exit /b 1
)
echo.
echo ✓ Firebase CLI installed successfully!
echo.

echo Step 3: Verifying Firebase CLI installation...
firebase --version
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Firebase CLI not found after installation
    echo Please restart your terminal and try again
    pause
    exit /b 1
)
echo.

echo Step 4: Logging into Firebase...
echo A browser window will open for authentication...
echo.
firebase login
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Firebase login failed
    pause
    exit /b 1
)
echo ✓ Logged in successfully
echo.

echo Step 5: Setting Firebase project...
firebase use splitx-451412
if %ERRORLEVEL% NEQ 0 (
    echo Warning: Could not set project automatically
    echo You may need to run: firebase use --add
)
echo.

echo Step 6: Checking functions directory...
if not exist "functions" (
    echo Initializing Firebase Functions...
    firebase init functions
    if %ERRORLEVEL% NEQ 0 (
        echo ERROR: Failed to initialize functions
        pause
        exit /b 1
    )
)
echo ✓ Functions directory ready
echo.

echo Step 7: Copying function code...
if exist "firebase_function_simple.js" (
    copy /Y "firebase_function_simple.js" "functions\index.js"
    echo ✓ Function code copied
) else (
    echo ERROR: firebase_function_simple.js not found!
    pause
    exit /b 1
)
echo.

echo Step 8: Installing function dependencies...
cd functions
call npm install
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to install dependencies
    cd ..
    pause
    exit /b 1
)
cd ..
echo ✓ Dependencies installed
echo.

echo Step 9: Deploying to Firebase...
echo This may take 1-2 minutes...
echo.
firebase deploy --only functions
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Deployment failed!
    echo.
    echo Common fixes:
    echo 1. Make sure you're logged in: firebase login
    echo 2. Check your internet connection
    echo 3. Verify project: firebase use splitx-451412
    echo.
    pause
    exit /b 1
)
echo.

echo ========================================
echo   ✓✓✓ SUCCESS! ✓✓✓
echo ========================================
echo.
echo Firebase Functions deployed successfully!
echo.
echo Next steps:
echo 1. Open your SplitX app
echo 2. Go to Profile → Test Notifications
echo 3. Click "Send Test Notification"
echo 4. Put app in BACKGROUND (press home button)
echo 5. Wait 2-3 seconds
echo 6. You should receive a notification!
echo.
echo To view logs:
echo firebase functions:log
echo.
echo To check deployed functions:
echo firebase functions:list
echo.
pause
