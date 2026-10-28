import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  static const String currentVersion = '1.0.8';
  static const String githubRepo = 'asmon31148-spec/PAGES-OF-US-';

  /// Checks Firestore remote config and GitHub releases for a newer APK version
  static Future<UpdateInfo?> checkLatestRelease() async {
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
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tagName = data['tag_name']?.toString() ?? '';
        final cleanVersion = tagName.replaceAll(RegExp(r'[^0-9.]'), '');

        if (_isNewerVersion(cleanVersion, currentVersion)) {
          final body = data['body']?.toString() ?? 'A new update is available for Pages of Us.';
          final assets = data['assets'] as List<dynamic>? ?? [];

          String apkUrl = 'https://github.com/$githubRepo/releases/download/latest/PagesOfUs.apk';
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
      debugPrint('Check update error (ignored): $e');
    }
    return null;
  }

  /// Compares semantic version numbers (e.g. 1.0.1 > 1.0.0)
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

  /// Prompts the user with the Echo-style update popup if available
  static Future<void> checkAndPrompt(BuildContext context) async {
    final update = await checkLatestRelease();
    if (update != null && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => UpdateDialog(updateInfo: update),
      );
    }
  }
}
