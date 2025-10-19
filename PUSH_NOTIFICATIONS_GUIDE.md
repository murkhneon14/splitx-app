# Push Notifications Guide - Complete Implementation

## Overview
Comprehensive push notification system using Firebase Cloud Messaging (FCM) for all message types in SplitX.

## Notification Types Implemented

### 1. **Regular Text Messages** 💬
- **Trigger:** User sends a text message in chat
- **Notification:** "New Message from [Name]" - "[Message text]"
- **Data:** chatId, senderId, messageId, type: 'direct_message'

### 2. **Group Messages** 👥
- **Trigger:** User sends a message in a group
- **Notification:** "[Group Name] - [Sender]" - "[Message text]"
- **Data:** chatId, senderId, messageId, type: 'group_message', groupName

### 3. **Expense Notifications** 💰
- **Trigger:** User creates an expense
- **Notification:** "💰 New Expense from [Payer]" - "[Payer] paid ₹[Amount] for [Description]. Your share: ₹[Share]"
- **Data:** expenseId, amount, recipientShare, description, type: 'expense'

### 4. **Settlement Request** 💳
- **Trigger:** User requests settlement
- **Notification:** "💳 Settlement Request" - "[Name] is requesting ₹[Amount] for settlement"
- **Data:** chatId, amount, messageId, type: 'settlement_request'

### 5. **Payment Confirmation** ✅
- **Trigger:** User confirms payment
- **Notification:** "✅ Payment Confirmation" - "[Name] has sent a payment confirmation for ₹[Amount]. Please verify and approve."
- **Data:** chatId, amount, messageId, type: 'payment_confirmation', requiresApproval: 'true'

### 6. **Settlement Completed** 🎉
- **Trigger:** Payment is approved
- **Notification:** "🎉 Settlement Completed" - "Payment of ₹[Amount] has been settled with [Name]"
- **Data:** chatId, amount, type: 'settlement_completed'

## Architecture

### Components

```
┌─────────────────────────────────────────────────┐
│         PushNotificationHelper                  │
│  (lib/services/push_notification_helper.dart)  │
│                                                 │
│  - sendMessageNotification()                    │
│  - sendExpenseNotification()                    │
│  - sendSettlementRequestNotification()          │
│  - sendPaymentConfirmationNotification()        │
│  - sendSettlementCompletedNotification()        │
│  - sendGroupNotification()                      │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│            Firestore Collection                 │
│              'notifications'                    │
│                                                 │
│  Document Structure:                            │
│  {                                              │
│    to: "FCM_TOKEN",                            │
│    notification: { title, body },              │
│    data: { type, chatId, ... },                │
│    android: { priority, channelId },           │
│    apns: { sound, badge },                     │
│    status: "pending"                           │
│  }                                              │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│       Firebase Cloud Functions                  │
│      (Processes notifications)                  │
│                                                 │
│  - Reads from 'notifications' collection        │
│  - Sends via FCM API                           │
│  - Updates status to 'sent'/'failed'           │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│         User's Device (FCM)                     │
│                                                 │
│  - Receives notification                        │
│  - Shows in notification tray                   │
│  - Opens app on tap                            │
└─────────────────────────────────────────────────┘
```

## Implementation Details

### 1. PushNotificationHelper Service

**Location:** `lib/services/push_notification_helper.dart`

**Key Methods:**

#### sendMessageNotification
```dart
await PushNotificationHelper.sendMessageNotification(
  recipientId: 'user_uid',
  senderName: 'John',
  messageText: 'Hello!',
  chatId: 'chat_123',
  messageId: 'msg_456',
  isGroup: false,
);
```

#### sendExpenseNotification
```dart
await PushNotificationHelper.sendExpenseNotification(
  recipientId: 'user_uid',
  payerName: 'John',
  description: 'Dinner',
  amount: 1000.0,
  recipientShare: 500.0,
  chatId: 'chat_123',
  expenseId: 'exp_789',
  isGroup: false,
);
```

#### sendSettlementRequestNotification
```dart
await PushNotificationHelper.sendSettlementRequestNotification(
  recipientId: 'user_uid',
  requesterName: 'John',
  amount: 500.0,
  chatId: 'chat_123',
  messageId: 'msg_456',
);
```

#### sendPaymentConfirmationNotification
```dart
await PushNotificationHelper.sendPaymentConfirmationNotification(
  recipientId: 'user_uid',
  payerName: 'John',
  amount: 500.0,
  chatId: 'chat_123',
  messageId: 'msg_456',
);
```

#### sendSettlementCompletedNotification
```dart
await PushNotificationHelper.sendSettlementCompletedNotification(
  recipientId: 'user_uid',
  payerName: 'John',
  amount: 500.0,
  chatId: 'chat_123',
);
```

#### sendGroupNotification
```dart
await PushNotificationHelper.sendGroupNotification(
  recipientIds: ['user1', 'user2', 'user3'],
  groupName: 'Trip to Goa',
  senderName: 'John',
  messageText: 'Hello everyone!',
  chatId: 'group_123',
  messageId: 'msg_456',
  type: 'group_message',
);
```

### 2. Integration Points

#### UserChatScreen.dart
- **Text messages:** Notification sent after message is saved
- **Settlement requests:** Notification sent when request is created
- **Payment confirmations:** Notification sent when payment is confirmed
- **Settlement completed:** Notification sent when payment is approved

#### calculation.dart
- **Expenses:** Notification sent to all participants after expense is saved
- **Batch notifications:** Sends to multiple users efficiently

### 3. Firestore Structure

#### Notifications Collection
```javascript
{
  // Document ID: auto-generated
  to: "FCM_TOKEN_STRING",
  notification: {
    title: "New Message from John",
    body: "Hello! How are you?"
  },
  data: {
    type: "direct_message",
    chatId: "chat_user1_user2",
    senderId: "user1_uid",
    messageId: "msg_123",
    click_action: "FLUTTER_NOTIFICATION_CLICK",
    android_channel_id: "chat_channel",
    sound: "default",
    priority: "high",
    content_available: "true"
  },
  android: {
    priority: "high",
    notification: {
      channelId: "chat_channel",
      sound: "default",
      priority: "high",
      defaultSound: true,
      defaultVibrateTimings: true
    }
  },
  apns: {
    payload: {
      aps: {
        sound: "default",
        badge: 1,
        alert: {
          title: "New Message from John",
          body: "Hello! How are you?"
        }
      }
    }
  },
  createdAt: Timestamp,
  status: "pending" // or "sent" or "failed"
}
```

#### Users Collection (FCM Token)
```javascript
{
  uid: "user_uid",
  username: "John",
  email: "john@example.com",
  fcmToken: "FCM_TOKEN_STRING",  // Updated on login
  fcmTokenUpdatedAt: Timestamp,
  upiId: "john@paytm"
}
```

## Firebase Cloud Functions Setup

You need to set up Cloud Functions to process the notifications:

### functions/index.js
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
        notification: notification.notification,
        data: notification.data,
        android: notification.android,
        apns: notification.apns,
      };

      const response = await admin.messaging().send(message);
      console.log('Successfully sent message:', response);

      // Update status to sent
      await snap.ref.update({
        status: 'sent',
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        response: response,
      });

      return response;
    } catch (error) {
      console.error('Error sending message:', error);
      
      // Update status to failed
      await snap.ref.update({
        status: 'failed',
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
        error: error.message,
      });

      throw error;
    }
  });
```

### Deploy Cloud Functions
```bash
cd functions
npm install firebase-functions firebase-admin
firebase deploy --only functions
```

## Testing

### 1. Test Regular Message
```dart
// In UserChatScreen
await PushNotificationHelper.sendMessageNotification(
  recipientId: 'test_user_id',
  senderName: 'Test User',
  messageText: 'Test message',
  chatId: 'test_chat',
  messageId: 'test_msg',
  isGroup: false,
);
```

### 2. Test Expense Notification
```dart
// In calculation.dart
await PushNotificationHelper.sendExpenseNotification(
  recipientId: 'test_user_id',
  payerName: 'Test Payer',
  description: 'Test Expense',
  amount: 100.0,
  recipientShare: 50.0,
  chatId: 'test_chat',
  expenseId: 'test_expense',
  isGroup: false,
);
```

### 3. Check Firestore
1. Open Firebase Console
2. Go to Firestore Database
3. Check `notifications` collection
4. Verify document structure
5. Check `status` field (should be 'sent')

### 4. Check Device
1. Ensure app is in background
2. Send a test notification
3. Check notification tray
4. Tap notification
5. Verify app opens to correct screen

## Troubleshooting

### Notifications Not Received

**1. Check FCM Token**
```dart
// In UserChatScreen or ProfileScreen
final token = await FirebaseMessaging.instance.getToken();
print('FCM Token: $token');

// Verify it's saved in Firestore
final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .get();
print('Saved token: ${userDoc.data()?['fcmToken']}');
```

**2. Check Notification Permission**
```dart
NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
  alert: true,
  badge: true,
  sound: true,
);
print('Permission status: ${settings.authorizationStatus}');
```

**3. Check Cloud Functions Logs**
```bash
firebase functions:log
```

**4. Check Firestore Notifications**
- Open Firebase Console
- Check `notifications` collection
- Look for `status: 'failed'`
- Check `error` field for details

### Common Issues

#### Issue: Token is null
**Solution:** 
- Ensure Firebase is initialized
- Request permission before getting token
- Check if device supports FCM

#### Issue: Notifications not showing
**Solution:**
- Check notification channel is created (Android)
- Verify app has notification permission
- Ensure app is in background (foreground requires local notification)

#### Issue: Cloud Function not triggering
**Solution:**
- Deploy functions: `firebase deploy --only functions`
- Check functions logs: `firebase functions:log`
- Verify Firestore rules allow writes to `notifications`

#### Issue: Wrong recipient receives notification
**Solution:**
- Verify `recipientId` is correct
- Check FCM token is up to date
- Ensure token belongs to correct user

## Best Practices

### 1. Error Handling
```dart
try {
  await PushNotificationHelper.sendMessageNotification(...);
} catch (e) {
  debugPrint('Failed to send notification: $e');
  // Don't fail the main operation
}
```

### 2. Batch Notifications
```dart
// For group messages, use sendGroupNotification
await PushNotificationHelper.sendGroupNotification(
  recipientIds: memberIds,
  groupName: groupName,
  senderName: senderName,
  messageText: message,
  chatId: chatId,
  messageId: messageId,
);
```

### 3. Token Management
- Update token on app launch
- Update token when it refreshes
- Remove token on logout

### 4. Notification Channels (Android)
- Create separate channels for different types
- Allow users to customize per channel
- Use appropriate priority levels

## Performance Considerations

### 1. Batch Operations
- Send multiple notifications in parallel
- Use `Future.wait()` for concurrent sends
- Don't block UI thread

### 2. Token Caching
- Cache tokens in Firestore
- Update only when changed
- Clean up old tokens

### 3. Rate Limiting
- Don't spam notifications
- Batch similar notifications
- Use quiet hours

### 4. Payload Size
- Keep data payload small
- Use IDs instead of full objects
- Fetch details on app open

## Security

### 1. Firestore Rules
```javascript
// notifications collection
match /notifications/{notificationId} {
  allow create: if request.auth != null;
  allow read, update: if request.auth != null;
  allow delete: if false;
}
```

### 2. Token Protection
- Never expose FCM tokens publicly
- Store securely in Firestore
- Validate sender before sending

### 3. Data Validation
- Validate recipient exists
- Check sender permissions
- Sanitize message content

## Monitoring

### 1. Success Rate
- Track sent vs failed notifications
- Monitor delivery times
- Alert on high failure rates

### 2. User Engagement
- Track notification opens
- Measure click-through rates
- Analyze user preferences

### 3. Performance Metrics
- Notification latency
- Token refresh rate
- Error rates by type

## Future Enhancements

- [ ] Rich notifications with images
- [ ] Action buttons in notifications
- [ ] Notification grouping
- [ ] Custom sounds per type
- [ ] Notification scheduling
- [ ] A/B testing for notification content
- [ ] Analytics integration
- [ ] Multi-language support
- [ ] Notification preferences UI
- [ ] Do Not Disturb mode
