# Push Notification Troubleshooting Guide

## ✅ Quick Fix Steps

### Step 1: Test Notification System
1. Open the app
2. Go to **Profile** screen (bottom right icon)
3. Tap on **"Test Notifications"** (purple icon)
4. Follow the test steps:
   - Click "Check FCM Token" - Should show a token
   - Click "Save FCM Token to Firestore" - Should save successfully
   - Click "Check Token in Firestore" - Should show token is saved
   - Click "Send Test Notification" - Should send notification
5. **Put app in background** (press home button)
6. You should see a notification appear!

### Step 2: If No Token Found
**Problem:** "No FCM token" or token is null

**Solution:**
1. Check Firebase is initialized properly
2. Restart the app completely
3. Check internet connection
4. Try on a real device (not emulator)

### Step 3: If Token Not Saving to Firestore
**Problem:** "No token saved in Firestore!"

**Solution:**
1. Check Firestore rules allow writes
2. Verify user is logged in
3. Check internet connection
4. Use the "Save FCM Token" button in test screen

### Step 4: If Notification Not Received
**Problem:** Notification sent but not showing

**Possible Causes:**
1. **App in foreground** - Notifications only show when app is in background
2. **No backend endpoint** - Need to deploy Cloud Function or backend API
3. **Notification permission denied** - Check app settings
4. **Wrong token** - Token might be outdated

**Solutions:**
1. **Put app in background** before sending test
2. **Deploy backend** (see Backend Setup below)
3. **Check permissions:**
   - Android: Settings → Apps → SplitX → Notifications → Allow
   - iOS: Settings → SplitX → Notifications → Allow
4. **Refresh token** using test screen

## 🔧 Backend Setup Required

The app currently saves notifications to Firestore but needs a backend to actually send them via FCM.

### Option 1: Firebase Cloud Functions (Recommended)

Create `functions/index.js`:
```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    
    try {
      const message = {
        token: notification.to,
        notification: {
          title: notification.notification.title,
          body: notification.notification.body,
        },
        data: notification.data,
        android: {
          priority: 'high',
          notification: {
            channelId: 'chat_channel',
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      const response = await admin.messaging().send(message);
      console.log('Notification sent:', response);

      await snap.ref.update({
        status: 'sent',
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return response;
    } catch (error) {
      console.error('Error:', error);
      await snap.ref.update({
        status: 'failed',
        error: error.message,
      });
      throw error;
    }
  });
```

**Deploy:**
```bash
cd functions
npm install firebase-functions firebase-admin
firebase deploy --only functions
```

### Option 2: Backend API Endpoint

The app tries to call: `https://splitx-451412.df.r.appspot.com/send-notification`

Create this endpoint in your backend:
```javascript
// Express.js example
app.post('/send-notification', async (req, res) => {
  const { token, title, body, data } = req.body;
  
  try {
    const message = {
      token: token,
      notification: { title, body },
      data: data,
      android: {
        priority: 'high',
        notification: {
          channelId: 'chat_channel',
          sound: 'default',
        },
      },
    };

    const response = await admin.messaging().send(message);
    res.json({ success: true, messageId: response });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

## 📱 Testing Checklist

- [ ] FCM token is generated
- [ ] Token is saved to Firestore
- [ ] User document has `fcmToken` field
- [ ] Notification permission granted
- [ ] App is in background when testing
- [ ] Backend/Cloud Function is deployed
- [ ] Internet connection is active
- [ ] Firestore rules allow writes to `notifications` collection

## 🔍 Debugging Commands

### Check FCM Token
```dart
final token = await FirebaseMessaging.instance.getToken();
print('FCM Token: $token');
```

### Check Firestore Token
```dart
final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .get();
print('Saved token: ${userDoc.data()?['fcmToken']}');
```

### Check Notification Permission
```dart
final settings = await FirebaseMessaging.instance.requestPermission();
print('Permission: ${settings.authorizationStatus}');
```

## 🐛 Common Issues

### Issue 1: "No FCM token"
**Cause:** Firebase not initialized or device doesn't support FCM
**Fix:** 
- Restart app
- Check Firebase initialization in `main.dart`
- Test on real device

### Issue 2: "Token not saving"
**Cause:** Firestore rules or authentication issue
**Fix:**
- Check Firestore rules
- Verify user is logged in
- Check console for errors

### Issue 3: "Notification not showing"
**Cause:** App in foreground or backend not deployed
**Fix:**
- Put app in background
- Deploy Cloud Function
- Check notification permissions

### Issue 4: "Wrong recipient"
**Cause:** FCM token mismatch
**Fix:**
- Refresh token using test screen
- Verify recipient ID is correct
- Check token in Firestore

## 📊 Firestore Structure Check

### Users Collection
```javascript
users/{userId}
  ├─ username: "John"
  ├─ email: "john@example.com"
  ├─ fcmToken: "FCM_TOKEN_STRING"  // ← Must exist!
  └─ fcmTokenUpdatedAt: Timestamp
```

### Notifications Collection
```javascript
notifications/{notificationId}
  ├─ to: "FCM_TOKEN_STRING"
  ├─ notification:
  │   ├─ title: "New Message"
  │   └─ body: "Hello!"
  ├─ data: { chatId, senderId, ... }
  ├─ status: "pending"  // → Changes to "sent" after Cloud Function
  └─ createdAt: Timestamp
```

## ✅ Success Indicators

When notifications are working:
1. ✅ FCM token visible in test screen
2. ✅ Token saved in Firestore `users` collection
3. ✅ Notification document created in Firestore
4. ✅ Notification status changes to "sent"
5. ✅ Notification appears in device notification tray
6. ✅ Tapping notification opens app

## 🚀 Next Steps

1. **Test locally** using the Test Notifications screen
2. **Deploy backend** (Cloud Functions or API endpoint)
3. **Test with real users** by sending messages
4. **Monitor** Firestore `notifications` collection for status
5. **Check logs** in Firebase Console → Functions → Logs

## 📞 Still Not Working?

If notifications still don't work after following all steps:

1. Check Firebase Console → Cloud Messaging
2. Verify FCM is enabled for your project
3. Check device notification settings
4. Try on different device
5. Check Firebase Console logs for errors
6. Verify internet connection
7. Restart app completely

## 🎯 Quick Test Command

Run this in your test screen or debug console:
```dart
// Test notification to yourself
await PushNotificationHelper.sendMessageNotification(
  recipientId: FirebaseAuth.instance.currentUser!.uid,
  senderName: 'Test',
  messageText: 'Test notification',
  chatId: 'test',
  messageId: 'test_123',
  isGroup: false,
);
```

Then **put app in background** and wait 2-3 seconds!
