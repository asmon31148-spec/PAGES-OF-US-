import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../widgets/update_dialog.dart';

class UpdateInfo {
  final String version;
  final String changelog;
  final String apkDownloadUrl;
  final int apkSizeBytes;

  UpdateInfo({
    required this.version,
    required this.changelog,
    required this.apkDownloadUrl,
    required this.apkSizeBytes,
  });
}

class UpdateService {
  // Fallback version in case native platform package info is unreachable
  static const String fallbackCurrentVersion = '1.0.105';
  static const String currentVersion = fallbackCurrentVersion;

  // Distribution repository
  static const String githubRepo = 'asmon31148-spec/PAGES-OF-US-';

  /// Dynamically retrieves the true installed version from Android runtime
  static Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final clean = info.version.replaceAll(RegExp(r'[^0-9.]'), '');
      if (clean.isNotEmpty) return clean;
    } catch (_) {}
    return fallbackCurrentVersion;
  }

  /// Checks Firestore remote config and GitHub releases for a newer APK version
  static Future<UpdateInfo?> checkLatestRelease() async {
    final currentVersion = await getCurrentVersion();

    // 1. First Priority: Firebase Firestore remote config document ('app_config/update')
    try {
      final doc = await FirebaseFirestore.instance.collection('app_config').doc('update').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final latestVersion = data['version']?.toString() ?? '';
        final cleanVersion = latestVersion.replaceAll(RegExp(r'[^0-9.]'), '');
        if (_isNewerVersion(cleanVersion, currentVersion)) {
          final body = data['changelog']?.toString() ?? 'A new update is available for Pages of Us.';
          final apkUrl = data['apk_url']?.toString() ?? '';
          final sizeBytes = (data['size_bytes'] as num?)?.toInt() ?? 0;

          if (apkUrl.isNotEmpty) {
            return UpdateInfo(
              version: latestVersion.startsWith('v') ? latestVersion : 'v$latestVersion',
              changelog: body,
              apkDownloadUrl: apkUrl,
              apkSizeBytes: sizeBytes,
            );
          }
        }
      }
    } catch (_) {}

    // 2. Second Priority: GitHub Releases public API
    try {
      final url = Uri.parse('https://api.github.com/repos/$githubRepo/releases/latest');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'PagesOfUs-App/1.0',
          'Cache-Control': 'no-cache',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tagName = data['tag_name']?.toString() ?? '';
        final cleanVersion = tagName.replaceAll(RegExp(r'[^0-9.]'), '');

        if (_isNewerVersion(cleanVersion, currentVersion)) {
          final body = data['changelog']?.toString() ?? data['body']?.toString() ?? 'A new update is available for Pages of Us.';
          final assets = data['assets'] as List<dynamic>? ?? [];

          String apkUrl = 'https://github.com/$githubRepo/releases/download/$tagName/PagesOfUs.apk';
          int sizeBytes = 0;

          for (final a in assets) {
            final name = a['name']?.toString() ?? '';
            if (name.endsWith('.apk')) {
              apkUrl = a['browser_download_url']?.toString() ?? apkUrl;
              sizeBytes = (a['size'] as num?)?.toInt() ?? 0;
              break;
            }
          }

          return UpdateInfo(
            version: tagName.isNotEmpty ? tagName : 'v$cleanVersion',
            changelog: body,
            apkDownloadUrl: apkUrl,
            apkSizeBytes: sizeBytes,
          );
        }
      }
    } catch (e) {
      debugPrint('Check GitHub API error: $e');
    }

    // 3. Third Priority Fallback: Direct Raw Repository Metadata with Cache-Busting
    // Cache-busting query parameter (?_t=...) prevents CDN caching from serving stale versions
    try {
      final rawUrl = Uri.parse(
        'https://raw.githubusercontent.com/$githubRepo/master/pubspec.yaml?_t=${DateTime.now().millisecondsSinceEpoch}',
      );
      final rawRes = await http.get(
        rawUrl,
        headers: {
          'User-Agent': 'PagesOfUs-App/1.0',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      ).timeout(const Duration(seconds: 6));

      if (rawRes.statusCode == 200) {
        final match = RegExp(r'version:\s*([0-9]+\.[0-9]+\.[0-9]+)').firstMatch(rawRes.body);
        if (match != null) {
          final latestVersion = match.group(1)!;
          if (_isNewerVersion(latestVersion, currentVersion)) {
            return UpdateInfo(
              version: 'v$latestVersion',
              changelog: 'A new update (v$latestVersion) is available with UI improvements and bug fixes.',
              apkDownloadUrl: 'https://github.com/$githubRepo/releases/download/v$latestVersion/PagesOfUs.apk',
              apkSizeBytes: 98000000,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Check raw update fallback error: $e');
    }

    return null;
  }

  /// Compares semantic version numbers (e.g. 1.0.84 > 1.0.83)
  static bool _isNewerVersion(String latest, String current) {
    if (latest.isEmpty || current.isEmpty) return false;
    final latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    while (latestParts.length < currentParts.length) {
      latestParts.add(0);
    }
    while (currentParts.length < latestParts.length) {
      currentParts.add(0);
    }

    for (int i = 0; i < latestParts.length; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  /// Downloads the APK and triggers Android native package installer
  static Future<void> downloadAndInstall({
    required String downloadUrl,
    required Function(double progress, int downloaded, int total) onProgress,
  }) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      final total = response.contentLength ?? 0;
      int downloaded = 0;

      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/PagesOfUs_Update.apk');
      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      final sink = apkFile.openWrite();

      await response.stream.listen((chunk) {
        sink.add(chunk);
        downloaded += chunk.length;
        final progress = total > 0 ? (downloaded / total) : 0.0;
        onProgress(progress, downloaded, total);
      }).asFuture();

      await sink.flush();
      await sink.close();

      // Trigger Android Native Package Installer
      await OpenFilex.open(
        apkFile.path,
        type: 'application/vnd.android.package-archive',
      );
    } finally {
      client.close();
    }
  }

  static bool _hasPromptedThisSession = false;

  /// Prompts the user with the update popup if a newer version is available.
  /// Intelligently checks per-version dismissal so a NEW version will always prompt
  /// on both phones immediately, while not nagging for the same dismissed version repeatedly.
  static Future<void> checkAndPrompt(BuildContext context, {bool force = false}) async {
    if (!force && _hasPromptedThisSession) return;

    final update = await checkLatestRelease();
    if (update == null || !context.mounted) return;

    if (!force) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastDismissedVersion = prefs.getString('dismissed_update_version');
        final lastPromptTime = prefs.getInt('last_update_prompt_timestamp') ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;

        // If the user already tapped "Next time" for THIS EXACT version, don't nag them again within 8 hours
        if (lastDismissedVersion == update.version && (now - lastPromptTime < 8 * 3600 * 1000)) {
          return;
        }
      } catch (_) {}
    }

    _hasPromptedThisSession = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_update_prompt_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => UpdateDialog(updateInfo: update),
    );
  }
}
