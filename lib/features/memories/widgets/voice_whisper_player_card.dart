import 'package:flutter/material.dart';
import '../../../data/models/memory_item.dart';
import '../../../providers/memories_provider.dart';
import '../../../providers/audio_provider.dart';
import '../../../widgets/sanctuary_voice_player.dart';

class VoiceWhisperPlayerCard extends StatelessWidget {
  final MemoryItem memory;
  final bool isDark;
  final MemoriesProvider memoriesProvider;
  final AudioProvider? audioProvider;

  const VoiceWhisperPlayerCard({
    super.key,
    required this.memory,
    required this.isDark,
    required this.memoriesProvider,
    this.audioProvider,
  });

  String _resolveAudioUrl() {
    if (memory.voiceUrl != null && memory.voiceUrl!.isNotEmpty) {
      return memory.voiceUrl!;
    }
    return memory.mediaUrl;
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolveAudioUrl();
    if (url.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SanctuaryVoicePlayer(
        id: memory.id,
        audioUrl: url,
        isDark: isDark,
        ambientAudio: audioProvider,
      ),
    );
  }
}
