import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart';

// This is a background message handler that runs in a separate isolate
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize debug logger
  final debugLog = <String>[];
  final addLog = (String log) {
    debugLog.add('${DateTime.now()}: $log');
    debugPrint('BACKGROUND_HANDLER: $log');
  };

  try {
    addLog('🚀 Starting background message handler');
    addLog('Message ID: ${message.messageId}');
    addLog('Message data: ${message.data}');
    addLog('Notification title: ${message.notification?.title}');
    addLog('Notification body: ${message.notification?.body}');

    // Initialize Firebase
    try {
      addLog('Initializing Firebase...');
      await Firebase.initializeApp();
      addLog('Firebase initialized successfully');
    } catch (e, stackTrace) {
      addLog('❌ Error initializing Firebase: $e');
      addLog('Stack trace: $stackTrace');
      rethrow;
    }

    // Initialize local notifications
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    try {
      // Initialize settings for Android
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // Initialize settings for iOS
      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        onDidReceiveLocalNotification: (id, title, body, payload) {
          addLog('iOS notification received in background: $title - $body');
        },
      );

      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      addLog('Initializing local notifications...');
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          addLog('Notification tapped: ${response.payload}');
        },
      );
      addLog('Local notifications initialized');
    } catch (e, stackTrace) {
      addLog('❌ Error initializing local notifications: $e');
      addLog('Stack trace: $stackTrace');
    }

    // Create notification channel for Android
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        addLog('Creating Android notification channel...');
        final vibrationPattern = Int64List(4)
          ..[0] = 0
          ..[1] = 250
          ..[2] = 250
          ..[3] = 250;
          
        final channel = AndroidNotificationChannel(
          'chat_channel',
          'Chat Messages',
          description: 'This channel is used for chat messages.',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          enableLights: true,
          ledColor: Colors.blue,
          vibrationPattern: vibrationPattern,
        );
        
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
        addLog('Android notification channel created');
      } catch (e, stackTrace) {
        addLog('❌ Error creating Android notification channel: $e');
        addLog('Stack trace: $stackTrace');
      }
    }

    // Show the notification
    if (message.notification != null || message.data.isNotEmpty) {
      try {
        addLog('Preparing notification details...');
        
        final androidDetails = AndroidNotificationDetails(
          'chat_channel',
          'Chat Messages',
          channelDescription: 'Notifications for new chat messages',
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            message.notification?.body ?? message.data['body'] ?? 'New message',
          ),
          enableLights: true,
          color: Colors.blue,
          ledColor: Colors.blue,
          ledOnMs: 1000,
          ledOffMs: 500,
          playSound: true,
          enableVibration: true,
          groupKey: 'com.example.splitx.messages',
          setAsGroupSummary: true,
          ticker: 'New message received',
        );
        
        final iOSDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          threadIdentifier: 'com.example.splitx.messages',
          badgeNumber: 1,
          subtitle: message.notification?.title ?? message.data['title'],
        );
        
        final details = NotificationDetails(
          android: androidDetails,
          iOS: iOSDetails,
        );
        
        final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final title = message.notification?.title ?? 
                     message.data['title'] ?? 'New Message';
        final body = message.notification?.body ?? 
                    message.data['body'] ?? 'You have a new message';
        
        addLog('Showing notification: $title - $body');
        
        await flutterLocalNotificationsPlugin.show(
          notificationId,
          title,
          body,
          details,
          payload: message.data.toString(),
        );
        
        addLog('✅ Notification shown successfully');
      } catch (e, stackTrace) {
        addLog('❌ Error showing notification: $e');
        addLog('Stack trace: $stackTrace');
        
        // Try to show a basic notification if the detailed one fails
        try {
          await FlutterLocalNotificationsPlugin().show(
            9999999, // Fixed ID for fallback
            'New Message',
            'You have a new message',
            const NotificationDetails(),
            payload: 'fallback_notification',
          );
          addLog('Fallback notification shown');
        } catch (e2) {
          addLog('❌ Fallback notification also failed: $e2');
        }
      }
    } else {
      addLog('⚠️ No notification data in message');
    }
  } catch (e, stackTrace) {
    addLog('❌ Unhandled error in background message handler: $e');
    addLog('Stack trace: $stackTrace');
  } finally {
    // Log all debug messages at the end
    addLog('Background message handling completed');
    debugPrint('=== BACKGROUND HANDLER DEBUG LOG ===');
    for (final log in debugLog) {
      debugPrint(log);
    }
    debugPrint('=== END OF DEBUG LOG ===');
  }
}
