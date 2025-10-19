/**
 * Simple Firebase Cloud Function for FCM Notifications
 * 
 * SETUP:
 * 1. Copy this entire file content
 * 2. Go to: c:\splitX\functions\index.js
 * 3. Replace everything with this code
 * 4. Run: firebase deploy --only functions
 * 
 * That's it! Notifications will work automatically.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

/**
 * Trigger: When a document is created in 'fcmMessages' collection
 * Action: Send FCM notification to the specified token
 */
exports.sendFCMNotification = functions.firestore
  .document('fcmMessages/{messageId}')
  .onCreate(async (snap, context) => {
    const messageId = context.params.messageId;
    const data = snap.data();

    console.log(`📨 Processing notification: ${messageId}`);
    console.log(`📱 Token: ${data.token ? data.token.substring(0, 20) + '...' : 'MISSING'}`);
    console.log(`📝 Title: ${data.notification?.title || 'MISSING'}`);

    try {
      // Validate required fields
      if (!data.token) {
        throw new Error('Missing FCM token');
      }

      if (!data.notification || !data.notification.title) {
        throw new Error('Missing notification title');
      }

      // Construct the FCM message
      const message = {
        token: data.token,
        notification: {
          title: data.notification.title,
          body: data.notification.body || '',
        },
        data: data.data || {},
        android: {
          priority: 'high',
          notification: {
            channelId: 'chat_channel',
            sound: 'default',
            priority: 'high',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
              contentAvailable: true,
            },
          },
          headers: {
            'apns-priority': '10',
          },
        },
      };

      // Send the notification
      const response = await admin.messaging().send(message);
      
      console.log(`✅ Notification sent successfully: ${response}`);

      // Update the document with success status
      await snap.ref.update({
        status: 'sent',
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        fcmMessageId: response,
      });

      return { success: true, messageId: response };

    } catch (error) {
      console.error(`❌ Error sending notification: ${error.message}`);
      
      // Update the document with error status
      await snap.ref.update({
        status: 'failed',
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
        error: error.message,
        errorCode: error.code || 'unknown',
      });

      // Don't throw - we've logged the error
      return { success: false, error: error.message };
    }
  });

/**
 * Optional: HTTP endpoint for manual testing
 * URL: https://YOUR_PROJECT.cloudfunctions.net/testFCM
 */
exports.testFCM = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }

  try {
    const { token, title, body } = req.body;

    if (!token) {
      res.status(400).json({ error: 'Missing FCM token' });
      return;
    }

    const message = {
      token: token,
      notification: {
        title: title || 'Test Notification',
        body: body || 'This is a test from Cloud Function',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'chat_channel',
        },
      },
    };

    const response = await admin.messaging().send(message);
    
    res.json({
      success: true,
      messageId: response,
      message: 'Notification sent successfully!',
    });
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

/**
 * Optional: Cleanup old notifications (runs daily at midnight)
 */
exports.cleanupOldNotifications = functions.pubsub
  .schedule('every 24 hours')
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    const db = admin.firestore();
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - 7); // Delete messages older than 7 days

    try {
      const oldMessages = await db
        .collection('fcmMessages')
        .where('createdAt', '<', cutoffDate)
        .where('status', 'in', ['sent', 'failed'])
        .get();

      if (oldMessages.empty) {
        console.log('No old messages to delete');
        return null;
      }

      const batch = db.batch();
      oldMessages.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      
      console.log(`🗑️ Deleted ${oldMessages.size} old notifications`);
      return null;
    } catch (error) {
      console.error('Error cleaning up:', error);
      return null;
    }
  });
