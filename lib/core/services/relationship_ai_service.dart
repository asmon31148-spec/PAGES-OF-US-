import 'dart:math';

class GeneratedPrompt {
  final String id;
  final String question;
  final String vibeTag;
  final String category;

  const GeneratedPrompt({
    required this.id,
    required this.question,
    required this.vibeTag,
    required this.category,
  });
}

class RelationshipStageInfo {
  final String id;
  final String label;
  final String icon;
  final String desc;

  const RelationshipStageInfo({
    required this.id,
    required this.label,
    required this.icon,
    required this.desc,
  });
}

class MoodVibeInfo {
  final String id;
  final String label;
  final String icon;
  final String desc;

  const MoodVibeInfo({
    required this.id,
    required this.label,
    required this.icon,
    required this.desc,
  });
}

class RelationshipAiService {
  static const List<RelationshipStageInfo> stages = [
    RelationshipStageInfo(
      id: 'deep',
      label: 'Deeply In Love',
      icon: '🌿',
      desc: 'Vulnerable, intimate & inseparable',
    ),
    RelationshipStageInfo(
      id: 'new_sparks',
      label: 'Sweet Sparks',
      icon: '✨',
      desc: 'First butterflies & early chapters',
    ),
    RelationshipStageInfo(
      id: 'long_distance',
      label: 'Long Distance',
      icon: '✈️',
      desc: 'Miles apart, counting days',
    ),
    RelationshipStageInfo(
      id: 'years',
      label: 'Years Together',
      icon: '☕',
      desc: 'Warm familiar rhythm & roots',
    ),
    RelationshipStageInfo(
      id: 'soft_reconnect',
      label: 'Soft Reconnect',
      icon: '🕯️',
      desc: 'Gentle warmth & quiet ease',
    ),
  ];

  static const List<MoodVibeInfo> moods = [
    MoodVibeInfo(
      id: 'vulnerable',
      label: 'Vulnerable',
      icon: '🕯️',
      desc: 'Raw feelings & quiet confessions',
    ),
    MoodVibeInfo(
      id: 'playful',
      label: 'Playful',
      icon: '☀️',
      desc: 'Inside jokes & playful banter',
    ),
    MoodVibeInfo(
      id: 'nostalgic',
      label: 'Nostalgic',
      icon: '🌙',
      desc: 'First times & memory lane',
    ),
    MoodVibeInfo(
      id: 'philosophical',
      label: 'Deep Thoughts',
      icon: '🌌',
      desc: 'Life, dreams & future',
    ),
    MoodVibeInfo(
      id: 'comforting',
      label: 'Comforting',
      icon: '🌧️',
      desc: 'Soft reassurance & peace',
    ),
  ];

  static const Map<String, Map<String, List<String>>> promptBank = {
    'vulnerable': {
      'new_sparks': [
        'What is something you were nervous to tell me when we first met?',
        'When was the exact moment you realized you felt safe with me?',
        'What is an unspoken insecurity you carry that you wish I understood better?',
        'What is a compliment you secretly crave to hear more often?'
      ],
      'deep': [
        'What is a fear you rarely say out loud, even to yourself?',
        'In what way has loving you changed how I look at my own flaws?',
        'What is a private thought you had about us recently that you haven\'t shared?',
        'What is a part of your heart you feel only I have ever seen?'
      ],
      'long_distance': [
        'What part of our days apart hurts the most quietly?',
        'When do you feel my presence the strongest, even across the distance?',
        'What is the first ordinary thing you want to do the second we are in the same room?',
        'What song makes you miss holding my hand the most?'
      ],
      'years': [
        'How have we evolved as people that you are quietly proud of?',
        'What is something we used to do in our early days that you miss?',
        'What is a way I make you feel loved that I might not even realize I do?',
        'What has been our most beautiful unspoken understanding?'
      ],
      'soft_reconnect': [
        'What is one small thing I could do this week that would make your shoulders drop?',
        'What is something gentle you need right now that you haven\'t asked for?',
        'What part of us feels like home to you, no matter how chaotic life gets?',
        'Can you remind me of a moment we felt totally in sync?'
      ],
    },
    'playful': {
      'new_sparks': [
        'If we were forced into a crime duo, what would our absurd specialty be?',
        'What is the weirdest first impression you had of me that turned out wrong?',
        'If you had to describe my laugh using an animal or sound effect, what is it?',
        'What is something silly you did just to impress me early on?'
      ],
      'deep': [
        'What is an inside joke between us that would sound completely unhinged to strangers?',
        'If we traded lives for 24 hours, what is the first thing you would do?',
        'What is my silliest habit that you secretly find endearing?',
        'Which one of our hypothetical couple reality shows would get cancelled first?'
      ],
      'long_distance': [
        'If teleportation existed for 5 minutes, what would we do before the timer ran out?',
        'What is the most ridiculous thing you did recently that you wish I was there to see?',
        'Rate our late-night phone call sanity on a scale from 1 to completely delirious.',
        'What snack are we fighting over the moment we meet?'
      ],
      'years': [
        'What is a silly habit we picked up from each other that we can\'t unlearn now?',
        'Which one of us would survive longer in a mild apocalypse and why?',
        'If we had a joint podcast with zero listeners, what would we argue about?',
        'What is the funniest thing we ever disagreed on?'
      ],
      'soft_reconnect': [
        'What is a tiny adventure we can take this weekend with zero plans and no pressure?',
        'What is the funniest thing that happened to us that still makes you smile?',
        'If we could only eat one comfort meal together for a week, what are we ordering?',
        'What silly face of mine always makes you break character?'
      ],
    },
    'nostalgic': {
      'new_sparks': [
        'What memory of our first couple of dates plays back the clearest in your head?',
        'What song instantly takes you back to the day we started talking?',
        'What is a detail you noticed about me on day one that I thought went unnoticed?',
        'What was the exact message from me that gave you the biggest butterflies?'
      ],
      'deep': [
        'What is a memory of us where we had no money or plans, but it was still perfect?',
        'Look back at who we were a year ago. What would that version think of us now?',
        'What is a quiet ordinary evening we shared that lives rent-free in your mind?',
        'What trip or late-night drive together do you replay the most?'
      ],
      'long_distance': [
        'What is your favorite memory of us saying hello at the airport or station?',
        'What scent or sensation reminds you immediately of the last time we hugged?',
        'Which trip of ours do you catch yourself daydreaming about the most?',
        'What was the hardest goodbye we said that made you love me more?'
      ],
      'years': [
        'What was the hardest thing we navigated together that made us unbreakable?',
        'Remember our first shared place or space? What do you miss about that era?',
        'What is a promise we made long ago that we quietly kept?',
        'What was the sweetest surprise you ever pulled off for me?'
      ],
      'soft_reconnect': [
        'What was the first moment you looked at me and thought, "This is my person"?',
        'Remember that time we couldn\'t stop laughing until our ribs hurt? What was that about?',
        'What old photo of us do you look at whenever you need comfort?',
        'What is a tradition we started by pure accident that you love?'
      ],
    },
    'philosophical': {
      'new_sparks': [
        'Do you think people cross paths by accident, or do we pull each other in?',
        'What does "home" mean to you—is it a place, a routine, or a person?',
        'What is a lesson about human connection you learned the hard way?',
        'What dream do you carry that you rarely tell people about?'
      ],
      'deep': [
        'How do you think our relationship will shape the people we grow into in 10 years?',
        'What is the difference between loving someone and choosing someone every day?',
        'If our lives together were a book, what would this current chapter be named?',
        'What is something you understand about love now that you didn\'t before us?'
      ],
      'long_distance': [
        'How has the distance deepened the emotional parts of our bond?',
        'What has waiting taught you about patience and devotion?',
        'What is a quiet truth about our connection that physical distance can never touch?',
        'When you imagine our future together with no miles between us, what does a normal Tuesday look like?'
      ],
      'years': [
        'What has surprised you most about growing together over the years?',
        'How have our definitions of happiness matured since we met?',
        'What part of our life together would you never change for anything in the world?',
        'What legacy of kindness and love do you want us to build?'
      ],
      'soft_reconnect': [
        'What is a belief about life you held firmly that you\'ve softened on lately?',
        'When the world feels too overwhelming, what helps you find your inner center?',
        'What is one thing you want more of in our daily rhythm?',
        'What is a grace you want to give yourself this week?'
      ],
    },
    'comforting': {
      'new_sparks': [
        'What is your favorite way to unwind when the world feels too loud?',
        'How can I make you feel supported right now without trying to fix anything?',
        'What makes you feel the most calm and cared for after a long day?',
        'What is a sweet ritual you want us to start?'
      ],
      'deep': [
        'What is a quiet comfort about us you never take for granted?',
        'On your hardest days, what is the one thing you need from me most?',
        'What room or spot in our world makes you breathe the easiest?',
        'When you rest your head on my chest, what feeling washes over you?'
      ],
      'long_distance': [
        'What comfort item or hoodie of mine brings you the most warmth when I\'m away?',
        'What voice note or message from me do you re-read when you miss me?',
        'Close your eyes: imagine I\'m sitting right beside you right now. What do we say?',
        'What is our sweetest sleep call memory?'
      ],
      'years': [
        'What is the simplest ritual we share (morning coffee, late walk) that you cherish?',
        'What gives you peace when you think about our future together?',
        'Thank you for being my anchor. What has made you feel anchored lately?',
        'What is a quiet gesture of mine that never fails to comfort you?'
      ],
      'soft_reconnect': [
        'Take a deep breath right now. What tension can you let go of today?',
        'I am right here with you. What is one gentle truth you need to hear today?',
        'No expectations tonight: what would bring your heart the most calm?',
        'Can I just hold you in quiet comfort without having to say a word?'
      ],
    },
  };

  static const List<Map<String, String>> curatedDeck = [
    {
      'category': 'vulnerable',
      'vibeTag': 'VULNERABLE · 🕯️',
      'question': 'When was the exact moment you realized you felt safe with me?',
    },
    {
      'category': 'vulnerable',
      'vibeTag': 'VULNERABLE · 🕯️',
      'question': 'What is an unspoken insecurity you carry that you wish I understood better?',
    },
    {
      'category': 'vulnerable',
      'vibeTag': 'VULNERABLE · 🕯️',
      'question': 'What is a private thought you had about us recently that you haven’t said out loud?',
    },
    {
      'category': 'playful',
      'vibeTag': 'PLAYFUL · ☀️',
      'question': 'If we were forced into a crime duo, what would our absurd specialty be?',
    },
    {
      'category': 'playful',
      'vibeTag': 'PLAYFUL · ☀️',
      'question': 'What is my silliest habit that you secretly find endearing?',
    },
    {
      'category': 'playful',
      'vibeTag': 'PLAYFUL · ☀️',
      'question': 'What is an inside joke between us that would sound completely unhinged to strangers?',
    },
    {
      'category': 'nostalgic',
      'vibeTag': 'NOSTALGIC · 🌙',
      'question': 'What memory of our first few dates plays back the clearest in your head?',
    },
    {
      'category': 'nostalgic',
      'vibeTag': 'NOSTALGIC · 🌙',
      'question': 'What song instantly takes you back to the exact day we started talking?',
    },
    {
      'category': 'nostalgic',
      'vibeTag': 'NOSTALGIC · 🌙',
      'question': 'What is a quiet ordinary evening we shared that lives rent-free in your mind?',
    },
    {
      'category': 'philosophical',
      'vibeTag': 'DEEP · 🌌',
      'question': 'How do you think our relationship has shaped the person you are becoming?',
    },
    {
      'category': 'philosophical',
      'vibeTag': 'DEEP · 🌌',
      'question': 'If our journey together were a book, what would this current chapter be named?',
    },
    {
      'category': 'philosophical',
      'vibeTag': 'DEEP · 🌌',
      'question': 'What does "home" mean to you—is it a place, a routine, or a person?',
    },
    {
      'category': 'comforting',
      'vibeTag': 'COMFORTING · 🌧️',
      'question': 'What is the simplest ritual we share (morning coffee, late walk) that you cherish?',
    },
    {
      'category': 'comforting',
      'vibeTag': 'COMFORTING · 🌧️',
      'question': 'On your hardest days, what is the one quiet thing you need from me most?',
    },
    {
      'category': 'comforting',
      'vibeTag': 'COMFORTING · 🌧️',
      'question': 'Take a deep breath right now. What is one gentle truth you need to hear today?',
    },
  ];

  static const List<String> quickStarters = [
    'What memory of us lives rent-free in your mind?',
    'What was going through your mind the first time we held hands?',
    'If we had an entire day with no alarms or phones, what are we doing?',
    'What is a tiny detail about me that you notice when I think no one is looking?',
    'What is something I did recently that gave you quiet butterflies?',
    'If you could freeze one moment from our past together forever, which one is it?',
    'What is a dream about our future that always brings a smile to your face?',
    'What is something you never thought you would share with anyone, but told me?',
  ];

  /// Generates 3 intimate relationship inquiry questions
  static List<GeneratedPrompt> generatePrompts({
    required String stage,
    required String mood,
    String? customTopic,
    String? partnerNickname,
  }) {
    final effectiveStage = promptBank[mood]?.containsKey(stage) == true ? stage : 'deep';
    final stagePool = promptBank[mood]?[effectiveStage] ?? [];
    final fallbackPool = promptBank['vulnerable']?['deep'] ?? [];

    final candidatePool = List<String>.from(stagePool)..addAll(fallbackPool);
    final random = Random();
    candidatePool.shuffle(random);

    final synthesized = <String>[];
    if (customTopic != null && customTopic.trim().isNotEmpty) {
      final topic = customTopic.trim();
      final pName = partnerNickname?.isNotEmpty == true ? partnerNickname! : 'your partner';
      synthesized.add('When you think about "$topic" in our story, what is the first feeling or memory that comes to you?');
      synthesized.add('What is something about "$topic" you\'ve always wanted to ask $pName?');
    }

    final selected = <String>[];
    selected.addAll(synthesized);
    for (final q in candidatePool) {
      if (!selected.contains(q)) {
        selected.add(q);
      }
      if (selected.length >= 3) break;
    }

    return selected.map((q) {
      return GeneratedPrompt(
        id: 'ai_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(1000)}',
        question: q,
        vibeTag: '${mood.toUpperCase()} · AI TAILORED',
        category: mood,
      );
    }).toList();
  }
}
