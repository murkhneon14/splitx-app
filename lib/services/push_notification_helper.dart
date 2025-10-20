import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Helper class for sending push notifications via Firestore
/// Notifications are processed by Firebase Cloud Functions
class PushNotificationHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Send notification for a regular text message
  static Future<void> sendMessageNotification({
    required String recipientId,
    required String senderName,
    required String messageText,
    required String chatId,
    required String messageId,
    bool isGroup = false,
  }) async {
    try {
      final recipientDoc = await _firestore.collection('users').doc(recipientId).get();
      final fcmToken = recipientDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('⚠️ No FCM token found for user: $recipientId');
        return;
      }

      await _sendNotification(
        token: fcmToken,
        title: isGroup ? senderName : 'New Message from $senderName',
        body: messageText,
        type: isGroup ? 'group_message' : 'direct_message',
        chatId: chatId,
        senderId: _auth.currentUser?.uid ?? '',
        messageId: messageId,
      );

      debugPrint('✅ Message notification sent to $recipientId');
    } catch (e) {
      debugPrint('❌ Error sending message notification: $e');
    }
  }

  /// Send notification for a new expense
  static Future<void> sendExpenseNotification({
    required String recipientId,
    required String payerName,
    required String description,
    required double amount,
    required double recipientShare,
    required String chatId,
    required String expenseId,
    bool isGroup = false,
  }) async {
    try {
      final recipientDoc = await _firestore.collection('users').doc(recipientId).get();
      final fcmToken = recipientDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('⚠️ No FCM token found for user: $recipientId');
        return;
      }

      final title = isGroup 
          ? '💰 New Expense in Group'
          : '💰 New Expense from $payerName';
      final body = '$payerName paid ₹$amount for "$description". Your share: ₹$recipientShare';

      await _sendNotification(
        token: fcmToken,
        title: title,
        body: body,
        type: 'expense',
        chatId: chatId,
        senderId: _auth.currentUser?.uid ?? '',
        messageId: expenseId,
        additionalData: {
          'expenseId': expenseId,
          'amount': amount.toString(),
          'recipientShare': recipientShare.toString(),
          'description': description,
        },
      );

      debugPrint('✅ Expense notification sent to $recipientId');
    } catch (e) {
      debugPrint('❌ Error sending expense notification: $e');
    }
  }

  /// Send notification for a settlement request
  static Future<void> sendSettlementRequestNotification({
    required String recipientId,
    required String requesterName,
    required double amount,
    required String chatId,
    required String messageId,
  }) async {
    try {
      final recipientDoc = await _firestore.collection('users').doc(recipientId).get();
      final fcmToken = recipientDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('⚠️ No FCM token found for user: $recipientId');
        return;
      }

      final title = '💳 Settlement Request';
      final body = '$requesterName is requesting ₹$amount for settlement';

      await _sendNotification(
        token: fcmToken,
        title: title,
        body: body,
        type: 'settlement_request',
        chatId: chatId,
        senderId: _auth.currentUser?.uid ?? '',
        messageId: messageId,
        additionalData: {
          'amount': amount.toString(),
          'requestType': 'settlement',
        },
      );

      debugPrint('✅ Settlement request notification sent to $recipientId');
    } catch (e) {
      debugPrint('❌ Error sending settlement request notification: $e');
    }
  }

  /// Send notification for a payment confirmation
  static Future<void> sendPaymentConfirmationNotification({
    required String recipientId,
    required String payerName,
    required double amount,
    required String chatId,
    required String messageId,
  }) async {
    try {
      final recipientDoc = await _firestore.collection('users').doc(recipientId).get();
      final fcmToken = recipientDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('⚠️ No FCM token found for user: $recipientId');
        return;
      }

      final title = '✅ Payment Confirmation';
      final body = '$payerName has sent a payment confirmation for ₹$amount. Please verify and approve.';

      await _sendNotification(
        token: fcmToken,
        title: title,
        body: body,
        type: 'payment_confirmation',
        chatId: chatId,
        senderId: _auth.currentUser?.uid ?? '',
        messageId: messageId,
        additionalData: {
          'amount': amount.toString(),
          'requiresApproval': 'true',
        },
      );

      debugPrint('✅ Payment confirmation notification sent to $recipientId');
    } catch (e) {
      debugPrint('❌ Error sending payment confirmation notification: $e');
    }
  }

  /// Send notification for settlement completion
  static Future<void> sendSettlementCompletedNotification({
    required String recipientId,
    required String payerName,
    required double amount,
    required String chatId,
  }) async {
    try {
      final recipientDoc = await _firestore.collection('users').doc(recipientId).get();
      final fcmToken = recipientDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('⚠️ No FCM token found for user: $recipientId');
        return;
      }

      final title = '🎉 Settlement Completed';
      final body = 'Payment of ₹$amount has been settled with $payerName';

      await _sendNotification(
        token: fcmToken,
        title: title,
        body: body,
        type: 'settlement_completed',
        chatId: chatId,
        senderId: _auth.currentUser?.uid ?? '',
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        additionalData: {
          'amount': amount.toString(),
        },
      );

      debugPrint('✅ Settlement completed notification sent to $recipientId');
    } catch (e) {
      debugPrint('❌ Error sending settlement completed notification: $e');
    }
  }

  /// Send notification to multiple group members
  static Future<void> sendGroupNotification({
    required List<String> recipientIds,
    required String groupName,
    required String senderName,
    required String messageText,
    required String chatId,
    required String messageId,
    String type = 'group_message',
  }) async {
    try {
      // Remove current user from recipients
      final currentUserId = _auth.currentUser?.uid;
      final filteredRecipients = recipientIds.where((id) => id != currentUserId).toList();

      if (filteredRecipients.isEmpty) {
        debugPrint('⚠️ No recipients to notify');
        return;
      }

      // Get FCM tokens for all recipients
      final usersSnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: filteredRecipients)
          .get();

      int successCount = 0;
      for (var doc in usersSnapshot.docs) {
        try {
          final fcmToken = doc.data()['fcmToken'] as String?;
          if (fcmToken != null && fcmToken.isNotEmpty) {
            await _sendNotification(
              token: fcmToken,
              title: '$groupName - $senderName',
              body: messageText,
              type: type,
              chatId: chatId,
              senderId: currentUserId ?? '',
              messageId: messageId,
              additionalData: {
                'groupName': groupName,
                'isGroup': 'true',
              },
            );
            successCount++;
          }
        } catch (e) {
          debugPrint('❌ Error sending notification to ${doc.id}: $e');
        }
      }

      debugPrint('✅ Group notifications sent: $successCount/${filteredRecipients.length}');
    } catch (e) {
      debugPrint('❌ Error sending group notifications: $e');
    }
  }

  /// Core method to send notification via Firestore
  /// Firebase will automatically process this and send via FCM
  static Future<void> _sendNotification({
    required String token,
    required String title,
    required String body,
    required String type,
    required String chatId,
    required String senderId,
    required String messageId,
    Map<String, String>? additionalData,
  }) async {
    try {
      final data = {
        'type': type,
        'chatId': chatId,
        'senderId': senderId,
        'messageId': messageId,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        ...?additionalData,
      };

      // Save to Firestore - Cloud Functions will process this
      final docRef = await _firestore.collection('notifications').add({
        'to': token,  // Changed from 'token' to 'to' to match Cloud Function
        'notification': {
          'title': title,
          'body': body,
        },
        'data': data,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Notification queued: ${docRef.id}');
      debugPrint('📱 Token: ${token.substring(0, 20)}...');
      debugPrint('📝 Title: $title');
      debugPrint('📄 Body: $body');
    } catch (e) {
      debugPrint('❌ Error queueing notification: $e');
      rethrow;
    }
  }

  /// Send notification to all participants of an expense
  static Future<void> sendExpenseNotificationToAll({
    required List<String> participantIds,
    required String payerName,
    required String description,
    required double totalAmount,
    required Map<String, double> shares,
    required String chatId,
    required String expenseId,
    bool isGroup = false,
  }) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      
      for (var participantId in participantIds) {
        if (participantId == currentUserId) continue; // Skip sender
        
        final recipientShare = shares[participantId] ?? 0.0;
        await sendExpenseNotification(
          recipientId: participantId,
          payerName: payerName,
          description: description,
          amount: totalAmount,
          recipientShare: recipientShare,
          chatId: chatId,
          expenseId: expenseId,
          isGroup: isGroup,
        );
      }
    } catch (e) {
      debugPrint('❌ Error sending expense notifications to all: $e');
    }
  }
}
