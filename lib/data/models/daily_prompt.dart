class DailyPrompt {
  final String id;
  final String prompt;
  final String category;
  final String vibeTag;
  final Map<String, String> answers;
  final Map<String, bool> reveals;
  final Map<String, Map<String, dynamic>> careChecks;
  final String? createdAt;
  final bool isCustom;

  DailyPrompt({
    required this.id,
    required this.prompt,
    required this.category,
    required this.vibeTag,
    required this.answers,
    required this.reveals,
    required this.careChecks,
    this.createdAt,
    this.isCustom = false,
  });

  factory DailyPrompt.fromJson(Map<String, dynamic> json) {
    final rawAnswers = json['answers'] as Map<String, dynamic>? ?? {};
    final rawReveals = json['reveals'] as Map<String, dynamic>? ?? {};
    final rawCare = json['careChecks'] as Map<String, dynamic>? ?? {};

    return DailyPrompt(
      id: json['id'] as String? ?? '',
      prompt: json['prompt'] as String? ?? json['question'] as String? ?? 'What was the sweetest little thought you had about us today?',
      category: json['category'] as String? ?? 'Soft Affection',
      vibeTag: json['vibeTag'] as String? ?? 'Gentle Whisper',
      answers: rawAnswers.map((k, v) => MapEntry(k, v.toString())),
      reveals: rawReveals.map((k, v) => MapEntry(k, v == true)),
      careChecks: rawCare.map(
        (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
      ),
      createdAt: json['createdAt'] as String?,
      isCustom: json['isCustom'] == true,
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
      'createdAt': createdAt,
      'isCustom': isCustom,
    };
  }
}

class PromptHistoryItem {
  final String id;
  final String question;
  final String vibeTag;
  final String category;
  final Map<String, String> answers;
  final String date;

  PromptHistoryItem({
    required this.id,
    required this.question,
    required this.vibeTag,
    required this.category,
    required this.answers,
    required this.date,
  });

  factory PromptHistoryItem.fromJson(Map<String, dynamic> json) {
    final rawAnswers = json['answers'] as Map<String, dynamic>? ?? {};
    return PromptHistoryItem(
      id: json['id'] as String? ?? '',
      question: json['question'] as String? ?? json['prompt'] as String? ?? '',
      vibeTag: json['vibeTag'] as String? ?? '',
      category: json['category'] as String? ?? '',
      answers: rawAnswers.map((k, v) => MapEntry(k, v.toString())),
      date: json['date'] as String? ?? json['createdAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'vibeTag': vibeTag,
    'category': category,
    'answers': answers,
    'date': date,
  };
}
