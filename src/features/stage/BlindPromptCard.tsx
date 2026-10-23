import React, { useState, useEffect } from 'react'
import { useAuth } from '@/core/auth'
import { useToast } from '@/core/toast'
import { realtimeBridge } from '@/core/realtime'
import { getSupabaseClient } from '@/core/storage/supabase'
import { getFirebaseDb } from '@/core/storage/firebase'
import { doc, setDoc, onSnapshot } from 'firebase/firestore'
import confetti from 'canvas-confetti'
import {
  Sparkles,
  PenLine,
  Trash2,
  RefreshCw,
  X,
  Lock,
  Unlock,
  Heart,
  ChevronRight,
  BookOpen,
  Wand2,
  Check
} from 'lucide-react'
import {
  generateRelationshipPrompts,
  GeneratedPrompt,
  RelationshipStage,
  MoodVibe
} from '@/core/ai'

export interface BlindPromptData {
  question: string
  vibeTag?: string
  stage?: RelationshipStage
  category?: MoodVibe
  isAiGenerated?: boolean
  answers: {
    [userId: string]: {
      text: string
      author: string
      answeredAt: string
    }
  }
  updatedAt: string
}

const STAGES: { id: RelationshipStage; label: string; icon: string; desc: string }[] = [
  { id: 'deep', label: 'Deeply In Love', icon: '🌿', desc: 'Vulnerable, intimate & inseparable' },
  { id: 'new', label: 'Sweet Sparks', icon: '✨', desc: 'First butterflies & early chapters' },
  { id: 'long_distance', label: 'Long Distance', icon: '✈️', desc: 'Miles apart, counting days' },
  { id: 'years', label: 'Years Together', icon: '☕', desc: 'Warm familiar rhythm & roots' },
  { id: 'soft_reconnect', label: 'Soft Reconnect', icon: '🕯️', desc: 'Gentle warmth & quiet ease' }
]

const MOODS: { id: MoodVibe; label: string; icon: string; desc: string }[] = [
  { id: 'vulnerable', label: 'Vulnerable', icon: '🕯️', desc: 'Raw feelings' },
  { id: 'playful', label: 'Playful', icon: '☀️', desc: 'Inside jokes & banter' },
  { id: 'nostalgic', label: 'Nostalgic', icon: '🌙', desc: 'First times & memory lane' },
  { id: 'philosophical', label: 'Deep Thoughts', icon: '🌌', desc: 'Life, dreams & future' },
  { id: 'comforting', label: 'Comforting', icon: '🌧️', desc: 'Soft reassurance' }
]

const CURATED_DECK: { category: MoodVibe; vibeTag: string; question: string }[] = [
  {
    category: 'vulnerable',
    vibeTag: 'VULNERABLE · 🕯️',
    question: 'When was the exact moment you realized you felt safe with me?'
  },
  {
    category: 'vulnerable',
    vibeTag: 'VULNERABLE · 🕯️',
    question: 'What is an unspoken insecurity you carry that you wish I understood better?'
  },
  {
    category: 'vulnerable',
    vibeTag: 'VULNERABLE · 🕯️',
    question: 'What is a private thought you had about us recently that you haven’t said out loud?'
  },
  {
    category: 'playful',
    vibeTag: 'PLAYFUL · ☀️',
    question: 'If we were forced into a crime duo, what would our absurd specialty be?'
  },
  {
    category: 'playful',
    vibeTag: 'PLAYFUL · ☀️',
    question: 'What is my silliest habit that you secretly find endearing?'
  },
  {
    category: 'playful',
    vibeTag: 'PLAYFUL · ☀️',
    question: 'What is an inside joke between us that would sound completely unhinged to strangers?'
  },
  {
    category: 'nostalgic',
    vibeTag: 'NOSTALGIC · 🌙',
    question: 'What memory of our first few dates plays back the clearest in your head?'
  },
  {
    category: 'nostalgic',
    vibeTag: 'NOSTALGIC · 🌙',
    question: 'What song instantly takes you back to the exact day we started talking?'
  },
  {
    category: 'nostalgic',
    vibeTag: 'NOSTALGIC · 🌙',
    question: 'What is a quiet ordinary evening we shared that lives rent-free in your mind?'
  },
  {
    category: 'philosophical',
    vibeTag: 'DEEP · 🌌',
    question: 'How do you think our relationship has shaped the person you are becoming?'
  },
  {
    category: 'philosophical',
    vibeTag: 'DEEP · 🌌',
    question: 'If our journey together were a book, what would this current chapter be named?'
  },
  {
    category: 'philosophical',
    vibeTag: 'DEEP · 🌌',
    question: 'What does "home" mean to you—is it a place, a routine, or a person?'
  },
  {
    category: 'comforting',
    vibeTag: 'COMFORTING · 🌧️',
    question: 'What is the simplest ritual we share (morning coffee, late walk) that you cherish?'
  },
  {
    category: 'comforting',
    vibeTag: 'COMFORTING · 🌧️',
    question: 'On your hardest days, what is the one quiet thing you need from me most?'
  },
  {
    category: 'comforting',
    vibeTag: 'COMFORTING · 🌧️',
    question: 'Take a deep breath right now. What is one gentle truth you need to hear today?'
  }
]

const QUICK_STARTERS = [
  'What memory of us lives rent-free in your mind?',
  'What was going through your mind the first time we held hands?',
  'If we had an entire day with no alarms or phones, what are we doing?',
  'What is a tiny detail about me that you notice when I think no one is looking?',
  'What is something we don’t talk about enough that you miss?'
]

export const BlindPromptCard: React.FC = () => {
  const { user, space, partner } = useAuth()
  const { showToast } = useToast()

  const spaceId = space?.id || 'default_space'
  const promptDocId = `prompt_${spaceId}`

  const [promptData, setPromptData] = useState<BlindPromptData>({
    question: CURATED_DECK[0].question,
    vibeTag: CURATED_DECK[0].vibeTag,
    answers: {},
    updatedAt: new Date().toISOString()
  })

  // Modals & form state
  const [isAnswering, setIsAnswering] = useState(false)
  const [myAnswer, setMyAnswer] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)

  // Studio modal (AI / Manual / Deck)
  const [showStudioModal, setShowStudioModal] = useState(false)
  const [studioTab, setStudioTab] = useState<'ai' | 'manual' | 'deck'>('ai')

  // AI Generator state
  const [selectedStage, setSelectedStage] = useState<RelationshipStage>('deep')
  const [selectedMood, setSelectedMood] = useState<MoodVibe>('vulnerable')
  const [customTopic, setCustomTopic] = useState('')
  const [isGeneratingAi, setIsGeneratingAi] = useState(false)
  const [generatedOptions, setGeneratedOptions] = useState<GeneratedPrompt[]>([])
  const [selectedAiPrompt, setSelectedAiPrompt] = useState<GeneratedPrompt | null>(null)

  // Manual Question state
  const [manualQuestionInput, setManualQuestionInput] = useState('')
  const [manualVibeTag, setManualVibeTag] = useState('CUSTOM QUESTION · ✍️')

  // Curated Deck state
  const [deckCategoryFilter, setDeckCategoryFilter] = useState<MoodVibe | 'all'>('all')

  // 1. Fetch & Listen to Realtime updates on this prompt document
  useEffect(() => {
    const supabase = getSupabaseClient()
    const db = getFirebaseDb()

    const fetchPrompt = async () => {
      try {
        const { data } = await supabase
          .from('app_content')
          .select('content')
          .eq('id', promptDocId)
          .single()

        if (data?.content) {
          setPromptData(data.content as BlindPromptData)
        }
      } catch (err) {
        console.warn('Error fetching blind prompt:', err)
      }
    }

    fetchPrompt()

    const channel = supabase
      .channel(`blind_prompt_chan_${spaceId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'app_content',
          filter: `id=eq.${promptDocId}`
        },
        (payload: any) => {
          if (payload.new?.content) {
            setPromptData(payload.new.content as BlindPromptData)
          }
        }
      )
      .subscribe()

    // Firestore listener for immediate peer sync
    let unsubFirestore: (() => void) | undefined
    if (db && spaceId) {
      try {
        unsubFirestore = onSnapshot(doc(db, 'spaces', spaceId, 'features', 'blind_prompt'), (snapshot) => {
          if (snapshot.exists()) {
            const data = snapshot.data() as BlindPromptData
            if (data?.question) {
              setPromptData(data)
            }
          }
        }, (err) => {
          console.warn('Firestore blind prompt snapshot error:', err)
        })
      } catch (err) {
        console.warn('Failed to listen to Firestore blind prompt:', err)
      }
    }

    // Peer broadcast listener
    const unsubBroadcast = realtimeBridge.subscribe((event) => {
      if (event.type === 'BLIND_PROMPT_UPDATE' && event.data) {
        setPromptData(event.data as BlindPromptData)
      }
    })

    return () => {
      supabase.removeChannel(channel)
      if (unsubFirestore) unsubFirestore()
      unsubBroadcast()
    }
  }, [promptDocId, spaceId])

  const myId = user?.id || ''
  const partnerId = partner?.id || ''

  const myResponse = myId ? promptData.answers[myId] : null
  const partnerResponse = partnerId ? promptData.answers[partnerId] : null

  const hasMyAnswer = Boolean(myResponse?.text)
  const hasPartnerAnswer = Boolean(partnerResponse?.text)

  // Both have answered -> Reveal mode!
  const isUnlocked = hasMyAnswer && hasPartnerAnswer

  useEffect(() => {
    if (isUnlocked) {
      confetti({
        particleCount: 55,
        spread: 65,
        origin: { y: 0.6 }
      })
    }
  }, [isUnlocked])

  // Save changes to Supabase & Firebase with atomic answer merge
  const syncToCloud = async (updatedData: BlindPromptData) => {
    try {
      const supabase = getSupabaseClient()

      // Fetch latest cloud state first to merge answers so neither partner's response is lost!
      let mergedAnswers = { ...updatedData.answers }
      try {
        const { data: latestRow } = await supabase
          .from('app_content')
          .select('content')
          .eq('id', promptDocId)
          .maybeSingle()
        if (latestRow?.content?.answers) {
          mergedAnswers = {
            ...latestRow.content.answers,
            ...updatedData.answers
          }
        }
      } catch {}

      const finalData: BlindPromptData = {
        ...updatedData,
        answers: mergedAnswers,
        updatedAt: new Date().toISOString()
      }

      await supabase.from('app_content').upsert({
        id: promptDocId,
        content: finalData,
        updated_at: new Date().toISOString()
      })

      // Also sync to Firebase Firestore if connected
      const db = getFirebaseDb()
      if (db) {
        try {
          await setDoc(doc(db, 'spaces', spaceId, 'features', 'blind_prompt'), finalData, { merge: true })
        } catch {}
      }

      // Instant broadcast to partner over realtime bridge
      await realtimeBridge.broadcast({
        type: 'BLIND_PROMPT_UPDATE',
        senderId: user?.id || 'unknown',
        senderNickname: user?.nickname || 'Partner',
        timestamp: Date.now(),
        data: finalData
      }).catch(() => {})
    } catch (err) {
      console.warn('Error saving blind prompt state:', err)
    }
  }

  // Answer handlers
  const handleAnswerSubmit = async () => {
    if (!myAnswer.trim() || !user) return

    setIsSubmitting(true)
    const updatedAnswers = {
      ...promptData.answers,
      [user.id]: {
        text: myAnswer.trim(),
        author: user.nickname || 'You',
        answeredAt: new Date().toISOString()
      }
    }

    const updatedData: BlindPromptData = {
      ...promptData,
      answers: updatedAnswers,
      updatedAt: new Date().toISOString()
    }

    setPromptData(updatedData)
    setIsAnswering(false)
    setMyAnswer('')
    showToast('Your answer is sealed in the envelope until both have answered.')

    await syncToCloud(updatedData)
    setIsSubmitting(false)
  }

  const handleDeleteMyAnswer = async () => {
    if (!user || !promptData.answers[user.id]) return
    if (!window.confirm('Delete and retract your sealed answer?')) return

    const updatedAnswers = { ...promptData.answers }
    delete updatedAnswers[user.id]

    const updatedData: BlindPromptData = {
      ...promptData,
      answers: updatedAnswers,
      updatedAt: new Date().toISOString()
    }

    setPromptData(updatedData)
    setIsAnswering(false)
    setMyAnswer('')
    showToast('Your answer was retracted and deleted.')

    await syncToCloud(updatedData)
  }

  // Pin a new question (resets answers for fresh gameplay)
  const handlePinNewQuestion = async (
    question: string,
    vibeTag?: string,
    isAi?: boolean,
    category?: MoodVibe,
    stage?: RelationshipStage
  ) => {
    if (!question.trim()) return

    const resetData: BlindPromptData = {
      question: question.trim(),
      vibeTag: vibeTag || 'DAILY THOUGHTS',
      category,
      stage,
      isAiGenerated: isAi,
      answers: {},
      updatedAt: new Date().toISOString()
    }

    setPromptData(resetData)
    setShowStudioModal(false)
    setManualQuestionInput('')
    setSelectedAiPrompt(null)
    showToast('New prompt pinned for both of you.')

    await syncToCloud(resetData)
  }

  // Clear or reset current prompt
  const handleResetCurrentPrompt = async () => {
    if (!window.confirm('Clear all answers and reset this question?')) return

    const resetData: BlindPromptData = {
      ...promptData,
      answers: {},
      updatedAt: new Date().toISOString()
    }

    setPromptData(resetData)
    showToast('Board reset. Ready for new answers.')
    await syncToCloud(resetData)
  }

  // AI Prompt Generation Trigger
  const handleGenerateAiPrompts = async () => {
    setIsGeneratingAi(true)
    try {
      const results = await generateRelationshipPrompts({
        userNickname: user?.nickname || 'Partner A',
        partnerNickname: partner?.nickname || 'Partner B',
        relationshipStage: selectedStage,
        mood: selectedMood,
        customTopic: customTopic.trim() || undefined
      })
      setGeneratedOptions(results)
      if (results.length > 0) {
        setSelectedAiPrompt(results[0])
      }
    } catch (err) {
      console.error('Failed to generate prompts:', err)
      showToast('Could not reach AI engine, loading curated selection.')
    } finally {
      setIsGeneratingAi(false)
    }
  }

  const filteredCuratedDeck =
    deckCategoryFilter === 'all'
      ? CURATED_DECK
      : CURATED_DECK.filter((item) => item.category === deckCategoryFilter)

  return (
    <>
      {/* SECTION HEADER ROW */}
      <div className="section-row flex-wrap gap-y-1">
        <strong>Random thoughts</strong>
        <div className="flex items-center gap-1.5 shrink-0">
          <span className="text-[9px] tracking-wider text-[#7a8178] uppercase max-w-[105px] truncate">
            {promptData.vibeTag || 'THIS WEEK · 04'}
          </span>
          <button
            type="button"
            onClick={() => {
              setShowStudioModal(true)
              // Auto generate initial batch if empty
              if (generatedOptions.length === 0) {
                handleGenerateAiPrompts()
              }
            }}
            className="flex items-center gap-1 text-[10px] font-medium text-[var(--app-accent)] bg-[var(--paper)] border border-[var(--line)] hover:opacity-90 active:scale-95 px-2.5 py-1 rounded-full cursor-pointer transition shrink-0"
            title="Create or generate new questions"
          >
            <Sparkles className="w-2.5 h-2.5 text-[#b77e6b]" />
            <span>＋ Studio</span>
          </button>
        </div>
      </div>

      {/* QUESTION CARD */}
      <div
        className="question-card cursor-pointer relative group"
        onClick={() => {
          setMyAnswer(myResponse?.text || '')
          setIsAnswering(true)
        }}
      >
        <div className="question-label">
          <span className="flex items-center gap-1.5 font-medium">
            {promptData.isAiGenerated && (
              <Sparkles className="w-2.5 h-2.5 text-[#b77e6b]" />
            )}
            <span>{promptData.vibeTag || 'Answer together'}</span>
          </span>

          <span className="flex items-center gap-1.5">
            {isUnlocked ? (
              <span className="text-[#4d655a] font-semibold flex items-center gap-1">
                <Unlock className="w-2.5 h-2.5" /> Unlocked · revealed ✨
              </span>
            ) : hasMyAnswer || hasPartnerAnswer ? (
              <span className="text-[#b77e6b] font-medium flex items-center gap-1">
                <Lock className="w-2.5 h-2.5" /> 1 of 2 sealed
              </span>
            ) : (
              <span className="text-[#83867d] flex items-center gap-1">
                <Lock className="w-2.5 h-2.5" /> Reveal when both answer
              </span>
            )}
          </span>
        </div>

        <p className="question-text">{promptData.question}</p>

        {/* 1. REVEALED STATE (BOTH HAVE ANSWERED) */}
        {isUnlocked ? (
          <div className="space-y-2 pt-1 pb-1">
            {/* User's Answer */}
            <div className="p-3 rounded-xl bg-[var(--paper)] border border-[var(--line)] text-xs relative">
              <div className="flex items-center justify-between mb-1">
                <span className="font-semibold text-[var(--app-accent)] text-[10px] uppercase tracking-wider">
                  {user?.nickname || 'You'}
                </span>
                <button
                  type="button"
                  onClick={(e) => {
                    e.stopPropagation()
                    handleDeleteMyAnswer()
                  }}
                  className="text-[10px] text-red-500 hover:text-red-700 flex items-center gap-0.5 cursor-pointer"
                  title="Retract your answer"
                >
                  <Trash2 className="w-2.5 h-2.5" />
                  <span>Delete</span>
                </button>
              </div>
              <p className="font-serif italic text-[var(--ink)] text-[13px] leading-relaxed">
                "{myResponse?.text}"
              </p>
            </div>

            {/* Partner's Answer */}
            <div className="p-3 rounded-xl bg-[var(--paper)] border border-[var(--line)] text-xs">
              <span className="font-semibold text-[var(--app-accent)] block text-[10px] uppercase tracking-wider mb-1">
                {partner?.nickname || 'Partner'}
              </span>
              <p className="font-serif italic text-[var(--ink)] text-[13px] leading-relaxed">
                "{partnerResponse?.text}"
              </p>
            </div>

            {/* Actions row when revealed */}
            <div className="flex items-center justify-between pt-1 text-[10px] text-[#7a8178]">
              <button
                type="button"
                onClick={(e) => {
                  e.stopPropagation()
                  setShowStudioModal(true)
                }}
                className="text-[#4d655a] font-medium hover:underline flex items-center gap-1 cursor-pointer"
              >
                <Sparkles className="w-3 h-3 text-[#b77e6b]" />
                <span>Next Question</span>
              </button>
              <button
                type="button"
                onClick={(e) => {
                  e.stopPropagation()
                  handleResetCurrentPrompt()
                }}
                className="text-red-500 hover:underline flex items-center gap-1 cursor-pointer"
              >
                <RefreshCw className="w-2.5 h-2.5" />
                <span>Reset game</span>
              </button>
            </div>
          </div>
        ) : (
          /* 2. SEALED / WAITING STATE */
          <div className="answer-row flex-wrap gap-1.5">
            <span className={`answer ${hasMyAnswer ? '' : 'cursor-pointer hover:bg-[#eceae2]'}`}>
              You{' '}
              <b>
                {hasMyAnswer ? (
                  <span className="text-[#4d655a]">Answered ✓</span>
                ) : (
                  'Tap to answer'
                )}
              </b>
            </span>

            <span className={`answer ${hasPartnerAnswer ? '' : 'locked'}`}>
              {partner?.nickname || 'Partner'}{' '}
              <b>{hasPartnerAnswer ? 'Answered ✓' : 'Locked · waiting'}</b>
            </span>

            <button
              type="button"
              className="react-link ml-auto shrink-0"
              onClick={async (e) => {
                e.stopPropagation()
                if (partner && user) {
                  showToast(`A gentle heart sent to ${partner.nickname}. ♡`)
                  await realtimeBridge.broadcast({
                    type: 'NOTIFICATION_TRIGGER',
                    senderId: user.id,
                    senderNickname: user.nickname,
                    timestamp: Date.now(),
                    data: {
                      title: `${user.nickname} sent you a gentle heart reminder ♡`
                    }
                  })
                } else {
                  showToast('Connect your partner to send a reaction. ♡')
                }
              }}
              title="Send a heart reminder"
            >
              ♡ React
            </button>
          </div>
        )}

        {/* Retract link if user answered but partner hasn't yet */}
        {!isUnlocked && hasMyAnswer && (
          <div className="mt-2 pt-1 border-t border-[#eeece4] flex items-center justify-between text-[10px] text-[#7a8178]">
            <span className="italic text-[#83867d]">
              Your response is safely sealed. Opens when {partner?.nickname || 'they'} answer.
            </span>
            <button
              type="button"
              onClick={(e) => {
                e.stopPropagation()
                handleDeleteMyAnswer()
              }}
              className="text-red-500 hover:underline ml-2 cursor-pointer flex items-center gap-1"
            >
              <Trash2 className="w-2.5 h-2.5" /> Retract
            </button>
          </div>
        )}
      </div>

      {/* ANSWER MODAL (SEAL YOUR ANSWER) */}
      {isAnswering && (
        <div
          className="modal-backdrop"
          onClick={(e) => {
            if (e.target === e.currentTarget) setIsAnswering(false)
          }}
        >
          <div className="modal max-h-[90vh] overflow-y-auto">
            <div className="modal-handle"></div>
            <button
              type="button"
              className="close"
              onClick={() => setIsAnswering(false)}
            >
              ×
            </button>
            <div className="modal-date">
              {promptData.vibeTag || 'RANDOM THOUGHTS · BLIND REVEAL'}
            </div>
            <h3 className="text-xl leading-snug">{promptData.question}</h3>
            <p className="text-xs text-[var(--soft)] mb-3 not-italic">
              Your answer will stay locked inside a digital envelope. Neither of you can peek
              until both answers are submitted.
            </p>

            <textarea
              rows={4}
              value={myAnswer}
              onChange={(e) => setMyAnswer(e.target.value)}
              placeholder="Speak honestly. Only your partner will read this..."
              className="w-full p-3.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-xs font-serif italic outline-none resize-none leading-relaxed text-[var(--ink)] focus:border-[var(--app-accent)]"
              autoFocus
            />

            <div className="flex gap-2 mt-4">
              {hasMyAnswer && (
                <button
                  type="button"
                  onClick={handleDeleteMyAnswer}
                  className="py-2.5 px-3 rounded-xl border border-red-300 dark:border-red-900 text-red-600 dark:text-red-400 text-xs font-medium cursor-pointer hover:bg-red-500/10 transition flex items-center gap-1"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                  <span>Delete</span>
                </button>
              )}
              <button
                type="button"
                onClick={handleAnswerSubmit}
                disabled={!myAnswer.trim() || isSubmitting}
                className="flex-1 py-2.5 rounded-xl bg-[var(--app-accent)] text-white text-xs font-medium cursor-pointer disabled:opacity-50 transition hover:opacity-90 flex items-center justify-center gap-1.5"
              >
                <Lock className="w-3 h-3" />
                <span>
                  {isSubmitting
                    ? 'Sealing...'
                    : hasMyAnswer
                    ? 'Update sealed answer'
                    : 'Seal answer into envelope'}
                </span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* QUESTION STUDIO MODAL (AI ENGINE · MANUAL WRITE · CURATED DECK) */}
      {showStudioModal && (
        <div
          className="modal-backdrop"
          onClick={(e) => {
            if (e.target === e.currentTarget) setShowStudioModal(false)
          }}
        >
          <div className="modal max-h-[88vh] overflow-y-auto">
            <div className="modal-handle"></div>
            <button
              type="button"
              className="close"
              onClick={() => setShowStudioModal(false)}
            >
              ×
            </button>

            <div className="modal-date">QUESTION STUDIO</div>
            <h3 className="text-xl mb-1">Pick your next Random Thought</h3>
            <p className="text-xs text-[var(--soft)] not-italic mb-4">
              Generate AI questions tailored to your relationship vibe or write your own.
            </p>

            {/* TAB SELECTOR */}
            <div className="flex p-1 bg-[var(--paper)] border border-[var(--line)] rounded-xl mb-4 text-xs font-medium">
              <button
                type="button"
                onClick={() => setStudioTab('ai')}
                className={`flex-1 py-1.5 rounded-lg flex items-center justify-center gap-1.5 cursor-pointer transition ${
                  studioTab === 'ai'
                    ? 'bg-[var(--white)] text-[var(--ink)] shadow-xs'
                    : 'text-[var(--soft)] hover:text-[var(--ink)]'
                }`}
              >
                <Sparkles className="w-3 h-3 text-[var(--terra)]" />
                <span>✦ AI Engine</span>
              </button>

              <button
                type="button"
                onClick={() => setStudioTab('manual')}
                className={`flex-1 py-1.5 rounded-lg flex items-center justify-center gap-1.5 cursor-pointer transition ${
                  studioTab === 'manual'
                    ? 'bg-[var(--white)] text-[var(--ink)] shadow-xs'
                    : 'text-[var(--soft)] hover:text-[var(--ink)]'
                }`}
              >
                <PenLine className="w-3 h-3 text-[var(--app-accent)]" />
                <span>✍️ Write Own</span>
              </button>

              <button
                type="button"
                onClick={() => setStudioTab('deck')}
                className={`flex-1 py-1.5 rounded-lg flex items-center justify-center gap-1.5 cursor-pointer transition ${
                  studioTab === 'deck'
                    ? 'bg-[var(--white)] text-[var(--ink)] shadow-xs'
                    : 'text-[var(--soft)] hover:text-[var(--ink)]'
                }`}
              >
                <BookOpen className="w-3 h-3 text-[var(--soft)]" />
                <span>🎴 Deck</span>
              </button>
            </div>

            {/* TAB 1: AI GENERATOR */}
            {studioTab === 'ai' && (
              <div className="space-y-4">
                {/* 1. Stage Selector */}
                <div>
                  <label className="text-[10px] font-semibold text-[var(--soft)] uppercase tracking-wider block mb-1.5">
                    1. Relationship dynamic
                  </label>
                  <div className="grid grid-cols-2 gap-1.5">
                    {STAGES.map((st) => {
                      const isSel = selectedStage === st.id
                      return (
                        <button
                          key={st.id}
                          type="button"
                          onClick={() => setSelectedStage(st.id)}
                          className={`p-2 rounded-xl text-left border cursor-pointer transition flex items-start gap-1.5 ${
                            isSel
                              ? 'bg-[var(--app-accent)] text-white border-[var(--app-accent)]'
                              : 'bg-[var(--paper)] border-[var(--line)] text-[var(--ink)] hover:opacity-90'
                          }`}
                        >
                          <span className="text-sm">{st.icon}</span>
                          <div>
                            <div className="text-[11px] font-semibold leading-tight">
                              {st.label}
                            </div>
                            <div
                              className={`text-[9px] ${
                                isSel ? 'text-white/80' : 'text-[var(--soft)]'
                              } leading-tight line-clamp-1`}
                            >
                              {st.desc}
                            </div>
                          </div>
                        </button>
                      )
                    })}
                  </div>
                </div>

                {/* 2. Mood Selector */}
                <div>
                  <label className="text-[10px] font-semibold text-[var(--soft)] uppercase tracking-wider block mb-1.5">
                    2. Desired mood & vibe
                  </label>
                  <div className="flex flex-wrap gap-1.5">
                    {MOODS.map((md) => {
                      const isSel = selectedMood === md.id
                      return (
                        <button
                          key={md.id}
                          type="button"
                          onClick={() => setSelectedMood(md.id)}
                          className={`px-2.5 py-1.5 rounded-full text-xs cursor-pointer border transition flex items-center gap-1 ${
                            isSel
                              ? 'bg-[var(--terra)] text-white border-[var(--terra)]'
                              : 'bg-[var(--paper)] text-[var(--ink)] border-[var(--line)] hover:opacity-90'
                          }`}
                        >
                          <span>{md.icon}</span>
                          <span>{md.label}</span>
                        </button>
                      )
                    })}
                  </div>
                </div>

                {/* 3. Optional Custom Focus */}
                <div>
                  <label className="text-[10px] font-semibold text-[var(--soft)] uppercase tracking-wider block mb-1">
                    3. Specific topic (optional)
                  </label>
                  <input
                    type="text"
                    value={customTopic}
                    onChange={(e) => setCustomTopic(e.target.value)}
                    placeholder="e.g. cozy rainy nights, moving in, inside jokes"
                    className="w-full px-3 py-2 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-xs text-[var(--ink)] outline-none focus:border-[var(--app-accent)]"
                  />
                </div>

                {/* Generate Button */}
                <button
                  type="button"
                  onClick={handleGenerateAiPrompts}
                  disabled={isGeneratingAi}
                  className="w-full py-2.5 rounded-xl bg-[var(--app-accent)] text-white text-xs font-medium cursor-pointer hover:opacity-90 transition flex items-center justify-center gap-1.5 disabled:opacity-50"
                >
                  <Sparkles className="w-3.5 h-3.5 text-[var(--terra)]" />
                  <span>
                    {isGeneratingAi ? 'Synthesizing with AI engine...' : 'Generate 3 Prompts ✦'}
                  </span>
                </button>

                {/* Generated Prompt Cards */}
                {generatedOptions.length > 0 && (
                  <div className="space-y-2 pt-2 border-t border-[var(--line)]">
                    <div className="text-[10px] uppercase font-semibold text-[#7a8178] tracking-wider">
                      Generated tailored questions
                    </div>
                    {generatedOptions.map((opt) => {
                      const isSelected = selectedAiPrompt?.id === opt.id
                      return (
                        <div
                          key={opt.id}
                          onClick={() => setSelectedAiPrompt(opt)}
                          className={`p-3 rounded-xl border cursor-pointer transition relative ${
                            isSelected
                              ? 'bg-[var(--white)] border-[var(--app-accent)] shadow-xs'
                              : 'bg-[var(--paper)] border-[var(--line)] hover:opacity-90'
                          }`}
                        >
                          <div className="flex items-center justify-between text-[9px] text-[var(--soft)] mb-1">
                            <span className="font-semibold text-[var(--terra)]">
                              {opt.vibeTag}
                            </span>
                            {isSelected && (
                              <span className="text-[var(--app-accent)] font-bold flex items-center gap-0.5">
                                <Check className="w-3 h-3" /> Selected
                              </span>
                            )}
                          </div>
                          <p className="font-serif italic text-xs text-[var(--ink)] leading-relaxed">
                            "{opt.question}"
                          </p>
                        </div>
                      )
                    })}

                    <button
                      type="button"
                      onClick={() => {
                        if (selectedAiPrompt) {
                          handlePinNewQuestion(
                            selectedAiPrompt.question,
                            selectedAiPrompt.vibeTag,
                            true,
                            selectedAiPrompt.category,
                            selectedStage
                          )
                        }
                      }}
                      disabled={!selectedAiPrompt}
                      className="w-full mt-2 py-2.5 rounded-xl bg-[var(--terra)] text-white text-xs font-medium cursor-pointer hover:opacity-90 transition disabled:opacity-50"
                    >
                      Pin selected question to board ✦
                    </button>
                  </div>
                )}
              </div>
            )}

            {/* TAB 2: MANUAL WRITE */}
            {studioTab === 'manual' && (
              <div className="space-y-4">
                <div>
                  <div className="flex justify-between items-center mb-1">
                    <label className="text-[10px] font-semibold text-[var(--soft)] uppercase tracking-wider">
                      Your Custom Question
                    </label>
                    <span className="text-[10px] text-[var(--soft)]">
                      {manualQuestionInput.length}/180
                    </span>
                  </div>

                  <textarea
                    rows={4}
                    maxLength={180}
                    value={manualQuestionInput}
                    onChange={(e) => setManualQuestionInput(e.target.value)}
                    placeholder="e.g. What is one thing you silently noticed about me this week?"
                    className="w-full p-3.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-xs font-serif italic outline-none resize-none leading-relaxed text-[var(--ink)] focus:border-[var(--app-accent)]"
                    autoFocus
                  />
                </div>

                {/* Vibe Category Tag */}
                <div>
                  <label className="text-[10px] font-semibold text-[var(--soft)] uppercase tracking-wider block mb-1">
                    Vibe tag
                  </label>
                  <div className="flex flex-wrap gap-1.5">
                    {[
                      'SECRET THOUGHTS · 🕯️',
                      'DEEP INQUIRY · 🌌',
                      'SWEET BANTER · ☀️',
                      'LATE NIGHT · 🌙',
                      'OUR STORY · 💌'
                    ].map((tag) => (
                      <button
                        key={tag}
                        type="button"
                        onClick={() => setManualVibeTag(tag)}
                        className={`px-2.5 py-1 rounded-full text-[10px] cursor-pointer border transition ${
                          manualVibeTag === tag
                            ? 'bg-[var(--app-accent)] text-white border-[var(--app-accent)]'
                            : 'bg-[var(--paper)] text-[var(--ink)] border-[var(--line)]'
                        }`}
                      >
                        {tag}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Quick Starters */}
                <div>
                  <label className="text-[10px] font-semibold text-[var(--soft)] uppercase tracking-wider block mb-1.5">
                    Inspiration starters (tap to insert)
                  </label>
                  <div className="space-y-1.5">
                    {QUICK_STARTERS.map((st, i) => (
                      <button
                        key={i}
                        type="button"
                        onClick={() => setManualQuestionInput(st)}
                        className="w-full p-2 text-left rounded-lg bg-[var(--paper)] hover:opacity-85 text-[11px] font-serif italic text-[var(--ink)] border border-[var(--line)] transition cursor-pointer flex items-center justify-between"
                      >
                        <span>"{st}"</span>
                        <ChevronRight className="w-3 h-3 text-[var(--soft)] shrink-0 ml-1" />
                      </button>
                    ))}
                  </div>
                </div>

                {/* Pin Manual Button */}
                <button
                  type="button"
                  onClick={() =>
                    handlePinNewQuestion(manualQuestionInput, manualVibeTag, false)
                  }
                  disabled={!manualQuestionInput.trim()}
                  className="w-full py-2.5 rounded-xl bg-[var(--app-accent)] text-white text-xs font-medium cursor-pointer hover:opacity-90 transition disabled:opacity-50"
                >
                  Pin custom question to board
                </button>
              </div>
            )}

            {/* TAB 3: CURATED DECK */}
            {studioTab === 'deck' && (
              <div className="space-y-3">
                {/* Category filter */}
                <div className="flex gap-1 overflow-x-auto pb-1 text-xs">
                  <button
                    type="button"
                    onClick={() => setDeckCategoryFilter('all')}
                    className={`px-2.5 py-1 rounded-full whitespace-nowrap text-[11px] cursor-pointer border transition ${
                      deckCategoryFilter === 'all'
                        ? 'bg-[var(--app-accent)] text-white border-[var(--app-accent)]'
                        : 'bg-[var(--paper)] text-[var(--ink)] border-[var(--line)]'
                    }`}
                  >
                    All Prompts
                  </button>
                  {MOODS.map((md) => (
                    <button
                      key={md.id}
                      type="button"
                      onClick={() => setDeckCategoryFilter(md.id)}
                      className={`px-2.5 py-1 rounded-full whitespace-nowrap text-[11px] cursor-pointer border transition flex items-center gap-1 ${
                        deckCategoryFilter === md.id
                          ? 'bg-[var(--app-accent)] text-white border-[var(--app-accent)]'
                          : 'bg-[var(--paper)] text-[var(--ink)] border-[var(--line)]'
                      }`}
                    >
                      <span>{md.icon}</span>
                      <span>{md.label}</span>
                    </button>
                  ))}
                </div>

                {/* Prompt List */}
                <div className="space-y-2 max-h-[46vh] overflow-y-auto pr-1">
                  {filteredCuratedDeck.map((item, idx) => (
                    <div
                      key={idx}
                      className="p-3 rounded-xl border border-[var(--line)] bg-[var(--paper)] hover:border-[var(--app-accent)] transition group flex items-start justify-between gap-3"
                    >
                      <div className="flex-1">
                        <span className="text-[9px] font-semibold text-[var(--terra)] block mb-0.5">
                          {item.vibeTag}
                        </span>
                        <p className="font-serif italic text-xs text-[var(--ink)] leading-relaxed">
                          "{item.question}"
                        </p>
                      </div>
                      <button
                        type="button"
                        onClick={() =>
                          handlePinNewQuestion(
                            item.question,
                            item.vibeTag,
                            false,
                            item.category
                          )
                        }
                        className="py-1 px-2.5 rounded-lg bg-[var(--white)] group-hover:bg-[var(--app-accent)] group-hover:text-white text-[10px] font-medium text-[var(--ink)] border border-[var(--line)] cursor-pointer transition shrink-0 self-center"
                      >
                        Use ✦
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </>
  )
}
