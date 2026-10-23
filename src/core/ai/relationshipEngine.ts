import { PromptGenerationRequest, GeneratedPrompt, MoodVibe, RelationshipStage } from './types'

// Curated high-authenticity relationship prompts by mood
const PROMPT_BANK: Record<MoodVibe, Record<RelationshipStage, string[]>> = {
  vulnerable: {
    new: [
      "What is something you were nervous to tell me when we first met?",
      "When was the exact moment you realized you felt safe with me?",
      "What is an unspoken insecurity you carry that you wish I understood better?"
    ],
    deep: [
      "What is a fear you rarely say out loud, even to yourself?",
      "In what way has loving you changed how I look at my own flaws?",
      "What is a private thought you had about us recently that you haven't shared?"
    ],
    long_distance: [
      "What part of our days apart hurts the most quietly?",
      "When do you feel my presence the strongest, even across the distance?",
      "What is the first ordinary thing you want to do the second we are in the same room?"
    ],
    years: [
      "How have we evolved as people that you are quietly proud of?",
      "What is something we used to do in our early days that you miss?",
      "What is a way I make you feel loved that I might not even realize I do?"
    ],
    soft_reconnect: [
      "What is one small thing I could do this week that would make your shoulders drop?",
      "What is something gentle you need right now that you haven't asked for?",
      "What part of us feels like home to you, no matter how chaotic life gets?"
    ]
  },
  playful: {
    new: [
      "If we were forced into a crime duo, what would our absurd specialty be?",
      "What is the weirdest first impression you had of me that turned out wrong?",
      "If you had to describe my laugh using an animal or sound effect, what is it?"
    ],
    deep: [
      "What is an inside joke between us that would sound completely unhinged to strangers?",
      "If we traded lives for 24 hours, what is the first thing you would do?",
      "What is my silliest habit that you secretly find endearing?"
    ],
    long_distance: [
      "If teleportation existed for 5 minutes, what would we do before the timer ran out?",
      "What is the most ridiculous thing you did recently that you wish I was there to see?",
      "Rate our late-night phone call sanity on a scale from 1 to completely delirious."
    ],
    years: [
      "What is a silly habit we picked up from each other that we can't unlearn now?",
      "Which one of us would survive longer in a mild apocalypse and why?",
      "If we had a joint podcast with zero listeners, what would we argue about?"
    ],
    soft_reconnect: [
      "What is a tiny adventure we can take this weekend with zero plans and no pressure?",
      "What is the funniest thing that happened to us that still makes you smile?",
      "If we could only eat one comfort meal together for a week, what are we ordering?"
    ]
  },
  nostalgic: {
    new: [
      "What memory of our first couple of dates plays back the clearest in your head?",
      "What song instantly takes you back to the day we started talking?",
      "What is a detail you noticed about me on day one that I thought went unnoticed?"
    ],
    deep: [
      "What is a memory of us where we had no money or plans, but it was still perfect?",
      "Look back at who we were a year ago. What would that version think of us now?",
      "What is a quiet ordinary evening we shared that lives rent-free in your mind?"
    ],
    long_distance: [
      "What is your favorite memory of us saying hello at the airport or station?",
      "What scent or sensation reminds you immediately of the last time we hugged?",
      "Which trip of ours do you catch yourself daydreaming about the most?"
    ],
    years: [
      "What was the hardest thing we navigated together that made us unbreakable?",
      "Remember our first shared place or space? What do you miss about that era?",
      "What is a promise we made long ago that we quietly kept?"
    ],
    soft_reconnect: [
      "What was the first moment you looked at me and thought, 'This is my person'?",
      "Remember that time we couldn't stop laughing until our ribs hurt? What was that about?",
      "What old photo of us do you look at whenever you need comfort?"
    ]
  },
  philosophical: {
    new: [
      "Do you think people cross paths by accident, or do we pull each other in?",
      "What does 'home' mean to you—is it a place, a routine, or a person?",
      "What is a lesson about human connection you learned the hard way?"
    ],
    deep: [
      "How do you think our relationship will shape the people we grow into in 10 years?",
      "What is the difference between loving someone and choosing someone every day?",
      "If our lives together were a book, what would this current chapter be named?"
    ],
    long_distance: [
      "How has distance tested or deepened our understanding of trust?",
      "Do you think distance makes the ordinary days sweeter when you finally have them?",
      "What is something you learned about yourself by being away from me?"
    ],
    years: [
      "In what ways have we softened each other's sharpest edges over time?",
      "How do we keep finding new things to discover about each other after all this time?",
      "What is the legacy of the life we are quietly building together?"
    ],
    soft_reconnect: [
      "What is something life has been trying to teach you lately?",
      "When everything feels overwhelming, what grounds your mind?",
      "What does peace look like for us in this season?"
    ]
  },
  comforting: {
    new: [
      "What made today feel lighter, even for a moment?",
      "What is your favorite way to unwind when the world feels too loud?",
      "How can I make you feel supported right now without trying to fix anything?"
    ],
    deep: [
      "What is a quiet comfort about us you never take for granted?",
      "On your hardest days, what is the one thing you need from me most?",
      "What room or spot in our world makes you breathe the easiest?"
    ],
    long_distance: [
      "What comfort item or hoodie of mine brings you the most warmth when I'm away?",
      "What voice note or message from me do you re-read when you miss me?",
      "Close your eyes: imagine I'm sitting right beside you right now. What do we say?"
    ],
    years: [
      "What is the simplest ritual we share (morning coffee, late walk) that you cherish?",
      "What gives you peace when you think about our future together?",
      "Thank you for being my anchor. What has made you feel anchored lately?"
    ],
    soft_reconnect: [
      "Take a deep breath right now. What tension can you let go of today?",
      "I am right here with you. What is one gentle truth you need to hear today?",
      "No expectations tonight: what would bring your heart the most calm?"
    ]
  }
}

/**
 * Generate relationship prompts based on mood, stage, and couple context.
 * Uses intelligent contextual synthesis with fallback to Gemini API if configured.
 */
export async function generateRelationshipPrompts(
  req: PromptGenerationRequest
): Promise<GeneratedPrompt[]> {
  const { userNickname, partnerNickname, relationshipStage, mood, customTopic } = req

  // 1. Check if Gemini API key exists in environment
  const geminiApiKey = import.meta.env.VITE_GEMINI_API_KEY
  if (geminiApiKey) {
    try {
      const promptText = `You are an intimate, emotionally intelligent inquiry engine for a private couples app called "Pages of Us".
The couple's names are "${userNickname}" and "${partnerNickname}".
Their relationship dynamic is: "${relationshipStage}".
Their desired mood/vibe is: "${mood}".
${customTopic ? `Specific focus/topic: "${customTopic}"` : ''}

Generate exactly 3 deeply thoughtful, poetic, and nuanced questions for them to play in a "Blind Reveal" game (where both partners answer blindly before seeing each other's response).
Guidelines:
- Avoid generic romance clichés (no "what is love", no cheesy quotes).
- Focus on genuine curiosity, shared memories, unspoken vulnerability, or playful inside dynamics.
- Format output as clean JSON array of strings: ["question 1", "question 2", "question 3"]`

      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiApiKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{ parts: [{ text: promptText }] }],
            generationConfig: { responseMimeType: 'application/json', temperature: 0.8 }
          })
        }
      )

      if (response.ok) {
        const data = await response.json()
        const text = data.candidates?.[0]?.content?.parts?.[0]?.text
        if (text) {
          const parsed: string[] = JSON.parse(text)
          if (Array.isArray(parsed) && parsed.length > 0) {
            return parsed.map((q, idx) => ({
              id: `ai-gemini-${Date.now()}-${idx}`,
              question: q,
              vibeTag: `${mood.toUpperCase()} · AI TAILORED`,
              category: mood
            }))
          }
        }
      }
    } catch (err) {
      console.warn('Gemini API call failed, falling back to algorithmic engine:', err)
    }
  }

  // 2. High-Authenticity Algorithmic Synthesis
  // Pulls from our specialized bank and adapts to the couple
  const stagePool = PROMPT_BANK[mood]?.[relationshipStage] || []
  const moodPool = Object.values(PROMPT_BANK[mood] || {}).flat()
  const fallbackPool = Object.values(PROMPT_BANK['vulnerable']).flat()

  // Build candidate pool and randomize so every generation produces fresh prompts
  const rawPool = Array.from(new Set([...stagePool, ...moodPool, ...fallbackPool]))
  const shuffledPool = [...rawPool].sort(() => Math.random() - 0.5)

  // If user provided a custom topic, dynamically synthesize a prompt
  const synthesized: string[] = []
  if (customTopic?.trim()) {
    synthesized.push(
      `When you think about "${customTopic.trim()}" in our story, what is the first feeling or memory that comes to you?`,
      `What is something about "${customTopic.trim()}" you've always wanted to ask ${partnerNickname}?`
    )
  }

  // Pick 3 diverse questions from randomized pool
  const selectedQuestions = [...synthesized, ...shuffledPool].slice(0, 3)

  return selectedQuestions.map((q, idx) => ({
    id: `alg-${mood}-${relationshipStage}-${idx}-${Date.now()}`,
    question: q,
    vibeTag: `${mood.toUpperCase()} · ${relationshipStage.toUpperCase()}`,
    category: mood
  }))
}
