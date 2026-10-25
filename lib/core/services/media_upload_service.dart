import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
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
  static const String cloudinaryCloudName = 'i8bn5qmo';
  static const String cloudinaryUploadPreset = 'pages_of_us_preset';
  static const String mediaBucketName = 'pages_of_us';

  /// Uploads media file (photo, video, audio) to Cloudinary or falls back to Supabase Storage
  static Future<UploadResult> uploadFile(
    File file, {
    String folder = 'memories',
    void Function(double progress)? onProgress,
  }) async {
    final fileName = p.basename(file.path);
    final size = await file.length();

    // 1. Try Cloudinary direct upload
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/auto/upload',
      );

      final request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = cloudinaryUploadPreset;
      request.fields['folder'] = folder;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      onProgress?.call(0.3);

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
      // Fallback to Supabase Storage
    }

    // 2. Supabase Storage fallback
    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
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
    } catch (e) {
      // If network fails completely, throw user-friendly error
      throw Exception('Failed to upload media. Please check your internet connection.');
    }

    throw Exception('Storage service unavailable.');
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
