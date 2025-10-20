import * as functions from 'firebase-functions';
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
  .onCreate(async (snapshot, context) => {
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
  .onCreate(async (snapshot, context) => {
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

      // Check if it's a group chat
      const participants: string[] = chatData.participants || [];
      const isGroup = chatData.isGroup === true || participants.length > 2;
      const groupName = chatData.groupName || chatData.name || 'Group Chat';

      console.log(`Processing message in ${isGroup ? 'group' : 'direct'} chat: ${chatId}`);
      console.log(`Participants: ${participants.length}, isGroup: ${isGroup}`);

      // Get all recipients (all participants except the sender)
      const recipientIds = participants.filter((id: string) => id !== senderId);
      
      if (recipientIds.length === 0) {
        console.log('No recipients found');
        return null;
      }

      console.log(`Sending notifications to ${recipientIds.length} recipient(s)`);

      // Create notifications for each recipient
      const notificationPromises = recipientIds.map(async (recipientId: string) => {
        try {
          // Get the recipient's FCM token
          const userDoc = await admin.firestore().collection('users').doc(recipientId).get();
          if (!userDoc.exists) {
            console.log(`User not found: ${recipientId}`);
            return null;
          }

          const userData = userDoc.data();
          const token = userData?.fcmToken;
          
          if (!token) {
            console.log(`No FCM token for user: ${recipientId}`);
            return null;
          }

          // Create notification title based on chat type
          const notificationTitle = isGroup 
            ? `${groupName} - ${senderName || 'Someone'}`
            : `New message from ${senderName || 'Someone'}`;

          // Create a notification document with proper data
          const notification = {
            to: token,
            notification: {
              title: notificationTitle,
              body: text || 'You have a new message',
            },
            data: {
              type: 'new_message',
              chatId: chatId,
              senderId: senderId,
              messageId: snapshot.id,
              isGroup: isGroup ? 'true' : 'false',
              groupName: isGroup ? groupName : '',
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            status: 'pending',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          };

          console.log(`Creating notification for ${recipientId}: ${notificationTitle}`);

          // Save the notification to Firestore (this will trigger the sendPushNotification function)
          return admin.firestore().collection('notifications').add(notification);
        } catch (error) {
          console.error(`Error creating notification for ${recipientId}:`, error);
          return null;
        }
      });

      // Wait for all notifications to be created
      await Promise.all(notificationPromises);
      console.log('All notifications created successfully');
      return null;
    } catch (error) {
      console.error('Error creating notification:', error);
      return null;
    }
  });
