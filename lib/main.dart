import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:audio_service/audio_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/services/local_cache_service.dart';
import 'core/services/audio_handler.dart';
import 'core/services/notification_service.dart';
import 'core/services/music_download_service.dart';
import 'data/services/supabase_service.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/stage_provider.dart';
import 'providers/audio_provider.dart';
import 'providers/world_provider.dart';
import 'providers/memories_provider.dart';
import 'providers/vault_provider.dart';
import 'features/auth/screens/auth_screen.dart';
import 'features/stage/screens/stage_screen.dart';
import 'features/world/screens/world_screen.dart';
import 'features/memories/screens/memories_screen.dart';
import 'features/vault/screens/vault_screen.dart';
import 'features/splash/screens/splash_screen.dart';
import 'features/music/screens/listen_together_screen.dart';
import 'widgets/custom_bottom_nav.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Instant local storage cache (0ms boot latency)
  await LocalCacheService.init();

  // 2. Initialize Firebase Core
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (_) {
    // Allows offline launch with cached state
  }

  // 3. Initialize Supabase Realtime client
  await SupabaseService.init();

  // 4. Initialize Background Audio Notification Handler
  SanctuaryAudioHandler? audioHandler;
  try {
    audioHandler = await AudioService.init(
      builder: () => SanctuaryAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.pagesofus.app.music',
        androidNotificationChannelName: 'Sanctuary Music',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (e) {
    debugPrint('AudioService init error: $e');
  }

  // 5. Initialize Exact Scheduled & Push Notification Service
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('NotificationService init error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StageProvider()),
        ChangeNotifierProvider(create: (_) => AudioProvider(audioHandler: audioHandler)),
        ChangeNotifierProvider(create: (_) => WorldProvider()),
        ChangeNotifierProvider(create: (_) => MemoriesProvider()),
        ChangeNotifierProvider(create: (_) => VaultProvider()),
        ChangeNotifierProvider.value(value: MusicDownloadService.instance),
      ],
      child: const PagesOfUsApp(),
    ),
  );
}

class PagesOfUsApp extends StatelessWidget {
  const PagesOfUsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Pages of Us',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // Instant check from local cache / provider state
    if (!authProvider.isAuthenticated) {
      return const AuthScreen();
    }

    return const MainNavigationScaffold();
  }
}

class MainNavigationScaffold extends StatefulWidget {
  const MainNavigationScaffold({super.key});

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> with WidgetsBindingObserver {
  int _currentIndex = 0;
  String? _syncedSpaceId;
  String? _syncedPartnerId;
  StreamSubscription? _notifSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Deep-linking from notification taps
    _notifSub = NotificationService.selectNotificationStream.stream.listen((payload) {
      if (!mounted || payload == null) return;
      if (payload == 'tab_0' || payload == 'daily_sync' || payload == 'pairing_success' || payload == 'couple_goals') {
        setState(() => _currentIndex = 0);
      } else if (payload == 'tab_1' || payload == 'partner_weather') {
        setState(() => _currentIndex = 1);
      } else if (payload == 'tab_2' || payload.startsWith('memory_') || payload.startsWith('letter_')) {
        setState(() => _currentIndex = 2);
      } else if (payload == 'tab_3' || payload.startsWith('vault_')) {
        setState(() => _currentIndex = 3);
      } else if (payload == 'listen_together') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ListenTogetherScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
        auth.refreshUserData(auth.user!.id);
      }
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      if (mounted) {
        final audioProvider = context.read<AudioProvider>();
        // Atmosphere sounds strictly stop when leaving the app!
        audioProvider.stopAtmosphereOnExit();
        // Songs continue only if user enabled background playback
        if (!audioProvider.allowBackgroundPlayback && audioProvider.isSongPlaying) {
          audioProvider.pauseSong();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final authProvider = context.watch<AuthProvider>();
    final isVaultTab = _currentIndex == 3;
    final isDarkScreen = isVaultTab || isDark;

    // Reactively connect space listeners whenever user pairs or space changes
    final space = authProvider.space;
    final user = authProvider.user;
    final partner = authProvider.partner;
    final effectiveSpaceId = space?.id ?? user?.spaceId;

    if (effectiveSpaceId != null && effectiveSpaceId.isNotEmpty && user != null) {
      if (_syncedSpaceId != effectiveSpaceId || _syncedPartnerId != partner?.id) {
        _syncedSpaceId = effectiveSpaceId;
        _syncedPartnerId = partner?.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.read<StageProvider>().initSpaceListeners(
                effectiveSpaceId,
                user.id,
                partner?.id,
              );
          context.read<WorldProvider>().initWorldSync(
                spaceId: effectiveSpaceId,
                currentUserId: user.id,
                partnerId: partner?.id,
              );
          context.read<VaultProvider>().initVaultSync(effectiveSpaceId);
          context.read<MemoriesProvider>().initMemoriesSync(
                spaceId: effectiveSpaceId,
                currentUserId: user.id,
                partnerNickname: partner?.nickname,
              );
          context.read<AudioProvider>().initMusicSync(effectiveSpaceId);
        });
      }
    }

    final systemOverlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkScreen ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDarkScreen ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: isVaultTab
          ? const Color(0xFF130F1A)
          : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
      systemNavigationBarIconBrightness: isDarkScreen ? Brightness.light : Brightness.dark,
    );

    final screens = [
      StageScreen(
        onGoToMemories: () => setState(() => _currentIndex = 2),
        onSelectTab: (index) => setState(() => _currentIndex = index),
      ),
      const WorldScreen(),
      const MemoriesScreen(),
      const VaultScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: systemOverlay,
        child: Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: CustomBottomNav(
            currentIndex: _currentIndex,
            onTabSelected: (index) => setState(() => _currentIndex = index),
          ),
        ),
      ),
    );
  }
}
