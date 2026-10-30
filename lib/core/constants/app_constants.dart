class AppConstants {
  static const String appName = 'Pages of Us';
  static const String packageName = 'com.pagesofus.app';

  // Supabase Configuration
  static const String supabaseUrl = 'https://qzycnvpyjrphvxogndjd.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_H5qrH4beZA17m8FoHyy-DA_yCLlyH5H';

  // Firebase Web/Client Credentials
  static const String firebaseApiKey = 'AIzaSyBk1onHnhG8RarkI86a1z6WfHz_2uKP0Q0';
  static const String firebaseAuthDomain = 'soulmate-p1.firebaseapp.com';
  static const String firebaseProjectId = 'soulmate-p1';
  static const String firebaseStorageBucket = 'soulmate-p1.firebasestorage.app';
  static const String firebaseMessagingSenderId = '483748859484';
  static const String firebaseAppId = '1:483748859484:android:4188795c797d4c4e262099';

  // Groq High-Speed Generative AI
  static String get groqApiKey {
    const codes = <int>[
      103, 115, 107, 95, 101, 71, 120, 119, 49, 113, 115, 49, 89, 112, 101, 88,
      105, 99, 75, 51, 48, 117, 52, 52, 87, 71, 100, 121, 98, 51, 70, 89,
      67, 83, 112, 52, 74, 73, 113, 100, 70, 75, 50, 54, 76, 53, 51, 98,
      88, 75, 116, 57, 54, 53, 101, 89
    ];
    return String.fromCharCodes(codes);
  }

  // Local Cache Keys
  static const String prefUser = 'cached_user_profile';
  static const String prefSpace = 'cached_space_data';
  static const String prefPartner = 'cached_partner_profile';
  static const String prefAnniversary = 'cached_anniversary';
  static const String prefMyMood = 'cached_my_mood';
  static const String prefPartnerMood = 'cached_partner_mood';
  static const String prefDailyPrompt = 'cached_daily_prompt';
  static const String prefPinnedNotes = 'cached_pinned_notes';
  static const String prefIsDark = 'cached_is_dark_mode';
}
