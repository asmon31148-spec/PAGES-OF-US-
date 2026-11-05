import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'local_cache_service.dart';
import '../../data/services/supabase_service.dart';
import '../../data/models/daily_care_item.dart';

class _NotifCopy {
  final String title;
  final String body;
  const _NotifCopy(this.title, this.body);
}

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

  // Reusable Interactive Quick Actions (One-Tap Love from Status Bar / Lock Screen)
  static const List<AndroidNotificationAction> _quickLoveActions = [
    AndroidNotificationAction(
      'action_send_love',
      '❤️ Send Love',
      showsUserInterface: false,
      cancelNotification: true,
    ),
    AndroidNotificationAction(
      'action_open_sanctuary',
      '✨ Open Sanctuary',
      showsUserInterface: true,
    ),
  ];

  // Keep track of recent notification triggers to avoid duplicate spam
  static final Set<String> _recentNotifiedKeys = {};

  // Gentle Sanctuary Mode (Mutes intrusive alerts, non-urgent vibrations & sounds)
  static bool _isGentleMode = false;
  static bool get isGentleMode => _isGentleMode;
  static void setGentleMode(bool enabled) => _isGentleMode = enabled;

  static void _configureLocalTimeZone() {
    try {
      tz.initializeTimeZones();
      final now = DateTime.now();
      final sysName = now.timeZoneName;

      // 1. Direct match in IANA timezone database
      if (tz.timeZoneDatabase.locations.containsKey(sysName)) {
        tz.setLocalLocation(tz.getLocation(sysName));
        debugPrint('[NotificationService] Local timezone set to $sysName');
        return;
      }

      // 2. Standard abbreviation mapping (India IST, US zones, EU, etc.)
      const abbrevMap = <String, String>{
        'IST': 'Asia/Kolkata',
        '+0530': 'Asia/Kolkata',
        'PST': 'America/Los_Angeles',
        'PDT': 'America/Los_Angeles',
        'EST': 'America/New_York',
        'EDT': 'America/New_York',
        'CST': 'America/Chicago',
        'CDT': 'America/Chicago',
        'MST': 'America/Denver',
        'MDT': 'America/Denver',
        'GMT': 'Europe/London',
        'BST': 'Europe/London',
        'CET': 'Europe/Paris',
        'CEST': 'Europe/Paris',
        'JST': 'Asia/Tokyo',
        'AEST': 'Australia/Sydney',
        'AEDT': 'Australia/Sydney',
        'SGT': 'Asia/Singapore',
        'HKT': 'Asia/Hong_Kong',
        'GST': 'Asia/Dubai',
      };
      final mapped = abbrevMap[sysName.toUpperCase()];
      if (mapped != null && tz.timeZoneDatabase.locations.containsKey(mapped)) {
        tz.setLocalLocation(tz.getLocation(mapped));
        debugPrint('[NotificationService] Local timezone mapped: $sysName -> $mapped');
        return;
      }

      // 3. Fallback: match by offset in milliseconds against IANA database
      final offsetMillis = now.timeZoneOffset.inMilliseconds;
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (tz.TZDateTime.now(loc).timeZoneOffset.inMilliseconds == offsetMillis) {
          tz.setLocalLocation(loc);
          debugPrint('[NotificationService] Local timezone matched by offset: ${loc.name}');
          return;
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Error configuring local timezone: $e');
    }
  }

  static _NotifCopy _getMorningCopy(String user, String partner, int dayIndex) {
    final list = [
      _NotifCopy('Morning lover 🥐', 'Bet you\'re looking cute right now. Check on $partner before they wonder where you are 😏💋'),
      _NotifCopy('Wake up sleepyhead! ☀️', 'Your favorite human $partner is out there. Steal their morning smile first ☕✨'),
      _NotifCopy('Partner radar beeped 👀', 'Pssst... $partner might be checking their phone for you right now. Sneak in and say hi 🍓💕'),
      _NotifCopy('Good morning gorgeous 🥑', 'Today\'s forecast: 100% chance of missing $partner. Tap to check their sky ☁️🌸'),
      _NotifCopy('Rise & shine cutie 🍯', 'The world is awake, but your sanctuary is just for the two of you. Drop a morning whisper 💌'),
      _NotifCopy('First thought of the day? 💭', 'Admit it, $partner was already in your head. Go send some morning warmth 🥞💛'),
      _NotifCopy('New day, same obsession 🧸', 'Go make $partner blush before their coffee kicks in. Tap to visit your sanctuary ☕💋'),
    ];
    return list[dayIndex % list.length];
  }

  static _NotifCopy _getAfternoonCopy(String user, String partner, int dayIndex) {
    final list = [
      _NotifCopy('Distraction alert 🚨', 'Stop working for 10 seconds. Send $partner a sneaky touch to tickle their screen 🪶😉'),
      _NotifCopy('Afternoon craving 🍩', 'Forget the snack — $partner is craving your attention right now. Tap to nudge them ☕✨'),
      _NotifCopy('Caught you daydreaming ☁️', 'Were you thinking of $partner? Thought so. Send a quick heart so they know 😏❤️'),
      _NotifCopy('Quick question... 🤔', 'When was the last time you told $partner they\'re cute today? Go fix it 🍓💨'),
      _NotifCopy('Boring afternoon? 🥱', 'Spice it up. Drop a silly note or a cute audio whisper for $partner 🎧💋'),
      _NotifCopy('Partner poke incoming 👉', 'Send a gentle tether touch to $partner — see how fast they touch back ⚡💛'),
      _NotifCopy('Missing them a little? 🧸', 'Halfway through the day. A 2-second touch on your screen will make $partner smile 🌸✨'),
    ];
    return list[dayIndex % list.length];
  }

  static _NotifCopy _getEveningCopy(String user, String partner, int dayIndex) {
    final list = [
      _NotifCopy('Spill the tea tonight 🍵', 'Today\'s couple question is juicy. What will $partner say? Seal your answer first 🤫✨'),
      _NotifCopy('No peeking allowed 🙈', 'Tonight\'s card is locked! Both of you have to answer to break the wax seal. Drop your truth 🕯️🔥'),
      _NotifCopy('Pillow talk time 🛋️', 'Time to unseal tonight\'s question with $partner. See if you two are on the same page 🌙🥂'),
      _NotifCopy('Secret envelope waiting 💌', 'A sweet question is ready for you two. Answer before midnight to unlock $partner\'s thoughts 🗝️💫'),
      _NotifCopy('Date night in your pocket 🍷', 'Break today\'s wax seal with $partner. Who\'s answering first tonight? 😏❤️'),
    ];
    return list[dayIndex % list.length];
  }

  static _NotifCopy _getNightCopy(String user, String partner, int dayIndex) {
    final list = [
      _NotifCopy('Don\'t sleep just yet 🥺', 'Leave $partner a little goodnight whisper so it\'s the first thing they wake up to tomorrow 🛌🌙'),
      _NotifCopy('Goodnight favorite human 🧸', 'Cuddle in through the screen. Send your last warm hug of the night to $partner 💫🕯️'),
      _NotifCopy('Midnight rule 🤫', 'No sleeping without saying goodnight! Drop a sweet bedtime kiss on $partner\'s sanctuary 🍯💋'),
      _NotifCopy('Counting stars with you 🌌', 'Another day loved by $partner. Close your eyes knowing you\'re their safe place 💤❤️'),
      _NotifCopy('Sweet dreams cutie 🌙', 'Tuck into bed softly. A quiet goodnight whisper for $partner is waiting to be sent ✨🤍'),
    ];
    return list[dayIndex % list.length];
  }

  static Future<void> init() async {
    // 1. Timezone database initialization and device local timezone resolution
    _configureLocalTimeZone();

    // 2. Local Notifications Initialization
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Notification tapped with action: ${response.actionId}, payload: ${response.payload}');
        if (response.actionId == 'action_send_love') {
          handleQuickSendLoveAction();
        } else if (response.payload != null && response.payload!.isNotEmpty) {
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

      // 4. Firebase Cloud Messaging (FCM) Foreground Listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        final data = message.data;
        if (notification != null || data.isNotEmpty) {
          showInstantNotification(
            title: notification?.title ?? data['title'] ?? 'Pages of Us ✦',
            body: notification?.body ?? data['body'] ?? 'Your partner shared something special.',
            payload: data['payload'] ?? 'tab_0',
          );
        }
      });
    } catch (e) {
      debugPrint('FCM init ignored/offline: $e');
    }

    // 5. Automatically schedule living sanctuary daily rhythm from cached profile
    try {
      final cachedUser = LocalCacheService.getCachedUser();
      final cachedPartner = LocalCacheService.getCachedPartner();
      await scheduleDailyLivingSanctuaryCadence(
        userNickname: cachedUser?['nickname'] as String?,
        partnerNickname: cachedPartner?['nickname'] as String?,
      );
    } catch (e) {
      debugPrint('Error scheduling initial sanctuary cadence: $e');
    }
  }

  /// Handle Instant "❤️ Send Love" from Android Notification Bar / Lock Screen
  static Future<void> handleQuickSendLoveAction() async {
    try {
      HapticFeedback.heavyImpact();
      final user = LocalCacheService.getCachedUser();
      final space = LocalCacheService.getCachedSpace();

      if (space != null && space['id'] != null) {
        final spaceId = space['id'] as String;
        final senderNickname = user?['nickname'] ?? 'Your partner';

        await SupabaseService.broadcastEvent(
          spaceId: spaceId,
          eventType: 'PULSE',
          payload: {
            'senderNickname': senderNickname,
            'type': 'HEART',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        debugPrint('[NotificationService] Quick "Send Love" pulse dispatched to space $spaceId');
      }
    } catch (e) {
      debugPrint('[NotificationService] Error handling quick send love: $e');
    }
  }

  // =========================================================================
  // PILLAR 1: DAILY EMOTIONAL CADENCE (4 DAILY SANCTUARY TETHERS)
  // =========================================================================
  static Future<void> scheduleDailyLivingSanctuaryCadence({
    String? userNickname,
    String? partnerNickname,
  }) async {
    try {
      _configureLocalTimeZone();
      final user = (userNickname != null && userNickname.trim().isNotEmpty) ? userNickname.trim() : 'you';
      final partner = (partnerNickname != null && partnerNickname.trim().isNotEmpty)
          ? partnerNickname.trim()
          : 'your partner';

      final now = tz.TZDateTime.now(tz.local);
      final dayOfYear = now.difference(tz.TZDateTime(tz.local, now.year, 1, 1)).inDays;

      // Cancel previous daily IDs so they are cleanly rescheduled with correct timezone and fresh copy
      await _localNotifications.cancel(80001);
      await _localNotifications.cancel(80002);
      await _localNotifications.cancel(80003);
      await _localNotifications.cancel(80004);

      final morningCopy = _getMorningCopy(user, partner, dayOfYear);
      final afternoonCopy = _getAfternoonCopy(user, partner, dayOfYear);
      final eveningCopy = _getEveningCopy(user, partner, dayOfYear);
      final nightCopy = _getNightCopy(user, partner, dayOfYear);

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
        actions: _quickLoveActions,
      );

      // 1. 08:30 AM — Morning Tether & Sky (Playful & Warm)
      var morning = tz.TZDateTime(tz.local, now.year, now.month, now.day, 8, 30);
      if (morning.isBefore(now)) morning = morning.add(const Duration(days: 1));

      await _localNotifications.zonedSchedule(
        80001,
        morningCopy.title,
        morningCopy.body,
        morning,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'tab_0',
      );

      // 2. 02:15 PM — Afternoon Intimacy Nudge (Teasing & Playful)
      var afternoon = tz.TZDateTime(tz.local, now.year, now.month, now.day, 14, 15);
      if (afternoon.isBefore(now)) afternoon = afternoon.add(const Duration(days: 1));

      await _localNotifications.zonedSchedule(
        80002,
        afternoonCopy.title,
        afternoonCopy.body,
        afternoon,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'touch',
      );

      // 3. 08:00 PM — Tonight's Daily Sync & Wax Seal (Curious & Informative)
      var evening = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 0);
      if (evening.isBefore(now)) evening = evening.add(const Duration(days: 1));

      await _localNotifications.zonedSchedule(
        80003,
        eveningCopy.title,
        eveningCopy.body,
        evening,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily_sync',
      );

      // 4. 10:45 PM — Nightfall & Sleep Whispers (Sweet & Cozy)
      var night = tz.TZDateTime(tz.local, now.year, now.month, now.day, 22, 45);
      if (night.isBefore(now)) night = night.add(const Duration(days: 1));

      await _localNotifications.zonedSchedule(
        80004,
        nightCopy.title,
        nightCopy.body,
        night,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'tab_0',
      );

      debugPrint('[NotificationService] Scheduled all 4 Daily Living Sanctuary Tethers in local timezone ${tz.local.name}!');
    } catch (e) {
      debugPrint('[NotificationService] Error scheduling daily sanctuary cadence: $e');
    }
  }

  // =========================================================================
  // PILLAR 4: PARTNER RAIN & WEATHER EMPATHY
  // =========================================================================
  static Future<void> showPartnerRainEmpathyNotification({
    required String partnerNickname,
    required String condition,
  }) async {
    final key = 'rain_${DateTime.now().day}_${DateTime.now().hour ~/ 6}';
    if (_recentNotifiedKeys.contains(key)) return;
    _recentNotifiedKeys.add(key);

    const androidDetails = AndroidNotificationDetails(
      alertChannelId,
      alertChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: _smallIcon,
      largeIcon: _largeAppIcon,
      color: Color(0xFF38BDF8), // Rain Sky Blue
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
      actions: _quickLoveActions,
    );

    await _localNotifications.show(
      90010,
      'Puddle alert near $partnerNickname 🌧️',
      'It\'s raining over their sky! Perfect excuse to text: "Wish I was sharing an umbrella with you" ☔☕',
      const NotificationDetails(android: androidDetails),
      payload: 'tab_1',
    );
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
      actions: _quickLoveActions,
    );

    await _localNotifications.show(
      90001,
      'Officially locked in! 🥂✨',
      'You and $partnerNickname are now paired! Your private universe for two is unlocked ✦💖',
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
      'Spotted: $partnerNickname near $placeName 📍',
      'They just reached your special spot "$placeName"$tagText. Send them a cute little wave 🏡✨',
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
    String notifBody;
    final cleanCaption = caption.trim().isNotEmpty ? ' — "$caption"' : '';
    switch (type.toLowerCase()) {
      case 'video':
        notifTitle = 'Mini movie saved! 🎬';
        notifBody = '$partnerNickname just added a new video "$title" to your storybook 🍿💖';
        break;
      case 'voice':
      case 'audio':
        notifTitle = 'Voice note from $partnerNickname 🎙️';
        notifBody = 'Plug in your earphones — their sweet voice is waiting for you 🎧✨';
        break;
      case 'letter':
        notifTitle = 'Secret love letter dropped 💌';
        notifBody = 'Ooh, $partnerNickname wrote something for your eyes only. Open it in private 🤫💋';
        break;
      case 'milestone':
        notifTitle = 'New milestone unlocked! ⭐';
        notifBody = '$partnerNickname celebrated: "$title"$cleanCaption 🥂💫';
        break;
      case 'photo':
      default:
        notifTitle = 'Cute moment preserved 📸';
        notifBody = '$partnerNickname just pinned "$title"$cleanCaption to your album 🥰';
        break;
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
      actions: _quickLoveActions,
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
      actions: _quickLoveActions,
    );

    await _localNotifications.show(
      90005,
      'DJ $partnerNickname is on aux 🎶',
      'They\'re jamming to "$songTitle". Hop on the shared frequency before they skip your song 🎧💃',
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
        'Don\'t leave $partnerNickname hanging! 🙈',
        'Tonight\'s question is still locked without your answer. Go break the wax seal together before midnight 🕯️🔥',
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
      actions: _quickLoveActions,
    );

    await _localNotifications.show(
      90071,
      'They answered! 👀',
      '$partnerNickname just locked in their answer. Tap to reveal what they wrote about you 💫💋',
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
      'Stormy skies near $partnerNickname ⛈️',
      '$condition and ${tempC.round()}°C detected over their sky! Check in on your favorite human to make sure they\'re cozy ❤️',
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
          ? 'You and your partner have $pendingGoalsCount milestones in progress! Take one cute little step together today 💫'
          : 'All shared goals conquered! Dream up your next big romantic adventure together today 🥂✨';

      await _localNotifications.zonedSchedule(
        90009,
        '🎯 Weekly Dream Check-In',
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
      actions: _quickLoveActions,
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
        'Weekly Touch Recap ❤️',
        'You and $partnerNickname shared $weeklyTouches touches this week! Send a quick poke to say you miss them ⚡💛',
        scheduled,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (_) {}
  }

  // ==========================================
  // DAILY CARE & ROUTINE NOTIFICATIONS
  // ==========================================

  /// Robust parser for time string, e.g. "08:30 AM", "1:15 PM", "14:30"
  static TimeOfDay? parseTimeString(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final clean = raw.trim().toUpperCase();
      final hasAm = clean.contains('AM');
      final hasPm = clean.contains('PM');

      final digitsAndColon = clean.replaceAll(RegExp(r'[^0-9:]'), '');
      final parts = digitsAndColon.split(':');
      if (parts.isEmpty) return null;

      int rawHour = int.parse(parts[0]);
      int minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

      int finalHour = rawHour;
      if (hasPm) {
        if (finalHour < 12) finalHour += 12;
      } else if (hasAm) {
        if (finalHour == 12) finalHour = 0;
      }

      if (finalHour < 0 || finalHour > 23 || minute < 0 || minute > 59) return null;
      return TimeOfDay(hour: finalHour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  /// Formats any time string or TimeOfDay into unambiguous "HH:MM AM/PM"
  static String formatWithAmPm(String rawTime) {
    final clean = rawTime.trim();
    if (clean.isEmpty) return '09:00 AM';
    final tod = parseTimeString(clean);
    if (tod == null) return clean;
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  /// Schedules local exact repeating alarms on the device for daily care items
  static Future<void> scheduleDailyCareNotifications({
    required List<DailyCareItem> items,
    required String? currentUserId,
    String? partnerName,
  }) async {
    try {
      _configureLocalTimeZone();
      final effectivePartner = (partnerName != null && partnerName.trim().isNotEmpty)
          ? partnerName.trim()
          : 'Your partner';

      final now = tz.TZDateTime.now(tz.local);
      final todayKey = now.toIso8601String().split('T')[0];

      for (final item in items) {
        // Deterministic ID per care item in range 70000 - 79999
        final notifId = 70000 + (item.id.hashCode.abs() % 9999);

        // Cancel previous registration to avoid duplicates
        await _localNotifications.cancel(notifId);

        // Only schedule items targeted for this phone's owner
        final isForCurrentUser = currentUserId == null ||
            currentUserId.isEmpty ||
            item.targetUserId == currentUserId ||
            (item.targetUserId.isEmpty && item.createdById != currentUserId);

        if (!isForCurrentUser) continue;

        final tod = parseTimeString(item.scheduledTime);
        if (tod == null) continue;

        final isDoneToday = item.isCompletedForDate(todayKey);

        var scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          tod.hour,
          tod.minute,
        );

        if (scheduledDate.isBefore(now) || isDoneToday) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }

        final title = '${item.icon} ${item.title} (${formatWithAmPm(item.scheduledTime)})';
        final body = item.caringNote.trim().isNotEmpty
            ? item.caringNote.trim()
            : '$effectivePartner lovingly scheduled this care checkup for you 💕';

        const androidDetails = AndroidNotificationDetails(
          partnerChannelId,
          partnerChannelName,
          channelDescription: 'Daily care routines, medicines, water, and sweet partner checkups',
          importance: Importance.max,
          priority: Priority.high,
          icon: _smallIcon,
          largeIcon: _largeAppIcon,
          color: _brandColor,
          enableVibration: true,
          styleInformation: BigTextStyleInformation(''),
          actions: _quickLoveActions,
        );

        await _localNotifications.zonedSchedule(
          notifId,
          title,
          body,
          scheduledDate,
          const NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'daily_care',
        );

        debugPrint('[NotificationService] Scheduled Daily Care "${item.title}" at ${item.scheduledTime} (ID: $notifId, Next: $scheduledDate)');
      }
    } catch (e) {
      debugPrint('[NotificationService] Error scheduling daily care notifications: $e');
    }
  }

  /// Instant notification when partner schedules a new care item
  static Future<void> showInstantDailyCareScheduledNotification({
    required String? partnerName,
    required String careTitle,
    required String scheduledTime,
  }) async {
    try {
      final name = (partnerName != null && partnerName.trim().isNotEmpty) ? partnerName.trim() : 'Your partner';
      const androidDetails = AndroidNotificationDetails(
        partnerChannelId,
        partnerChannelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: _smallIcon,
        largeIcon: _largeAppIcon,
        color: _brandColor,
        enableVibration: true,
        actions: _quickLoveActions,
      );
      await _localNotifications.show(
        80010,
        '💖 New Care Checkup from $name',
        '$name added "$careTitle" scheduled for ${formatWithAmPm(scheduledTime)} ✨',
        const NotificationDetails(android: androidDetails),
        payload: 'daily_care',
      );
    } catch (e) {
      debugPrint('[NotificationService] Error showing instant daily care notification: $e');
    }
  }

  /// Instant notification when partner lovingly nudges a care item
  static Future<void> showInstantDailyCareNudgeNotification({
    required String? partnerName,
    required String careTitle,
  }) async {
    try {
      final name = (partnerName != null && partnerName.trim().isNotEmpty) ? partnerName.trim() : 'Your partner';
      const androidDetails = AndroidNotificationDetails(
        partnerChannelId,
        partnerChannelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: _smallIcon,
        largeIcon: _largeAppIcon,
        color: _brandColor,
        enableVibration: true,
        actions: _quickLoveActions,
      );
      await _localNotifications.show(
        80011,
        '🌸 Gentle Care Nudge from $name',
        '$name is lovingly reminding you: "$careTitle" 💕',
        const NotificationDetails(android: androidDetails),
        payload: 'daily_care',
      );
    } catch (e) {
      debugPrint('[NotificationService] Error showing daily care nudge notification: $e');
    }
  }

  /// Cancel a single daily care notification if item is deleted
  static Future<void> cancelDailyCareNotification(String itemId) async {
    try {
      final notifId = 70000 + (itemId.hashCode.abs() % 9999);
      await _localNotifications.cancel(notifId);
    } catch (_) {}
  }
}
