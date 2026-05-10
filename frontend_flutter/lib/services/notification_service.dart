import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../services/firebase_service.dart';

/// Required top-level handler for background messages.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // In background isolate we must ensure Firebase is initialized.
  // This is safe to call multiple times.
  try {
    // ignore: unused_import
    await Firebase.initializeApp();
  } catch (_) {
    // If Firebase init fails (or already initialized), background handling can still continue.
  }
}

/// Handles Firebase Cloud Messaging (FCM) and foreground notifications.
class NotificationService {
  final FirebaseService firebaseService;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const String _channelId = 'emergency_channel';
  static const String _channelName = 'Emergency Notifications';

  NotificationService({required this.firebaseService});

  Future<void> init({required GlobalKey<NavigatorState> navigatorKey}) async {
    if (kIsWeb) {
      debugPrint('NotificationService is bypassed on Web.');
      return;
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // For simplicity, don't navigate on tap here. The app will also get
        // `onMessageOpenedApp` when the user taps system notifications.
      },
    );

    // Android 8+ notification channel.
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Notifications for emergency requests',
        importance: Importance.max,
      ),
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // iOS foreground presentation options (no-op on Android).
    await firebaseService.messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((message) async {
      final title = message.notification?.title ?? 'SmartCity Emergency';
      final body = message.notification?.body ?? '';
      await _showForegroundNotification(title: title, body: body, payload: message.data);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      // Route based on payload, default to Emergency screen.
      final route = message.data['route'] as String? ?? 'emergency';
      if (route == 'map') {
        navigatorKey.currentState?.pushNamed('/map');
      } else if (route == 'profile') {
        navigatorKey.currentState?.pushNamed('/profile');
      } else {
        navigatorKey.currentState?.pushNamed('/emergency');
      }
    });

    // Save token now + keep updated.
    final token = await firebaseService.messaging.getToken();
    if (token != null) {
      await saveFcmTokenForCurrentUser(token);
    }

    firebaseService.messaging.onTokenRefresh.listen((newToken) async {
      if (newToken.isEmpty) return;
      await saveFcmTokenForCurrentUser(newToken);
    });
  }

  Future<void> saveFcmTokenForCurrentUser(String token) async {
    
    final uid = firebaseService.auth.currentUser?.uid;
    if (uid == null) return;
    await firebaseService.getUsersCollection().doc(uid).set({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Grabs the current FCM token and stores it in the signed-in user's profile.
  Future<void> refreshAndSaveTokenForCurrentUser() async {
    if (kIsWeb) return;
    
    final token = await firebaseService.messaging.getToken();
    if (token == null || token.isEmpty) return;
    await saveFcmTokenForCurrentUser(token);
  }

  Future<void> _showForegroundNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    // Unique ID per notification to avoid overwriting.
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      id,
      title,
      body,
      details,
      payload: payload.entries.map((e) => '${e.key}=${e.value}').join('&'),
    );
  }
}

