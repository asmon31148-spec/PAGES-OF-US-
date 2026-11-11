import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/supabase_service.dart';

class UploadResult {
  final String url;
  final String? thumbnailUrl;
  final String fileName;
  final int size;
  final String provider;

  UploadResult({
    required this.url,
    this.thumbnailUrl,
    required this.fileName,
    required this.size,
    required this.provider,
  });
}

class MediaUploadService {
  // 1. Cloudinary: High-performance auto-compression for Photos & Audio Whispers (25 GB Free, No Card)
  static const String cloudinaryCloudName = 'i8bn5qmo';
  static const String cloudinaryUploadPreset = 'pages_of_us_preset';

  // 2. ImageKit.io: Dedicated High-Speed Video Streaming (20 GB Free, Zero Billing, No Card)
  static const String imageKitEndpoint = 'https://ik.imagekit.io/asmon96';
  static const String imageKitPublicKey = 'public_2DxFyUqrIx65H0BV8faIyT0APK8=';
  static const String imageKitUploadUrl = 'https://upload.imagekit.io/api/v1/files/upload';

  // Secret key (supports secure --dart-define or fallback)
  static final String _ikSecret = const String.fromEnvironment('IMAGEKIT_PRIVATE_KEY').isNotEmpty
      ? const String.fromEnvironment('IMAGEKIT_PRIVATE_KEY')
      : utf8.decode(
          base64Decode('cHJpdmF0ZV96c1JvUm5BblhPZzBYQnlEemRkU1FrVEJhdHM9'),
        );

  // 3. Supabase Storage Fallback Bucket
  static const String mediaBucketName = 'pages-media';

  /// Uploads media file based on intelligent multi-cloud routing:
  /// - Videos (Vault & Memories) -> ImageKit.io (20 GB Free, fast edge CDN streaming)
  /// - Photos & Voice Whispers -> Cloudinary (auto-WebP, auto-compression, face crop)
  /// - Fallback -> Supabase Storage
  static Future<UploadResult> uploadFile(
    File file, {
    String folder = 'memories',
    void Function(double progress)? onProgress,
  }) async {
    final ext = p.extension(file.path).replaceAll('.', '').toLowerCase();
    final isVideo = ['mp4', 'mov', 'mkv', 'webm', 'avi', '3gp'].contains(ext) || folder.contains('video');

    // -------------------------------------------------------------
    // ROUTE 1: VIDEOS -> ImageKit.io (20 GB Free, separated folders)
    // -------------------------------------------------------------
    if (isVideo) {
      final targetFolder = folder.contains('vault') ? '/vault_videos' : '/memories_videos';
      final imageKitResult = await _uploadToImageKit(file, targetFolder, onProgress);
      if (imageKitResult != null) {
        return imageKitResult;
      }
      // If ImageKit has a network issue, gracefully falls back to Cloudinary
    }

    // -------------------------------------------------------------
    // ROUTE 2: PHOTOS & AUDIO -> Cloudinary (Optimized WebP & Audio)
    // -------------------------------------------------------------
    final cloudResult = await _uploadToCloudinary(file, folder, onProgress);
    if (cloudResult != null) {
      return cloudResult;
    }

    // -------------------------------------------------------------
    // ROUTE 3: FALLBACK -> Supabase Storage
    // -------------------------------------------------------------
    final supaResult = await _uploadToSupabase(file, folder, onProgress);
    if (supaResult != null) {
      return supaResult;
    }

    throw Exception('Failed to upload media. Please check your internet connection.');
  }

  /// Uploads video directly to ImageKit.io REST API with Basic Auth
  static Future<UploadResult?> _uploadToImageKit(
    File file,
    String targetFolder,
    void Function(double progress)? onProgress,
  ) async {
    try {
      final fileName = p.basename(file.path);
      final size = await file.length();
      final uri = Uri.parse(imageKitUploadUrl);

      final request = http.MultipartRequest('POST', uri);
      final authHeader = 'Basic ${base64Encode(utf8.encode('$_ikSecret:'))}';
      request.headers['Authorization'] = authHeader;

      request.fields['fileName'] = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      request.fields['folder'] = targetFolder;
      request.fields['useUniqueFileName'] = 'true';
      request.fields['tags'] = 'pages_of_us';

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      onProgress?.call(0.3);
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawUrl = data['url'] as String? ?? '';
        final thumb = (data['thumbnailUrl'] as String?) ??
            (data['thumbnail'] as String?) ??
            '$rawUrl/ik-thumbnail.jpg';

        onProgress?.call(1.0);
        return UploadResult(
          url: rawUrl,
          thumbnailUrl: thumb,
          fileName: fileName,
          size: size,
          provider: 'imagekit',
        );
      }
    } catch (_) {
      // Allows seamless fallback to Cloudinary / Supabase
    }
    return null;
  }

  /// Uploads media directly to Cloudinary with unsigned preset
  static Future<UploadResult?> _uploadToCloudinary(
    File file,
    String folder,
    void Function(double progress)? onProgress,
  ) async {
    try {
      final fileName = p.basename(file.path);
      final size = await file.length();
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/auto/upload',
      );

      final request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = cloudinaryUploadPreset;
      request.fields['folder'] = folder;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      onProgress?.call(0.4);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final secureUrl = data['secure_url'] as String? ?? '';
        final optimizedUrl = secureUrl.replaceAll('/upload/', '/upload/f_auto,q_auto/');
        final thumb = secureUrl.replaceAll('/upload/', '/upload/c_thumb,w_300,g_face,f_auto,q_auto/');

        onProgress?.call(1.0);
        return UploadResult(
          url: optimizedUrl.isNotEmpty ? optimizedUrl : secureUrl,
          thumbnailUrl: thumb,
          fileName: fileName,
          size: size,
          provider: 'cloudinary',
        );
      }
    } catch (_) {
      // Allows seamless fallback to Supabase
    }
    return null;
  }

  /// Uploads media to Supabase Storage fallback
  static Future<UploadResult?> _uploadToSupabase(
    File file,
    String folder,
    void Function(double progress)? onProgress,
  ) async {
    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        final fileName = p.basename(file.path);
        final size = await file.length();
        final ext = p.extension(file.path).replaceAll('.', '');
        final uniquePath = '$folder/${DateTime.now().millisecondsSinceEpoch}_$fileName';

        await supabase.storage.from(mediaBucketName).upload(
              uniquePath,
              file,
              fileOptions: FileOptions(
                upsert: true,
                contentType: _resolveContentType(ext),
              ),
            );

        final publicUrl = supabase.storage.from(mediaBucketName).getPublicUrl(uniquePath);
        onProgress?.call(1.0);
        return UploadResult(
          url: publicUrl,
          thumbnailUrl: publicUrl,
          fileName: fileName,
          size: size,
          provider: 'supabase',
        );
      }
    } catch (_) {
      // Ignored
    }
    return null;
  }

  static String _resolveContentType(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'm4a':
        return 'audio/m4a';
      case 'mp3':
        return 'audio/mpeg';
      case 'aac':
        return 'audio/aac';
      case 'wav':
        return 'audio/wav';
      default:
        return 'application/octet-stream';
    }
  }

  /// Extracts a Supabase Storage object path inside [mediaBucketName] from a public or signed URL.
  static String? extractSupabaseStoragePath(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final bucketIdx = segments.indexOf(mediaBucketName);
    if (bucketIdx == -1 || bucketIdx + 1 >= segments.length) return null;
    return segments.sublist(bucketIdx + 1).join('/');
  }

  /// Extracts ImageKit relative file path from an `ik.imagekit.io/<id>/...` URL.
  static String? extractImageKitFileName(String url) {
    final trimmed = url.trim();
    if (!trimmed.startsWith(imageKitEndpoint)) return null;
    final rest = trimmed.substring(imageKitEndpoint.length).replaceFirst(RegExp(r'^/+'), '');
    if (rest.isEmpty) return null;
    final clean = rest.split('?').first;
    return p.basename(clean);
  }

  /// Permanently deletes a remote media file from Supabase Storage or ImageKit (and local file if local path).
  static Future<bool> deleteRemoteFile(String? url) async {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) return true;

    // 0. Local filesystem path
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      try {
        final localPath = trimmed.startsWith('file://') ? trimmed.substring(7) : trimmed;
        final f = File(localPath);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
      return true;
    }

    // 1. Supabase Storage
    final supaPath = extractSupabaseStoragePath(trimmed);
    if (supaPath != null) {
      try {
        final client = SupabaseService.client;
        if (client != null) {
          await client.storage.from(mediaBucketName).remove([supaPath]);
          return true;
        }
      } catch (_) {
        return false;
      }
    }

    // 2. ImageKit Storage
    final ikName = extractImageKitFileName(trimmed);
    if (ikName != null && _ikSecret.isNotEmpty) {
      try {
        final authHeader = 'Basic ${base64Encode(utf8.encode('$_ikSecret:'))}';
        final searchUri = Uri.https('api.imagekit.io', '/v1/files', {
          'searchQuery': 'name="$ikName"',
          'limit': '5',
        });
        final listResp = await http
            .get(searchUri, headers: {'Authorization': authHeader})
            .timeout(const Duration(seconds: 10));
        if (listResp.statusCode == 200) {
          final decoded = jsonDecode(listResp.body);
          if (decoded is List) {
            for (final item in decoded) {
              if (item is Map && item['fileId'] != null) {
                final fileId = item['fileId'].toString();
                await http
                    .delete(
                      Uri.parse('https://api.imagekit.io/v1/files/$fileId'),
                      headers: {'Authorization': authHeader},
                    )
                    .timeout(const Duration(seconds: 10));
              }
            }
          }
          return true;
        }
      } catch (_) {
        return false;
      }
    }

    // 3. Cloudinary unsigned uploads cannot be securely destroyed without API secret on-device.
    // Returning true so DB deletion is never blocked on unsigned Cloudinary URLs.
    return true;
  }

  static Future<void> deleteRemoteFiles(Iterable<String?> urls) async {
    for (final url in urls) {
      if (url != null && url.trim().isNotEmpty) {
        await deleteRemoteFile(url);
      }
    }
  }
}
