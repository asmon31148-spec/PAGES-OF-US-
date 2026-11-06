import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';

/// Adaptive Couple Taste Service
/// Gradually learns the couple's unique preferences (tone, intimacy, boldness, warmth)
/// for each filter combination without storing conversations or expanding storage.
/// Summaries are kept to a concise 2-sentence profile per combination (O(1) memory).
class CoupleTasteService {
  CoupleTasteService._();
  static final instance = CoupleTasteService._();

  static const String _prefPrefix = 'couple_taste_profile_';
  final Map<String, String> _memoryCache = {};

  String _comboKey(String stage, String mood, String boldness) =>
      '${stage}_${mood}_$boldness'.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');

  /// Get the learned 2-sentence taste profile for a specific filter combination
  Future<String?> getTasteSummary({
    required String stage,
    required String mood,
    required String boldness,
    String? spaceId,
  }) async {
    final key = _comboKey(stage, mood, boldness);

    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final localVal = prefs.getString('$_prefPrefix$key');
      if (localVal != null && localVal.trim().isNotEmpty) {
        _memoryCache[key] = localVal.trim();
        return localVal.trim();
      }

      if (spaceId != null && spaceId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('spaces')
            .doc(spaceId)
            .collection('couple_ai_taste')
            .doc(key)
            .get();

        if (doc.exists) {
          final summary = doc.data()?['summary']?.toString();
          if (summary != null && summary.trim().isNotEmpty) {
            _memoryCache[key] = summary.trim();
            await prefs.setString('$_prefPrefix$key', summary.trim());
            return summary.trim();
          }
        }
      }
    } catch (e) {
      debugPrint('[CoupleTasteService] Failed to load taste profile: $e');
    }

    return null;
  }

  /// Adapt the profile when a user refines instructions, dislikes, or chooses a question
  Future<void> recordFeedbackAndAdapt({
    required String stage,
    required String mood,
    required String boldness,
    String? earlierQuestion,
    required String userCorrection,
    required String finalQuestion,
    String? spaceId,
  }) async {
    final key = _comboKey(stage, mood, boldness);
    final previousSummary = await getTasteSummary(
      stage: stage,
      mood: mood,
      boldness: boldness,
      spaceId: spaceId,
    );

    final apiKey = AppConstants.groqApiKey;
    if (apiKey.isEmpty) return;

    try {
      final prompt = '''
You are an intimate relationship AI tuning module for a couple's sanctuary app called "Pages of Us".
Analyze what this couple desires based on their refinement:
- Stage: $stage, Mood: $mood, Romance Intensity: $boldness
- Existing Couple Taste Profile: "${previousSummary ?? 'No previous notes'}"
- Earlier Question generated: "${earlierQuestion ?? 'N/A'}"
- User's Correction / Desired Vibe: "$userCorrection"
- Final Question they loved: "$finalQuestion"

In exactly 2 concise, evocative sentences, summarize this couple's real underlying taste in tone, intimacy, emotional warmth, and romantic flavor for this filter combination.
Do NOT quote the prompt. Output ONLY the 2 sentences summarizing their preferences.
''';

      final response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode({
              'model': 'qwen/qwen3.8-27b',
              'messages': [
                {'role': 'system', 'content': prompt},
                {'role': 'user', 'content': 'Summarize couple taste in 2 sentences.'},
              ],
              'max_tokens': 160,
              'temperature': 0.7,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final choices = decoded['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final summary = choices[0]['message']?['content']?.toString().trim();
          if (summary != null && summary.isNotEmpty) {
            _memoryCache[key] = summary;

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('$_prefPrefix$key', summary);

            if (spaceId != null && spaceId.isNotEmpty) {
              await FirebaseFirestore.instance
                  .collection('spaces')
                  .doc(spaceId)
                  .collection('couple_ai_taste')
                  .doc(key)
                  .set({
                'comboKey': key,
                'stage': stage,
                'mood': mood,
                'boldness': boldness,
                'summary': summary,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            }

            debugPrint('[CoupleTasteService] Updated taste profile for $key: $summary');
          }
        }
      }
    } catch (e) {
      debugPrint('[CoupleTasteService] Adapt error: $e');
    }
  }

  /// Reset all stored taste profiles for this couple
  Future<void> resetAllProfiles({String? spaceId}) async {
    _memoryCache.clear();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefPrefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }

    if (spaceId != null && spaceId.isNotEmpty) {
      try {
        final snapshots = await FirebaseFirestore.instance
            .collection('spaces')
            .doc(spaceId)
            .collection('couple_ai_taste')
            .get();

        for (final doc in snapshots.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('[CoupleTasteService] Reset firestore error: $e');
      }
    }
  }
}
