import React, { useState, useEffect, useCallback } from 'react'
import { useAuth } from '@/core/auth'
import { useTheme } from '@/core/theme'
import { useToast } from '@/core/toast'
import { getSupabaseClient, formatLocalDate } from '@/core/storage'
import { getFirebaseDb } from '@/core/storage/firebase'
import { doc, setDoc } from 'firebase/firestore'
import { realtimeBridge } from '@/core/realtime'
import confetti from 'canvas-confetti'
import {
  Sparkles,
  HelpCircle,
  Plus,
  RefreshCw,
  Edit3,
  Trash2,
  CheckCircle2,
  Circle,
  Clock,
  Heart,
  MessageCircle,
  Bell,
  X,
  Droplets,
  Pill,
  Utensils,
  Coffee,
  BookOpen
} from 'lucide-react'

export interface DailyCheckinAnswer {
  text: string
  author: string
  answeredAt: string
}

export interface CareCheckItem {
  id: string
  title: string
  scheduledTime?: string
  createdById: string
  createdBy: string
  isCompleted: boolean
  completedAt?: string
  completedBy?: string
}

export interface DailyCheckinContent {
  question: string
  category?: string
  askedBy?: string
  askedById?: string
  askedAt?: string
  answers: Record<string, DailyCheckinAnswer>
  careChecks?: CareCheckItem[]
}

const PRESET_QUESTIONS = [
  { text: 'What made today feel lighter for you?', category: 'Reflection' },
  { text: 'What is one moment today that made you think of me?', category: 'Intimacy' },
  { text: 'How can I take care of you or support you today?', category: 'Care' },
  { text: 'What little thing brought a smile to your face today?', category: 'Sweet' },
  { text: 'If today had a theme song, what would it be?', category: 'Playful' },
  { text: 'What are you most grateful for right now?', category: 'Gratitude' },
  { text: 'What is one dream you had or want to achieve this week?', category: 'Dreams' }
]

const QUICK_CARE_PRESETS = [
  { title: 'Drink water', icon: '💧', defaultTime: '13:00' },
  { title: 'Take daily meds / vitamins', icon: '💊', defaultTime: '09:00' },
  { title: 'Have lunch or dinner', icon: '🥗', defaultTime: '19:30' },
  { title: 'Study or work break', icon: '☕', defaultTime: '16:00' },
  { title: 'Go for a gentle walk', icon: '🌿', defaultTime: '18:00' }
]

export const StageDailyCheckin: React.FC = () => {
  const { user, space, partner } = useAuth()
  const { theme } = useTheme()
  const { showToast } = useToast()

  const spaceId = space?.id || 'default_space'
  const checkinDocId = `checkin_${spaceId}`

  // Main checkin state
  const [checkinData, setCheckinData] = useState<DailyCheckinContent>({
    question: 'What made today feel lighter for you?',
    category: 'Daily Reflection',
    answers: {},
    careChecks: []
  })

  // Modal states
  const [isAnswering, setIsAnswering] = useState(false)
  const [answerInput, setAnswerInput] = useState('')

  const [isAskingCustom, setIsAskingCustom] = useState(false)
  const [customQuestionInput, setCustomQuestionInput] = useState('')
  const [customCategoryInput, setCustomCategoryInput] = useState('Daily Reflection')

  const [isAddingCare, setIsAddingCare] = useState(false)
  const [careTitleInput, setCareTitleInput] = useState('')
  const [careTimeInput, setCareTimeInput] = useState('')

  // Fetch checkin data from Supabase
  const fetchCheckin = useCallback(async () => {
    try {
      const supabase = getSupabaseClient()
      const { data, error } = await supabase
        .from('app_content')
        .select('content')
        .eq('id', checkinDocId)
        .maybeSingle()

      if (error) {
        console.warn('Error fetching checkin:', error.message)
        return
      }

      if (data?.content) {
        const raw = data.content

        // Backward compatibility: If raw is legacy { answer, answeredBy, answeredAt }
        let normalizedAnswers: Record<string, DailyCheckinAnswer> = {}
        if (raw.answers && typeof raw.answers === 'object') {
          normalizedAnswers = raw.answers
        } else if (raw.answer && typeof raw.answer === 'string') {
          const fallbackKey = user?.id || 'legacy_partner'
          normalizedAnswers[fallbackKey] = {
            text: raw.answer,
            author: raw.answeredBy || 'You',
            answeredAt: raw.answeredAt || new Date().toISOString()
          }
        }

        setCheckinData({
          question: raw.question || 'What made today feel lighter for you?',
          category: raw.category || 'Daily Reflection',
          askedBy: raw.askedBy,
          askedById: raw.askedById,
          askedAt: raw.askedAt,
          answers: normalizedAnswers,
          careChecks: Array.isArray(raw.careChecks) ? raw.careChecks : []
        })
      }
    } catch (err) {
      console.warn('Error in fetchCheckin:', err)
    }
  }, [checkinDocId, user?.id])

  useEffect(() => {
    fetchCheckin()

    const supabase = getSupabaseClient()
    const channel = supabase
      .channel(`checkin_chan_${spaceId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'app_content',
          filter: `id=eq.${checkinDocId}`
        },
        () => {
          fetchCheckin()
        }
      )
      .subscribe()

    // Realtime WebSocket listener
    const unsubBridge = realtimeBridge.subscribe((event) => {
      if (event.type === 'CHECKIN_ANSWERED' || event.type === 'CARE_CHECK_UPDATED') {
        fetchCheckin()
        if (event.senderId !== user?.id && event.data?.message) {
          showToast(event.data.message)
        }
      }
    })

    return () => {
      supabase.removeChannel(channel)
      unsubBridge()
    }
  }, [spaceId, checkinDocId, fetchCheckin, user?.id, showToast])

  // Sync to database and peer bridge
  const syncCheckin = async (
    updated: DailyCheckinContent,
    broadcastType: 'CHECKIN_ANSWERED' | 'CARE_CHECK_UPDATED',
    notificationMsg?: string
  ) => {
    setCheckinData(updated)
    try {
      const supabase = getSupabaseClient()
      const nowIso = new Date().toISOString()
      await supabase.from('app_content').upsert({
        id: checkinDocId,
        content: updated,
        updated_at: nowIso
      })

      const db = getFirebaseDb()
      if (db && spaceId) {
        try {
          await setDoc(doc(db, 'spaces', spaceId, 'features', 'checkin'), updated, { merge: true })
        } catch {}
      }

      await realtimeBridge.broadcast({
        type: broadcastType,
        senderId: user?.id || '',
        senderNickname: user?.nickname || 'Partner',
        timestamp: Date.now(),
        data: { message: notificationMsg }
      })
    } catch (err) {
      console.warn('Error syncing checkin to backend:', err)
    }
  }

  // Cycle / Shuffle Preset Question
  const handleShuffleQuestion = async () => {
    const currentIndex = PRESET_QUESTIONS.findIndex((q) => q.text === checkinData.question)
    const nextIndex = (currentIndex + 1) % PRESET_QUESTIONS.length
    const nextPreset = PRESET_QUESTIONS[nextIndex]

    const updated: DailyCheckinContent = {
      ...checkinData,
      question: nextPreset.text,
      category: nextPreset.category,
      askedBy: undefined,
      askedById: undefined,
      askedAt: undefined
    }

    showToast('Question refreshed for today ✦')
    await syncCheckin(updated, 'CHECKIN_ANSWERED', `${user?.nickname || 'Partner'} changed the daily question.`)
  }

  // Ask Custom Question
  const handleSaveCustomQuestion = async () => {
    if (!customQuestionInput.trim() || !user) return

    const updated: DailyCheckinContent = {
      ...checkinData,
      question: customQuestionInput.trim(),
      category: customCategoryInput.trim() || 'Custom Question',
      askedBy: user.nickname,
      askedById: user.id,
      askedAt: new Date().toISOString(),
      // Keep existing care checks
      careChecks: checkinData.careChecks || []
    }

    setIsAskingCustom(false)
    setCustomQuestionInput('')
    confetti({ particleCount: 25, spread: 50, origin: { y: 0.7 } })
    showToast('Your custom question has been posted to both of you!')

    await syncCheckin(
      updated,
      'CHECKIN_ANSWERED',
      `${user.nickname} asked a new question: "${customQuestionInput.trim().slice(0, 35)}..."`
    )
  }

  // Answer question (only current user's key)
  const handleSaveAnswer = async () => {
    if (!answerInput.trim() || !user) return

    const nowIso = new Date().toISOString()
    const updatedAnswers = {
      ...(checkinData.answers || {}),
      [user.id]: {
        text: answerInput.trim(),
        author: user.nickname || 'You',
        answeredAt: nowIso
      }
    }

    const updated: DailyCheckinContent = {
      ...checkinData,
      answers: updatedAnswers
    }

    setIsAnswering(false)
    confetti({ particleCount: 30, spread: 60, origin: { y: 0.6 } })
    showToast('Your answer has been saved!')

    await syncCheckin(
      updated,
      'CHECKIN_ANSWERED',
      `${user.nickname} answered today's check-in question 💕`
    )
  }

  // Delete current user's own answer
  const handleDeleteMyAnswer = async () => {
    if (!user) return
    if (!window.confirm('Delete your answer?')) return

    const updatedAnswers = { ...(checkinData.answers || {}) }
    delete updatedAnswers[user.id]

    const updated: DailyCheckinContent = {
      ...checkinData,
      answers: updatedAnswers
    }

    showToast('Your answer was deleted.')
    await syncCheckin(updated, 'CHECKIN_ANSWERED')
  }

  // Add Care Check
  const handleSaveCareCheck = async () => {
    if (!careTitleInput.trim() || !user) return

    const newCare: CareCheckItem = {
      id: `care_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      title: careTitleInput.trim(),
      scheduledTime: careTimeInput || undefined,
      createdById: user.id,
      createdBy: user.nickname || 'Partner',
      isCompleted: false
    }

    const updated: DailyCheckinContent = {
      ...checkinData,
      careChecks: [...(checkinData.careChecks || []), newCare]
    }

    setIsAddingCare(false)
    setCareTitleInput('')
    setCareTimeInput('')
    showToast('Scheduled care reminder added!')

    await syncCheckin(
      updated,
      'CARE_CHECK_UPDATED',
      `${user.nickname} added a care check: "${newCare.title}"`
    )
  }

  // Toggle Care Check Completion
  const handleToggleCareCheck = async (careId: string) => {
    if (!user) return

    const nowTimeStr = new Date().toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
    let completedTitle = ''
    let isNowCompleted = false

    const updatedCareList = (checkinData.careChecks || []).map((c) => {
      if (c.id === careId) {
        const nextState = !c.isCompleted
        isNowCompleted = nextState
        completedTitle = c.title
        return {
          ...c,
          isCompleted: nextState,
          completedAt: nextState ? nowTimeStr : undefined,
          completedBy: nextState ? user.nickname : undefined
        }
      }
      return c
    })

    const updated: DailyCheckinContent = {
      ...checkinData,
      careChecks: updatedCareList
    }

    if (isNowCompleted) {
      try {
        if (navigator.vibrate) navigator.vibrate([25, 50, 25])
      } catch {}
      confetti({ particleCount: 20, spread: 45, origin: { y: 0.65 } })
      showToast(`Marked "${completedTitle}" as completed! ✨`)
    } else {
      showToast(`Unchecked "${completedTitle}".`)
    }

    await syncCheckin(
      updated,
      'CARE_CHECK_UPDATED',
      isNowCompleted ? `${user.nickname} completed: "${completedTitle}" ✅` : undefined
    )
  }

  // Delete Care Check
  const handleDeleteCareCheck = async (careId: string) => {
    const updated: DailyCheckinContent = {
      ...checkinData,
      careChecks: (checkinData.careChecks || []).filter((c) => c.id !== careId)
    }
    showToast('Care check removed.')
    await syncCheckin(updated, 'CARE_CHECK_UPDATED')
  }

  // Answers extraction
  const myAnswer = user?.id ? checkinData.answers?.[user.id] : undefined
  const partnerAnswer = partner?.id ? checkinData.answers?.[partner.id] : undefined

  return (
    <div className="w-full rounded-2xl sm:rounded-3xl p-4 sm:p-5 border border-[var(--line)] bg-[var(--white)] shadow-xs transition-all my-4 space-y-4">
      {/* 1. Header Row */}
      <div className="flex items-center justify-between gap-2 border-b border-[var(--line)]/60 pb-3">
        <div className="flex items-center gap-2">
          <span className="w-7 h-7 rounded-full bg-[var(--app-accent)]/10 text-[var(--app-accent)] flex items-center justify-center shrink-0">
            <Sparkles className="w-3.5 h-3.5" />
          </span>
          <div>
            <div className="flex items-center gap-1.5">
              <span className="text-[10px] uppercase font-mono tracking-wider font-semibold text-[var(--app-accent)]">
                Daily Check-In
              </span>
              <span className="px-1.5 py-0.5 rounded-full bg-[var(--paper)] text-[9px] font-medium text-[var(--soft)] border border-[var(--line)]">
                {checkinData.category || 'Intimacy'}
              </span>
            </div>
            {checkinData.askedBy && (
              <p className="text-[10px] text-[var(--soft)] mt-0.5">
                Asked by <span className="font-medium text-[var(--ink)]">{checkinData.askedBy}</span>
              </p>
            )}
          </div>
        </div>

        {/* Action Buttons: Shuffle Preset & Ask Custom */}
        <div className="flex items-center gap-1.5 shrink-0">
          <button
            type="button"
            onClick={handleShuffleQuestion}
            className="w-7 h-7 rounded-full bg-[var(--paper)] hover:bg-[var(--line)]/60 text-[var(--soft)] hover:text-[var(--ink)] flex items-center justify-center border border-[var(--line)] active:scale-90 transition cursor-pointer"
            title="Shuffle daily question"
          >
            <RefreshCw className="w-3 h-3" />
          </button>
          <button
            type="button"
            onClick={() => {
              setCustomQuestionInput('')
              setIsAskingCustom(true)
            }}
            className="flex items-center gap-1 px-2.5 py-1 rounded-full bg-[var(--paper)] hover:bg-[var(--line)]/60 text-[10.5px] font-medium text-[var(--ink)] border border-[var(--line)] active:scale-95 transition cursor-pointer"
            title="Ask your partner a custom question"
          >
            <Plus className="w-3 h-3 text-[var(--app-accent)]" />
            <span>Ask ＋</span>
          </button>
        </div>
      </div>

      {/* 2. Persistent Question Display (NEVER disappears when answered) */}
      <div className="py-1">
        <h3 className="font-serif text-base sm:text-lg font-medium text-[var(--ink)] leading-snug">
          “{checkinData.question}”
        </h3>
      </div>

      {/* 3. Dual Partner Answer Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-1">
        {/* Your Answer Card */}
        <div className="p-3.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] flex flex-col justify-between min-h-[92px] transition">
          <div className="flex items-center justify-between gap-1 mb-1.5">
            <div className="flex items-center gap-1.5">
              <span className="w-2 h-2 rounded-full bg-emerald-500" />
              <span className="text-[10.5px] font-semibold text-[var(--ink)]">You</span>
            </div>
            {myAnswer && (
              <div className="flex items-center gap-1">
                <span className="text-[9px] text-[var(--soft)]">
                  {formatLocalDate(myAnswer.answeredAt, { hour: 'numeric', minute: '2-digit' })}
                </span>
                <button
                  type="button"
                  onClick={() => {
                    setAnswerInput(myAnswer.text)
                    setIsAnswering(true)
                  }}
                  className="p-1 hover:text-[var(--app-accent)] text-[var(--soft)] transition cursor-pointer"
                  title="Edit your answer"
                >
                  <Edit3 className="w-3 h-3" />
                </button>
                <button
                  type="button"
                  onClick={handleDeleteMyAnswer}
                  className="p-1 hover:text-red-500 text-[var(--soft)] transition cursor-pointer"
                  title="Delete your answer"
                >
                  <Trash2 className="w-3 h-3" />
                </button>
              </div>
            )}
          </div>

          {myAnswer ? (
            <p className="font-serif italic text-xs text-[var(--ink)] leading-relaxed">
              “{myAnswer.text}”
            </p>
          ) : (
            <button
              type="button"
              onClick={() => {
                setAnswerInput('')
                setIsAnswering(true)
              }}
              className="w-full py-2.5 px-3 border border-dashed border-[var(--app-accent)]/50 rounded-lg text-center text-xs font-medium text-[var(--app-accent)] hover:bg-[var(--app-accent)]/5 transition active:scale-[0.98] cursor-pointer"
            >
              ＋ Tap to share your answer
            </button>
          )}
        </div>

        {/* Partner's Answer Card */}
        <div className="p-3.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] flex flex-col justify-between min-h-[92px] transition">
          <div className="flex items-center justify-between gap-1 mb-1.5">
            <div className="flex items-center gap-1.5">
              <span className="w-2 h-2 rounded-full bg-rose-400" />
              <span className="text-[10.5px] font-semibold text-[var(--ink)]">
                {partner?.nickname || 'Partner'}
              </span>
            </div>
            {partnerAnswer && (
              <span className="text-[9px] text-[var(--soft)]">
                {formatLocalDate(partnerAnswer.answeredAt, { hour: 'numeric', minute: '2-digit' })}
              </span>
            )}
          </div>

          {partnerAnswer ? (
            <div>
              <p className="font-serif italic text-xs text-[var(--ink)] leading-relaxed">
                “{partnerAnswer.text}”
              </p>
              <div className="flex justify-end mt-2">
                <button
                  type="button"
                  onClick={() => {
                    confetti({ particleCount: 20, spread: 45, origin: { y: 0.6 } })
                    showToast(`Heart sent to ${partner?.nickname || 'partner'} 💕`)
                  }}
                  className="inline-flex items-center gap-1 text-[9.5px] text-rose-500 hover:text-rose-600 font-medium cursor-pointer"
                >
                  <Heart className="w-2.5 h-2.5 fill-current" />
                  <span>Loved this</span>
                </button>
              </div>
            </div>
          ) : (
            <div className="py-2 text-center">
              <p className="text-[11px] text-[var(--soft)] italic">
                Waiting for {partner?.nickname || 'partner'} to answer...
              </p>
            </div>
          )}
        </div>
      </div>

      {/* 4. Scheduled Care Check Series (Water, Meds, Meals, Study) */}
      <div className="pt-2 border-t border-[var(--line)]/60">
        <div className="flex items-center justify-between mb-2.5">
          <div className="flex items-center gap-1.5">
            <Clock className="w-3.5 h-3.5 text-[var(--app-accent)]" />
            <span className="text-[11px] font-semibold text-[var(--ink)]">
              Scheduled Care Checks
            </span>
            <span className="text-[9.5px] text-[var(--soft)] font-mono">
              ({(checkinData.careChecks || []).filter((c) => c.isCompleted).length}/{(checkinData.careChecks || []).length})
            </span>
          </div>

          <button
            type="button"
            onClick={() => {
              setCareTitleInput('')
              setCareTimeInput('')
              setIsAddingCare(true)
            }}
            className="inline-flex items-center gap-1 text-[10.5px] text-[var(--app-accent)] font-medium hover:underline cursor-pointer"
          >
            <Plus className="w-3 h-3" />
            <span>Add Check</span>
          </button>
        </div>

        {/* Care Checks List */}
        {checkinData.careChecks && checkinData.careChecks.length > 0 ? (
          <div className="space-y-2">
            {checkinData.careChecks.map((care) => {
              const isCreator = user?.id === care.createdById
              return (
                <div
                  key={care.id}
                  className={`flex items-center justify-between p-2.5 rounded-xl border transition-all ${
                    care.isCompleted
                      ? 'bg-emerald-500/5 border-emerald-500/20 text-[var(--ink)]'
                      : 'bg-[var(--paper)] border-[var(--line)]'
                  }`}
                >
                  {/* Left: Checkmark & Title */}
                  <div
                    className="flex items-center gap-2.5 min-w-0 cursor-pointer flex-1"
                    onClick={() => handleToggleCareCheck(care.id)}
                  >
                    <button
                      type="button"
                      className="shrink-0 transition-transform active:scale-80 cursor-pointer"
                      title={care.isCompleted ? 'Mark incomplete' : 'Mark completed'}
                    >
                      {care.isCompleted ? (
                        <CheckCircle2 className="w-4 h-4 text-emerald-600 fill-emerald-100 dark:fill-emerald-950" />
                      ) : (
                        <Circle className="w-4 h-4 text-[var(--soft)]" />
                      )}
                    </button>
                    <div className="min-w-0">
                      <p
                        className={`text-xs font-medium truncate ${
                          care.isCompleted ? 'line-through opacity-70 text-[var(--soft)]' : 'text-[var(--ink)]'
                        }`}
                      >
                        {care.title}
                      </p>
                      <div className="flex items-center gap-2 text-[9px] text-[var(--soft)] mt-0.5">
                        {care.scheduledTime && (
                          <span className="font-mono bg-[var(--white)] px-1 py-0.2 rounded border border-[var(--line)]">
                            ⏰ {care.scheduledTime}
                          </span>
                        )}
                        {care.isCompleted ? (
                          <span className="text-emerald-600 font-medium">
                            Done by {care.completedBy || 'You'} at {care.completedAt}
                          </span>
                        ) : (
                          <span>Added by {care.createdBy}</span>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Right: Delete button (Creator only or either partner) */}
                  {(isCreator || !care.createdById) && (
                    <button
                      type="button"
                      onClick={() => handleDeleteCareCheck(care.id)}
                      className="p-1 hover:text-red-500 text-[var(--soft)] transition cursor-pointer shrink-0 ml-2"
                      title="Remove care check"
                    >
                      <Trash2 className="w-3 h-3" />
                    </button>
                  )}
                </div>
              )
            })}
          </div>
        ) : (
          <div className="py-2.5 px-3 rounded-xl bg-[var(--paper)] border border-dashed border-[var(--line)] text-center">
            <p className="text-[11px] text-[var(--soft)]">
              No care checks set for today. Schedule water, meds, or meal reminders for each other!
            </p>
          </div>
        )}
      </div>

      {/* MODAL 1: Answer Check-in */}
      {isAnswering && (
        <div
          className="modal-backdrop"
          onClick={(e) => {
            if (e.target === e.currentTarget) setIsAnswering(false)
          }}
        >
          <div className="modal">
            <div className="modal-handle" />
            <button
              type="button"
              className="close"
              onClick={() => setIsAnswering(false)}
            >
              ×
            </button>
            <div className="modal-date">DAILY CHECK-IN</div>
            <h3>“{checkinData.question}”</h3>
            <p style={{ fontStyle: 'normal', fontSize: '11px', color: '#777a76', marginBottom: '12px' }}>
              Your answer will appear on your shared sanctuary board.
            </p>
            <textarea
              rows={3}
              value={answerInput}
              onChange={(e) => setAnswerInput(e.target.value)}
              placeholder="Speak from your heart..."
              className="w-full p-3 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] text-xs font-serif italic outline-none resize-none leading-relaxed"
              autoFocus
            />
            <div className="flex gap-2 mt-4">
              <button
                type="button"
                onClick={() => setIsAnswering(false)}
                className="py-2.5 px-4 rounded-xl border border-[var(--line)] text-xs text-[var(--soft)] hover:bg-[var(--line)]/30 transition cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleSaveAnswer}
                className="flex-1 py-2.5 rounded-xl bg-[var(--app-accent)] text-white text-xs font-medium cursor-pointer hover:opacity-90"
              >
                Save Answer
              </button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL 2: Ask Custom Question */}
      {isAskingCustom && (
        <div
          className="modal-backdrop"
          onClick={(e) => {
            if (e.target === e.currentTarget) setIsAskingCustom(false)
          }}
        >
          <div className="modal">
            <div className="modal-handle" />
            <button
              type="button"
              className="close"
              onClick={() => setIsAskingCustom(false)}
            >
              ×
            </button>
            <div className="modal-date">CUSTOM PROMPT</div>
            <h3>Ask Your Partner</h3>
            <p style={{ fontStyle: 'normal', fontSize: '11px', color: '#777a76', marginBottom: '12px' }}>
              Pose a question you want both of you to answer today.
            </p>
            <textarea
              rows={2}
              value={customQuestionInput}
              onChange={(e) => setCustomQuestionInput(e.target.value)}
              placeholder="e.g. What is your favourite memory of us this month?"
              className="w-full p-3 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] text-xs font-serif outline-none resize-none leading-relaxed mb-3"
              autoFocus
            />
            <div className="space-y-1.5 mb-4">
              <label className="text-[10px] uppercase font-mono tracking-wider text-[var(--soft)]">
                Category
              </label>
              <div className="flex flex-wrap gap-1.5">
                {['Reflection', 'Intimacy', 'Fun & Silly', 'Gratitude', 'Future Plans'].map((cat) => (
                  <button
                    key={cat}
                    type="button"
                    onClick={() => setCustomCategoryInput(cat)}
                    className={`px-2.5 py-1 rounded-full text-[10px] font-medium border transition cursor-pointer ${
                      customCategoryInput === cat
                        ? 'bg-[var(--app-accent)] text-white border-[var(--app-accent)]'
                        : 'bg-[var(--paper)] text-[var(--ink)] border-[var(--line)]'
                    }`}
                  >
                    {cat}
                  </button>
                ))}
              </div>
            </div>
            <div className="flex gap-2">
              <button
                type="button"
                onClick={() => setIsAskingCustom(false)}
                className="py-2.5 px-4 rounded-xl border border-[var(--line)] text-xs text-[var(--soft)] hover:bg-[var(--line)]/30 transition cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleSaveCustomQuestion}
                className="flex-1 py-2.5 rounded-xl bg-[var(--app-accent)] text-white text-xs font-medium cursor-pointer hover:opacity-90"
              >
                Set Today's Question
              </button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL 3: Add Care Check Reminder */}
      {isAddingCare && (
        <div
          className="modal-backdrop"
          onClick={(e) => {
            if (e.target === e.currentTarget) setIsAddingCare(false)
          }}
        >
          <div className="modal">
            <div className="modal-handle" />
            <button
              type="button"
              className="close"
              onClick={() => setIsAddingCare(false)}
            >
              ×
            </button>
            <div className="modal-date">CARE CHECK REMINDER</div>
            <h3>Add a Care Check</h3>
            <p style={{ fontStyle: 'normal', fontSize: '11px', color: '#777a76', marginBottom: '12px' }}>
              Schedule a daily care reminder for water, medicines, meals, or study check-in.
            </p>

            {/* Quick Presets */}
            <div className="space-y-1.5 mb-3">
              <label className="text-[10px] uppercase font-mono tracking-wider text-[var(--soft)]">
                Quick Presets
              </label>
              <div className="flex flex-wrap gap-1.5">
                {QUICK_CARE_PRESETS.map((p) => (
                  <button
                    key={p.title}
                    type="button"
                    onClick={() => {
                      setCareTitleInput(`${p.icon} ${p.title}`)
                      setCareTimeInput(p.defaultTime)
                    }}
                    className="px-2.5 py-1 rounded-full text-[10px] font-medium bg-[var(--paper)] hover:bg-[var(--line)]/40 text-[var(--ink)] border border-[var(--line)] transition cursor-pointer"
                  >
                    {p.icon} {p.title}
                  </button>
                ))}
              </div>
            </div>

            <div className="space-y-3 mb-4">
              <div>
                <label className="text-[10px] uppercase font-mono tracking-wider text-[var(--soft)] block mb-1">
                  Reminder Title
                </label>
                <input
                  type="text"
                  value={careTitleInput}
                  onChange={(e) => setCareTitleInput(e.target.value)}
                  placeholder="e.g. 💧 Drink 500ml water"
                  className="w-full p-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] text-xs outline-none"
                  autoFocus
                />
              </div>

              <div>
                <label className="text-[10px] uppercase font-mono tracking-wider text-[var(--soft)] block mb-1">
                  Scheduled Time (Optional)
                </label>
                <input
                  type="time"
                  value={careTimeInput}
                  onChange={(e) => setCareTimeInput(e.target.value)}
                  className="w-full p-2 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] text-xs outline-none font-mono"
                />
              </div>
            </div>

            <div className="flex gap-2">
              <button
                type="button"
                onClick={() => setIsAddingCare(false)}
                className="py-2.5 px-4 rounded-xl border border-[var(--line)] text-xs text-[var(--soft)] hover:bg-[var(--line)]/30 transition cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleSaveCareCheck}
                className="flex-1 py-2.5 rounded-xl bg-[var(--app-accent)] text-white text-xs font-medium cursor-pointer hover:opacity-90"
              >
                Add Reminder
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
