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
    final rawAnswers = json['answers'] is Map ? (json['answers'] as Map) : {};
    final rawReveals = json['reveals'] is Map ? (json['reveals'] as Map) : {};
    final rawCare = json['careChecks'] is Map ? (json['careChecks'] as Map) : {};

    final parsedAnswers = <String, String>{};
    rawAnswers.forEach((k, v) {
      if (k != null && v != null) {
        parsedAnswers[k.toString()] = v.toString();
      }
    });

    final parsedReveals = <String, bool>{};
    rawReveals.forEach((k, v) {
      if (k != null) {
        parsedReveals[k.toString()] = v == true;
      }
    });

    final parsedCare = <String, Map<String, dynamic>>{};
    rawCare.forEach((k, v) {
      if (k != null && v is Map) {
        try {
          parsedCare[k.toString()] = Map<String, dynamic>.from(v);
        } catch (_) {}
      }
    });

    return DailyPrompt(
      id: json['id']?.toString() ?? '',
      prompt: json['prompt']?.toString() ?? json['question']?.toString() ?? 'What was the sweetest little thought you had about us today?',
      category: json['category']?.toString() ?? 'Soft Affection',
      vibeTag: json['vibeTag']?.toString() ?? 'Gentle Whisper',
      answers: parsedAnswers,
      reveals: parsedReveals,
      careChecks: parsedCare,
      createdAt: json['createdAt']?.toString(),
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
    final rawAnswers = json['answers'] is Map ? (json['answers'] as Map) : {};
    final parsedAnswers = <String, String>{};
    rawAnswers.forEach((k, v) {
      if (k != null && v != null) {
        parsedAnswers[k.toString()] = v.toString();
      }
    });

    return PromptHistoryItem(
      id: json['id']?.toString() ?? '',
      question: json['question']?.toString() ?? json['prompt']?.toString() ?? '',
      vibeTag: json['vibeTag']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      answers: parsedAnswers,
      date: json['date']?.toString() ?? json['createdAt']?.toString() ?? '',
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
