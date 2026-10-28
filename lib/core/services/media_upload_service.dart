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
  // 1. Cloudinary: High-performance auto-compression for Photos, Videos & Audio Whispers
  // Uses client-safe unsigned upload preset (Zero private keys exposed)
  static const String cloudinaryCloudName = 'i8bn5qmo';
  static const String cloudinaryUploadPreset = 'pages_of_us_preset';

  // 2. Supabase Storage Fallback Bucket
  static const String mediaBucketName = 'pages-media';

  /// Uploads media file based on secure client-side routing:
  /// - Primary: Cloudinary (Auto-compression, adaptive video streaming, WebP & face-crop)
  /// - Secondary Fallback: Supabase Storage
  static Future<UploadResult> uploadFile(
    File file, {
    String folder = 'memories',
    void Function(double progress)? onProgress,
  }) async {
    // -------------------------------------------------------------
    // ROUTE 1: PRIMARY -> Cloudinary (Secure Unsigned Preset)
    // -------------------------------------------------------------
    final cloudResult = await _uploadToCloudinary(file, folder, onProgress);
    if (cloudResult != null) {
      return cloudResult;
    }

    // -------------------------------------------------------------
    // ROUTE 2: FALLBACK -> Supabase Storage
    // -------------------------------------------------------------
    final supaResult = await _uploadToSupabase(file, folder, onProgress);
    if (supaResult != null) {
      return supaResult;
    }

    throw Exception('Failed to upload media. Please check your internet connection.');
  }

  /// Uploads media directly to Cloudinary with secure unsigned preset
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
        final resourceType = data['resource_type'] as String? ?? 'image';
        final isVideo = resourceType == 'video';

        final optimizedUrl = isVideo
            ? secureUrl.replaceAll('/upload/', '/upload/q_auto/')
            : secureUrl.replaceAll('/upload/', '/upload/f_auto,q_auto/');

        final thumb = isVideo
            ? secureUrl.replaceAll(p.extension(secureUrl), '.jpg').replaceAll('/upload/', '/upload/so_0,w_400,c_fill,q_auto,f_jpg/')
            : secureUrl.replaceAll('/upload/', '/upload/c_thumb,w_300,g_face,f_auto,q_auto/');

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
}
