import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../config/debug_config.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/chat_utils.dart';
import '../services/push_notification_helper.dart';
import 'SubscriptionScreen.dart';

class UserChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final List<String> members;

  const UserChatScreen({
    super.key,
    required this.groupName,
    required this.members,
    required this.groupId,
  });

  @override
  State<UserChatScreen> createState() => _UserChatScreenState();
}

class _UserChatScreenState extends State<UserChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  Stream<QuerySnapshot>? _messagesStream;
  bool _isSettled = false;
  double _balance = 0.0;
  bool _isLoadingBalance = true;
  String? _otherUserId;
  String? _otherUserUpiId;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  Future<void> _saveFCMToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ No authenticated user found for saving FCM token');
        return;
      }

      // Request notification permissions
      await _requestNotificationPermissions();

      // Get the token
      String? token;
      try {
        token = await _fcm.getToken(
          vapidKey:
              'YOUR_VAPID_KEY', // Optional: Add your VAPID key if using web
        );
        debugPrint(
          '📱 FCM Token: ${token != null ? '${token.substring(0, 10)}...' : 'null'}',
        );
      } catch (e) {
        debugPrint('❌ Error getting FCM token: $e');
        return;
      }

      if (token == null) {
        debugPrint('⚠️ FCM token is null');
        return;
      }

      // Save token to Firestore
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'fcmTokens': FieldValue.arrayUnion([
            token,
          ]), // Store all tokens for the user
          'updatedAt': FieldValue.serverTimestamp(),
          'platform': defaultTargetPlatform.toString(),
          'appVersion': '1.0.0', // Replace with your app version
        }, SetOptions(merge: true));

        debugPrint('✅ FCM token saved successfully for user: ${user.uid}');

        // Listen for token refresh
        _fcm.onTokenRefresh.listen((newToken) async {
          debugPrint('🔄 FCM token refreshed: ${newToken.substring(0, 10)}...');
          await _firestore.collection('users').doc(user.uid).set({
            'fcmToken': newToken,
            'fcmTokens': FieldValue.arrayUnion([newToken]),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          debugPrint('✅ Refreshed FCM token saved');
        });
      } catch (e, stackTrace) {
        debugPrint('❌ Error saving FCM token to Firestore: $e');
        debugPrint('Stack trace: $stackTrace');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Unhandled error in _saveFCMToken: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _requestNotificationPermissions() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        debugPrint('🔔 Requesting notification permissions for Android...');
        final settings = await _fcm.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

        debugPrint(
          '🔔 Notification permission status: ${settings.authorizationStatus}',
        );
        debugPrint('🔔 Notification settings: $settings');
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        debugPrint('🔔 Requesting notification permissions for iOS...');
        final settings = await _fcm.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: true, // Request provisional permissions on iOS
          sound: true,
        );

        debugPrint(
          '🔔 Notification permission status: ${settings.authorizationStatus}',
        );
        debugPrint('🔔 Notification settings: $settings');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error requesting notification permissions: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  void _setupFCMListeners() {
    debugPrint('🔔 Setting up FCM listeners...');

    // Handle messages when the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('📨 Received message while in foreground');
      debugPrint('📱 Message ID: ${message.messageId}');
      debugPrint('📊 Data: ${message.data}');
      debugPrint('📢 Notification: ${message.notification}');

      if (message.notification != null) {
        final notification = message.notification!;
        debugPrint('🔔 Notification - Title: ${notification.title}');
        debugPrint('🔔 Notification - Body: ${notification.body}');

        // Show local notification
        try {
          await _showLocalNotification(
            title: notification.title ?? 'New Message',
            body: notification.body ?? 'You have a new message',
            payload: message.data.toString(),
          );
        } catch (e) {
          debugPrint('❌ Error showing local notification: $e');
        }
      }
    });

    // Handle when a notification is tapped while the app is in the background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('👆 Notification tapped while app was in background');
      _handleNotificationTap(message);
    });

    // Handle when the app is opened from a terminated state via notification
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        debugPrint('🚀 App opened from terminated state by notification');
        _handleNotificationTap(message);
      }
    });

    // Handle token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint('🔄 FCM token refreshed: ${newToken.substring(0, 10)}...');
      _saveFCMToken();
    });
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      debugPrint('🔄 Showing local notification: $title - $body');

      // You can use flutter_local_notifications package here
      // This is a simplified example - adjust based on your notification package
      // Example with flutter_local_notifications:
      /*
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
     
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'chat_channel',
        'Chat Messages',
        channelDescription: 'Notifications for chat messages',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );
     
      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );
     
      await flutterLocalNotificationsPlugin.show(
        0, // Notification ID
        title,
        body,
        platformDetails,
        payload: payload,
      );
      */

      debugPrint('✅ Local notification shown');
    } catch (e, stackTrace) {
      debugPrint('❌ Error in _showLocalNotification: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    try {
      debugPrint('👆 Handling notification tap');
      debugPrint('📱 Message data: ${message.data}');

      // Extract data from the notification
      final data = message.data;
      final type = data['type'];
      final chatId = data['chatId'];
      final messageId = data['messageId'];

      debugPrint('📌 Type: $type, Chat ID: $chatId, Message ID: $messageId');

      // Navigate to the appropriate screen based on the notification type
      if (chatId != null) {
        // Navigate to the chat screen
        // You can use Navigator.pushNamed or any navigation solution you're using
        debugPrint('🚀 Navigating to chat: $chatId');

        // Example navigation (adjust based on your app's navigation):
        /*
        if (type == 'group_message') {
          Navigator.pushNamed(
            context,
            '/group_chat',
            arguments: {'groupId': chatId},
          );
        } else {
          Navigator.pushNamed(
            context,
            '/direct_chat',
            arguments: {'chatId': chatId},
          );
        }
        */
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error handling notification tap: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 Initializing UserChatScreen for ${widget.groupName}');

    // Setup message stream
    _setupMessageStream();

    // Initialize FCM and notifications
    _initializeNotifications();

    // Animation setup
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.6).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Calculate balance
    _calculateBalance();

    // Log screen view
    _logScreenView();
  }

  Future<void> _initializeNotifications() async {
    try {
      debugPrint('🔔 Initializing notifications...');

      // Save FCM token if not exists
      await _saveFCMToken();

      // Setup FCM message listeners
      // NOTE: Commented out to prevent duplicate listeners
      // FCM listeners should be set up globally in main.dart or a service
      // _setupFCMListeners();

      // Request notification permissions
      await _requestNotificationPermissions();

      // Check initial message if app was opened from a notification
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🚀 App opened from terminated state by notification');
        _handleNotificationTap(initialMessage);
      }

      // Configure FCM settings
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );

      debugPrint('✅ Notifications initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error initializing notifications: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _logScreenView() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('user_activity').add({
          'userId': user.uid,
          'screen': 'UserChatScreen',
          'groupId': widget.groupId,
          'groupName': widget.groupName,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('❌ Error logging screen view: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _calculateBalance() async {
    setState(() {
      _isLoadingBalance = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Get the other user ID
      _otherUserId = widget.members.firstWhere(
        (id) => id != currentUser.uid,
        orElse: () => '',
      );

      if (_otherUserId == null || _otherUserId!.isEmpty) {
        setState(() {
          _isLoadingBalance = false;
        });
        return;
      }

      // Get other user's UPI ID
      final otherUserDoc =
          await _firestore.collection('users').doc(_otherUserId).get();
      if (otherUserDoc.exists) {
        _otherUserUpiId = otherUserDoc.data()?['upiId'] as String?;
      }

      // Calculate balance from expenses
      double balance = 0.0;

      // Get all expenses where current user is involved
      final expensesSnapshot =
          await _firestore
              .collection('expenses')
              .where('participants', arrayContains: currentUser.uid)
              .get();

      for (var expenseDoc in expensesSnapshot.docs) {
        final data = expenseDoc.data();
        final payerId = data['payerId'] as String?;
        final shares = data['shares'] as Map<String, dynamic>?;
        final settled = data['settled'] as Map<String, dynamic>? ?? {};

        if (shares == null) continue;

        // Check if this expense involves the other user
        if (!data['participants'].contains(_otherUserId)) continue;

        // Check if already settled between these two users
        final settlementKey = '${currentUser.uid}_$_otherUserId';
        final reverseSettlementKey = '${_otherUserId}_${currentUser.uid}';
        if (settled[settlementKey] == true ||
            settled[reverseSettlementKey] == true) {
          continue;
        }

        // Calculate balance
        if (payerId == currentUser.uid) {
          // Current user paid, other user owes them
          final otherUserShare =
              (shares[_otherUserId] as num?)?.toDouble() ?? 0.0;
          balance += otherUserShare;
        } else if (payerId == _otherUserId) {
          // Other user paid, current user owes them
          final currentUserShare =
              (shares[currentUser.uid] as num?)?.toDouble() ?? 0.0;
          balance -= currentUserShare;
        }
      }

      setState(() {
        _balance = balance;
        _isSettled =
            balance.abs() < 0.01; // Consider settled if balance is near zero
        _isLoadingBalance = false;
      });
    } catch (e) {
      debugPrint('Error calculating balance: $e');
      setState(() {
        _isLoadingBalance = false;
      });
    }
  }

  Future<void> _initiateSettlement() async {
    if (_otherUserId == null) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Determine who owes whom
    final amount = _balance.abs();
    if (amount < 0.01) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Already settled up!')));
      return;
    }

    // If current user owes money, they can pay directly
    if (_balance < 0) {
      await _initiateDirectPayment();
    } else {
      // If other user owes money, send a settlement request
      await _sendSettlementRequest();
    }
  }

  Future<void> _initiateDirectPayment() async {
    // Show payment dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildPaymentDialog(),
    );

    if (confirmed == true) {
      // Launch UPI payment
      await _launchUPIPayment();
    }
  }

  Future<void> _sendSettlementRequest() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || _otherUserId == null) return;

    final formatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final amount = _balance.abs();

    // Confirm sending request
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Request Settlement'),
            content: Text(
              'Send a settlement request to ${widget.groupName} for ${formatter.format(amount)}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                ),
                child: const Text('Send Request'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      // Send settlement request message
      final chatId = ChatUtils.generateChatId(currentUser.uid, _otherUserId!);
      final messageDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
            'text': 'Settlement request for ${formatter.format(amount)}',
            'senderId': currentUser.uid,
            'senderName': currentUser.displayName ?? 'You',
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'settlement_request',
            'amount': amount,
            'isSettlementRequest': true,
            'status': 'pending',
            'requesterId': currentUser.uid,
            'payerId': _otherUserId,
          });

      // Send push notification
      await PushNotificationHelper.sendSettlementRequestNotification(
        recipientId: _otherUserId!,
        requesterName: currentUser.displayName ?? 'Someone',
        amount: amount,
        chatId: chatId,
        messageId: messageDoc.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settlement request sent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending settlement request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPaymentDialog() {
    final formatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final amount = _balance.abs();

    return AlertDialog(
      title: const Text('Settle Up Payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount to pay: ${formatter.format(amount)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_otherUserUpiId != null && _otherUserUpiId!.isNotEmpty)
            Text('UPI ID: $_otherUserUpiId')
          else
            const Text(
              'Note: Recipient has not set up their UPI ID. You can still proceed with payment.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          const SizedBox(height: 16),
          const Text(
            'After making the payment, please confirm to mark this as settled.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
          ),
          child: const Text('Pay Now'),
        ),
      ],
    );
  }

  Future<void> _launchUPIPayment() async {
    final amount = _balance.abs().toStringAsFixed(2);
    final upiId = _otherUserUpiId ?? '';
    final name = widget.groupName;

    final uri = Uri.parse(
      'upi://pay?pa=$upiId&pn=$name&am=$amount&cu=INR&tn=SplitX Settlement',
    );

    try {
      final result = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (result) {
        // Show confirmation dialog after payment
        if (mounted) {
          _showPaymentConfirmationDialog();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No UPI app found')));
        }
      }
    } catch (e) {
      debugPrint('Error launching UPI: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error launching UPI app')),
        );
      }
    }
  }

  Future<void> _showPaymentConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Payment'),
            content: const Text('Have you completed the payment successfully?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not Yet'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                ),
                child: const Text('Yes, Paid'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      // Send payment confirmation request to recipient for approval
      await _sendPaymentConfirmation();
    }
  }

  Future<void> _sendPaymentConfirmation() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null || _otherUserId == null) return;

      final amount = _balance.abs();
      final formatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

      // Send payment confirmation message that requires approval
      final chatId = ChatUtils.generateChatId(currentUser.uid, _otherUserId!);
      final messageDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
            'text': 'Payment confirmation: ${formatter.format(amount)}',
            'senderId': currentUser.uid,
            'senderName': currentUser.displayName ?? 'You',
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'payment_confirmation',
            'amount': amount,
            'isPaymentConfirmation': true,
            'status': 'pending',
            'payerId': currentUser.uid,
            'recipientId': _otherUserId,
          });

      // Send push notification
      await PushNotificationHelper.sendPaymentConfirmationNotification(
        recipientId: _otherUserId!,
        payerName: currentUser.displayName ?? 'Someone',
        amount: amount,
        chatId: chatId,
        messageId: messageDoc.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment confirmation sent! Waiting for approval...'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending payment confirmation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send confirmation'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _recordSettlement() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null || _otherUserId == null) return;

      // Update all unsettled expenses between these two users
      final expensesSnapshot =
          await _firestore
              .collection('expenses')
              .where('participants', arrayContains: currentUser.uid)
              .get();

      final batch = _firestore.batch();
      final now = DateTime.now();

      for (var expenseDoc in expensesSnapshot.docs) {
        final data = expenseDoc.data();
        if (!data['participants'].contains(_otherUserId)) continue;

        final settled = data['settled'] as Map<String, dynamic>? ?? {};
        final settlementKey = '${currentUser.uid}_$_otherUserId';
        final reverseSettlementKey = '${_otherUserId}_${currentUser.uid}';

        if (settled[settlementKey] != true &&
            settled[reverseSettlementKey] != true) {
          batch.update(expenseDoc.reference, {
            'settled.$settlementKey': true,
            'settledAt.$settlementKey': now,
          });
        }
      }

      // Create a settlement record
      final chatId = ChatUtils.generateChatId(currentUser.uid, _otherUserId!);
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
            'text': 'Payment of ₹${_balance.abs().toStringAsFixed(2)} settled',
            'senderId': currentUser.uid,
            'senderName': currentUser.displayName ?? 'You',
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'settlement',
            'amount': _balance.abs(),
            'isSettlement': true,
          });

      // Send push notification
      await PushNotificationHelper.sendSettlementCompletedNotification(
        recipientId: _otherUserId!,
        payerName: currentUser.displayName ?? 'Someone',
        amount: _balance.abs(),
        chatId: chatId,
      );

      await batch.commit();

      setState(() {
        _balance = 0.0;
        _isSettled = true;
        _animationController.forward();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settlement recorded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error recording settlement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to record settlement'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper method to create a consistent chat ID between two users
  String _createChatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> _setupMessageStream() async {
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('🚀 _setupMessageStream STARTED');
    debugPrint('═══════════════════════════════════════════════════');

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('❌ Error: No current user in _setupMessageStream');
      return;
    }

    debugPrint('✅ Current user authenticated: ${currentUser.uid}');
    debugPrint('📋 Group ID: ${widget.groupId}');
    debugPrint('👥 Members: ${widget.members}');
    debugPrint('📝 Group Name: ${widget.groupName}');

    // For direct messages (1:1 chat)
    if (widget.groupId == 'direct_message' || widget.members.length == 2) {
      debugPrint('💬 Detected 1:1 chat (direct message)');

      // Filter out current user to get the other participant
      final otherUserId = widget.members.firstWhere(
        (id) => id != currentUser.uid,
        orElse: () => '',
      );

      debugPrint('🔍 Found other user ID: $otherUserId');

      if (otherUserId.isNotEmpty) {
        // Set the _otherUserId for use in other methods
        setState(() {
          _otherUserId = otherUserId;
        });
        
        // Create a consistent chat ID using both user IDs
        final chatId = ChatUtils.generateChatId(currentUser.uid, otherUserId);

        debugPrint('🆔 Generated chat ID: $chatId');
        debugPrint('👤 Current user: ${currentUser.uid}');
        debugPrint('👤 Other user: $otherUserId');

        try {
          // Set up the message stream for this chat
          setState(() {
            _messagesStream =
                _firestore
                    .collection('chats')
                    .doc(chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots();
          });

          debugPrint('✅ 1:1 Message stream created for chat: $chatId');
          debugPrint('📡 Stream is now active and listening for messages');

          // Get the other user's display name if not already provided
          String otherUserName = widget.groupName;
          if (otherUserName.isEmpty || otherUserName == 'direct_message') {
            try {
              final otherUserDoc =
                  await _firestore.collection('users').doc(otherUserId).get();
              if (otherUserDoc.exists) {
                otherUserName =
                    otherUserDoc['username'] ??
                    otherUserDoc['displayName'] ??
                    otherUserDoc['email']?.split('@').first ??
                    'User';
              }
            } catch (e) {
              debugPrint('Error getting other user data: $e');
            }
          }

          // Ensure the chat document exists with proper metadata
          await _firestore.collection('chats').doc(chatId).set({
            'chatId': chatId,
            'isGroup': false,
            'participants': [currentUser.uid, otherUserId]..sort(),
            'participantNames': {
              currentUser.uid: currentUser.displayName ?? 'User',
              otherUserId: otherUserName,
            },
            'createdAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
            'lastMessage': '',
            'lastMessageTime': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          debugPrint('✅ Successfully updated 1:1 chat metadata for: $chatId');
          debugPrint('═══════════════════════════════════════════════════');
          return;
        } catch (e) {
          debugPrint('❌ Error setting up 1:1 chat stream: $e');
        }
      } else {
        debugPrint('❌ Error: Could not determine other user ID for 1:1 chat');
      }
    }

    // Default to group chat if not a direct message
    debugPrint(
      'Setting up group message stream for group ID: ${widget.groupId}',
    );
    setState(() {
      _messagesStream =
          _firestore
              .collection('groups')
              .doc(widget.groupId)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .snapshots();
    });
  }

  Future<void> _sendMessage() async {
    const tag = 'UserChatScreen';
    try {
      DebugConfig.log(tag, 'Starting message send process');
      final message = _messageController.text.trim();
      if (message.isEmpty) {
        DebugConfig.log(tag, 'Message is empty, not sending');
        return;
      }

      final user = _auth.currentUser;
      if (user == null) {
        DebugConfig.error(tag, 'No authenticated user found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You need to be logged in to send messages'),
            ),
          );
        }
        return;
      }

      DebugConfig.log(tag, 'Sending message as user: ${user.uid}');

      // Get current user's username from Firestore
      String? username;
      try {
        DebugConfig.log(tag, 'Fetching user data from Firestore');
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          username =
              userData?['username']?.toString() ??
              user.displayName ??
              user.email?.split('@').first ??
              'User';
          DebugConfig.log(tag, 'Retrieved username: $username');
        } else {
          DebugConfig.log(tag, 'User document does not exist');
        }
      } catch (e, stackTrace) {
        DebugConfig.error(
          tag,
          'Error getting user data',
          error: e,
          stackTrace: stackTrace,
        );
      }

      final senderName = username ?? user.displayName ?? 'User';
      DebugConfig.log(tag, 'Using sender name: $senderName');

      if (widget.groupId == 'direct_message') {
        final otherUserId = widget.members.firstWhere(
          (id) => id != user.uid,
          orElse: () => '',
        );

        if (otherUserId.isEmpty) return;

        final chatId = _createChatId(user.uid, otherUserId);
        final chatRef = _firestore.collection('chats').doc(chatId);
        final messagesRef = chatRef.collection('messages');

        // Add message to chat
        final messageDoc = await messagesRef.add({
          'text': message,
          'senderId': user.uid,
          'senderName': senderName,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'text',
        });

        // Get recipient's FCM token
        final recipientDoc =
            await _firestore.collection('users').doc(otherUserId).get();
        final recipientToken = recipientDoc.data()?['fcmToken'] as String?;

        // Send notification if token exists
        if (recipientToken != null) {
          await _sendPushNotification(
            token: recipientToken,
            title: 'New message from $senderName',
            body: message,
            chatId: chatId,
            senderId: user.uid,
            messageId: messageDoc.id,
          );
        }

        // Update chat metadata
        await chatRef.set({
          'lastMessage': message,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'participants': [user.uid, otherUserId]..sort(),
          'participantNames': {
            user.uid: senderName,
            otherUserId: widget.groupName,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        // For group chats
        debugPrint(
          '[_sendMessage] Sending group message to group: ${widget.groupId}',
        );

        // First check if group exists and get its data
        final groupRef = _firestore.collection('groups').doc(widget.groupId);
        DocumentSnapshot groupDoc;

        try {
          groupDoc = await groupRef.get();
          if (!groupDoc.exists) {
            debugPrint(
              '[_sendMessage] Error: Group ${widget.groupId} does not exist',
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Error: Group does not exist')),
              );
            }
            return;
          }
        } catch (e) {
          debugPrint('[_sendMessage] Error fetching group data: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: Could not load group data')),
            );
          }
          return;
        }

        // Add message to group's messages subcollection
        DocumentReference messageDoc;
        try {
          messageDoc = await _firestore
              .collection('groups')
              .doc(widget.groupId)
              .collection('messages')
              .add({
                'text': message,
                'senderId': user.uid,
                'senderName': senderName,
                'timestamp': FieldValue.serverTimestamp(),
                'type': 'text',
              });

          debugPrint('[_sendMessage] Message added with ID: ${messageDoc.id}');

          // Send push notification for regular message
          if (_otherUserId != null) {
            final chatId = ChatUtils.generateChatId(user.uid, _otherUserId!);
            await PushNotificationHelper.sendMessageNotification(
              recipientId: _otherUserId!,
              senderName: senderName,
              messageText: message,
              chatId: chatId,
              messageId: messageDoc.id,
              isGroup: false,
            );
          }

          // Update group's last message timestamp
          await groupRef.update({
            'lastMessage': message,
            'lastMessageTime': FieldValue.serverTimestamp(),
            'lastMessageSender': senderName,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          debugPrint('[_sendMessage] Group metadata updated');
        } catch (e) {
          debugPrint('[_sendMessage] Error adding message to group: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: Could not send message')),
            );
          }
          return;
        }

        // Get group members except sender for notifications
        try {
          final members = List<String>.from(groupDoc['members'] ?? []);
          members.remove(
            user.uid,
          ); // Remove current user from notification list

          debugPrint(
            '[_sendMessage] Sending notifications to ${members.length} group members',
          );

          if (members.isNotEmpty) {
            // Get FCM tokens of all group members
            final usersSnapshot =
                await _firestore
                    .collection('users')
                    .where(FieldPath.documentId, whereIn: members)
                    .get();

            debugPrint(
              '[_sendMessage] Found ${usersSnapshot.docs.length} user records',
            );

            int notificationCount = 0;
            for (var doc in usersSnapshot.docs) {
              try {
                final token = doc.data()['fcmToken'] as String?;
                if (token != null && token.isNotEmpty) {
                  debugPrint(
                    '[_sendMessage] Sending notification to user: ${doc.id}',
                  );
                  await _sendPushNotification(
                    token: token,
                    title: '${widget.groupName} - $senderName',
                    body: message,
                    chatId: widget.groupId,
                    senderId: user.uid,
                    messageId: messageDoc.id,
                    isGroup: true,
                  );
                  notificationCount++;
                } else {
                  debugPrint(
                    '[_sendMessage] No FCM token found for user: ${doc.id}',
                  );
                }
              } catch (e) {
                debugPrint(
                  '[_sendMessage] Error sending notification to user ${doc.id}: $e',
                );
                // Continue with other users even if one fails
              }
            }
            debugPrint(
              '[_sendMessage] Successfully sent $notificationCount notifications',
            );
          } else {
            debugPrint('[_sendMessage] No members to notify');
          }
        } catch (e) {
          debugPrint('[_sendMessage] Error in notification process: $e');
          // Don't fail the entire message send if notifications fail
        }
      }

      _messageController.clear();
      debugPrint('[_sendMessage] Message sent and processed successfully');
    } catch (e, stackTrace) {
      debugPrint('[_sendMessage] Critical error sending message: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _sendPushNotification({
    required String token,
    required String title,
    required String body,
    required String chatId,
    required String senderId,
    required String messageId,
    bool isGroup = false,
  }) async {
    try {
      debugPrint('🔄 Preparing to send push notification...');
      debugPrint(
        '📱 Token: ${token.length > 10 ? '${token.substring(0, 10)}...' : token}',
      );
      debugPrint('📝 Title: $title');
      debugPrint('📄 Body: $body');
      debugPrint('💬 Chat ID: $chatId');
      debugPrint('👤 Sender ID: $senderId');
      debugPrint('🔢 Message ID: $messageId');
      debugPrint('👥 Is Group: $isGroup');

      // Add a retry mechanism
      const maxRetries = 3;
      for (var i = 0; i < maxRetries; i++) {
        try {
          final notificationRef = await FirebaseFirestore.instance
              .collection('notifications')
              .add({
                'to': token,
                'notification': {'title': title, 'body': body},
                'data': {
                  'type': isGroup ? 'group_message' : 'direct_message',
                  'chatId': chatId,
                  'senderId': senderId,
                  'messageId': messageId,
                  'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                  'android_channel_id': 'chat_channel',
                  'sound': 'default',
                  'priority': 'high',
                  'content_available': 'true',
                },
                'android': {
                  'priority': 'high',
                  'notification': {
                    'notification_priority': 'PRIORITY_HIGH',
                    'visibility': 'public',
                    'default_sound': true,
                    'default_vibrate_timings': true,
                  },
                },
                'apns': {
                  'payload': {
                    'aps': {
                      'sound': 'default',
                      'content-available': 1,
                      'mutable-content': 1,
                    },
                  },
                  'headers': {
                    'apns-push-type': 'background',
                    'apns-priority': '5',
                    'apns-topic':
                        'YOUR_BUNDLE_ID', // Replace with your iOS bundle ID
                  },
                },
                'createdAt': FieldValue.serverTimestamp(),
                'status': 'pending',
                'retryCount': i,
              });

          debugPrint(
            '✅ Notification sent successfully with ID: ${notificationRef.id}',
          );
          return; // Exit on success
        } catch (e, stackTrace) {
          debugPrint('❌ Attempt ${i + 1} failed to send notification: $e');
          debugPrint('Stack trace: $stackTrace');

          if (i == maxRetries - 1) {
            // Last attempt failed
            debugPrint(
              '❌ All $maxRetries attempts to send notification failed',
            );

            // Log the failed notification for later retry
            await FirebaseFirestore.instance
                .collection('failed_notifications')
                .add({
                  'to': token,
                  'title': title,
                  'body': body,
                  'chatId': chatId,
                  'senderId': senderId,
                  'messageId': messageId,
                  'isGroup': isGroup,
                  'error': e.toString(),
                  'timestamp': FieldValue.serverTimestamp(),
                  'retryCount': i + 1,
                });

            debugPrint('📝 Failed notification logged for retry');
          } else {
            // Wait before retrying
            await Future.delayed(Duration(seconds: 1 * (i + 1)));
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Critical error in _sendPushNotification: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    final isExpense = message['isExpense'] == true;
    final isSettlement = message['isSettlement'] == true;
    final isSettlementRequest = message['isSettlementRequest'] == true;
    final isPaymentConfirmation = message['isPaymentConfirmation'] == true;
    final isSubscriptionBilling = message['isSubscriptionBilling'] == true;

    if (isExpense) {
      return _buildExpenseMessage(message, isMe);
    }

    if (isSettlement) {
      return _buildSettlementMessage(message, isMe);
    }

    if (isSettlementRequest) {
      return _buildSettlementRequestMessage(message, isMe);
    }

    if (isPaymentConfirmation) {
      return _buildPaymentConfirmationMessage(message, isMe);
    }

    if (isSubscriptionBilling) {
      return _buildSubscriptionBillingMessage(message);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMe ? Colors.blue[100] : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Text(
              message['senderName']?.toString() ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          Text(message['text']?.toString() ?? ''),
          const SizedBox(height: 4),
          Text(
            _formatTimestamp(message['timestamp']),
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementMessage(Map<String, dynamic> message, bool isMe) {
    final amount = (message['amount'] as num?)?.toDouble() ?? 0.0;
    final formatter = NumberFormat.currency(symbol: '₹');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe
                      ? 'You settled up'
                      : '${message['senderName']} settled up',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Amount: ${formatter.format(amount)}',
                  style: TextStyle(color: Colors.green[800], fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(message['timestamp']),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementRequestMessage(
    Map<String, dynamic> message,
    bool isMe,
  ) {
    final amount = (message['amount'] as num?)?.toDouble() ?? 0.0;
    final formatter = NumberFormat.currency(symbol: '₹');
    final status = message['status'] as String? ?? 'pending';
    final currentUser = _auth.currentUser;
    final payerId = message['payerId'] as String?;
    final isForMe = payerId == currentUser?.uid;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            status == 'approved'
                ? Colors.green[50]
                : status == 'rejected'
                ? Colors.red[50]
                : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              status == 'approved'
                  ? Colors.green.withOpacity(0.3)
                  : status == 'rejected'
                  ? Colors.red.withOpacity(0.3)
                  : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status == 'approved'
                    ? Icons.check_circle
                    : status == 'rejected'
                    ? Icons.cancel
                    : Icons.payment,
                color:
                    status == 'approved'
                        ? Colors.green[700]
                        : status == 'rejected'
                        ? Colors.red[700]
                        : Colors.orange[700],
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMe
                          ? 'Settlement Request Sent'
                          : 'Settlement Request Received',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:
                            status == 'approved'
                                ? Colors.green[900]
                                : status == 'rejected'
                                ? Colors.red[900]
                                : Colors.orange[900],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Amount: ${formatter.format(amount)}',
                      style: TextStyle(
                        color:
                            status == 'approved'
                                ? Colors.green[800]
                                : status == 'rejected'
                                ? Colors.red[800]
                                : Colors.orange[800],
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (status == 'pending' && isForMe) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleSettlementRequest(message, true),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Pay Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleSettlementRequest(message, false),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[700],
                      side: BorderSide(color: Colors.red[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (status == 'approved') ...[
            const SizedBox(height: 8),
            Text(
              '✓ Payment completed',
              style: TextStyle(
                color: Colors.green[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else if (status == 'rejected') ...[
            const SizedBox(height: 8),
            Text(
              '✗ Request declined',
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _formatTimestamp(message['timestamp']),
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSettlementRequest(
    Map<String, dynamic> message,
    bool approve,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final messageId = message['id'] as String?;
      if (messageId == null) {
        // Find the message document
        final chatId = ChatUtils.generateChatId(currentUser.uid, _otherUserId!);
        final messagesQuery =
            await _firestore
                .collection('chats')
                .doc(chatId)
                .collection('messages')
                .where('isSettlementRequest', isEqualTo: true)
                .where('status', isEqualTo: 'pending')
                .where('payerId', isEqualTo: currentUser.uid)
                .limit(1)
                .get();

        if (messagesQuery.docs.isEmpty) return;
        final messageDoc = messagesQuery.docs.first;

        if (approve) {
          // Launch UPI payment
          await _launchUPIPaymentForRequest(message, messageDoc.reference);
        } else {
          // Reject the request
          await messageDoc.reference.update({'status': 'rejected'});
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settlement request declined')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error handling settlement request: $e');
    }
  }

  Future<void> _launchUPIPaymentForRequest(
    Map<String, dynamic> message,
    DocumentReference messageRef,
  ) async {
    final amount = (message['amount'] as num?)?.toDouble() ?? 0.0;
    final upiId = _otherUserUpiId ?? '';
    final name = widget.groupName;

    final uri = Uri.parse(
      'upi://pay?pa=$upiId&pn=$name&am=${amount.toStringAsFixed(2)}&cu=INR&tn=SplitX Settlement',
    );

    try {
      final result = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (result) {
        // Show confirmation dialog
        if (mounted) {
          final confirmed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder:
                (context) => AlertDialog(
                  title: const Text('Confirm Payment'),
                  content: const Text(
                    'Have you completed the payment successfully?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Not Yet'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                      ),
                      child: const Text('Yes, Paid'),
                    ),
                  ],
                ),
          );

          if (confirmed == true) {
            // Update settlement request status
            await messageRef.update({'status': 'approved'});

            // Send payment confirmation for approval
            final currentUser = _auth.currentUser;
            if (currentUser != null && _otherUserId != null) {
              final chatId = ChatUtils.generateChatId(
                currentUser.uid,
                _otherUserId!,
              );
              final messageDoc = await _firestore
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .add({
                    'text':
                        'Payment confirmation: ₹${amount.toStringAsFixed(2)}',
                    'senderId': currentUser.uid,
                    'senderName': currentUser.displayName ?? 'You',
                    'timestamp': FieldValue.serverTimestamp(),
                    'type': 'payment_confirmation',
                    'amount': amount,
                    'isPaymentConfirmation': true,
                    'status': 'pending',
                    'payerId': currentUser.uid,
                    'recipientId': _otherUserId,
                  });

              // Send push notification
              await PushNotificationHelper.sendPaymentConfirmationNotification(
                recipientId: _otherUserId!,
                payerName: currentUser.displayName ?? 'Someone',
                amount: amount,
                chatId: chatId,
                messageId: messageDoc.id,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Payment confirmation sent! Waiting for approval...',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No UPI app found')));
        }
      }
    } catch (e) {
      debugPrint('Error launching UPI: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error launching UPI app')),
        );
      }
    }
  }

  Widget _buildPaymentConfirmationMessage(
    Map<String, dynamic> message,
    bool isMe,
  ) {
    final amount = (message['amount'] as num?)?.toDouble() ?? 0.0;
    final formatter = NumberFormat.currency(symbol: '₹');
    final status = message['status'] as String? ?? 'pending';
    final currentUser = _auth.currentUser;
    final recipientId = message['recipientId'] as String?;
    final isForMe = recipientId == currentUser?.uid;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            status == 'approved'
                ? Colors.green[50]
                : status == 'rejected'
                ? Colors.red[50]
                : Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              status == 'approved'
                  ? Colors.green.withOpacity(0.3)
                  : status == 'rejected'
                  ? Colors.red.withOpacity(0.3)
                  : Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status == 'approved'
                    ? Icons.check_circle
                    : status == 'rejected'
                    ? Icons.cancel
                    : Icons.pending_actions,
                color:
                    status == 'approved'
                        ? Colors.green[700]
                        : status == 'rejected'
                        ? Colors.red[700]
                        : Colors.blue[700],
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMe
                          ? 'Payment Confirmation Received'
                          : 'Payment Confirmation Sent',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:
                            status == 'approved'
                                ? Colors.green[900]
                                : status == 'rejected'
                                ? Colors.red[900]
                                : Colors.blue[900],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Amount: ${formatter.format(amount)}',
                      style: TextStyle(
                        color:
                            status == 'approved'
                                ? Colors.green[800]
                                : status == 'rejected'
                                ? Colors.red[800]
                                : Colors.blue[800],
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (status == 'pending' && isForMe) ...[
            const SizedBox(height: 12),
            const Text(
              'Please verify that you received the payment before approving.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handlePaymentConfirmation(message, true),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handlePaymentConfirmation(message, false),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[700],
                      side: BorderSide(color: Colors.red[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (status == 'approved') ...[
            const SizedBox(height: 8),
            Text(
              '✓ Payment approved and settled',
              style: TextStyle(
                color: Colors.green[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else if (status == 'rejected') ...[
            const SizedBox(height: 8),
            Text(
              '✗ Payment rejected',
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else if (status == 'pending' && !isForMe) ...[
            const SizedBox(height: 8),
            Text(
              '⏳ Waiting for approval...',
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _formatTimestamp(message['timestamp']),
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionBillingMessage(Map<String, dynamic> message) {
    final subscriptionName = message['subscriptionName'] ?? 'Subscription';
    final totalAmount = (message['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final perPersonAmount =
        (message['perPersonAmount'] as num?)?.toDouble() ?? 0.0;
    final payerName = message['payerName'] ?? 'Unknown';
    final paidBy = message['paidBy'] ?? '';
    final billingCycle = message['billingCycle'] ?? 'Monthly';
    final currentUser = _auth.currentUser;
    final isPayerMe = paidBy == currentUser?.uid;
    final formatter = NumberFormat.currency(symbol: '₹');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.deepOrange.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.subscriptions,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔔 Subscription Billing',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.orange,
                      ),
                    ),
                    Text(
                      subscriptionName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Billing details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildBillingDetailRow(
                  'Total Amount',
                  '${formatter.format(totalAmount)} / $billingCycle',
                  Icons.payment,
                ),
                const Divider(height: 16),
                _buildBillingDetailRow(
                  'Your Share',
                  formatter.format(perPersonAmount),
                  Icons.person,
                  highlight: true,
                ),
                const Divider(height: 16),
                _buildBillingDetailRow(
                  'Pay To',
                  isPayerMe ? 'You (Payer)' : payerName,
                  Icons.account_circle,
                ),
              ],
            ),
          ),

          // Action buttons
          if (!isPayerMe) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleSubscriptionPayment(message),
                    icon: const Icon(Icons.payment, size: 20),
                    label: const Text('Pay Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openUPIApp(),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open UPI'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You are the payer. Others will pay you their share.',
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          Text(
            _formatTimestamp(message['timestamp']),
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingDetailRow(
    String label,
    String value,
    IconData icon, {
    bool highlight = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: highlight ? Colors.orange : Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: highlight ? 16 : 14,
            fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
            color: highlight ? Colors.orange.shade900 : Colors.black87,
          ),
        ),
      ],
    );
  }

  Future<void> _handleSubscriptionPayment(Map<String, dynamic> message) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final perPersonAmount =
          (message['perPersonAmount'] as num?)?.toDouble() ?? 0.0;
      final paidBy = message['paidBy'] ?? '';
      final subscriptionName = message['subscriptionName'] ?? 'Subscription';

      // Get payer's UPI ID
      String? payerUpiId;
      try {
        final payerDoc = await _firestore.collection('users').doc(paidBy).get();
        if (payerDoc.exists) {
          payerUpiId = payerDoc.data()?['upiId'] as String?;
        }
      } catch (e) {
        debugPrint('Error fetching payer UPI: $e');
      }

      if (payerUpiId == null || payerUpiId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payer has not set up UPI ID yet'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Launch UPI payment
      final upiUrl =
          'upi://pay?pa=$payerUpiId&pn=${Uri.encodeComponent(message['payerName'] ?? 'Payer')}&am=$perPersonAmount&cu=INR&tn=${Uri.encodeComponent('Subscription: $subscriptionName')}';
      final uri = Uri.parse(upiUrl);

      debugPrint('Launching UPI URL: $upiUrl');
      
      try {
        // Try to launch the UPI URL directly without checking canLaunchUrl
        // as canLaunchUrl often returns false even when UPI apps are installed
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        if (launched) {
          debugPrint('UPI app launched successfully');
          // After payment attempt, show confirmation dialog
          if (mounted) {
            await Future.delayed(const Duration(seconds: 2));
            _showSubscriptionPaymentConfirmationDialog(message);
          }
        } else {
          throw Exception('Failed to launch UPI app');
        }
      } catch (launchError) {
        debugPrint('Error launching UPI: $launchError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No UPI app found. Please install Google Pay, PhonePe, or Paytm.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error handling subscription payment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initiate payment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showSubscriptionPaymentConfirmationDialog(
    Map<String, dynamic> message,
  ) async {
    final perPersonAmount =
        (message['perPersonAmount'] as num?)?.toDouble() ?? 0.0;
    final formatter = NumberFormat.currency(symbol: '₹');

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Payment'),
            content: Text(
              'Did you complete the payment of ${formatter.format(perPersonAmount)}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not Yet'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Yes, Paid'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _sendSubscriptionPaymentConfirmation(message);
    }
  }

  Future<void> _sendSubscriptionPaymentConfirmation(
    Map<String, dynamic> message,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final perPersonAmount =
          (message['perPersonAmount'] as num?)?.toDouble() ?? 0.0;
      final paidBy = message['paidBy'] ?? '';
      final subscriptionName = message['subscriptionName'] ?? 'Subscription';
      final formatter = NumberFormat.currency(symbol: '₹');

      // Get current user's name
      String senderName = 'User';
      try {
        final userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          senderName =
              userDoc.data()?['username'] ?? currentUser.displayName ?? 'User';
        }
      } catch (e) {
        senderName = currentUser.displayName ?? 'User';
      }

      // Send confirmation message to group chat
      await _firestore
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .add({
            'text':
                'Payment confirmation: ${formatter.format(perPersonAmount)} for $subscriptionName',
            'senderId': currentUser.uid,
            'senderName': senderName,
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'subscription_payment_confirmation',
            'amount': perPersonAmount,
            'subscriptionName': subscriptionName,
            'recipientId': paidBy,
            'isPaymentConfirmation': true,
            'status': 'pending',
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment confirmation sent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending payment confirmation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send confirmation'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handlePaymentConfirmation(
    Map<String, dynamic> message,
    bool approve,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Determine if this is a group chat or 1:1 chat
      final isGroupChat = widget.groupId != 'direct_message' && widget.members.length > 2;
      
      QuerySnapshot messagesQuery;
      
      if (isGroupChat) {
        // For group chats, use the groups collection
        messagesQuery = await _firestore
            .collection('groups')
            .doc(widget.groupId)
            .collection('messages')
            .where('isPaymentConfirmation', isEqualTo: true)
            .where('status', isEqualTo: 'pending')
            .where('recipientId', isEqualTo: currentUser.uid)
            .get();
      } else {
        // For 1:1 chats, use the chats collection
        final chatId = ChatUtils.generateChatId(currentUser.uid, _otherUserId!);
        messagesQuery = await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .where('isPaymentConfirmation', isEqualTo: true)
            .where('status', isEqualTo: 'pending')
            .where('recipientId', isEqualTo: currentUser.uid)
            .limit(1)
            .get();
      }

      if (messagesQuery.docs.isEmpty) {
        debugPrint('No pending payment confirmation found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No pending payment confirmation found'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      final messageDoc = messagesQuery.docs.first;

      if (approve) {
        // Update confirmation status
        await messageDoc.reference.update({
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
        });

        // Record the settlement (for 1:1 chats)
        if (!isGroupChat) {
          await _recordSettlement();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment approved and settlement recorded!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Reject the payment confirmation
        await messageDoc.reference.update({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment confirmation rejected'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error handling payment confirmation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process confirmation: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Widget _buildAppButton(String appName, String packageName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ElevatedButton(
        onPressed: () async {
          // Try to open the app directly
          final url = Uri.parse('market://details?id=$packageName');
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[50],
          foregroundColor: Colors.blue[800],
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.blue[200]!),
          ),
          minimumSize: const Size(double.infinity, 48),
        ),
        child: Text(
          'Open $appName',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Future<void> _openUPIApp() async {
    // Try to open Google Pay first (most common in India)
    try {
      const googlePayUrl = 'https://gpay.app.goo.gl/'; // Google Pay web URL
      final uri = Uri.parse(googlePayUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('Error launching Google Pay: $e');
    }

    // Try with UPI deep link
    try {
      // This is a generic UPI deep link that should open the default UPI app
      const upiUrl = 'upi://pay?pa=&pn=&am=&cu=INR&tn=SplitX%20Payment';
      final uri = Uri.parse(upiUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('Error launching UPI: $e');
    }

    // If we get here, show a message to the user with instructions
    if (mounted) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Open UPI App'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Please open your preferred UPI app to complete the payment.\n\n'
                    'Common UPI apps include:',
                  ),
                  const SizedBox(height: 10),
                  _buildAppButton(
                    'Google Pay',
                    'com.google.android.apps.nbu.paisa.user',
                  ),
                  _buildAppButton('PhonePe', 'com.phonepe.app'),
                  _buildAppButton('BHIM', 'in.org.npci.upiapp'),
                  const SizedBox(height: 10),
                  const Text('Or visit the app store to install one.'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    }
  }

  Widget _buildExpenseMessage(Map<String, dynamic> message, bool isMe) {
    final formatter = NumberFormat.currency(symbol: '₹');
    final amount = (message['amount'] as num?)?.toDouble() ?? 0.0;
    final userShare = (message['userShare'] as num?)?.toDouble() ?? 0.0;

    final currentUserId = _auth.currentUser?.uid;
    final payerName = message['payer'] ?? 'Someone';

    bool isPayer = false;
    if (message['payerId'] != null) {
      isPayer = message['payerId'] == currentUserId;
    } else {
      isPayer =
          payerName == _auth.currentUser?.displayName ||
          payerName == _auth.currentUser?.email?.split('@').first;
    }

    return GestureDetector(
      onTap: _openUPIApp,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(Icons.receipt, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Expense: ${message['expenseName'] ?? 'an expense'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Paid by and Share
            Text(
              isPayer
                  ? 'You paid ${formatter.format(amount)} for an expense.\nYour share is ${formatter.format(userShare)}.'
                  : '$payerName paid ${formatter.format(amount)} for an expense.\nYour share is ${formatter.format(userShare)}.',
              style: const TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 4),
            Text(
              'Paid by: ${isPayer ? "You" : payerName}',
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
            ),
            const SizedBox(height: 4),

            // Amount Highlight
            Text(
              'Amount: ${formatter.format(userShare)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isPayer ? Colors.green[800] : Colors.red[800],
              ),
            ),
            const SizedBox(height: 4),

            // Timestamp
            Text(
              _formatTimestamp(message['timestamp']),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return '';
    }

    return DateFormat('MMM d, yyyy h:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building UserChatScreen with groupId: ${widget.groupId}');
    debugPrint('Members: ${widget.members}');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.grey[200],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const CircleAvatar(
              backgroundImage: AssetImage('assets/profile.png'),
            ),
            const SizedBox(width: 10),
            Text(
              widget.groupName,
              style: const TextStyle(color: Colors.black, fontSize: 18),
            ),
          ],
        ),
        actions: [
          // Show subscription button only for group chats (not 1:1 chats)
          if (widget.groupId != 'direct_message')
            IconButton(
              icon: const Icon(Icons.subscriptions, color: Colors.orange),
              tooltip: 'Manage Subscriptions',
              onPressed: () async {
                // Fetch group details to get member information
                try {
                  final groupDoc =
                      await _firestore
                          .collection('groups')
                          .doc(widget.groupId)
                          .get();
                  if (groupDoc.exists) {
                    final groupData = groupDoc.data();
                    List<dynamic> memberDetails = [];

                    if (groupData?['memberDetails'] != null) {
                      memberDetails = groupData!['memberDetails'];
                    } else if (groupData?['members'] != null) {
                      memberDetails =
                          (groupData!['members'] as List)
                              .map((id) => {'id': id, 'username': id})
                              .toList();
                    }

                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => SubscriptionScreen(
                                groupId: widget.groupId,
                                groupName: widget.groupName,
                                members: memberDetails,
                              ),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  debugPrint('Error opening subscriptions: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to open subscriptions'),
                      ),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child:
                _messagesStream == null
                    ? const Center(child: CircularProgressIndicator())
                    : StreamBuilder<QuerySnapshot>(
                      stream: _messagesStream,
                      builder: (context, snapshot) {
                        debugPrint(
                          'StreamBuilder snapshot state: ${snapshot.connectionState}',
                        );
                        debugPrint('Has data: ${snapshot.hasData}');
                        debugPrint(
                          'Data docs count: ${snapshot.data?.docs.length ?? 0}',
                        );

                        if (snapshot.hasError) {
                          debugPrint('Stream error: ${snapshot.error}');
                          return Center(
                            child: Text(
                              'Error loading messages: ${snapshot.error}',
                            ),
                          );
                        }

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (!snapshot.hasData) {
                          debugPrint('No data in snapshot');
                          return const Center(child: Text('No messages yet'));
                        }

                        final messages = snapshot.data!.docs;
                        debugPrint('Displaying ${messages.length} messages');

                        if (messages.isEmpty) {
                          return const Center(
                            child: Text(
                              'No messages yet. Start the conversation!',
                            ),
                          );
                        }

                        return ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          physics: const BouncingScrollPhysics(),
                          cacheExtent: 1000,
                          addAutomaticKeepAlives: true,
                          addRepaintBoundaries: true,
                          itemBuilder: (context, index) {
                            final message =
                                messages[index].data() as Map<String, dynamic>;
                            final isMe =
                                message['senderId'] == _auth.currentUser?.uid;

                            return RepaintBoundary(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Align(
                                  alignment:
                                      isMe
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width * 0.8,
                                    ),
                                    child: _buildMessageBubble(message, isMe),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
          // Split and Message buttons removed
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child:
                      _isLoadingBalance
                          ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                          : SizedBox(
                            width: double.infinity,
                            child: Column(
                              children: [
                                if (!_isSettled && _balance.abs() >= 0.01)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Text(
                                      _balance > 0
                                          ? 'They owe you: ₹${_balance.toStringAsFixed(2)}'
                                          : 'You owe: ₹${_balance.abs().toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            _balance > 0
                                                ? Colors.green[700]
                                                : Colors.red[700],
                                      ),
                                    ),
                                  ),
                                ElevatedButton(
                                  onPressed:
                                      _isSettled ? null : _initiateSettlement,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4CAF50),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                    disabledBackgroundColor: Colors.grey[400],
                                  ),
                                  child: Text(
                                    _isSettled
                                        ? 'All settled up! ✓'
                                        : _balance > 0
                                        ? 'Request Settlement'
                                        : 'Settle up payment!',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ExpenseCard extends StatelessWidget {
  final String amount;
  final String paidBy;
  final String yourShare;
  final String date;
  final bool isSent;

  const ExpenseCard({
    super.key,
    required this.amount,
    required this.paidBy,
    required this.yourShare,
    required this.date,
    this.isSent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt, color: Colors.blue[400], size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Expense: an expense',
                    style: TextStyle(
                      color: Colors.blue[400],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$paidBy paid ₹$amount for an expense.',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 2),
              Text(
                'Your share is $yourShare.',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                'Paid by: $paidBy',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                'Amount: $yourShare',
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
              const SizedBox(height: 2),
              Text(
                date,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
