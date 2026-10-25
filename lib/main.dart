import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'core/services/local_cache_service.dart';
import 'data/services/supabase_service.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/stage_provider.dart';
import 'providers/audio_provider.dart';
import 'features/auth/screens/auth_screen.dart';
import 'features/stage/screens/stage_screen.dart';
import 'features/world/screens/world_screen.dart';
import 'features/memories/screens/memories_screen.dart';
import 'features/vault/screens/vault_screen.dart';
import 'widgets/custom_bottom_nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Instant local storage cache (0ms boot latency)
  await LocalCacheService.init();

  // 2. Initialize Firebase Core
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Allows offline launch with cached state
  }

  // 3. Initialize Supabase Realtime client
  await SupabaseService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StageProvider()),
        ChangeNotifierProvider(create: (_) => AudioProvider()),
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
      home: const AuthGate(),
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

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      StageScreen(onGoToMemories: () => setState(() => _currentIndex = 2)),
      const WorldScreen(),
      const MemoriesScreen(),
      const VaultScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTabSelected: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
