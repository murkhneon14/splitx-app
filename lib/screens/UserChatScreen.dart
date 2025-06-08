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
  late final Stream<QuerySnapshot> _messagesStream;
  bool _isSettled = false;
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

    // Log screen view
    _logScreenView();
  }

  Future<void> _initializeNotifications() async {
    try {
      debugPrint('🔔 Initializing notifications...');

      // Save FCM token if not exists
      await _saveFCMToken();

      // Setup FCM message listeners
      _setupFCMListeners();

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

  Future<void> _initiateUPIPayment() async {
    // Dummy UPI details - replace with actual payment details
    const upiId = 'test@upi';
    const name = 'Recipient Name';
    const amount = '1';

    final uri = Uri.parse(
      'upi://pay?pa=$upiId&pn=$name&am=$amount&cu=INR&tn=SplitX Payment',
    );

    try {
      final result = await launchUrl(uri);
      if (!result) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No UPI app found')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error launching UPI app')),
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
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('Error: No current user in _setupMessageStream');
      return;
    }

    debugPrint('Setting up message stream for group: ${widget.groupId}');
    debugPrint('Members: ${widget.members}');

    // For direct messages (1:1 chat)
    if (widget.groupId == 'direct_message' || widget.members.length == 2) {
      // Filter out current user to get the other participant
      final otherUserId = widget.members.firstWhere(
        (id) => id != currentUser.uid,
        orElse: () => '',
      );

      debugPrint('Found other user ID: $otherUserId');

      if (otherUserId.isNotEmpty) {
        // Create a consistent chat ID using both user IDs
        final chatId = ChatUtils.generateChatId(currentUser.uid, otherUserId);

        debugPrint('Setting up 1:1 message stream for chat ID: $chatId');
        debugPrint('Current user: ${currentUser.uid}');
        debugPrint('Other user: $otherUserId');

        try {
          // Set up the message stream for this chat
          _messagesStream =
              _firestore
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots();

          debugPrint('1:1 Message stream created for chat: $chatId');

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

          debugPrint('Successfully updated 1:1 chat metadata for: $chatId');
          return;
        } catch (e) {
          debugPrint('Error setting up 1:1 message stream: $e');
        }
      } else {
        debugPrint('Error: Could not determine other user ID for 1:1 chat');
      }
    }

    // Default to group chat if not a direct message
    debugPrint(
      'Setting up group message stream for group ID: ${widget.groupId}',
    );
    _messagesStream =
        _firestore
            .collection('groups')
            .doc(widget.groupId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .snapshots();
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

    if (isExpense) {
      return _buildExpenseMessage(message, isMe);
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
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                debugPrint(
                  'StreamBuilder snapshot state: ${snapshot.connectionState}',
                );
                if (snapshot.hasError) {
                  debugPrint('Stream error: ${snapshot.error}');
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading messages'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data?.docs ?? [];

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message =
                        messages[index].data() as Map<String, dynamic>;
                    final isMe = message['senderId'] == _auth.currentUser?.uid;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.8,
                          ),
                          child: _buildMessageBubble(message, isMe),
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
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _isSettled
                              ? null
                              : () {
                                setState(() {
                                  _isSettled = true;
                                  _animationController.forward();
                                });
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        disabledBackgroundColor: Colors.grey[400],
                      ),
                      child: Text(
                        _isSettled ? 'Nothing to settle' : 'Settle up payment!',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
