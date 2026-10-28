import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Channels
  static const String vaultChannelId = 'com.pagesofus.app.vault';
  static const String vaultChannelName = 'Sanctuary Vault & Surprises';
  static const String partnerChannelId = 'com.pagesofus.app.partner';
  static const String partnerChannelName = 'Partner Moments & Letters';
  static const String alertChannelId = 'com.pagesofus.app.alerts';
  static const String alertChannelName = 'Important Place & Weather Alerts';

  // App Icons (Displays full color official App Icon on the notification card)
  static const String _smallIcon = '@mipmap/ic_launcher';
  static const DrawableResourceAndroidBitmap _largeAppIcon =
      DrawableResourceAndroidBitmap('@mipmap/ic_launcher');
  static const Color _brandColor = Color(0xFFE07A5F); // Signature Terracotta Rose

  // Navigation Stream for Instant Deep-Linking
  static final StreamController<String?> selectNotificationStream =
      StreamController<String?>.broadcast();

  // Keep track of recent notification triggers to avoid duplicate spam
  static final Set<String> _recentNotifiedKeys = {};

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
        if (response.payload != null && response.payload!.isNotEmpty) {
          selectNotificationStream.add(response.payload);
        }
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
          description: 'Midnight time-lock vault unlocks and secret surprises',
          importance: Importance.max,
          enableVibration: true,
          showBadge: true,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          partnerChannelId,
          partnerChannelName,
          description: 'Instant alerts when partner preserves memories, plays music or sends letters',
          importance: Importance.high,
          enableVibration: true,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          alertChannelId,
          alertChannelName,
          description: 'Geofenced place arrivals and unnatural weather alerts',
          importance: Importance.high,
          enableVibration: true,
        ),
      );

      // Request runtime notification permission on Android 13+
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }

    // 4. Firebase Cloud Messaging (FCM) Foreground Listener
    try {
      final fcm = FirebaseMessaging.instance;
      await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Foreground message handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null) {
          showInstantNotification(
            title: notification.title ?? 'Pages of Us ✦',
            body: notification.body ?? 'Your partner shared something special.',
            payload: message.data['payload'] ?? 'tab_0',
          );
        }
      });
    } catch (e) {
      debugPrint('FCM init ignored/offline: $e');
    }
  }

  /// Synchronize FCM Device Token to user profile in Firestore
  static Future<void> syncDeviceToken(String userId) async {
    if (userId.isEmpty) return;
    try {
      final fcm = FirebaseMessaging.instance;
      final token = await fcm.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'fcmToken': token,
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('FCM Token successfully synced for $userId');
      }

      fcm.onTokenRefresh.listen((newToken) async {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'fcmToken': newToken,
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint('Error syncing FCM token: $e');
    }
  }

  // =========================================================================
  // 1st: PAIRING SUCCESSFUL NOTIFICATION
  // =========================================================================
  static Future<void> showPairingSuccessNotification({
    required String partnerNickname,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      partnerChannelId,
      partnerChannelName,
      importance: Importance.max,
      priority: Priority.high,
      icon: _smallIcon,
      largeIcon: _largeAppIcon,
      color: _brandColor,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );

    await _localNotifications.show(
      90001,
      '✨ Sanctuary Connected Forever!',
      'You are now paired with $partnerNickname. Your private world for two is officially unlocked ✦',
      const NotificationDetails(android: androidDetails),
      payload: 'tab_0',
    );
  }

  // =========================================================================
  // 2nd: WEEKLY RANDOM OLD MEMORIES RECAP
  // =========================================================================
  static Future<void> scheduleWeeklyMemoryRecap({
    required String memoryId,
    required String memoryTitle,
    required String memoryCaption,
  }) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 19, 0); // 7:00 PM Sunday
      while (scheduled.weekday != DateTime.sunday || scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        partnerChannelId,
        partnerChannelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: _smallIcon,
        largeIcon: _largeAppIcon,
        color: _brandColor,
        styleInformation: BigTextStyleInformation(''),
      );

      final cleanCaption = memoryCaption.trim().isNotEmpty
          ? ' — "$memoryCaption"'
          : '';

      await _localNotifications.zonedSchedule(
        90002,
        '📖 A Page from Our Story...',
        'Remember this moment? "$memoryTitle"$cleanCaption ✨ Tap to relive it together.',
        scheduled,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'memory_$memoryId',
      );
      debugPrint('Scheduled weekly memory recap for $scheduled');
    } catch (e) {
      debugPrint('Failed to schedule weekly memory recap: $e');
    }
  }

  // =========================================================================
  // 3rd: PARTNER LOCATION AROUND TAGGED PLACE
  // =========================================================================
  static Future<void> showPartnerArrivedPlaceNotification({
    required String partnerNickname,
    required String placeName,
    required String placeTag,
  }) async {
    final key = 'place_${placeName}_${DateTime.now().hour}';
    if (_recentNotifiedKeys.contains(key)) return;
    _recentNotifiedKeys.add(key);

    const androidDetails = AndroidNotificationDetails(
      alertChannelId,
      alertChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: _smallIcon,
      largeIcon: _largeAppIcon,
      color: Color(0xFF6B8E23),
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );

    final tagText = placeTag.isNotEmpty ? ' ($placeTag)' : '';

    await _localNotifications.show(
      placeName.hashCode.abs() % 100000,
      '📍 $partnerNickname is around $placeName',
      'They just arrived near your tagged spot "$placeName"$tagText 🏡',
      const NotificationDetails(android: androidDetails),
      payload: 'tab_1',
    );
  }

  // =========================================================================
  // 4th: ADDING NEW MEMORIES (VIDEO, VOICE, PHOTO, LETTER, TIMELINE)
  // =========================================================================
  static Future<void> showNewMemoryNotification({
    required String partnerNickname,
    required String type, // 'photo', 'video', 'voice', 'letter', 'milestone'
    required String title,
    required String caption,
    required String id,
  }) async {
    String notifTitle;
    switch (type.toLowerCase()) {
      case 'video':
        notifTitle = '🎥 $partnerNickname shared a video moment!';
        break;
      case 'voice':
      case 'audio':
        notifTitle = '🎙️ $partnerNickname recorded a voice note for you!';
        break;
      case 'letter':
        notifTitle = '💌 $partnerNickname sent you a love letter!';
        break;
      case 'milestone':
        notifTitle = '⭐ $partnerNickname marked a new milestone!';
        break;
      case 'photo':
      default:
        notifTitle = '📸 $partnerNickname preserved a new photo!';
        break;
    }

    final summary = caption.trim().isNotEmpty
        ? ' — "$caption"'
        : '';
    final notifBody = '"$title"$summary';

    const androidDetails = AndroidNotificationDetails(
      partnerChannelId,
      partnerChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: _smallIcon,
      largeIcon: _largeAppIcon,
      color: _brandColor,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );

    final payload = type.toLowerCase() == 'letter' ? 'letter_$id' : 'memory_$id';

    await _localNotifications.show(
      id.hashCode.abs() % 100000,
      notifTitle,
      notifBody,
      const NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  // =========================================================================
  // 5th: PARTNER LISTENING SONG / QUICK CALL TO LISTEN TOGETHER
  // =========================================================================
  static Future<void> showListenTogetherInviteNotification({
    required String partnerNickname,
    required String songTitle,
    required String artist,
  }) async {
    final key = 'listen_${songTitle}_${DateTime.now().minute}';
    if (_recentNotifiedKeys.contains(key)) return;
    _recentNotifiedKeys.add(key);

    const androidDetails = AndroidNotificationDetails(
      partnerChannelId,
      partnerChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: _smallIcon,
      largeIcon: _largeAppIcon,
      color: Color(0xFF9D84B7),
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );

    await _localNotifications.show(
      90005,
      '🎵 Listen Together with $partnerNickname?',
      '$partnerNickname is listening to "$songTitle" by $artist. Tap to tune in and listen in sync 🎧✨',
      const NotificationDetails(android: androidDetails),
      payload: 'listen_together',
    );
  }

  // =========================================================================
  // 6th: TIMER-SETTED VAULT COUNTDOWN END (SMART CONTEXTUAL WARM WISH)
  // =========================================================================
  static Future<void> scheduleVaultUnlockNotification({
    required String capsuleId,
    required String title,
    required DateTime unlockDateTime,
  }) async {
    if (unlockDateTime.isBefore(DateTime.now())) return;

    final id = capsuleId.hashCode.abs() % 100000;
    final scheduledDate = tz.TZDateTime.from(unlockDateTime, tz.local);

    final lower = title.toLowerCase();
    String notifTitle;
    String notifBody;

    if (lower.contains('birthday') || lower.contains('bday')) {
      notifTitle = '🎂 Happy Birthday, my love! ✨';
      notifBody = 'Your secret birthday vault "$title" is now waiting for you! Open it to reveal your surprise 🎁💖';
    } else if (lower.contains('meet') || lower.contains('anniversary') || lower.contains('first date')) {
      notifTitle = '🥂 Happy Meet Day & Anniversary! 💫';
      notifBody = 'Our special celebration vault "$title" is finally unlocked! Step inside to relive our magic ✨';
    } else if (lower.contains('valentine') || lower.contains('vday')) {
      notifTitle = '🌹 Happy Valentine’s Day, sweetheart! ❤️';
      notifBody = 'A treasure box of love "$title" has unlocked for you! Enter your 6-digit key to see your surprise 💌';
    } else if (lower.contains('christmas') || lower.contains('new year')) {
      notifTitle = '🎄 Warm Holiday Wishes, my heart! ✨';
      notifBody = 'Your holiday vault "$title" has unlocked. Open it to celebrate together ❄️💖';
    } else {
      notifTitle = '🗝️ Your Secret Vault is Ready!';
      notifBody = 'The countdown for "$title" has ended. It\'s patiently waiting for you — open the vault to reveal it ✨';
    }

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
            channelDescription: 'Midnight time-lock vault unlocks and secret surprises',
            importance: Importance.max,
            priority: Priority.high,
            icon: _smallIcon,
            largeIcon: _largeAppIcon,
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
      debugPrint('Scheduled smart vault unlock notification for $scheduledDate (ID: $id)');
    } catch (e) {
      debugPrint('Failed to schedule vault alarm: $e');
    }
  }

  static Future<void> cancelScheduledVaultNotification(String capsuleId) async {
    final id = capsuleId.hashCode.abs() % 100000;
    await _localNotifications.cancel(id);
  }

  // =========================================================================
  // 7th: DAILY QUESTION PENDING REMINDER & PARTNER SUBMITTED ALERT
  // =========================================================================
  /// If the user already answered it, this reminder is cancelled / suppressed!
  static Future<void> scheduleDailyQuestionPendingReminder({
    required bool hasUserAnswered,
    required String partnerNickname,
  }) async {
    const int notifId = 90007;

    // Condition: If user ALREADY answered today's question, no notification needed!
    if (hasUserAnswered) {
      await _localNotifications.cancel(notifId);
      debugPrint('Daily question already answered: pending notification cancelled.');
      return;
    }

    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 30); // 8:30 PM
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        partnerChannelId,
        partnerChannelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: _smallIcon,
        largeIcon: _largeAppIcon,
        color: _brandColor,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(''),
      );

      await _localNotifications.zonedSchedule(
        notifId,
        '💭 Today\'s Daily Question is Waiting...',
        'You haven\'t answered today\'s question yet. Share your heart with $partnerNickname before midnight ✦',
        scheduled,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily_sync',
      );
    } catch (e) {
      debugPrint('Error scheduling daily question reminder: $e');
    }
  }

  /// Inform user when partner submits their answer
  static Future<void> showPartnerAnsweredDailyQuestionNotification({
    required String partnerNickname,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      partnerChannelId,
      partnerChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: _smallIcon,
      largeIcon: _largeAppIcon,
      color: _brandColor,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );

    await _localNotifications.show(
      90071,
      '✨ $partnerNickname answered today\'s question!',
      'Their thoughts are locked in! Reveal both of your answers now 💫',
      const NotificationDetails(android: androidDetails),
      payload: 'daily_sync',
    );
  }

  // =========================================================================
  // 8th: PARTNER LOCATION UNNATURAL / EXTREME WEATHER ALERT
  // =========================================================================
  static Future<void> showUnnaturalWeatherAlert({
    required String partnerNickname,
    required String condition,
    required double tempC,
  }) async {
    final key = 'weather_${condition}_${DateTime.now().day}_${DateTime.now().hour ~/ 4}';
    if (_recentNotifiedKeys.contains(key)) return;
    _recentNotifiedKeys.add(key);

    const androidDetails = AndroidNotificationDetails(
      alertChannelId,
      alertChannelName,
      importance: Importance.max,
      priority: Priority.max,
      icon: _smallIcon,
      largeIcon: _largeAppIcon,
      color: Color(0xFF1E88E5),
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );

    await _localNotifications.show(
      90008,
      '⛈️ Severe Weather Alert near $partnerNickname!',
      'Unnatural weather detected ($condition, ${tempC.round()}°C). Check in on $partnerNickname to make sure they\'re safe ❤️',
      const NotificationDetails(android: androidDetails),
      payload: 'tab_1',
    );
  }

  // =========================================================================
  // 9th: WEEKLY MILESTONE / COUPLE GOAL REMINDER
  // =========================================================================
  static Future<void> scheduleWeeklyGoalReminder({
    required int pendingGoalsCount,
  }) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 11, 0); // 11:00 AM Sunday
      while (scheduled.weekday != DateTime.sunday || scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        partnerChannelId,
        partnerChannelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: _smallIcon,
        largeIcon: _largeAppIcon,
        color: _brandColor,
        styleInformation: BigTextStyleInformation(''),
      );

      final notifBody = pendingGoalsCount > 0
          ? 'You and your partner have $pendingGoalsCount milestones in progress! Take a small step together today 💫'
          : 'You\'ve completed all your shared goals! Plan a new dream milestone together today 🥂✨';

      await _localNotifications.zonedSchedule(
        90009,
        '🎯 Weekly Couple Goals Check-In',
        notifBody,
        scheduled,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'couple_goals',
      );
    } catch (e) {
      debugPrint('Error scheduling weekly goal reminder: $e');
    }
  }

  // =========================================================================
  // General Instant Notification
  // =========================================================================
  static Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      partnerChannelId,
      partnerChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: _smallIcon,
      largeIcon: _largeAppIcon,
      color: _brandColor,
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
        icon: _smallIcon,
        largeIcon: _largeAppIcon,
        color: _brandColor,
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
