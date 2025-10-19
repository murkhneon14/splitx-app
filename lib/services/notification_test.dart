import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'push_notification_helper.dart';

/// Test widget for debugging push notifications
class NotificationTestWidget extends StatefulWidget {
  const NotificationTestWidget({Key? key}) : super(key: key);

  @override
  State<NotificationTestWidget> createState() => _NotificationTestWidgetState();
}

class _NotificationTestWidgetState extends State<NotificationTestWidget> {
  String _status = 'Ready to test';
  String? _fcmToken;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkFCMToken();
  }

  Future<void> _checkFCMToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      setState(() {
        _fcmToken = token;
        _status = token != null ? 'FCM Token found' : 'No FCM token';
      });
      debugPrint('FCM Token: $token');
    } catch (e) {
      setState(() {
        _status = 'Error getting token: $e';
      });
    }
  }

  Future<void> _testSendNotification() async {
    setState(() {
      _isLoading = true;
      _status = 'Sending test notification...';
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _status = 'Error: Not logged in';
          _isLoading = false;
        });
        return;
      }

      // Get current user's FCM token
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final token = userDoc.data()?['fcmToken'] as String?;

      if (token == null || token.isEmpty) {
        setState(() {
          _status = 'Error: No FCM token saved in Firestore';
          _isLoading = false;
        });
        return;
      }

      // Send test notification to yourself
      await PushNotificationHelper.sendMessageNotification(
        recipientId: currentUser.uid,
        senderName: 'Test System',
        messageText: 'This is a test notification sent at ${DateTime.now()}',
        chatId: 'test_chat',
        messageId: 'test_${DateTime.now().millisecondsSinceEpoch}',
        isGroup: false,
      );

      setState(() {
        _status = 'Test notification sent! Check your device.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
      debugPrint('Error sending test notification: $e');
    }
  }

  Future<void> _checkFirestoreToken() async {
    setState(() {
      _isLoading = true;
      _status = 'Checking Firestore...';
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _status = 'Error: Not logged in';
          _isLoading = false;
        });
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final firestoreToken = userDoc.data()?['fcmToken'] as String?;

      setState(() {
        if (firestoreToken != null && firestoreToken.isNotEmpty) {
          _status = 'Token in Firestore: ${firestoreToken.substring(0, 20)}...';
        } else {
          _status = 'No token saved in Firestore!';
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error checking Firestore: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveFCMToken() async {
    setState(() {
      _isLoading = true;
      _status = 'Saving FCM token...';
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _status = 'Error: Not logged in';
          _isLoading = false;
        });
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        setState(() {
          _status = 'Error: Could not get FCM token';
          _isLoading = false;
        });
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _status = 'FCM token saved successfully!';
        _fcmToken = token;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error saving token: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (_fcmToken != null) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'FCM Token:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_fcmToken!.substring(0, 30)}...',
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              ElevatedButton.icon(
                onPressed: _checkFCMToken,
                icon: const Icon(Icons.refresh),
                label: const Text('Check FCM Token'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _saveFCMToken,
                icon: const Icon(Icons.save),
                label: const Text('Save FCM Token to Firestore'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _checkFirestoreToken,
                icon: const Icon(Icons.cloud),
                label: const Text('Check Token in Firestore'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _testSendNotification,
                icon: const Icon(Icons.send),
                label: const Text('Send Test Notification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Card(
              color: Colors.blue[50],
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Check if FCM token exists\n'
                      '2. Save token to Firestore\n'
                      '3. Verify token is in Firestore\n'
                      '4. Send test notification\n'
                      '5. Put app in background to see notification',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
