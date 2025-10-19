@echo off
echo ========================================
echo   SplitX - Deploy FCM Notifications
echo ========================================
echo.

echo Step 1: Checking if Firebase CLI is installed...
where firebase >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Firebase CLI not found!
    echo.
    echo Please install Firebase CLI first:
    echo npm install -g firebase-tools
    echo.
    pause
    exit /b 1
)
echo ✓ Firebase CLI found
echo.

echo Step 2: Checking if functions directory exists...
if not exist "functions" (
    echo Creating functions directory...
    firebase init functions
    if %ERRORLEVEL% NEQ 0 (
        echo ERROR: Failed to initialize functions
        pause
        exit /b 1
    )
)
echo ✓ Functions directory exists
echo.

echo Step 3: Copying function code...
if exist "firebase_function_simple.js" (
    copy /Y "firebase_function_simple.js" "functions\index.js"
    echo ✓ Function code copied
) else (
    echo ERROR: firebase_function_simple.js not found!
    pause
    exit /b 1
)
echo.

echo Step 4: Installing dependencies...
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

echo Step 5: Deploying to Firebase...
firebase deploy --only functions
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Deployment failed!
    pause
    exit /b 1
)
echo.

echo ========================================
echo   ✓ Deployment Successful!
echo ========================================
echo.
echo Your notifications are now live!
echo.
echo Next steps:
echo 1. Open your app
echo 2. Go to Profile → Test Notifications
echo 3. Send a test notification
echo 4. Put app in background
echo 5. You should receive the notification!
echo.
echo To view logs:
echo firebase functions:log
echo.
pause
