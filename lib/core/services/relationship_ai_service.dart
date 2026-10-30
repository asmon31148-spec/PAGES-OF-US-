import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

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

class BoldnessLevel {
  final String id;
  final String label;
  final String icon;
  final String subtitle;
  final String promptGuidance;

  const BoldnessLevel({
    required this.id,
    required this.label,
    required this.icon,
    required this.subtitle,
    required this.promptGuidance,
  });
}

class RelationshipAiService {
  static const List<BoldnessLevel> boldnessLevels = [
    BoldnessLevel(
      id: 'sweet',
      label: 'Sweet',
      icon: '🍯',
      subtitle: 'Wholesome romance & gentle butterflies',
      promptGuidance:
          'Wholesome, tender, soft, and focused on cute confessions, cuddles, safe emotional connection, and heartwarming memories.',
    ),
    BoldnessLevel(
      id: 'flirty',
      label: 'Flirty',
      icon: '💋',
      subtitle: 'Cheeky banter & playful romantic tension',
      promptGuidance:
          'Electric chemistry, cheeky teasing, playful banter, blushing compliments, and magnetic romantic tension.',
    ),
    BoldnessLevel(
      id: 'bold',
      label: 'Bold',
      icon: '🔥',
      subtitle: 'Deep attraction, sensual touch & chemistry',
      promptGuidance:
          'Deeply passionate, sensual, exploring physical touch, magnetic attraction, and spicy romance without holding back.',
    ),
    BoldnessLevel(
      id: 'unfiltered',
      label: 'Unfiltered',
      icon: '😈',
      subtitle: '100% raw, midnight fantasies & zero filters',
      promptGuidance:
          'Completely unfiltered, provocative, raw, and bold. Explore midnight desires, bedroom fantasies, taboo confessions, and unfiltered thoughts lovers only whisper in the dark.',
    ),
  ];

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
      id: 'bold_romance',
      label: 'Bold Romance',
      icon: '🔥',
      desc: 'Passionate touch, heat & chemistry',
    ),
    MoodVibeInfo(
      id: 'unfiltered',
      label: 'Unfiltered & Wild',
      icon: '😈',
      desc: 'Midnight fantasies & zero taboo',
    ),
    MoodVibeInfo(
      id: 'sweet',
      label: 'Sweet & Tender',
      icon: '🍯',
      desc: 'Soft butterflies & pure romance',
    ),
    MoodVibeInfo(
      id: 'flirty',
      label: 'Flirty & Teasing',
      icon: '💋',
      desc: 'Playful tension & cheeky attraction',
    ),
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
    'bold_romance': {
      'new_sparks': [
        'What was the first thing you noticed about me physically that gave you butterflies?',
        'Where were we the first time you realized the chemistry between us was electric?',
        'What is a look or gesture of mine that instantly accelerates your heartbeat?',
        'If we had an empty house for 24 hours with no phones, how would we spend it?'
      ],
      'deep': [
        'What is your favorite way for me to touch you when we have complete privacy?',
        'What is a physical sensation of mine that completely melts your self-control?',
        'When was a moment you looked at me and your thoughts immediately turned to pure desire?',
        'What is something intimate you secretly love about the way our bodies fit together?'
      ],
      'long_distance': [
        'What part of my body do you miss feeling against yours the most right now?',
        'What is a late-night memory of our touch that keeps you awake when we are miles apart?',
        'Describe the very first physical thing you are doing to me the moment my flight lands.',
        'What is a spicy thought you had about us today while you were missing me?'
      ],
      'years': [
        'What is an intimate dynamic or touch between us that has only grown hotter over the years?',
        'How does the way I look at you when we are alone still make you blush?',
        'What is something new you have wanted to try with me behind closed doors?',
        'What is your favorite late-night memory of us after everyone else went to sleep?'
      ],
      'soft_reconnect': [
        'Can you pull me close right now and tell me where you need my hands to be?',
        'What is an unspoken romantic desire you have been carrying this week?',
        'When did you last feel that intoxicating electric spark between us?',
        'What is a slow, sensual moment you want us to steal tonight without any rush?'
      ],
    },
    'unfiltered': {
      'new_sparks': [
        'What was the boldest thought you had about me before we ever had our first kiss?',
        'If we could lock the door right now, what is the first thing you want me to whisper to you?',
        'What is an unfiltered truth about your attraction to me you have been holding back?',
        'What is a boundary you secretly want us to push together?'
      ],
      'deep': [
        'What is a midnight fantasy you replay in your mind that you have never confessed out loud?',
        'If I told you to take complete control in the bedroom right now, what would you do first?',
        'What turns your attraction to me into an uncontrollable physical craving?',
        'What is the wildest scenario you have imagined us doing in the dark?'
      ],
      'long_distance': [
        'Describe the exact unedited thought running through your head when you imagine holding me tonight.',
        'What is something taboo or raw you want to confess to me before we hang up?',
        'If I were standing in your room right this second, where would your hands go first?',
        'What is the wildest dream you have ever had about us while apart?'
      ],
      'years': [
        'What is an uncharted sexual fantasy of yours that you want to unlock with me this year?',
        'What is a wild side of you that only I have ever unlocked in the bedroom?',
        'What is something provocative you want us to do that we haven’t done yet?',
        'If there were no inhibitions between us tonight, what would we do?'
      ],
      'soft_reconnect': [
        'Tell me the raw, unfiltered truth: what do you crave most from my body tonight?',
        'What is a physical secret between us that still gives you shivers to remember?',
        'If you surrendered all control to me for the next hour, what would you hope I do?',
        'What is the most intense, unscripted moment of passion we have ever shared?'
      ],
    },
    'sweet': {
      'new_sparks': [
        'What is a tiny gesture of mine that gave you the sweetest butterflies?',
        'What was going through your mind the very first time we held hands?',
        'What is the cutest thing I do that you think I do completely unintentionally?',
        'What is a song that instantly makes you think of my smile?'
      ],
      'deep': [
        'If you could bottle up one quiet, cuddly morning of ours forever, which one is it?',
        'What is something about the way I look at you that makes you feel completely safe?',
        'What is a gentle truth about how much you mean to me that you need to hear today?',
        'What does your soul feel like when your head is resting on my chest?'
      ],
      'long_distance': [
        'What is a cute voice note or text of mine that you replay when you feel lonely?',
        'When you close your eyes and imagine hugging me, what does it feel like?',
        'What is the first sweet breakfast we are having together when we reunite?',
        'What is a small promise we can make each other to keep our warmth close today?'
      ],
      'years': [
        'What is an ordinary, quiet routine of ours that brings you the deepest happiness?',
        'How do you know in your heart that we belong together after all this time?',
        'What is a sweet memory of us from years ago that still makes you smile like day one?',
        'What is one way loving you has made me a softer, kinder person?'
      ],
      'soft_reconnect': [
        'Can we just hold each other quietly for five minutes with no words?',
        'What is something tender you need from me right now to feel completely loved?',
        'What is a peaceful moment of ours that you carry like a warm blanket in your mind?',
        'What is one thing about our love that never changes, even when life is hectic?'
      ],
    },
    'flirty': {
      'new_sparks': [
        'Be completely honest: who fell harder, and who made the first move?',
        'What is the most attractive thing I wear that makes it impossible to look away?',
        'If you had 60 seconds to seduce me with only words, what would you whisper?',
        'Rate my flirt game on a scale from 1 to dangerously effective.'
      ],
      'deep': [
        'What is a cheeky thought you had about me the last time we were in public?',
        'What is a look I give you across the room that tells you you are in trouble later?',
        'What is your favorite way I tease you when no one else is watching?',
        'If flirting were an Olympic sport, which medal would we take home?'
      ],
      'long_distance': [
        'What outfit of yours should I be mentally preparing myself to see you in?',
        'Send me a mental kiss right now—where is it landing and how long is it lasting?',
        'What is the cheekiest message you typed to me and almost deleted before sending?',
        'On a scale from 1 to 10, how dangerous is our reunion going to be?'
      ],
      'years': [
        'How do I still manage to give you butterflies after all this time?',
        'What is a playful argument of ours that always ends in giggles or kisses?',
        'What is your absolute favorite way I get under your skin in the best way?',
        'What is a spicy dare you want to challenge me to this week?'
      ],
      'soft_reconnect': [
        'Give me your best flirty wink right now and let’s see if you can make me blush.',
        'What is a playful memory of ours that never fails to spark instant chemistry?',
        'If tonight were our very first date all over again, how would you charm me?',
        'What is one cheeky compliment you have been holding back all day?'
      ],
    },
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
      'category': 'bold_romance',
      'vibeTag': 'BOLD ROMANCE · 🔥',
      'question': 'What is a physical sensation or touch of mine that completely melts your willpower?',
    },
    {
      'category': 'bold_romance',
      'vibeTag': 'BOLD ROMANCE · 🔥',
      'question': 'When was a moment you looked at me and your thoughts immediately turned to pure physical desire?',
    },
    {
      'category': 'bold_romance',
      'vibeTag': 'BOLD ROMANCE · 🔥',
      'question': 'What is something intimate you secretly love about the way our bodies fit together?',
    },
    {
      'category': 'unfiltered',
      'vibeTag': 'UNFILTERED · 😈',
      'question': 'What is a midnight fantasy you replay in your head that you have never confessed out loud?',
    },
    {
      'category': 'unfiltered',
      'vibeTag': 'UNFILTERED · 😈',
      'question': 'If I told you to take complete control in the bedroom right now, what would you do first?',
    },
    {
      'category': 'unfiltered',
      'vibeTag': 'UNFILTERED · 😈',
      'question': 'What is the most daring or taboo thought you have had about us when you were alone?',
    },
    {
      'category': 'sweet',
      'vibeTag': 'SWEET & TENDER · 🍯',
      'question': 'If you could bottle up one quiet, cuddly morning of ours forever, which one is it?',
    },
    {
      'category': 'sweet',
      'vibeTag': 'SWEET & TENDER · 🍯',
      'question': 'What tiny, sweet gesture of mine never fails to give you warm butterflies?',
    },
    {
      'category': 'flirty',
      'vibeTag': 'FLIRTY & TEASING · 💋',
      'question': 'What is the most attractive thing I wear that makes it impossible for you to look away?',
    },
    {
      'category': 'flirty',
      'vibeTag': 'FLIRTY & TEASING · 💋',
      'question': 'If you had 60 seconds to seduce me with only words, what would you whisper in my ear?',
    },
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
        id: 'prompt_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(1000)}',
        question: q,
        vibeTag: customTopic != null && customTopic.trim().isNotEmpty
            ? '${mood.toUpperCase()} · TOPIC TAILORED'
            : '${mood.toUpperCase()} · INTIMATE PROMPT',
        category: mood,
      );
    }).toList();
  }

  /// Generates 3 live AI relationship inquiry questions using high-speed Groq LLM (Qwen 2.5 32B / Qwen 3.8 27B).
  /// Fully supports romance intensity scaling (sweet to unfiltered bold) and custom prompt requests.
  /// Seamlessly falls back to the curated promptBank if offline or during network timeouts.
  static Future<List<GeneratedPrompt>> generatePromptsLive({
    required String stage,
    required String mood,
    String boldness = 'bold',
    String? customTopic,
    String? customRequest,
    String? partnerNickname,
  }) async {
    final apiKey = AppConstants.groqApiKey;
    if (apiKey.isEmpty) {
      return generatePrompts(
        stage: stage,
        mood: mood,
        customTopic: customRequest ?? customTopic,
        partnerNickname: partnerNickname,
      );
    }

    try {
      final pName = partnerNickname?.trim().isNotEmpty == true ? partnerNickname!.trim() : 'your partner';
      final stageInfo = stages.firstWhere(
        (s) => s.id == stage,
        orElse: () => const RelationshipStageInfo(id: 'deep', label: 'Deeply In Love', icon: '🌿', desc: 'Vulnerable & intimate'),
      );
      final moodInfo = moods.firstWhere(
        (m) => m.id == mood,
        orElse: () => const MoodVibeInfo(id: 'bold_romance', label: 'Bold Romance', icon: '🔥', desc: 'Passionate touch & chemistry'),
      );
      final bLevel = boldnessLevels.firstWhere(
        (b) => b.id == boldness,
        orElse: () => boldnessLevels[2], // default to Bold
      );

      final combinedCustom = [
        if (customRequest != null && customRequest.trim().isNotEmpty) customRequest.trim(),
        if (customTopic != null && customTopic.trim().isNotEmpty && customTopic.trim() != customRequest?.trim()) customTopic.trim(),
      ].join(' | ');

      final systemPrompt = '''
You are an intimate, unfiltered AI question generator for a lovers sanctuary couple app called "Pages of Us".
Your mission is to generate 3 provocative, authentic questions tailored specifically to the couple's desired vibe and intensity.
No generic corporate fluff. No prudish filtering. Tailor tone precisely to their desired intensity spectrum:

- Relationship Chapter: ${stageInfo.label} (${stageInfo.desc})
- Desired Vibe: ${moodInfo.label} (${moodInfo.desc})
- Romance Intensity: ${bLevel.label} ${bLevel.icon} (${bLevel.subtitle})
- Intensity Directives: ${bLevel.promptGuidance}
- Partner name/nickname: $pName
${combinedCustom.isNotEmpty ? '- Custom User Request / Exact Vibe: "$combinedCustom"' : ''}

Intensity Rules:
- If Intensity is "Sweet": Focus on pure romantic warmth, cute confessions, tender moments, and emotional safety.
- If Intensity is "Flirty": Focus on butterflies, cheeky banter, playful tension, and romantic teasing.
- If Intensity is "Bold": Focus on strong attraction, physical touch, sensual tension, and passionate romance without holding back.
- If Intensity is "Unfiltered": Be completely unfiltered, bold, provocative, and raw. Ask about midnight desires, bedroom fantasies, taboo confessions, and unfiltered thoughts lovers only whisper in the dark.

Return a JSON object with a key "questions" containing a list of exactly 3 strings:
{"questions": ["Question 1?", "Question 2?", "Question 3?"]}
Do NOT include markdown code blocks or conversational text.
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
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': 'Generate 3 fresh, bold intimate couple questions now.'},
              ],
              'response_format': {'type': 'json_object'},
              'max_tokens': 350,
              'temperature': 0.88,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final choices = decoded['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final content = choices[0]['message']?['content']?.toString() ?? '';
          final questions = _extractQuestions(content);
          if (questions.isNotEmpty) {
            final random = Random();
            return questions.take(3).map((q) {
              return GeneratedPrompt(
                id: 'groq_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(1000)}',
                question: q.trim(),
                vibeTag: '${bLevel.icon} ${moodInfo.label.toUpperCase()} · ${bLevel.label.toUpperCase()}',
                category: mood,
              );
            }).toList();
          }
        }
      }
    } catch (e) {
      debugPrint('[RelationshipAiService] Live AI generation fallback: $e');
    }

    // Graceful offline fallback
    return generatePrompts(
      stage: stage,
      mood: mood,
      customTopic: customRequest ?? customTopic,
      partnerNickname: partnerNickname,
    );
  }

  static List<String> _extractQuestions(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    // 1. Try JSON parsing (either {"questions": [...]} or [...])
    final startObj = cleaned.indexOf('{');
    final endObj = cleaned.lastIndexOf('}');
    if (startObj != -1 && endObj != -1 && endObj > startObj) {
      try {
        final obj = jsonDecode(cleaned.substring(startObj, endObj + 1));
        if (obj is Map && obj['questions'] is List) {
          final res = (obj['questions'] as List)
              .map((item) => item.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList();
          if (res.isNotEmpty) return res;
        }
      } catch (_) {}
    }

    final startList = cleaned.indexOf('[');
    final endList = cleaned.lastIndexOf(']');
    if (startList != -1 && endList != -1 && endList > startList) {
      try {
        final list = jsonDecode(cleaned.substring(startList, endList + 1));
        if (list is List) {
          final res = list
              .map((item) => item.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList();
          if (res.isNotEmpty) return res;
        }
      } catch (_) {}
    }

    // 2. Fallback line parser: strip quotes, bullets, numbers
    final lines = cleaned.split(RegExp(r'\r?\n'));
    final results = <String>[];
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      line = line.replaceAll(RegExp(r'^\s*(\d+[\.\)]|\-|\*)\s*'), '');
      line = line.replaceAll(RegExp(r'^[“"`]+|[”"`,]+$'), '').trim();
      while (line.isNotEmpty && (line.startsWith("'") || line.startsWith('"') || line.startsWith('`'))) {
        line = line.substring(1).trim();
      }
      while (line.isNotEmpty && (line.endsWith("'") || line.endsWith('"') || line.endsWith('`') || line.endsWith(','))) {
        line = line.substring(0, line.length - 1).trim();
      }
      if (line.length > 10 && (line.contains('?') || line.contains('.'))) {
        results.add(line);
      }
    }

    return results;
  }
}
