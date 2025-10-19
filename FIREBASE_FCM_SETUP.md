# Firebase FCM Setup - No Backend Required! 🚀

## Overview
This guide shows you how to enable FCM notifications using **Firebase Extensions** - no backend code needed!

## Option 1: Firebase Extensions (Easiest - Recommended)

### Step 1: Install Firebase Extension
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **splitx-451412**
3. Click **Extensions** in left menu
4. Click **"Explore Extensions"**
5. Search for **"Trigger Email from Firestore"** or **"Send with SendGrid"**
   
   **OR use the FCM extension:**
   - Search: **"Firebase Cloud Messaging"**
   - Install the extension

### Step 2: Configure Extension
When installing, set:
- **Collection path:** `fcmMessages`
- **Token field:** `token`
- **Notification title field:** `notification.title`
- **Notification body field:** `notification.body`
- **Data field:** `data`

### Step 3: Test
1. Open your app
2. Go to Profile → Test Notifications
3. Send a test notification
4. Check Firestore → `fcmMessages` collection
5. Extension will automatically process and send!

## Option 2: Simple Cloud Function (5 minutes)

### Step 1: Initialize Firebase Functions
```bash
cd c:\splitX
firebase init functions
```

Select:
- JavaScript (not TypeScript)
- Install dependencies: Yes

### Step 2: Replace functions/index.js
```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendFCM = functions.firestore
  .document('fcmMessages/{messageId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    
    try {
      await admin.messaging().send({
        token: data.token,
        notification: data.notification,
        data: data.data || {},
        android: data.android || { priority: 'high' },
        apns: data.apns || {},
      });
      
      await snap.ref.update({ status: 'sent' });
      console.log('✅ Sent notification');
    } catch (error) {
      await snap.ref.update({ status: 'failed', error: error.message });
      console.error('❌ Error:', error);
    }
  });
```

### Step 3: Deploy
```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

That's it! 🎉

## Option 3: Firestore Triggers (Manual)

If you already have Cloud Functions set up, just add this trigger:

```javascript
exports.processNotification = functions.firestore
  .document('fcmMessages/{docId}')
  .onCreate(async (snapshot, context) => {
    const notification = snapshot.data();
    
    const message = {
      token: notification.token,
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
    };

    try {
      const response = await admin.messaging().send(message);
      await snapshot.ref.update({
        status: 'sent',
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        messageId: response,
      });
    } catch (error) {
      await snapshot.ref.update({
        status: 'failed',
        error: error.message,
      });
    }
  });
```

## Testing Your Setup

### 1. Check FCM Token
```dart
// In your app
final token = await FirebaseMessaging.instance.getToken();
print('Token: $token');
```

### 2. Save Token to Firestore
Use the Test Notifications screen in Profile

### 3. Send Test Notification
1. Open app
2. Profile → Test Notifications
3. Click "Send Test Notification"
4. **Put app in background**
5. Wait 2-3 seconds

### 4. Check Firestore
1. Firebase Console → Firestore
2. Check `fcmMessages` collection
3. Look for your test message
4. Status should change from `pending` to `sent`

### 5. Check Logs
```bash
firebase functions:log
```

Look for:
- ✅ "Sent notification"
- Or ❌ error messages

## Firestore Structure

### Collection: `fcmMessages`
```javascript
{
  token: "FCM_TOKEN_STRING",
  notification: {
    title: "New Message",
    body: "Hello!"
  },
  data: {
    type: "direct_message",
    chatId: "chat_123",
    senderId: "user_456",
    messageId: "msg_789"
  },
  android: {
    priority: "high",
    notification: {
      channelId: "chat_channel",
      sound: "default"
    }
  },
  apns: {
    payload: {
      aps: {
        sound: "default",
        badge: 1
      }
    }
  },
  createdAt: Timestamp,
  status: "pending" // → "sent" or "failed"
}
```

## Firestore Rules

Add these rules to allow writes:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to create FCM messages
    match /fcmMessages/{messageId} {
      allow create: if request.auth != null;
      allow read, update: if request.auth != null;
    }
    
    // Allow users to read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Troubleshooting

### Issue: Function not triggering
**Check:**
1. Functions deployed: `firebase deploy --only functions`
2. Check logs: `firebase functions:log`
3. Verify collection name is `fcmMessages`

### Issue: "Permission denied"
**Fix:**
1. Update Firestore rules (see above)
2. Verify user is authenticated
3. Check Firebase Console → Firestore → Rules

### Issue: "Invalid token"
**Fix:**
1. Get fresh token from device
2. Save to Firestore using Test screen
3. Verify token in Firestore matches device token

### Issue: Notification not showing
**Check:**
1. App is in **background** (not foreground)
2. Notification permission granted
3. Device has internet connection
4. Check Firestore - status should be "sent"

## Quick Deploy Commands

```bash
# Initialize (first time only)
firebase init functions

# Deploy functions
firebase deploy --only functions

# View logs
firebase functions:log

# Test locally
firebase emulators:start --only functions,firestore
```

## Verification Checklist

- [ ] Firebase project created
- [ ] Cloud Functions enabled
- [ ] Function deployed successfully
- [ ] Firestore rules updated
- [ ] FCM token saved in Firestore
- [ ] Test notification sent
- [ ] App in background during test
- [ ] Notification received!

## Cost

Firebase Cloud Functions:
- **Free tier:** 2M invocations/month
- **Your usage:** ~100-1000 notifications/day = FREE
- No credit card required for testing

## Next Steps

1. **Deploy the function** (Option 2 above)
2. **Test with the app** (Profile → Test Notifications)
3. **Send real messages** and verify notifications work
4. **Monitor** in Firebase Console → Functions → Logs

## Support

If notifications still don't work:
1. Check Firebase Console → Functions → Logs for errors
2. Verify FCM token in Firestore
3. Test with Firebase Console → Cloud Messaging → Send test message
4. Check device notification settings

---

**That's it!** Your notifications will now work automatically whenever a document is created in `fcmMessages` collection. No backend server needed! 🎉
