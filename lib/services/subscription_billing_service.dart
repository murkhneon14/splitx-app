import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SubscriptionBillingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check all subscriptions and send billing reminders for due subscriptions
  Future<void> checkAndSendBillingReminders() async {
    try {
      debugPrint('🔔 Checking for due subscriptions...');
      
      // Get all groups
      final groupsSnapshot = await _firestore.collection('groups').get();
      
      for (var groupDoc in groupsSnapshot.docs) {
        final groupId = groupDoc.id;
        final groupData = groupDoc.data();
        final groupName = groupData['name'] ?? 'Group';
        final members = groupData['members'] as List<dynamic>? ?? [];
        final memberDetails = groupData['memberDetails'] as List<dynamic>? ?? [];
        
        // Get subscriptions for this group
        final subscriptionsSnapshot = await _firestore
            .collection('groups')
            .doc(groupId)
            .collection('subscriptions')
            .where('isActive', isEqualTo: true)
            .get();
        
        for (var subDoc in subscriptionsSnapshot.docs) {
          final subData = subDoc.data();
          final nextBillingDate = (subData['nextBillingDate'] as Timestamp?)?.toDate();
          
          if (nextBillingDate == null) continue;
          
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final billingDay = DateTime(
            nextBillingDate.year,
            nextBillingDate.month,
            nextBillingDate.day,
          );
          
          // Check if billing is due today
          if (billingDay.isAtSameMomentAs(today)) {
            await _sendBillingMessage(
              groupId: groupId,
              groupName: groupName,
              subscriptionId: subDoc.id,
              subscriptionData: subData,
              members: members,
              memberDetails: memberDetails,
            );
            
            // Update next billing date based on cycle
            await _updateNextBillingDate(
              groupId: groupId,
              subscriptionId: subDoc.id,
              currentBillingDate: nextBillingDate,
              billingCycle: subData['billingCycle'] ?? 'Monthly',
            );
          }
        }
      }
      
      debugPrint('✅ Billing reminder check completed');
    } catch (e) {
      debugPrint('❌ Error checking billing reminders: $e');
    }
  }

  /// Send billing reminder message to group chat
  Future<void> _sendBillingMessage({
    required String groupId,
    required String groupName,
    required String subscriptionId,
    required Map<String, dynamic> subscriptionData,
    required List<dynamic> members,
    required List<dynamic> memberDetails,
  }) async {
    try {
      final subscriptionName = subscriptionData['name'] ?? 'Subscription';
      final totalPrice = (subscriptionData['totalPrice'] ?? 0).toDouble();
      final perPersonCost = (subscriptionData['perPersonCost'] ?? 0).toDouble();
      final paidBy = subscriptionData['paidBy'] ?? '';
      final payerName = subscriptionData['payerName'] ?? 'Unknown';
      final billingCycle = subscriptionData['billingCycle'] ?? 'Monthly';
      
      // Create message text
      final messageText = '''
🔔 Subscription Billing Reminder

📺 $subscriptionName
💰 Total: ₹${totalPrice.toStringAsFixed(2)} ($billingCycle)
👥 Your share: ₹${perPersonCost.toStringAsFixed(2)}
💳 Pay to: $payerName

Tap below to settle your payment!
''';
      
      // Send message to group chat
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .add({
        'text': messageText,
        'senderId': 'system',
        'senderName': 'SplitX Bot',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'subscription_billing',
        'subscriptionId': subscriptionId,
        'subscriptionName': subscriptionName,
        'totalAmount': totalPrice,
        'perPersonAmount': perPersonCost,
        'paidBy': paidBy,
        'payerName': payerName,
        'billingCycle': billingCycle,
        'isSubscriptionBilling': true,
      });
      
      // Update group's last message
      await _firestore.collection('groups').doc(groupId).update({
        'lastMessage': '🔔 $subscriptionName billing reminder',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': 'SplitX Bot',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Billing message sent for $subscriptionName in $groupName');
    } catch (e) {
      debugPrint('❌ Error sending billing message: $e');
    }
  }

  /// Update the next billing date after sending reminder
  Future<void> _updateNextBillingDate({
    required String groupId,
    required String subscriptionId,
    required DateTime currentBillingDate,
    required String billingCycle,
  }) async {
    try {
      DateTime nextDate;
      
      switch (billingCycle) {
        case 'Monthly':
          nextDate = DateTime(
            currentBillingDate.year,
            currentBillingDate.month + 1,
            currentBillingDate.day,
          );
          break;
        case 'Quarterly':
          nextDate = DateTime(
            currentBillingDate.year,
            currentBillingDate.month + 3,
            currentBillingDate.day,
          );
          break;
        case 'Yearly':
          nextDate = DateTime(
            currentBillingDate.year + 1,
            currentBillingDate.month,
            currentBillingDate.day,
          );
          break;
        default:
          nextDate = DateTime(
            currentBillingDate.year,
            currentBillingDate.month + 1,
            currentBillingDate.day,
          );
      }
      
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('subscriptions')
          .doc(subscriptionId)
          .update({
        'nextBillingDate': Timestamp.fromDate(nextDate),
        'lastBillingDate': Timestamp.fromDate(currentBillingDate),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Next billing date updated to: $nextDate');
    } catch (e) {
      debugPrint('❌ Error updating next billing date: $e');
    }
  }

  /// Manually trigger billing reminder for a specific subscription
  Future<void> sendManualBillingReminder({
    required String groupId,
    required String subscriptionId,
  }) async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return;
      
      final groupData = groupDoc.data()!;
      final groupName = groupData['name'] ?? 'Group';
      final members = groupData['members'] as List<dynamic>? ?? [];
      final memberDetails = groupData['memberDetails'] as List<dynamic>? ?? [];
      
      final subDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('subscriptions')
          .doc(subscriptionId)
          .get();
      
      if (!subDoc.exists) return;
      
      await _sendBillingMessage(
        groupId: groupId,
        groupName: groupName,
        subscriptionId: subscriptionId,
        subscriptionData: subDoc.data()!,
        members: members,
        memberDetails: memberDetails,
      );
    } catch (e) {
      debugPrint('❌ Error sending manual billing reminder: $e');
    }
  }

  /// Check if a subscription is due today
  Future<bool> isSubscriptionDueToday(String groupId, String subscriptionId) async {
    try {
      final subDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('subscriptions')
          .doc(subscriptionId)
          .get();
      
      if (!subDoc.exists) return false;
      
      final subData = subDoc.data()!;
      final nextBillingDate = (subData['nextBillingDate'] as Timestamp?)?.toDate();
      
      if (nextBillingDate == null) return false;
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final billingDay = DateTime(
        nextBillingDate.year,
        nextBillingDate.month,
        nextBillingDate.day,
      );
      
      return billingDay.isAtSameMomentAs(today);
    } catch (e) {
      debugPrint('❌ Error checking if subscription is due: $e');
      return false;
    }
  }

  /// Get all overdue subscriptions for a group
  Future<List<Map<String, dynamic>>> getOverdueSubscriptions(String groupId) async {
    try {
      final subscriptionsSnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('subscriptions')
          .where('isActive', isEqualTo: true)
          .get();
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final overdueSubscriptions = <Map<String, dynamic>>[];
      
      for (var doc in subscriptionsSnapshot.docs) {
        final data = doc.data();
        final nextBillingDate = (data['nextBillingDate'] as Timestamp?)?.toDate();
        
        if (nextBillingDate != null) {
          final billingDay = DateTime(
            nextBillingDate.year,
            nextBillingDate.month,
            nextBillingDate.day,
          );
          
          if (billingDay.isBefore(today)) {
            overdueSubscriptions.add({
              'id': doc.id,
              ...data,
            });
          }
        }
      }
      
      return overdueSubscriptions;
    } catch (e) {
      debugPrint('❌ Error getting overdue subscriptions: $e');
      return [];
    }
  }
}
