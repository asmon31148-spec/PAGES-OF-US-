import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String vaultChannelId = 'com.pagesofus.app.vault';
  static const String vaultChannelName = 'Sanctuary Vault & Surprises';
  static const String partnerChannelId = 'com.pagesofus.app.partner';
  static const String partnerChannelName = 'Partner Moments & Letters';

  static Future<void> init() async {
    // 1. Timezone database initialization for exact scheduling
    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint('Timezone init error: $e');
    }

    // 2. Local Notifications Initialization
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Notification tapped with payload: ${response.payload}');
      },
    );

    // 3. Android High-Importance Channels
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          vaultChannelId,
          vaultChannelName,
          description: 'Midnight time-lock capsule unlocks and secret surprises',
          importance: Importance.max,
          enableVibration: true,
          showBadge: true,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          partnerChannelId,
          partnerChannelName,
          description: 'Instant alerts when partner preserves memories or sends love letters',
          importance: Importance.high,
          enableVibration: true,
        ),
      );

      // Request runtime notification permission on Android 13+
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }

    // 4. Firebase Cloud Messaging (FCM)
    try {
      final fcm = FirebaseMessaging.instance;
      final settings = await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await fcm.getToken();
        debugPrint('FCM Device Token: $token');
      }

      // Foreground message handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null) {
          showInstantNotification(
            title: notification.title ?? 'Pages of Us ✦',
            body: notification.body ?? 'Your partner shared something special.',
          );
        }
      });
    } catch (e) {
      debugPrint('FCM init ignored/offline: $e');
    }
  }

  /// Schedules a notification to fire at the exact date and time (e.g. 12:01 AM on her birthday)
  static Future<void> scheduleVaultUnlockNotification({
    required String capsuleId,
    required String title,
    required DateTime unlockDateTime,
  }) async {
    if (unlockDateTime.isBefore(DateTime.now())) return;

    final id = capsuleId.hashCode.abs() % 100000;
    final scheduledDate = tz.TZDateTime.from(unlockDateTime, tz.local);

    final isBirthday = title.toLowerCase().contains('bday') ||
        title.toLowerCase().contains('birthday');

    final notifTitle = isBirthday
        ? 'Happy Birthday my love! 🎂'
        : 'Special Moment Unlocked in Our Vault! 🗝️';

    final notifBody =
        'Your secret capsule "$title" is now unlocked! Enter the 6-digit key to reveal your surprise ✨';

    try {
      await _localNotifications.zonedSchedule(
        id,
        notifTitle,
        notifBody,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            vaultChannelId,
            vaultChannelName,
            channelDescription: 'Midnight time-lock capsule unlocks and secret surprises',
            importance: Importance.max,
            priority: Priority.high,
            color: Color(0xFFE89A8A), // Rose Gold
            enableVibration: true,
            styleInformation: BigTextStyleInformation(''),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'vault_$capsuleId',
      );
      debugPrint('Scheduled midnight notification for $scheduledDate (ID: $id)');
    } catch (e) {
      debugPrint('Failed to schedule exact alarm: $e');
    }
  }

  /// Cancels a scheduled capsule notification
  static Future<void> cancelScheduledVaultNotification(String capsuleId) async {
    final id = capsuleId.hashCode.abs() % 100000;
    await _localNotifications.cancel(id);
  }

  /// Instant notification when partner does an action
  static Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      partnerChannelId,
      partnerChannelName,
      channelDescription: 'Instant alerts when partner preserves memories or sends love letters',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFFE07A5F), // Terracotta
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const details = NotificationDetails(android: androidDetails);
    final id = DateTime.now().millisecondsSinceEpoch % 100000;

    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  static Future<void> scheduleWeeklyMissYouNotification({
    required int weeklyTouches,
    required String partnerNickname,
  }) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 0);
      while (scheduled.weekday != DateTime.sunday || scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        partnerChannelId,
        partnerChannelName,
        importance: Importance.high,
        priority: Priority.high,
      );

      await _localNotifications.zonedSchedule(
        777777,
        'Weekly Touch Summary ❤️',
        'You and $partnerNickname shared $weeklyTouches touches this week! Send a touch to say you miss them.',
        scheduled,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (_) {}
  }
}
