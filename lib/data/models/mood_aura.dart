import 'package:flutter/material.dart';

class MoodAura {
  final String id;
  final String emoji;
  final String label;
  final Color glowColor;

  const MoodAura({
    required this.id,
    required this.emoji,
    required this.label,
    required this.glowColor,
  });

  factory MoodAura.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? 'calm';
    return moodAuraOptions.firstWhere(
      (m) => m.id == id,
      orElse: () => MoodAura(
        id: id,
        emoji: json['emoji'] as String? ?? '🍃',
        label: json['label'] as String? ?? 'Calm',
        glowColor: const Color(0xFF8A9B85),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'emoji': emoji,
      'label': label,
    };
  }
}

const List<MoodAura> moodAuraOptions = [
  MoodAura(id: 'radiant', emoji: '☀️', label: 'Radiant', glowColor: Color(0xFFF4A261)),
  MoodAura(id: 'calm', emoji: '🍃', label: 'Calm', glowColor: Color(0xFF8A9B85)),
  MoodAura(id: 'cozy', emoji: '☕', label: 'Cozy', glowColor: Color(0xFFE07A5F)),
  MoodAura(id: 'in_love', emoji: '💕', label: 'In Love', glowColor: Color(0xFFF28482)),
  MoodAura(id: 'tired', emoji: '🌙', label: 'Tired', glowColor: Color(0xFF9CA3AF)),
  MoodAura(id: 'thoughtful', emoji: '💭', label: 'Thoughtful', glowColor: Color(0xFF93C5FD)),
  MoodAura(id: 'playful', emoji: '✨', label: 'Playful', glowColor: Color(0xFFFBBF24)),
  MoodAura(id: 'longing', emoji: '🕊️', label: 'Longing', glowColor: Color(0xFFA78BFA)),
];
