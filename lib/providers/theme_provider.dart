import 'package:flutter/material.dart';
import '../core/services/local_cache_service.dart';

class ThemeOption {
  final String id;
  final String name;
  final String description;
  final bool isDark;
  final Color accentColor;

  const ThemeOption({
    required this.id,
    required this.name,
    required this.description,
    required this.isDark,
    required this.accentColor,
  });
}

class ThemeProvider extends ChangeNotifier {
  bool _isDark = false;
  String _themeId = 'paper';

  bool get isDark => _isDark;
  String get themeId => _themeId;

  static const List<ThemeOption> availableThemes = [
    ThemeOption(
      id: 'paper',
      name: 'Warm Paper',
      description: 'Editorial ivory and calm sage atmosphere',
      isDark: false,
      accentColor: Color(0xFF4D655A),
    ),
    ThemeOption(
      id: 'terracotta',
      name: 'Terracotta Sunset',
      description: 'Warm earthen clay and dusk glow',
      isDark: false,
      accentColor: Color(0xFFE07A5F),
    ),
    ThemeOption(
      id: 'noir',
      name: 'Midnight Sanctuary',
      description: 'Deep slate darkness and gentle moonlight',
      isDark: true,
      accentColor: Color(0xFF8A9B85),
    ),
    ThemeOption(
      id: 'forest',
      name: 'Deep Forest',
      description: 'Rich moss greens and midnight canopy',
      isDark: true,
      accentColor: Color(0xFF6B8E7D),
    ),
    ThemeOption(
      id: 'ember',
      name: 'Velvet Ember',
      description: 'Warm nighttime glow and cozy fireplace',
      isDark: true,
      accentColor: Color(0xFFE07A5F),
    ),
  ];

  ThemeProvider() {
    _isDark = LocalCacheService.getCachedIsDark() ?? false;
  }

  void toggleDarkLight() {
    _isDark = !_isDark;
    LocalCacheService.setCachedIsDark(_isDark);
    notifyListeners();
  }

  void setTheme(String id) {
    final theme = availableThemes.firstWhere(
      (t) => t.id == id,
      orElse: () => availableThemes.first,
    );
    _themeId = theme.id;
    _isDark = theme.isDark;
    LocalCacheService.setCachedIsDark(_isDark);
    notifyListeners();
  }
}
