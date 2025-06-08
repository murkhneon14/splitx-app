import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_messaging_background.dart' show firebaseMessagingBackgroundHandler;

class NotificationService { 
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  
  // Stream controllers for notification events
  final StreamController<Map<String, dynamic>> _notificationStreamController = 
      StreamController<Map<String, dynamic>>.broadcast();
      
  Stream<Map<String, dynamic>> get notificationStream => _notificationStreamController.stream;

  // Initialize notifications
  Future<void> initialize() async {
    try {
      debugPrint('Initializing notification service...');
      
      // Initialize local notifications first
      debugPrint('Initializing local notifications...');
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
        onDidReceiveLocalNotification: (id, title, body, payload) async {
          debugPrint('iOS local notification received - ID: $id, Title: $title');
          _notificationStreamController.add({
            'type': 'notification_tap',
            'title': title,
            'body': body,
            'payload': payload,
          });
        },
      );
      
      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      
      // Initialize the plugin
      debugPrint('Initializing FlutterLocalNotificationsPlugin...');
      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification tapped: ${response.payload}');
          _notificationStreamController.add({
            'type': 'notification_tap',
            'payload': response.payload,
          });
        },
      );

      // Request notification permissions
      debugPrint('Requesting notification permissions...');
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('User granted permission: ${settings.authorizationStatus}');

      // Create notification channel for Android
      debugPrint('Creating notification channel...');
      await _createNotificationChannel();

      // Set up foreground message handler
      debugPrint('Setting up foreground message handler...');
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('=== FOREGROUND MESSAGE RECEIVED ===');
        debugPrint('Message ID: ${message.messageId}');
        debugPrint('From: ${message.from}');
        debugPrint('Data: ${message.data}');
        debugPrint('Notification - Title: ${message.notification?.title}');
        debugPrint('Notification - Body: ${message.notification?.body}');
        debugPrint('==================================');

        try {
          // Show notification
          await showNotification(
            title: message.notification?.title ?? 'New Message',
            body: message.notification?.body ?? 'You have a new message',
            payload: message.data.toString(),
            data: message.data,
          );
          
          // Also update the UI if needed
          if (message.data.isNotEmpty) {
            _notificationStreamController.add({
              'type': 'message_received',
              'title': message.notification?.title,
              'body': message.notification?.body,
              'data': message.data,
            });
          }
        } catch (e, stackTrace) {
          debugPrint('Error showing notification: $e');
          debugPrint('Stack trace: $stackTrace');
          
          // Try a simpler notification if the first attempt fails
          try {
            await _notifications.show(
              9999999, // Fixed ID for fallback
              'New Message',
              'You have a new message',
              const NotificationDetails(),
              payload: 'fallback_notification',
            );
          } catch (e2) {
            debugPrint('Fallback notification also failed: $e2');
          }
        }
      });

      // Handle when the app is in the background but opened from a notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('App opened from notification: ${message.messageId}');
        _handleMessage(message);
      });

      // Get initial message if the app was opened from a terminated state
      debugPrint('Checking for initial message...');
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('Initial message found: ${initialMessage.messageId}');
        _handleMessage(initialMessage);
      } else {
        debugPrint('No initial message found');
      }

      // Set background message handler
      debugPrint('Setting up background message handler...');
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Handle token refresh
      _fcm.onTokenRefresh.listen((String newToken) async {
        debugPrint('FCM Token refreshed: $newToken');
        // You might want to send this new token to your server
      });

      // Get the token for this device
      debugPrint('Getting FCM token...');
      String? token = await getFCMToken();
      debugPrint('FCM Token: $token');
      
      if (token == null) {
        debugPrint('WARNING: FCM token is null!');
      } else {
        debugPrint('FCM token obtained successfully');
      }
    } catch (e, stackTrace) {
      debugPrint('Error initializing notifications: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  // Show local notification
  Future<void> showNotification({
    required String title,
    required String body,
    String payload = 'chat',
    Map<String, dynamic>? data,
  }) async {
    try {
      debugPrint('=== PREPARING NOTIFICATION ===');
      debugPrint('Title: $title');
      debugPrint('Body: $body');
      debugPrint('Payload: $payload');
      debugPrint('Data: $data');

      // Ensure the notification channel is created
      await _createNotificationChannel();

      debugPrint('Creating Android notification details...');
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'chat_channel',
        'Chat Messages',
        channelDescription: 'Notifications for new chat messages',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        channelShowBadge: true,
        styleInformation: BigTextStyleInformation(body),
        color: Colors.blue,
        ledColor: Colors.blue,
        ledOnMs: 1000,
        ledOffMs: 500,
        enableLights: true,
        groupKey: 'com.example.splitx.messages',
        setAsGroupSummary: true,
      );

      debugPrint('Creating iOS notification details...');
      final DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
        threadIdentifier: 'com.example.splitx.messages',
      );

      debugPrint('Creating platform-specific notification details...');
      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      debugPrint('Attempting to show notification with ID: $notificationId');
      await _notifications.show(
        notificationId,
        title,
        body,
        platformDetails,
        payload: payload,
      );
      
      debugPrint('=== NOTIFICATION SHOWN SUCCESSFULLY ===');
    } catch (e, stackTrace) {
      debugPrint('ERROR in showNotification:');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Try to show a simpler notification in case of error
      try {
        debugPrint('Attempting fallback notification...');
        await _notifications.show(
          9999999, // Fixed ID for fallback
          'Error',
          'Failed to show notification',
          const NotificationDetails(),
        );
        debugPrint('Fallback notification shown');
      } catch (e2) {
        debugPrint('Failed to show fallback notification: $e2');
      }
    }
  }

  // Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'chat_channel', // Same as in AndroidManifest.xml
      'Chat Messages',
      description: 'This channel is used for chat messages.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Create the notification channel
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    
    debugPrint('Notification channel created successfully');
  }

  // Get FCM token with retry logic
  Future<String?> getFCMToken() async {
    try {
      debugPrint('Requesting FCM token...');
      String? token = await _fcm.getToken();
      
      if (token == null || token.isEmpty) {
        debugPrint('Warning: Received empty FCM token, retrying...');
        // Wait a bit and retry once
        await Future.delayed(const Duration(seconds: 2));
        token = await _fcm.getToken();
      }
      
      if (token == null || token.isEmpty) {
        debugPrint('Error: Failed to get FCM token after retry');
      } else {
        debugPrint('Successfully retrieved FCM token: ${token.substring(0, 10)}...');
      }
      
      return token;
    } catch (e, stackTrace) {
      debugPrint('Error getting FCM token: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  // Test notification
  Future<void> testNotification() async {
    try {
      debugPrint('=== SENDING TEST NOTIFICATION ===');
      await showNotification(
        title: 'Test Notification',
        body: 'This is a test notification sent at ${DateTime.now()}',
        payload: 'test_notification',
      );
      debugPrint('Test notification sent successfully');
    } catch (e, stackTrace) {
      debugPrint('Error sending test notification: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Handle message when app is opened from notification
  void _handleMessage(RemoteMessage message) {
    debugPrint('Handling message: ${message.messageId}');
    
    // Add the message to the stream for UI updates
    _notificationStreamController.add({
      'type': 'message_received',
      'title': message.notification?.title,
      'body': message.notification?.body,
      'data': message.data,
    });
    
    // You can add more specific handling based on message data
    // For example, navigate to a specific chat screen
    /*
    if (message.data['type'] == 'chat') {
      // Navigate to chat screen with chatId
      Navigator.of(context).pushNamed(
        '/chat',
        arguments: message.data['chatId'],
      );
    }
    */
  }

  // Dispose the stream controller when done
  void dispose() {
    _notificationStreamController.close();
  }
}
