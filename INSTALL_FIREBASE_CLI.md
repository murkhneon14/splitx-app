# Install Firebase CLI - Step by Step

## Quick Fix

### Option 1: Automatic Installation (Easiest)
**Just double-click:** `install_and_deploy.bat`

This will:
1. Check if Node.js is installed
2. Install Firebase CLI
3. Login to Firebase
4. Deploy your functions
5. Done!

### Option 2: Manual Installation

#### Step 1: Check if Node.js is Installed
```bash
node --version
npm --version
```

**If you see version numbers** → Node.js is installed ✓  
**If you see error** → Install Node.js first (see below)

#### Step 2: Install Firebase CLI
```bash
npm install -g firebase-tools
```

Wait 2-3 minutes for installation...

#### Step 3: Verify Installation
```bash
firebase --version
```

Should show: `12.x.x` or similar

#### Step 4: Login to Firebase
```bash
firebase login
```

Browser will open → Login with your Google account

#### Step 5: Deploy Functions
```bash
cd c:\splitX
firebase use splitx-451412
firebase deploy --only functions
```

## If Node.js is Not Installed

### Download Node.js
1. Go to: https://nodejs.org/
2. Download **LTS version** (recommended)
3. Run installer
4. Click "Next" through all steps
5. Restart your terminal/PowerShell
6. Verify: `node --version`

### After Installing Node.js
Run the automatic script:
```bash
cd c:\splitX
install_and_deploy.bat
```

## Troubleshooting

### Issue: "npm is not recognized"
**Solution:** Restart your terminal after installing Node.js

### Issue: "Permission denied" when installing
**Solution:** Run PowerShell as Administrator:
1. Right-click PowerShell
2. Select "Run as Administrator"
3. Run: `npm install -g firebase-tools`

### Issue: "Firebase login failed"
**Solution:**
1. Check internet connection
2. Try: `firebase login --reauth`
3. Or: `firebase login --no-localhost`

### Issue: "Project not found"
**Solution:**
```bash
firebase use --add
# Select: splitx-451412
```

### Issue: "Deployment failed"
**Check:**
1. You're logged in: `firebase login`
2. Project is set: `firebase use splitx-451412`
3. Internet connection is active
4. Functions folder exists with index.js

## Verify Everything Works

### Check 1: Firebase CLI Installed
```bash
firebase --version
```
Should show version number

### Check 2: Logged In
```bash
firebase projects:list
```
Should show your projects including splitx-451412

### Check 3: Functions Deployed
```bash
firebase functions:list
```
Should show: `sendFCMNotification`

### Check 4: Test Notification
1. Open app
2. Profile → Test Notifications
3. Send test
4. Put app in background
5. Receive notification!

## Quick Commands Reference

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Set project
firebase use splitx-451412

# Deploy functions
firebase deploy --only functions

# View logs
firebase functions:log

# List functions
firebase functions:list

# Delete a function
firebase functions:delete functionName
```

## Alternative: Use Firebase Console

If CLI doesn't work, you can use Firebase Console:

1. Go to: https://console.firebase.google.com/
2. Select project: splitx-451412
3. Click "Functions" in left menu
4. Click "Get Started"
5. Follow the web-based setup

## Need Help?

### Check Installation
```bash
# Check Node.js
node --version

# Check npm
npm --version

# Check Firebase CLI
firebase --version

# Check if logged in
firebase projects:list
```

### Common Fixes
```bash
# Reinstall Firebase CLI
npm uninstall -g firebase-tools
npm install -g firebase-tools

# Clear npm cache
npm cache clean --force

# Login again
firebase logout
firebase login
```

## Success Checklist

- [ ] Node.js installed (`node --version` works)
- [ ] npm installed (`npm --version` works)
- [ ] Firebase CLI installed (`firebase --version` works)
- [ ] Logged into Firebase (`firebase projects:list` shows projects)
- [ ] Project set (`firebase use splitx-451412`)
- [ ] Functions deployed (`firebase deploy --only functions`)
- [ ] Test notification works!

## Next Steps After Installation

1. **Copy function code:**
   ```bash
   copy firebase_function_simple.js functions\index.js
   ```

2. **Install dependencies:**
   ```bash
   cd functions
   npm install
   cd ..
   ```

3. **Deploy:**
   ```bash
   firebase deploy --only functions
   ```

4. **Test:**
   - Open app → Profile → Test Notifications
   - Send test → Background app → Receive notification!

---

**Still having issues?** Run `install_and_deploy.bat` - it handles everything automatically!
