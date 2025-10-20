# 🔔 Fix Push Notifications - Quick Guide

## ✅ What Was Fixed

The push notifications weren't working because:
1. **Wrong collection name**: App was writing to `fcmMessages` but Cloud Function was listening to `notifications`
2. **Wrong field name**: App used `token` but Cloud Function expected `to`
3. **Duplicate keys**: Had duplicate `status` and `createdAt` fields

## 🚀 Deploy the Fix

### Step 1: Install Firebase CLI (if not installed)

```bash
npm install -g firebase-tools
```

**Verify installation:**
```bash
firebase --version
```

### Step 2: Login to Firebase

```bash
firebase login
```

This will open a browser window - login with your Google account.

### Step 3: Deploy Cloud Functions

**Option A - Using batch file:**
```bash
cd c:\splitX
.\deploy_notifications.bat
```

**Option B - Manual deployment:**
```bash
cd c:\splitX\functions
npm install
firebase deploy --only functions
```

### Step 2: Test Notifications

1. **Open the app** on your device
2. **Navigate** to any chat
3. **Send a message** or create an expense
4. **Put the app in background**
5. **You should receive a notification!** 🎉

## 📝 What Changed

### File: `lib/services/push_notification_helper.dart`

**Before:**
```dart
await _firestore.collection('fcmMessages').add({
  'token': token,  // ❌ Wrong field name
  'notification': {...},
  'data': {...},
});
```

**After:**
```dart
await _firestore.collection('notifications').add({
  'to': token,  // ✅ Correct field name
  'notification': {...},
  'data': {...},
  'status': 'pending',
  'createdAt': FieldValue.serverTimestamp(),
});
```

## 🔍 Verify Cloud Functions Are Deployed

Check if functions are deployed:

```bash
firebase functions:list
```

You should see:
- ✅ `sendPushNotification` - Sends FCM notifications
- ✅ `onMessageCreated` - Auto-creates notifications for new messages

## 📊 Monitor Notifications

### View Logs:
```bash
firebase functions:log
```

### Check Firestore:
1. Open Firebase Console
2. Go to Firestore Database
3. Check `notifications` collection
4. You should see documents with:
   - `status: 'sent'` (successful)
   - `status: 'error'` (failed - check error field)

## 🐛 Troubleshooting

### Notifications Still Not Working?

1. **Check FCM Token:**
   - Open app
   - Check debug logs for "📱 FCM Token:"
   - Token should be saved to Firestore

2. **Check Cloud Functions:**
   ```bash
   firebase functions:log --only sendPushNotification
   ```

3. **Check Firestore Rules:**
   - Ensure `notifications` collection is writable
   - Ensure `users` collection is readable

4. **Check Android Permissions:**
   - Go to App Settings
   - Enable Notifications
   - Enable "Show on lock screen"

5. **Re-deploy Functions:**
   ```bash
   firebase deploy --only functions --force
   ```

## ✨ How It Works Now

1. **User sends message/expense**
   ↓
2. **App writes to Firestore `notifications` collection**
   ```json
   {
     "to": "fcm_token_here",
     "notification": {
       "title": "New Message",
       "body": "Hello!"
     },
     "status": "pending"
   }
   ```
   ↓
3. **Cloud Function `sendPushNotification` triggers**
   ↓
4. **Function sends via Firebase Cloud Messaging**
   ↓
5. **Updates document with status: 'sent'**
   ↓
6. **User receives notification!** 🎉

## 📱 Test Checklist

- [ ] Deploy Cloud Functions
- [ ] Open app and check FCM token is saved
- [ ] Send a message
- [ ] Put app in background
- [ ] Receive notification
- [ ] Tap notification → Opens correct chat
- [ ] Check Firestore `notifications` collection
- [ ] Check Firebase Functions logs

## 🎯 Next Steps

1. **Deploy the fix** using the command above
2. **Test thoroughly** on real devices
3. **Monitor logs** for any errors
4. **Enjoy working notifications!** 🎉
