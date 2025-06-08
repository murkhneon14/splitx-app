import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin
admin.initializeApp();

// Define interfaces for our data structures
interface NotificationPayload {
  title: string;
  body: string;
}

interface NotificationData {
  to: string;
  notification: NotificationPayload;
  data: Record<string, string>;
  status?: string;
  sentAt?: admin.firestore.Timestamp;
  error?: string;
  messageId?: string;
}

// When a new notification document is created, send it via FCM
export const sendPushNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snapshot: admin.firestore.DocumentSnapshot, context: functions.EventContext) => {
    const notification = snapshot.data() as NotificationData | undefined;
    if (!notification) {
      console.error('No notification data found');
      return null;
    }

    const { to, notification: notifData, data } = notification;

    try {
      // Send the notification
      const response = await admin.messaging().send({
        token: to,
        notification: {
          title: notifData.title,
          body: notifData.body,
        },
        data: data,
        android: {
          priority: 'high',
        },
        apns: {
          payload: {
            aps: {
              contentAvailable: true,
              badge: 1,
              sound: 'default',
            },
          },
        },
      });

      console.log('Successfully sent message:', response);
      
      // Update the notification document with the message ID
      return snapshot.ref.update({
        status: 'sent',
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        messageId: response,
      });
    } catch (error) {
      console.error('Error sending message:', error);
      
      // Update the notification document with the error
      return snapshot.ref.update({
        status: 'error',
        error: error instanceof Error ? error.message : String(error),
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

// Define message interface
interface ChatMessage {
  senderId: string;
  text: string;
  senderName: string;
  timestamp: admin.firestore.Timestamp;
  type: string;
}

// When a new message is added to a chat, create a notification for the recipient
export const onMessageCreated = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snapshot: admin.firestore.DocumentSnapshot, context: functions.EventContext) => {
    const message = snapshot.data() as ChatMessage | undefined;
    if (!message) {
      console.error('No message data found');
      return null;
    }

    const { chatId } = context.params;
    const { senderId, text, senderName } = message;

    try {
      // Get the chat document
      const chatDoc = await admin.firestore().collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return null;

      const chatData = chatDoc.data();
      if (!chatData) return null;

      // Find the recipient (the other user in the chat)
      const participants: string[] = chatData.participants || [];
      const recipientId = participants.find((id: string) => id !== senderId);
      if (!recipientId) return null;

      // Get the recipient's FCM token
      const userDoc = await admin.firestore().collection('users').doc(recipientId).get();
      if (!userDoc.exists) return null;

      const userData = userDoc.data();
      const token = userData?.fcmToken;
      if (!token) return null;

      // Create a notification document
      const notification = {
        to: token,
        notification: {
          title: `New message from ${senderName || 'Someone'}`,
          body: text || 'You have a new message',
        },
        data: {
          type: 'new_message',
          chatId: chatId,
          senderId: senderId,
          messageId: snapshot.id,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Save the notification to Firestore (this will trigger the sendPushNotification function)
      return admin.firestore().collection('notifications').add(notification);
    } catch (error) {
      console.error('Error creating notification:', error);
      return null;
    }
  });
