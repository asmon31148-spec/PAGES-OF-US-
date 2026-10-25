import 'package:flutter/material.dart';
import '../core/services/local_cache_service.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDark = false;

  bool get isDark => _isDark;

  ThemeProvider() {
    // Instant startup from local cache (0ms delay)
    _isDark = LocalCacheService.getCachedIsDark() ?? false;
  }

  void toggleDarkLight() {
    _isDark = !_isDark;
    LocalCacheService.setCachedIsDark(_isDark);
    notifyListeners();
  }
}
