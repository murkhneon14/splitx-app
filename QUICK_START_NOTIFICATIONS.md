# 🚀 Quick Start - Enable Notifications in 5 Minutes

## What You Need
- ✅ Firebase project (already set up: splitx-451412)
- ✅ Firebase CLI installed
- ✅ 5 minutes

## Step-by-Step Guide

### Method 1: Automatic (Windows)

1. **Double-click** `deploy_notifications.bat`
2. Wait for deployment to complete
3. Done! ✅

### Method 2: Manual (All Platforms)

#### Step 1: Install Firebase CLI (if not installed)
```bash
npm install -g firebase-tools
```

#### Step 2: Login to Firebase
```bash
firebase login
```

#### Step 3: Initialize Functions (if not done)
```bash
cd c:\splitX
firebase init functions
```
- Select: **JavaScript**
- Install dependencies: **Yes**

#### Step 4: Copy Function Code
1. Open `firebase_function_simple.js`
2. Copy all content (Ctrl+A, Ctrl+C)
3. Open `functions\index.js`
4. Replace everything with copied content
5. Save file

#### Step 5: Deploy
```bash
firebase deploy --only functions
```

Wait 1-2 minutes for deployment...

#### Step 6: Test
1. Open your app
2. Go to **Profile** screen
3. Tap **"Test Notifications"**
4. Click **"Send Test Notification"**
5. **Put app in background** (press home button)
6. Wait 2-3 seconds
7. You should see a notification! 🎉

## Verify It's Working

### Check 1: Deployment Success
After running `firebase deploy`, you should see:
```
✔ functions[sendFCMNotification]: Successful create operation.
✔ Deploy complete!
```

### Check 2: Firestore
1. Open Firebase Console
2. Go to Firestore Database
3. Check `fcmMessages` collection
4. Send a test notification
5. Watch the `status` field change from `pending` to `sent`

### Check 3: Logs
```bash
firebase functions:log
```

Look for:
```
📨 Processing notification: abc123
✅ Notification sent successfully
```

## Troubleshooting

### "Firebase CLI not found"
**Install it:**
```bash
npm install -g firebase-tools
```

### "Permission denied"
**Login again:**
```bash
firebase login
```

### "Deployment failed"
**Check:**
1. You're in the correct directory: `c:\splitX`
2. You have internet connection
3. Firebase project is selected: `firebase use splitx-451412`

### "Function not triggering"
**Check:**
1. Function is deployed: `firebase functions:list`
2. Collection name is correct: `fcmMessages` (not `notifications`)
3. Check logs: `firebase functions:log`

### "Notification not received"
**Check:**
1. App is in **background** (not foreground)
2. Notification permission granted
3. FCM token saved in Firestore
4. Check Firestore - status should be "sent"
5. Device has internet connection

## How It Works

```
1. User sends message
   ↓
2. App saves to Firestore 'fcmMessages' collection
   ↓
3. Cloud Function automatically triggers
   ↓
4. Function sends notification via FCM
   ↓
5. User receives notification
```

## What Gets Deployed

**Function Name:** `sendFCMNotification`
- **Trigger:** Firestore document created in `fcmMessages`
- **Action:** Send FCM notification
- **Cost:** FREE (within Firebase free tier)

**Optional Functions:**
- `testFCM` - HTTP endpoint for manual testing
- `cleanupOldNotifications` - Runs daily to clean up old messages

## Testing Commands

### Test from Command Line
```bash
# View logs
firebase functions:log

# Test locally (optional)
firebase emulators:start --only functions,firestore

# List deployed functions
firebase functions:list

# Delete a function (if needed)
firebase functions:delete sendFCMNotification
```

### Test from Firebase Console
1. Go to Firebase Console → Cloud Messaging
2. Click "Send test message"
3. Enter your FCM token (from Test Notifications screen)
4. Send message
5. Should receive notification!

## Cost Breakdown

**Firebase Cloud Functions:**
- Free tier: 2,000,000 invocations/month
- Your usage: ~100-1,000 notifications/day
- **Total cost: $0** (well within free tier)

**Firebase Cloud Messaging:**
- Completely FREE
- Unlimited messages

## Next Steps

After deployment:

1. ✅ **Test with app** - Use Test Notifications screen
2. ✅ **Send real messages** - Verify notifications work in chat
3. ✅ **Test expenses** - Create expense and check notification
4. ✅ **Test settlements** - Request settlement and check notification
5. ✅ **Monitor logs** - Check Firebase Console for any errors

## Support

If you still have issues:

1. **Check logs:**
   ```bash
   firebase functions:log --limit 50
   ```

2. **Verify function is deployed:**
   ```bash
   firebase functions:list
   ```

3. **Test with Firebase Console:**
   - Go to Cloud Messaging
   - Send test message with your FCM token

4. **Check Firestore rules:**
   - Ensure users can write to `fcmMessages`

5. **Verify FCM token:**
   - Use Test Notifications screen
   - Check token is saved in Firestore

## Success Checklist

- [ ] Firebase CLI installed
- [ ] Logged into Firebase
- [ ] Function code copied to `functions/index.js`
- [ ] Dependencies installed (`npm install` in functions folder)
- [ ] Function deployed successfully
- [ ] Test notification sent from app
- [ ] App put in background
- [ ] Notification received!

## Quick Reference

```bash
# Deploy
firebase deploy --only functions

# View logs
firebase functions:log

# Test locally
firebase emulators:start

# List functions
firebase functions:list
```

---

**That's it!** Your notifications should now work automatically. Every time a message is sent, expense is created, or settlement is requested, the recipient will get a push notification! 🎉
