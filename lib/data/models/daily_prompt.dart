class DailyPrompt {
  final String id;
  final String prompt;
  final String category;
  final String vibeTag;
  final Map<String, String> answers;
  final Map<String, bool> reveals;
  final Map<String, Map<String, dynamic>> careChecks;

  DailyPrompt({
    required this.id,
    required this.prompt,
    required this.category,
    required this.vibeTag,
    required this.answers,
    required this.reveals,
    required this.careChecks,
  });

  factory DailyPrompt.fromJson(Map<String, dynamic> json) {
    final rawAnswers = json['answers'] as Map<String, dynamic>? ?? {};
    final rawReveals = json['reveals'] as Map<String, dynamic>? ?? {};
    final rawCare = json['careChecks'] as Map<String, dynamic>? ?? {};

    return DailyPrompt(
      id: json['id'] as String? ?? '',
      prompt: json['prompt'] as String? ?? 'What was the sweetest little thought you had about us today?',
      category: json['category'] as String? ?? 'Soft Affection',
      vibeTag: json['vibeTag'] as String? ?? 'Gentle Whisper',
      answers: rawAnswers.map((k, v) => MapEntry(k, v.toString())),
      reveals: rawReveals.map((k, v) => MapEntry(k, v == true)),
      careChecks: rawCare.map(
        (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prompt': prompt,
      'category': category,
      'vibeTag': vibeTag,
      'answers': answers,
      'reveals': reveals,
      'careChecks': careChecks,
    };
  }
}
