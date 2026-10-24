import React, { useState, useEffect } from 'react'
import { useAuth } from '@/core/auth'
import { useTheme } from '@/core/theme'
import { useToast } from '@/core/toast'
import { getSupabaseClient } from '@/core/storage/supabase'
import { getFirebaseDb } from '@/core/storage/firebase'
import { doc, getDoc, setDoc } from 'firebase/firestore'
import { realtimeBridge } from '@/core/realtime'
import { triggerNativeNotification } from '@/core/notifications'
import confetti from 'canvas-confetti'
import {
  X,
  Plus,
  Check,
  Calendar,
  Sparkles,
  Heart,
  Trash2,
  Trophy,
  Target,
  ChevronRight
} from 'lucide-react'

export interface CoupleGoalItem {
  id: string
  title: string
  icon: string
  category: 'firsts' | 'future'
  completedDate?: string
  targetDate?: string
  note?: string
  isCompleted: boolean
  completedBy?: string
}

const DEFAULT_PRESET_GOALS: Omit<CoupleGoalItem, 'id'>[] = [
  {
    title: 'Met Each Other',
    icon: '🌸',
    category: 'firsts',
    isCompleted: false
  },
  {
    title: 'First Date',
    icon: '☕',
    category: 'firsts',
    isCompleted: false
  },
  {
    title: 'Kissed First Time',
    icon: '🕊️',
    category: 'firsts',
    isCompleted: false
  },
  {
    title: 'First Trip Together',
    icon: '✈️',
    category: 'firsts',
    isCompleted: false
  },
  {
    title: 'Said "I Love You"',
    icon: '💌',
    category: 'firsts',
    isCompleted: false
  },
  {
    title: 'Moved in Together',
    icon: '🏡',
    category: 'future',
    isCompleted: false
  },
  {
    title: 'Got Engaged',
    icon: '💍',
    category: 'future',
    isCompleted: false
  }
]

interface GoalTrackerModalProps {
  isOpen: boolean
  onClose: () => void
  daysTogether: number
  startDate: Date
  onUpdateAnniversary?: (dateStr: string) => void
}

export const GoalTrackerModal: React.FC<GoalTrackerModalProps> = ({
  isOpen,
  onClose,
  daysTogether,
  startDate,
  onUpdateAnniversary
}) => {
  const { user, space, partner } = useAuth()
  const { theme } = useTheme()
  const { showToast } = useToast()

  const [goals, setGoals] = useState<CoupleGoalItem[]>([])
  const [activeTab, setActiveTab] = useState<'all' | 'firsts' | 'future'>('all')
  const [isAddingCustom, setIsAddingCustom] = useState(false)
  const [newTitle, setNewTitle] = useState('')
  const [newIcon, setNewIcon] = useState('✨')
  const [newCategory, setNewCategory] = useState<'firsts' | 'future'>('future')
  const [newTargetDate, setNewTargetDate] = useState('')
  const [isEditingAnniversary, setIsEditingAnniversary] = useState(false)
  const [annivInput, setAnnivInput] = useState(() => startDate.toISOString().split('T')[0])

  const spaceId = space?.id || 'default_space'
  const goalsDocId = `couple_goals_${spaceId}`

  // 1. Fetch Goals from Supabase / Firestore
  useEffect(() => {
    if (!isOpen) return

    const fetchGoals = async () => {
      const supabase = getSupabaseClient()
      const db = getFirebaseDb()

      try {
        const { data } = await supabase
          .from('app_content')
          .select('content')
          .eq('id', goalsDocId)
          .maybeSingle()

        if (data?.content && Array.isArray(data.content) && data.content.length > 0) {
          setGoals(data.content)
          return
        }

        // Firestore fallback
        if (db && spaceId) {
          const snap = await getDoc(doc(db, 'spaces', spaceId, 'features', 'couple_goals'))
          if (snap.exists() && Array.isArray(snap.data()?.goals)) {
            setGoals(snap.data().goals)
            return
          }
        }

        // Initialize with default preset goals
        const initial = DEFAULT_PRESET_GOALS.map((g, idx) => ({
          ...g,
          id: `preset_${idx}_${Date.now()}`
        }))
        setGoals(initial)
      } catch (err) {
        console.warn('Error fetching goals:', err)
      }
    }

    fetchGoals()
  }, [isOpen, spaceId, goalsDocId])

  if (!isOpen) return null

  // Save goals state to cloud
  const saveGoals = async (updated: CoupleGoalItem[]) => {
    setGoals(updated)
    const supabase = getSupabaseClient()
    const db = getFirebaseDb()

    try {
      await supabase.from('app_content').upsert({
        id: goalsDocId,
        content: updated,
        updated_at: new Date().toISOString()
      })

      if (db && spaceId) {
        await setDoc(
          doc(db, 'spaces', spaceId, 'features', 'couple_goals'),
          { goals: updated, updatedAt: new Date().toISOString() },
          { merge: true }
        )
      }

      await realtimeBridge.broadcast({
        type: 'NOTIFICATION_TRIGGER',
        senderId: user?.id || 'me',
        senderNickname: user?.nickname || 'Partner',
        timestamp: Date.now(),
        data: {
          title: '✨ Relationship Goal Updated',
          body: `${user?.nickname || 'Your partner'} updated your couple goals.`
        }
      })
    } catch (err) {
      console.warn('Error saving goals:', err)
    }
  }

  // Toggle Goal Completed
  const handleToggleGoal = async (goal: CoupleGoalItem) => {
    const isNowCompleted = !goal.isCompleted
    const todayStr = new Date().toISOString().split('T')[0]

    const updated = goals.map((g) => {
      if (g.id === goal.id) {
        return {
          ...g,
          isCompleted: isNowCompleted,
          completedDate: isNowCompleted ? g.completedDate || todayStr : undefined,
          completedBy: isNowCompleted ? user?.nickname : undefined
        }
      }
      return g
    })

    if (isNowCompleted) {
      confetti({
        particleCount: 45,
        spread: 60,
        origin: { y: 0.5 }
      })
      showToast(`🎉 "${goal.title}" completed together!`)
      triggerNativeNotification({
        title: `🎉 Goal Completed: ${goal.title}`,
        body: 'A special milestone was unlocked in your couple journey!'
      })
    }

    await saveGoals(updated)
  }

  // Add Custom Goal
  const handleAddCustomGoal = async () => {
    if (!newTitle.trim()) return

    const newGoal: CoupleGoalItem = {
      id: `goal_${Date.now()}`,
      title: newTitle.trim(),
      icon: newIcon.trim() || '✨',
      category: newCategory,
      targetDate: newTargetDate || undefined,
      isCompleted: false
    }

    const updated = [...goals, newGoal]
    await saveGoals(updated)

    setNewTitle('')
    setNewTargetDate('')
    setIsAddingCustom(false)
    showToast('New relationship goal added! ✨')
  }

  // Delete Goal
  const handleDeleteGoal = async (id: string) => {
    const updated = goals.filter((g) => g.id !== id)
    await saveGoals(updated)
    showToast('Goal removed.')
  }

  // Save Anniversary Date
  const handleSaveAnniversary = () => {
    if (annivInput && onUpdateAnniversary) {
      onUpdateAnniversary(annivInput)
      showToast('Anniversary date updated!')
      setIsEditingAnniversary(false)
    }
  }

  const filteredGoals = goals.filter((g) => {
    if (activeTab === 'firsts') return g.category === 'firsts'
    if (activeTab === 'future') return g.category === 'future'
    return true
  })

  const completedCount = goals.filter((g) => g.isCompleted).length

  return (
    <div
      className="fixed inset-0 z-[9999] flex flex-col overflow-hidden"
      style={{
        backgroundColor: theme.bg,
        color: theme.textPrimary
      }}
    >
      {/* Top Header Bar */}
      <div className="pt-safe px-4 py-3 flex items-center justify-between border-b border-[var(--line)] bg-[var(--white)] shrink-0">
        <button
          type="button"
          onClick={onClose}
          className="p-1.5 -ml-1.5 rounded-full cursor-pointer hover:bg-[var(--paper)] transition flex items-center gap-1.5 text-xs font-medium text-[var(--ink)]"
        >
          <X className="w-4 h-4" />
          <span>Close</span>
        </button>
        <div className="text-center">
          <h3 className="text-sm font-semibold tracking-tight">Our Story & Goals</h3>
        </div>
        <div className="w-12" />
      </div>

      <div className="flex-1 overflow-y-auto px-4 py-6 max-w-md mx-auto w-full space-y-4">

        {/* 1. Relationship Days Counter Hero Banner (Image 1 Style) */}
        <div
          className="p-6 rounded-3xl border shadow-md text-center space-y-2"
          style={{
            backgroundColor: theme.surface,
            borderColor: theme.surfaceBorder
          }}
        >
          <div
            className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full shadow-2xs border text-[11px] font-semibold text-rose-600"
            style={{
              backgroundColor: theme.badgeBg,
              borderColor: theme.surfaceBorder
            }}
          >
            <Heart className="w-3.5 h-3.5 fill-rose-500 text-rose-500" />
            <span>Been Together</span>
          </div>

          <div className="text-4xl font-extrabold tracking-tight">
            {daysTogether} Days
          </div>

          {isEditingAnniversary ? (
            <div className="flex items-center justify-center gap-2 pt-1">
              <input
                type="date"
                value={annivInput}
                onChange={(e) => setAnnivInput(e.target.value)}
                className="text-xs p-1.5 rounded-xl border border-[var(--line)] bg-[var(--white)] text-[var(--ink)]"
              />
              <button
                type="button"
                onClick={handleSaveAnniversary}
                className="text-xs px-2.5 py-1.5 rounded-xl bg-[var(--app-accent)] text-white font-medium cursor-pointer"
              >
                Save
              </button>
            </div>
          ) : (
            <p
              onClick={() => setIsEditingAnniversary(true)}
              className="text-xs text-[var(--soft)] cursor-pointer hover:underline flex items-center justify-center gap-1"
              title="Tap to change anniversary date"
            >
              <Calendar className="w-3 h-3 text-[var(--soft)]" />
              <span>Since {startDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })} ✎</span>
            </p>
          )}

          {/* Quick Stats Pill */}
          <div className="pt-2 flex justify-center gap-3 text-[11px]">
            <span className="text-[var(--soft)]">
              Completed: <b className="text-[var(--ink)]">{completedCount} of {goals.length}</b>
            </span>
          </div>
        </div>

        {/* 2. Category Tabs */}
        <div className="grid grid-cols-3 p-1 rounded-2xl bg-[var(--paper)] border border-[var(--line)] text-xs font-medium">
          <button
            type="button"
            onClick={() => setActiveTab('all')}
            className={`py-1.5 rounded-xl transition cursor-pointer ${
              activeTab === 'all'
                ? 'bg-[var(--white)] text-[var(--ink)] shadow-2xs font-semibold'
                : 'text-[var(--soft)] hover:text-[var(--ink)]'
            }`}
          >
            All Goals
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('firsts')}
            className={`py-1.5 rounded-xl transition cursor-pointer ${
              activeTab === 'firsts'
                ? 'bg-[var(--white)] text-[var(--ink)] shadow-2xs font-semibold'
                : 'text-[var(--soft)] hover:text-[var(--ink)]'
            }`}
          >
            Our Firsts 🌸
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('future')}
            className={`py-1.5 rounded-xl transition cursor-pointer ${
              activeTab === 'future'
                ? 'bg-[var(--white)] text-[var(--ink)] shadow-2xs font-semibold'
                : 'text-[var(--soft)] hover:text-[var(--ink)]'
            }`}
          >
            Future Dreams ✨
          </button>
        </div>

        {/* 3. Goals List */}
        <div className="space-y-2.5 max-h-[46vh] overflow-y-auto pr-1">
          {filteredGoals.map((goal) => (
            <div
              key={goal.id}
              className={`p-3.5 rounded-2xl border transition-all duration-200 flex items-center justify-between gap-3 shadow-xs ${
                goal.isCompleted
                  ? 'bg-emerald-500/10 border-emerald-500/30'
                  : ''
              }`}
              style={{
                backgroundColor: goal.isCompleted ? undefined : theme.surface,
                borderColor: goal.isCompleted ? undefined : theme.surfaceBorder
              }}
            >
              <div className="flex items-center gap-3 min-w-0 flex-1">
                <div
                  className={`w-10 h-10 rounded-2xl flex items-center justify-center text-lg shrink-0 border ${
                    goal.isCompleted
                      ? 'bg-emerald-500/10 border-emerald-500/30'
                      : 'bg-[var(--paper)] border-[var(--line)]'
                  }`}
                >
                  {goal.icon}
                </div>

                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <span
                      className={`text-xs font-semibold truncate ${
                        goal.isCompleted
                          ? 'line-through text-[var(--soft)]'
                          : 'text-[var(--ink)]'
                      }`}
                    >
                      {goal.title}
                    </span>
                    {goal.isCompleted && (
                      <span className="text-[9px] px-1.5 py-0.2 rounded-full bg-emerald-500/15 text-emerald-700 font-semibold shrink-0">
                        Achieved
                      </span>
                    )}
                  </div>

                  <p className="text-[10px] text-[var(--soft)] mt-0.5 truncate">
                    {goal.isCompleted
                      ? `Completed on ${goal.completedDate || 'Special Day'}`
                      : goal.targetDate
                      ? `Target: ${goal.targetDate}`
                      : goal.category === 'firsts'
                      ? 'Tap + to mark when it happened'
                      : 'Future relationship wish'}
                  </p>
                </div>
              </div>

              {/* Action Buttons */}
              <div className="flex items-center gap-1.5 shrink-0">
                <button
                  type="button"
                  onClick={() => handleToggleGoal(goal)}
                  className={`w-8 h-8 rounded-full flex items-center justify-center transition cursor-pointer border ${
                    goal.isCompleted
                      ? 'bg-emerald-500 text-white border-emerald-600 shadow-xs'
                      : 'bg-[var(--paper)] text-[var(--ink)] border-[var(--line)] hover:border-[var(--app-accent)]'
                  }`}
                  title={goal.isCompleted ? 'Mark incomplete' : 'Mark completed'}
                >
                  {goal.isCompleted ? (
                    <Check className="w-4 h-4" />
                  ) : (
                    <Plus className="w-4 h-4" />
                  )}
                </button>

                <button
                  type="button"
                  onClick={() => handleDeleteGoal(goal.id)}
                  className="p-1.5 text-[var(--soft)] hover:text-rose-500 transition cursor-pointer opacity-40 hover:opacity-100"
                  title="Delete goal"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                </button>
              </div>
            </div>
          ))}
        </div>

        {/* 4. Add Custom Goal Section */}
        {isAddingCustom ? (
          <div className="p-4 rounded-3xl bg-[var(--white)] border border-[var(--line)] shadow-md space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-xs font-semibold text-[var(--ink)]">New Couple Goal</span>
              <button
                type="button"
                onClick={() => setIsAddingCustom(false)}
                className="text-xs text-[var(--soft)] hover:text-[var(--ink)] cursor-pointer"
              >
                Cancel
              </button>
            </div>

            <div className="flex gap-2">
              <input
                type="text"
                value={newIcon}
                onChange={(e) => setNewIcon(e.target.value)}
                maxLength={2}
                className="w-12 text-center text-sm p-2 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)]"
                placeholder="Emoji"
              />
              <input
                type="text"
                value={newTitle}
                onChange={(e) => setNewTitle(e.target.value)}
                placeholder="e.g. Vacation to Japan, Cook dinner together..."
                className="flex-1 text-xs p-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] focus:outline-none focus:border-[var(--app-accent)]"
              />
            </div>

            <div className="grid grid-cols-2 gap-2 text-xs">
              <select
                value={newCategory}
                onChange={(e) => setNewCategory(e.target.value as any)}
                className="p-2 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] text-xs"
              >
                <option value="firsts">Couple First 🌸</option>
                <option value="future">Future Dream ✨</option>
              </select>

              <input
                type="date"
                value={newTargetDate}
                onChange={(e) => setNewTargetDate(e.target.value)}
                className="p-2 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] text-xs"
              />
            </div>

            <button
              type="button"
              onClick={handleAddCustomGoal}
              className="w-full py-2.5 rounded-2xl bg-[var(--app-accent)] text-white text-xs font-semibold hover:opacity-90 transition cursor-pointer shadow-xs flex items-center justify-center gap-1.5"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>Add to Our Goals</span>
            </button>
          </div>
        ) : (
          <button
            type="button"
            onClick={() => setIsAddingCustom(true)}
            className="w-full py-3 rounded-2xl border-2 border-dashed border-[var(--line)] hover:border-[var(--app-accent)] bg-[var(--white)] text-[var(--ink)] text-xs font-medium transition flex items-center justify-center gap-1.5 cursor-pointer shadow-2xs"
          >
            <Plus className="w-3.5 h-3.5 text-[var(--app-accent)]" />
            <span>Add Custom Couple Goal or First</span>
          </button>
        )}
      </div>
    </div>
  )
}
