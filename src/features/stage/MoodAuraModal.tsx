import React from 'react'
import { X, Check } from 'lucide-react'

export interface MoodAura {
  id: string
  emoji: string
  label: string
  subtext: string
  glowColor: string
  bgSoft: string
}

export const MOOD_AURA_OPTIONS: MoodAura[] = [
  {
    id: 'warm',
    emoji: '☀️',
    label: 'Warm & Happy',
    subtext: 'Soft, joyful and grateful for us',
    glowColor: 'rgba(245, 158, 11, 0.55)',
    bgSoft: 'bg-amber-500/10 border-amber-500/30 text-amber-900'
  },
  {
    id: 'tender',
    emoji: '🌧️',
    label: 'Needing Love',
    subtext: 'A little gentle care or cuddle needed',
    glowColor: 'rgba(96, 165, 250, 0.55)',
    bgSoft: 'bg-blue-500/10 border-blue-500/30 text-blue-900'
  },
  {
    id: 'focused',
    emoji: '☕',
    label: 'In the Zone',
    subtext: 'Deep in thought, working calmly',
    glowColor: 'rgba(16, 185, 129, 0.55)',
    bgSoft: 'bg-emerald-500/10 border-emerald-500/30 text-emerald-900'
  },
  {
    id: 'recharge',
    emoji: '🔋',
    label: 'Low Battery',
    subtext: 'Tired mind, resting and recharging',
    glowColor: 'rgba(244, 63, 94, 0.55)',
    bgSoft: 'bg-rose-500/10 border-rose-500/30 text-rose-900'
  },
  {
    id: 'excited',
    emoji: '✨',
    label: 'Excited & Playful',
    subtext: 'Bursting with fun and good news',
    glowColor: 'rgba(168, 85, 247, 0.55)',
    bgSoft: 'bg-purple-500/10 border-purple-500/30 text-purple-900'
  },
  {
    id: 'sleepy',
    emoji: '🌙',
    label: 'Soft & Sleepy',
    subtext: 'Curled in blankets, drifting off soon',
    glowColor: 'rgba(129, 140, 248, 0.55)',
    bgSoft: 'bg-indigo-500/10 border-indigo-500/30 text-indigo-900'
  }
]

interface MoodAuraModalProps {
  isOpen: boolean
  onClose: () => void
  currentMoodId?: string
  onSelectMood: (mood: MoodAura | null) => Promise<void>
}

export const MoodAuraModal: React.FC<MoodAuraModalProps> = ({
  isOpen,
  onClose,
  currentMoodId,
  onSelectMood
}) => {
  if (!isOpen) return null

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-black/60 backdrop-blur-sm transition-opacity duration-200"
      onClick={onClose}
    >
      <div
        className="w-full max-w-md bg-[var(--white)] text-[var(--ink)] rounded-t-3xl sm:rounded-3xl border border-[var(--line)] shadow-2xl overflow-hidden p-6 animate-in slide-in-from-bottom-6 duration-300"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between pb-3 border-b border-[var(--line)]">
          <div>
            <span className="text-[10px] tracking-widest font-mono uppercase text-[var(--app-accent)] font-bold">
              Intimate Presence
            </span>
            <h3 className="font-serif text-lg font-medium text-[var(--ink)]">
              How is your heart feeling?
            </h3>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="w-8 h-8 rounded-full bg-[var(--paper)] flex items-center justify-center text-[var(--soft)] hover:text-[var(--ink)] transition cursor-pointer"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        <p className="text-xs text-[var(--soft)] mt-2 mb-4 leading-relaxed">
          Select a quiet aura for today. Your partner will see your ambient glow around your avatar on their home screen.
        </p>

        {/* Mood Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5 max-h-[50vh] overflow-y-auto pr-1">
          {MOOD_AURA_OPTIONS.map((mood) => {
            const isSelected = currentMoodId === mood.id
            return (
              <button
                key={mood.id}
                type="button"
                onClick={async () => {
                  await onSelectMood(mood)
                  onClose()
                }}
                className={`flex items-start gap-3 p-3 rounded-2xl border text-left transition-all duration-200 cursor-pointer ${
                  isSelected
                    ? `${mood.bgSoft} border-2 shadow-xs scale-[1.01]`
                    : 'bg-[var(--paper)] border-[var(--line)] hover:opacity-90'
                }`}
              >
                <div
                  className="w-9 h-9 rounded-xl flex items-center justify-center text-lg shrink-0 shadow-xs"
                  style={{
                    boxShadow: isSelected ? `0 0 12px ${mood.glowColor}` : undefined,
                    backgroundColor: 'var(--white)'
                  }}
                >
                  {mood.emoji}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center justify-between">
                    <span className="font-serif text-xs font-semibold text-[var(--ink)]">
                      {mood.label}
                    </span>
                    {isSelected && <Check className="w-3.5 h-3.5 text-[var(--app-accent)]" />}
                  </div>
                  <p className="text-[10.5px] text-[var(--soft)] leading-tight mt-0.5 line-clamp-2">
                    {mood.subtext}
                  </p>
                </div>
              </button>
            )
          })}
        </div>

        {/* Clear Aura Option */}
        {currentMoodId && (
          <div className="pt-4 mt-3 border-t border-[var(--line)] flex justify-center">
            <button
              type="button"
              onClick={async () => {
                await onSelectMood(null)
                onClose()
              }}
              className="text-xs text-[var(--soft)] hover:text-red-500 transition cursor-pointer"
            >
              Clear current aura
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
