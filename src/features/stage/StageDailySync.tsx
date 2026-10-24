import React, { useState, useEffect, useCallback, useMemo } from 'react'
import { useAuth } from '@/core/auth'
import { useToast } from '@/core/toast'
import { realtimeBridge } from '@/core/realtime'
import { getSupabaseClient } from '@/core/storage/supabase'
import { getFirebaseDb } from '@/core/storage/firebase'
import { doc, setDoc } from 'firebase/firestore'
import confetti from 'canvas-confetti'
import {
  Sparkles,
  Lock,
  Unlock,
  Heart,
  ChevronRight,
  RefreshCw,
  Plus,
  Trash2,
  X,
  Send,
  Wand2,
  PenLine,
  CheckCircle2,
  Circle,
  HelpCircle
} from 'lucide-react'
import {
  generateRelationshipPrompts,
  GeneratedPrompt,
  RelationshipStage,
  MoodVibe
} from '@/core/ai'

export interface SyncAnswer {
  text: string
  author: string
  answeredAt: string
}

export interface CareCheckItem {
  id: string
  title: string
  icon?: string
  createdById: string
  createdBy: string
  isCompleted: boolean
  completedAt?: string
  completedBy?: string
}

export interface DailySyncData {
  question: string
  vibeTag: string
  stage?: RelationshipStage
  category?: MoodVibe
  answers: {
    [userId: string]: SyncAnswer
  }
  careChecks?: CareCheckItem[]
  updatedAt: string
}

const DEFAULT_CARE_ITEMS = [
  { id: 'water', title: 'Drink water', icon: '💧' },
  { id: 'vitamins', title: 'Take vitamins / meds', icon: '💊' },
  { id: 'meal', title: 'Eat a good meal', icon: '🥗' },
  { id: 'rest', title: 'Gentle screen break', icon: '🌿' }
]

const LDR_CURATED_QUESTIONS: { category: MoodVibe; vibeTag: string; question: string }[] = [
  {
    category: 'vulnerable',
    vibeTag: 'RAW INTIMACY · 🕯️',
    question: 'When do you feel my absence the most during the day, and what brings you comfort then?'
  },
  {
    category: 'vulnerable',
    vibeTag: 'DEEP VULNERABILITY · 🕯️',
    question: 'What is an unspoken insecurity or thought you carry that you wish I understood better?'
  },
  {
    category: 'philosophical',
    vibeTag: 'REUNION DREAMS · ✈️',
    question: 'What is the very first thing you want to do the second we drop our bags after arriving?'
  },
  {
    category: 'philosophical',
    vibeTag: 'FUTURE LIFE · 🌌',
    question: 'Describe one tiny morning ritual you look forward to sharing under the same roof someday.'
  },
  {
    category: 'playful',
    vibeTag: 'PLAYFUL BANTER · ☀️',
    question: 'What is my silliest habit or quirk that you secretly find completely irresistible?'
  },
  {
    category: 'playful',
    vibeTag: 'INSIDE SECRETS · ☀️',
    question: 'What inside joke between us would sound completely unhinged to a stranger?'
  },
  {
    category: 'nostalgic',
    vibeTag: 'NOSTALGIC · 🌙',
    question: 'What quiet moment from the last time we were together plays back clearest in your mind?'
  },
  {
    category: 'comforting',
    vibeTag: 'QUIET COMFORT · 🌧️',
    question: 'Take a deep breath right now. What is one gentle truth you need to hear from me today?'
  }
]

export const StageDailySync: React.FC = () => {
  const { user, space, partner } = useAuth()
  const { showToast } = useToast()

  const spaceId = space?.id || 'default_space'
  const promptDocId = `prompt_${spaceId}`
  const checkinDocId = `checkin_${spaceId}`

  const [syncData, setSyncData] = useState<DailySyncData>({
    question: LDR_CURATED_QUESTIONS[0].question,
    vibeTag: LDR_CURATED_QUESTIONS[0].vibeTag,
    answers: {},
    careChecks: DEFAULT_CARE_ITEMS.map((item) => ({
      id: item.id,
      title: item.title,
      icon: item.icon,
      createdById: 'system',
      createdBy: 'System',
      isCompleted: false
    })),
    updatedAt: new Date().toISOString()
  })

  const [isLoading, setIsLoading] = useState(true)

  // Answering Modal State
  const [isAnswering, setIsAnswering] = useState(false)
  const [answerInput, setAnswerInput] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)

  // Studio / Personalize Modal State
  const [showStudioModal, setShowStudioModal] = useState(false)
  const [studioTab, setStudioTab] = useState<'ai' | 'deck' | 'custom'>('deck')

  // AI Prompt Studio
  const [selectedStage, setSelectedStage] = useState<RelationshipStage>('long_distance')
  const [selectedMood, setSelectedMood] = useState<MoodVibe>('vulnerable')
  const [customTopic, setCustomTopic] = useState('')
  const [isGeneratingAi, setIsGeneratingAi] = useState(false)
  const [aiOptions, setAiOptions] = useState<GeneratedPrompt[]>([])

  // Custom Prompt Composer
  const [customQuestionInput, setCustomQuestionInput] = useState('')
  const [customVibeInput, setCustomVibeInput] = useState('SWEET SURPRISE · 💌')

  // Add Care Check State
  const [isAddingCare, setIsAddingCare] = useState(false)
  const [newCareTitle, setNewCareTitle] = useState('')

  // 1. Fetch & Subscribe to Data
  useEffect(() => {
    const supabase = getSupabaseClient()

    const fetchSyncData = async () => {
      try {
        setIsLoading(true)
        const [promptRes, checkinRes] = await Promise.all([
          supabase.from('app_content').select('content').eq('id', promptDocId).maybeSingle(),
          supabase.from('app_content').select('content').eq('id', checkinDocId).maybeSingle()
        ])

        const promptContent = promptRes.data?.content as DailySyncData | undefined
        const checkinContent = checkinRes.data?.content

        if (promptContent && promptContent.question) {
          // If promptContent has careChecks, use them; otherwise use checkinContent careChecks
          const careChecks =
            promptContent.careChecks ||
            checkinContent?.careChecks ||
            DEFAULT_CARE_ITEMS.map((item) => ({
              id: item.id,
              title: item.title,
              icon: item.icon,
              createdById: 'system',
              createdBy: 'System',
              isCompleted: false
            }))

          setSyncData({
            ...promptContent,
            careChecks
          })
        }
      } catch (err) {
        console.warn('Error fetching daily sync data:', err)
      } finally {
        setIsLoading(false)
      }
    }

    fetchSyncData()

    // Realtime Supabase Channel
    const channel = supabase
      .channel(`sync_prompt_${spaceId}`)
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
            setSyncData(payload.new.content as DailySyncData)
          }
        }
      )
      .subscribe()

    // Realtime Bridge listener
    const unsubscribe = realtimeBridge.subscribe((event) => {
      if (event.type === 'BLIND_PROMPT_UPDATE' || event.type === 'CHECKIN_ANSWERED') {
        if (event.data) {
          setSyncData((prev) => ({
            ...prev,
            ...event.data
          }))
        }
      }
    })

    return () => {
      supabase.removeChannel(channel)
      unsubscribe()
    }
  }, [spaceId, promptDocId, checkinDocId])

  // Save changes to Supabase & Firebase
  const persistSyncData = async (updated: DailySyncData) => {
    setSyncData(updated)
    try {
      const supabase = getSupabaseClient()
      const nowIso = new Date().toISOString()
      await supabase.from('app_content').upsert({
        id: promptDocId,
        content: updated,
        updated_at: nowIso
      })

      const db = getFirebaseDb()
      if (db) {
        const ref = doc(db, 'spaces', spaceId, 'app_content', promptDocId)
        await setDoc(ref, { ...updated, updatedAt: nowIso }, { merge: true })
      }

      await realtimeBridge.broadcast({
        type: 'BLIND_PROMPT_UPDATE',
        senderId: user?.id || '',
        senderNickname: user?.nickname || 'Partner',
        timestamp: Date.now(),
        data: updated
      })
    } catch (err) {
      console.warn('Error saving daily sync data:', err)
    }
  }

  // Determine Answer States
  const myAnswer = user?.id ? syncData.answers[user.id] : undefined
  const partnerAnswer = partner?.id ? syncData.answers[partner.id] : undefined
  const hasUserAnswered = !!myAnswer?.text
  const hasPartnerAnswered = !!partnerAnswer?.text
  const isBothRevealed = hasUserAnswered && hasPartnerAnswered

  // Handle Submit Answer
  const handleSubmitAnswer = async () => {
    if (!user || !answerInput.trim()) return
    setIsSubmitting(true)

    const nowIso = new Date().toISOString()
    const newAnswers = {
      ...syncData.answers,
      [user.id]: {
        text: answerInput.trim(),
        author: user.nickname || 'You',
        answeredAt: nowIso
      }
    }

    const updated: DailySyncData = {
      ...syncData,
      answers: newAnswers,
      updatedAt: nowIso
    }

    await persistSyncData(updated)
    setIsSubmitting(false)
    setIsAnswering(false)
    setAnswerInput('')

    if (hasPartnerAnswered) {
      confetti({ particleCount: 40, spread: 70, origin: { y: 0.6 } })
      showToast('Both envelopes opened! Answer revealed ✨')
    } else {
      showToast('Your answer is sealed in the envelope 💌')
    }
  }

  // Handle Care Check Toggle
  const handleToggleCareCheck = async (careId: string) => {
    if (!user) return
    const currentList = syncData.careChecks || []
    const updatedList = currentList.map((item) => {
      if (item.id === careId) {
        const nextState = !item.isCompleted
        return {
          ...item,
          isCompleted: nextState,
          completedAt: nextState ? new Date().toISOString() : undefined,
          completedBy: nextState ? user.nickname : undefined
        }
      }
      return item
    })

    try {
      if (navigator.vibrate) navigator.vibrate(30)
    } catch {}

    const updated: DailySyncData = {
      ...syncData,
      careChecks: updatedList,
      updatedAt: new Date().toISOString()
    }

    await persistSyncData(updated)
  }

  // Handle Add Custom Care Item
  const handleAddCareItem = async () => {
    if (!user || !newCareTitle.trim()) return
    const newItem: CareCheckItem = {
      id: `care_${Date.now()}`,
      title: newCareTitle.trim(),
      icon: '🌿',
      createdById: user.id,
      createdBy: user.nickname,
      isCompleted: false
    }

    const updated: DailySyncData = {
      ...syncData,
      careChecks: [...(syncData.careChecks || []), newItem],
      updatedAt: new Date().toISOString()
    }

    await persistSyncData(updated)
    setNewCareTitle('')
    setIsAddingCare(false)
    showToast('New care reminder added 🌿')
  }

  // Handle Select Curated Question
  const handleSelectCurated = async (q: { category: MoodVibe; vibeTag: string; question: string }) => {
    const updated: DailySyncData = {
      ...syncData,
      question: q.question,
      vibeTag: q.vibeTag,
      category: q.category,
      answers: {}, // Reset answers for fresh prompt
      updatedAt: new Date().toISOString()
    }
    await persistSyncData(updated)
    setShowStudioModal(false)
    showToast('New daily sync prompt placed! Sealed for both 💌')
  }

  // Handle Random Shuffle
  const handleShuffle = () => {
    const pool = LDR_CURATED_QUESTIONS.filter((q) => q.question !== syncData.question)
    const randomPick = pool[Math.floor(Math.random() * pool.length)] || LDR_CURATED_QUESTIONS[0]
    handleSelectCurated(randomPick)
  }

  // Handle Generate AI Prompts
  const handleGenerateAi = async () => {
    setIsGeneratingAi(true)
    try {
      const results = await generateRelationshipPrompts({
        userNickname: user?.nickname || 'You',
        partnerNickname: partner?.nickname || 'Partner',
        relationshipStage: selectedStage,
        mood: selectedMood,
        customTopic: customTopic.trim() || undefined
      })
      setAiOptions(results)
    } catch (err) {
      console.warn('AI generation fallback:', err)
      showToast('Could not reach AI prompt service, using curated library.')
    } finally {
      setIsGeneratingAi(false)
    }
  }

  // Handle Submit Custom Question
  const handleSubmitCustomQuestion = async () => {
    if (!customQuestionInput.trim()) return
    const updated: DailySyncData = {
      ...syncData,
      question: customQuestionInput.trim(),
      vibeTag: customVibeInput.trim() || 'CUSTOM QUESTION · ✍️',
      answers: {},
      updatedAt: new Date().toISOString()
    }
    await persistSyncData(updated)
    setCustomQuestionInput('')
    setShowStudioModal(false)
    showToast('Your custom question is now on the stage! 💌')
  }

  return (
    <div className="card w-full mb-6 relative overflow-hidden transition-all duration-300">
      {/* Background Atmosphere glow */}
      <div className="absolute -top-16 -right-16 w-36 h-36 bg-[#e07a5f]/10 rounded-full blur-2xl pointer-events-none" />

      {/* 1. Header Bar: Title, Vibe Tag, and Action Controls */}
      <div className="flex items-center justify-between pb-3 border-b border-[var(--line)] mb-4">
        <div className="flex items-center gap-2 min-w-0">
          <span className="text-base">💌</span>
          <div className="min-w-0">
            <h3 className="text-xs font-bold tracking-wider text-[var(--terra)] uppercase truncate">
              Daily Connection
            </h3>
            <span className="text-[10px] text-[var(--soft)] font-medium block truncate">
              {syncData.vibeTag || 'LONG DISTANCE SYNC · ✈️'}
            </span>
          </div>
        </div>

        <div className="flex items-center gap-1.5 shrink-0">
          <button
            type="button"
            onClick={handleShuffle}
            className="p-1.5 rounded-lg text-[var(--soft)] hover:text-[var(--ink)] hover:bg-[var(--chip-bg)] transition text-xs flex items-center gap-1"
            title="Shuffle to another question"
          >
            <RefreshCw className="w-3.5 h-3.5" />
            <span className="text-[10px] hidden sm:inline">Shuffle</span>
          </button>
          <button
            type="button"
            onClick={() => setShowStudioModal(true)}
            className="px-2.5 py-1 rounded-full bg-[var(--app-accent)]/10 text-[var(--app-accent)] hover:bg-[var(--app-accent)]/20 transition text-[11px] font-semibold flex items-center gap-1 border border-[var(--app-accent)]/25"
            title="Personalize or ask custom question"
          >
            <Sparkles className="w-3 h-3" />
            <span>Personalize</span>
          </button>
        </div>
      </div>

      {/* 2. Today's Question Editorial Typography */}
      <div className="py-2 mb-4">
        <p className="text-base sm:text-lg font-serif italic text-[var(--ink)] leading-relaxed font-normal">
          &ldquo;{syncData.question}&rdquo;
        </p>
      </div>

      {/* 3. The Sealed Frosted Envelope Blind Reveal State */}
      <div className="space-y-3 mb-5">
        {isBothRevealed ? (
          /* BOTH REVEALED: Side-by-side or stacked transparent warm cards */
          <div className="space-y-3 animate-fadeIn">
            <div className="flex items-center justify-between text-[11px] text-[#4d655a] font-semibold px-1">
              <span className="flex items-center gap-1">
                <Unlock className="w-3.5 h-3.5 text-[#e07a5f]" />
                Envelopes Unsealed &bull; Both Answered
              </span>
              <span className="text-[10px] text-[var(--soft)] font-mono">Today</span>
            </div>

            {/* User Answer Card */}
            <div className="p-3.5 rounded-2xl bg-[var(--white)] border border-[var(--line)] shadow-2xs">
              <div className="flex items-center justify-between mb-1.5">
                <span className="text-xs font-bold text-[var(--ink)] flex items-center gap-1.5">
                  <span className="w-2 h-2 rounded-full bg-[var(--app-accent)]" />
                  {myAnswer?.author || 'You'}
                </span>
                <span className="text-[10px] text-[var(--soft)] font-mono">
                  {myAnswer?.answeredAt ? new Date(myAnswer.answeredAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ''}
                </span>
              </div>
              <p className="text-sm text-[var(--ink)] leading-relaxed whitespace-pre-wrap">{myAnswer?.text}</p>
            </div>

            {/* Partner Answer Card */}
            <div className="p-3.5 rounded-2xl bg-[var(--white)] border border-[#e07a5f]/25 shadow-2xs">
              <div className="flex items-center justify-between mb-1.5">
                <span className="text-xs font-bold text-[#e07a5f] flex items-center gap-1.5">
                  <span className="w-2 h-2 rounded-full bg-[#e07a5f]" />
                  {partnerAnswer?.author || partner?.nickname || 'Partner'}
                </span>
                <span className="text-[10px] text-[var(--soft)] font-mono">
                  {partnerAnswer?.answeredAt ? new Date(partnerAnswer.answeredAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ''}
                </span>
              </div>
              <p className="text-sm text-[var(--ink)] leading-relaxed whitespace-pre-wrap">{partnerAnswer?.text}</p>
            </div>
          </div>
        ) : hasUserAnswered && !hasPartnerAnswered ? (
          /* USER ANSWERED, PARTNER AWAITING */
          <div className="space-y-3">
            {/* My Sealed Envelope */}
            <div className="p-3.5 rounded-2xl bg-[var(--white)] border border-[var(--line)]">
              <div className="flex items-center justify-between mb-1">
                <span className="text-xs font-bold text-[var(--ink)] flex items-center gap-1.5">
                  <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />
                  Your answer is recorded
                </span>
                <button
                  type="button"
                  onClick={() => {
                    setAnswerInput(myAnswer?.text || '')
                    setIsAnswering(true)
                  }}
                  className="text-[11px] text-[var(--app-accent)] hover:underline font-semibold"
                >
                  Edit
                </button>
              </div>
              <p className="text-xs text-[var(--soft)] italic line-clamp-2">&ldquo;{myAnswer?.text}&rdquo;</p>
            </div>

            {/* Partner Sealed Envelope */}
            <div className="p-4 rounded-2xl bg-gradient-to-tr from-[var(--chip-bg)] to-[var(--white)] border border-dashed border-[#e07a5f]/30 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-full bg-[#e07a5f]/15 text-[#e07a5f] flex items-center justify-center text-sm shadow-2xs">
                  <Lock className="w-4 h-4" />
                </div>
                <div>
                  <h4 className="text-xs font-bold text-[var(--ink)]">
                    {partner?.nickname || 'Partner'}&rsquo;s envelope is sealed
                  </h4>
                  <p className="text-[11px] text-[var(--soft)] mt-0.5">
                    Hidden until {partner?.nickname || 'they'} open and reply
                  </p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => {
                  realtimeBridge.broadcast({
                    type: 'PULSE',
                    senderId: user?.id || '',
                    senderNickname: user?.nickname || 'Partner',
                    timestamp: Date.now()
                  })
                  showToast(`Gentle ping sent to ${partner?.nickname || 'partner'} 💌`)
                }}
                className="px-2.5 py-1 rounded-full bg-[#e07a5f]/10 text-[#e07a5f] hover:bg-[#e07a5f]/20 transition text-[10px] font-bold"
              >
                Nudge
              </button>
            </div>
          </div>
        ) : (
          /* NEITHER HAS ANSWERED OR PARTNER ANSWERED FIRST */
          <div className="p-4 rounded-2xl bg-gradient-to-tr from-[var(--chip-bg)] to-[var(--white)] border border-[var(--line)] shadow-2xs flex flex-col sm:flex-row items-center justify-between gap-3">
            <div className="flex items-center gap-3 w-full sm:w-auto">
              <div className="w-10 h-10 rounded-2xl bg-[var(--app-accent)]/15 text-[var(--app-accent)] flex items-center justify-center text-lg shrink-0">
                💌
              </div>
              <div>
                <h4 className="text-xs font-bold text-[var(--ink)]">
                  {hasPartnerAnswered
                    ? `${partner?.nickname || 'Partner'} has answered! Open yours to reveal`
                    : 'Awaiting both answers'}
                </h4>
                <p className="text-[11px] text-[var(--soft)] mt-0.5">
                  {hasPartnerAnswered
                    ? '1 of 2 answered · Sealed until you reply'
                    : 'Answers remain sealed until both of you write'}
                </p>
              </div>
            </div>

            <button
              type="button"
              onClick={() => {
                setAnswerInput('')
                setIsAnswering(true)
              }}
              className="w-full sm:w-auto px-4 py-2 rounded-xl bg-[var(--app-accent)] hover:opacity-90 active:scale-95 text-white font-semibold text-xs tracking-wide shadow-md transition flex items-center justify-center gap-2"
            >
              <span>Write Answer</span>
              <ChevronRight className="w-3.5 h-3.5" />
            </button>
          </div>
        )}
      </div>

      {/* 4. Gentle Daily Care Ribbon (Drink water, vitamins, meals) */}
      <div className="pt-3 border-t border-[var(--line)]">
        <div className="flex items-center justify-between mb-2">
          <span className="text-[11px] font-bold uppercase tracking-wider text-[var(--soft)] flex items-center gap-1.5">
            <span>🌿</span> Daily Care Checks
          </span>
          <button
            type="button"
            onClick={() => setIsAddingCare(true)}
            className="text-[11px] font-semibold text-[var(--app-accent)] hover:underline flex items-center gap-1"
          >
            <Plus className="w-3 h-3" /> Add Reminder
          </button>
        </div>

        {/* Care Check Chips */}
        <div className="flex flex-wrap gap-2">
          {(syncData.careChecks || []).map((care) => (
            <button
              key={care.id}
              type="button"
              onClick={() => handleToggleCareCheck(care.id)}
              className={`px-3 py-1.5 rounded-full text-xs font-medium transition flex items-center gap-2 border select-none ${
                care.isCompleted
                  ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-700 dark:text-emerald-300 font-semibold shadow-2xs'
                  : 'bg-[var(--chip-bg)] border-[var(--line)] text-[var(--ink)] hover:border-[var(--app-accent)]/40'
              }`}
              title={care.isCompleted ? `Completed by ${care.completedBy || 'partner'}` : 'Tap to mark completed'}
            >
              <span>{care.icon || '🌿'}</span>
              <span>{care.title}</span>
              {care.isCompleted ? (
                <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600 dark:text-emerald-400" />
              ) : (
                <Circle className="w-3.5 h-3.5 text-[var(--soft)]" />
              )}
            </button>
          ))}
        </div>
      </div>

      {/* ================================================================= */}
      {/* FULL-SCREEN SOLID MODAL: WRITE ANSWER */}
      {/* ================================================================= */}
      {isAnswering && (
        <div className="fixed inset-0 z-50 bg-[var(--bg)] flex flex-col animate-fadeIn">
          {/* Header */}
          <div className="flex items-center justify-between px-4 py-3.5 border-b border-[var(--line)] bg-[var(--white)] shrink-0">
            <button
              type="button"
              onClick={() => setIsAnswering(false)}
              className="p-2 -ml-2 text-[var(--soft)] hover:text-[var(--ink)] transition"
              aria-label="Close"
            >
              <X className="w-5 h-5" />
            </button>
            <span className="text-xs font-bold tracking-wider uppercase text-[var(--terra)]">
              Open Envelope & Answer
            </span>
            <button
              type="button"
              onClick={handleSubmitAnswer}
              disabled={isSubmitting || !answerInput.trim()}
              className="px-4 py-1.5 rounded-full bg-[var(--app-accent)] text-white text-xs font-bold disabled:opacity-40 transition shadow-sm"
            >
              {isSubmitting ? 'Sealing...' : 'Seal & Send'}
            </button>
          </div>

          {/* Body */}
          <div className="flex-1 overflow-y-auto p-4 sm:p-6 max-w-lg mx-auto w-full space-y-4">
            <div className="p-4 rounded-2xl bg-[var(--chip-bg)] border border-[var(--line)]">
              <span className="text-[10px] uppercase font-bold text-[var(--terra)] tracking-wider block mb-1">
                {syncData.vibeTag || 'DAILY SYNC'}
              </span>
              <p className="text-base font-serif italic text-[var(--ink)] leading-relaxed font-normal">
                &ldquo;{syncData.question}&rdquo;
              </p>
            </div>

            <div>
              <label className="block text-xs font-bold text-[var(--ink)] mb-2">
                Your Answer <span className="text-[var(--soft)] font-normal font-sans">(Sealed until both reply)</span>
              </label>
              <textarea
                value={answerInput}
                onChange={(e) => setAnswerInput(e.target.value)}
                placeholder="Speak openly from your heart. Miles disappear when we are real with each other..."
                className="w-full h-44 p-4 rounded-2xl bg-[var(--white)] border border-[var(--line)] focus:outline-none focus:ring-2 focus:ring-[var(--app-accent)] text-sm text-[var(--ink)] placeholder-[var(--soft)] resize-none shadow-2xs"
                autoFocus
              />
            </div>

            <div className="p-3 rounded-xl bg-amber-500/10 border border-amber-500/20 text-amber-800 dark:text-amber-200 text-xs flex items-start gap-2.5">
              <Lock className="w-4 h-4 shrink-0 mt-0.5" />
              <span>
                Your answer is encrypted and sealed. Neither you nor {partner?.nickname || 'your partner'} can see
                each other&rsquo;s answers until both of you have answered!
              </span>
            </div>
          </div>
        </div>
      )}

      {/* ================================================================= */}
      {/* FULL-SCREEN SOLID MODAL: PERSONALIZE / STUDIO */}
      {/* ================================================================= */}
      {showStudioModal && (
        <div className="fixed inset-0 z-50 bg-[var(--bg)] flex flex-col animate-fadeIn">
          {/* Header */}
          <div className="flex items-center justify-between px-4 py-3.5 border-b border-[var(--line)] bg-[var(--white)] shrink-0">
            <button
              type="button"
              onClick={() => setShowStudioModal(false)}
              className="p-2 -ml-2 text-[var(--soft)] hover:text-[var(--ink)] transition"
              aria-label="Close"
            >
              <X className="w-5 h-5" />
            </button>
            <span className="text-xs font-bold tracking-wider uppercase text-[var(--terra)]">
              Personalize Connection
            </span>
            <div className="w-7" />
          </div>

          {/* Subheader Switcher */}
          <div className="flex p-1.5 bg-[var(--chip-bg)] border-b border-[var(--line)] shrink-0">
            <button
              type="button"
              onClick={() => setStudioTab('deck')}
              className={`flex-1 py-1.5 text-xs font-semibold rounded-lg transition ${
                studioTab === 'deck' ? 'bg-[var(--white)] text-[var(--ink)] shadow-2xs' : 'text-[var(--soft)]'
              }`}
            >
              Curated LDR Deck
            </button>
            <button
              type="button"
              onClick={() => setStudioTab('ai')}
              className={`flex-1 py-1.5 text-xs font-semibold rounded-lg transition flex items-center justify-center gap-1 ${
                studioTab === 'ai' ? 'bg-[var(--white)] text-[var(--ink)] shadow-2xs' : 'text-[var(--soft)]'
              }`}
            >
              <Sparkles className="w-3 h-3 text-[var(--app-accent)]" />
              <span>AI Tailored</span>
            </button>
            <button
              type="button"
              onClick={() => setStudioTab('custom')}
              className={`flex-1 py-1.5 text-xs font-semibold rounded-lg transition ${
                studioTab === 'custom' ? 'bg-[var(--white)] text-[var(--ink)] shadow-2xs' : 'text-[var(--soft)]'
              }`}
            >
              Write Custom
            </button>
          </div>

          {/* Content Area */}
          <div className="flex-1 overflow-y-auto p-4 sm:p-6 max-w-lg mx-auto w-full space-y-4">
            {studioTab === 'deck' && (
              <div className="space-y-3">
                <p className="text-xs text-[var(--soft)]">
                  Hand-crafted relationship prompts specially designed to bridge distance, spark vulnerability, and dream together.
                </p>
                {LDR_CURATED_QUESTIONS.map((q, idx) => (
                  <div
                    key={idx}
                    onClick={() => handleSelectCurated(q)}
                    className="p-4 rounded-2xl bg-[var(--white)] border border-[var(--line)] hover:border-[var(--app-accent)] cursor-pointer transition shadow-2xs active:scale-[0.99] space-y-1.5"
                  >
                    <span className="text-[10px] font-bold text-[var(--terra)] tracking-wider uppercase">
                      {q.vibeTag}
                    </span>
                    <p className="text-sm font-serif italic text-[var(--ink)]">&ldquo;{q.question}&rdquo;</p>
                  </div>
                ))}
              </div>
            )}

            {studioTab === 'ai' && (
              <div className="space-y-4">
                <p className="text-xs text-[var(--soft)]">
                  Generate hyper-personalized questions tailored to your relationship duration, mood, and current longing.
                </p>

                {/* Mood Selector */}
                <div>
                  <label className="block text-xs font-bold text-[var(--ink)] mb-1.5">Emotional Tone</label>
                  <div className="grid grid-cols-2 gap-2">
                    {[
                      { id: 'vulnerable', label: '🕯️ Raw Vulnerability' },
                      { id: 'playful', label: '☀️ Playful Banter' },
                      { id: 'nostalgic', label: '🌙 First Times & Memories' },
                      { id: 'philosophical', label: '🌌 Future & Dreams' }
                    ].map((m) => (
                      <button
                        key={m.id}
                        type="button"
                        onClick={() => setSelectedMood(m.id as MoodVibe)}
                        className={`p-2.5 rounded-xl border text-left text-xs font-medium transition ${
                          selectedMood === m.id
                            ? 'bg-[var(--app-accent)]/10 border-[var(--app-accent)] text-[var(--app-accent)] font-bold'
                            : 'bg-[var(--white)] border-[var(--line)] text-[var(--ink)]'
                        }`}
                      >
                        {m.label}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Custom Topic Input */}
                <div>
                  <label className="block text-xs font-bold text-[var(--ink)] mb-1.5">
                    Specific Topic <span className="text-[var(--soft)] font-normal">(optional)</span>
                  </label>
                  <input
                    type="text"
                    value={customTopic}
                    onChange={(e) => setCustomTopic(e.target.value)}
                    placeholder="e.g. Next plane ticket, childhood dreams, late night calls..."
                    className="w-full px-3.5 py-2.5 rounded-xl bg-[var(--white)] border border-[var(--line)] text-xs text-[var(--ink)] placeholder-[var(--soft)] focus:outline-none focus:ring-2 focus:ring-[var(--app-accent)]"
                  />
                </div>

                <button
                  type="button"
                  onClick={handleGenerateAi}
                  disabled={isGeneratingAi}
                  className="w-full py-2.5 rounded-xl bg-[var(--app-accent)] text-white text-xs font-bold transition flex items-center justify-center gap-2 shadow-sm disabled:opacity-50"
                >
                  <Sparkles className="w-4 h-4" />
                  <span>{isGeneratingAi ? 'Generating AI Prompts...' : 'Generate New Questions ✦'}</span>
                </button>

                {/* AI Results */}
                {aiOptions.length > 0 && (
                  <div className="space-y-3 pt-2">
                    <span className="text-xs font-bold text-[var(--ink)]">Tap to pick:</span>
                    {aiOptions.map((opt, idx) => (
                      <div
                        key={idx}
                        onClick={() =>
                          handleSelectCurated({
                            category: selectedMood,
                            vibeTag: `AI GENERATED · ✨`,
                            question: opt.question
                          })
                        }
                        className="p-4 rounded-2xl bg-[var(--white)] border border-[var(--app-accent)]/30 hover:border-[var(--app-accent)] cursor-pointer transition shadow-2xs space-y-1"
                      >
                        <p className="text-sm font-serif italic text-[var(--ink)]">&ldquo;{opt.question}&rdquo;</p>
                        {opt.vibeTag && (
                          <span className="text-[10px] text-[var(--soft)] font-medium">{opt.vibeTag}</span>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}

            {studioTab === 'custom' && (
              <div className="space-y-4">
                <p className="text-xs text-[var(--soft)]">
                  Write a private question specifically for your partner. Both of your answers will remain sealed in the envelope until you both respond!
                </p>

                <div>
                  <label className="block text-xs font-bold text-[var(--ink)] mb-1.5">Question Title / Tag</label>
                  <input
                    type="text"
                    value={customVibeInput}
                    onChange={(e) => setCustomVibeInput(e.target.value)}
                    placeholder="e.g. A SECRET QUESTION · 💌"
                    className="w-full px-3.5 py-2.5 rounded-xl bg-[var(--white)] border border-[var(--line)] text-xs text-[var(--ink)] placeholder-[var(--soft)] focus:outline-none focus:ring-2 focus:ring-[var(--app-accent)]"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-[var(--ink)] mb-1.5">Your Question</label>
                  <textarea
                    value={customQuestionInput}
                    onChange={(e) => setCustomQuestionInput(e.target.value)}
                    placeholder="What is the question you've been wanting to ask?"
                    className="w-full h-32 p-3.5 rounded-xl bg-[var(--white)] border border-[var(--line)] text-xs text-[var(--ink)] placeholder-[var(--soft)] resize-none focus:outline-none focus:ring-2 focus:ring-[var(--app-accent)]"
                  />
                </div>

                <button
                  type="button"
                  onClick={handleSubmitCustomQuestion}
                  disabled={!customQuestionInput.trim()}
                  className="w-full py-2.5 rounded-xl bg-[var(--app-accent)] text-white text-xs font-bold transition shadow-sm disabled:opacity-40"
                >
                  Post Sealed Question to Stage 💌
                </button>
              </div>
            )}
          </div>
        </div>
      )}

      {/* MODAL: ADD CARE ITEM */}
      {isAddingCare && (
        <div className="fixed inset-0 z-50 bg-[var(--bg)]/90 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="w-full max-w-xs rounded-2xl bg-[var(--white)] border border-[var(--line)] p-4 shadow-xl space-y-3">
            <div className="flex items-center justify-between">
              <h4 className="text-xs font-bold text-[var(--ink)]">Add Daily Care Reminder</h4>
              <button
                type="button"
                onClick={() => setIsAddingCare(false)}
                className="text-[var(--soft)] hover:text-[var(--ink)]"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
            <input
              type="text"
              value={newCareTitle}
              onChange={(e) => setNewCareTitle(e.target.value)}
              placeholder="e.g. Drink chamomile tea, stretch..."
              className="w-full px-3 py-2 rounded-xl bg-[var(--chip-bg)] border border-[var(--line)] text-xs text-[var(--ink)] focus:outline-none focus:ring-2 focus:ring-[var(--app-accent)]"
              autoFocus
            />
            <div className="flex justify-end gap-2 pt-1">
              <button
                type="button"
                onClick={() => setIsAddingCare(false)}
                className="px-3 py-1.5 text-xs text-[var(--soft)]"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleAddCareItem}
                disabled={!newCareTitle.trim()}
                className="px-3 py-1.5 rounded-xl bg-[var(--app-accent)] text-white text-xs font-bold disabled:opacity-40"
              >
                Add
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
