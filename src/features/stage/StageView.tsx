import React, { useState, useEffect } from 'react'
import { useAuth } from '@/core/auth'
import { useTheme } from '@/core/theme'
import { useAudio } from '@/core/audio'
import { useToast } from '@/core/toast'
import { getSupabaseClient } from '@/core/storage'
import { getFirebaseDb } from '@/core/storage/firebase'
import { doc, setDoc } from 'firebase/firestore'
import { realtimeBridge } from '@/core/realtime'
import { BlindPromptCard } from './BlindPromptCard'
import { PartnerLocationCard } from './PartnerLocationCard'
import { MoodAuraModal, MoodAura, MOOD_AURA_OPTIONS } from './MoodAuraModal'
import { GoalTrackerModal } from './GoalTrackerModal'
import { StageMemoryHeroDeck } from './StageMemoryHeroDeck'
import { StageDailyCheckin } from './StageDailyCheckin'
import { StagePinnedCorkboard } from './StagePinnedCorkboard'
import confetti from 'canvas-confetti'
import { RefreshCw, Calendar, Heart, Target, ChevronRight, Sparkles } from 'lucide-react'

interface StageViewProps {
  onGoToMemories?: () => void
  onOpenPairModal?: () => void
  onOpenAudioModal?: () => void
  onOpenThemeModal?: () => void
  onOpenProfileModal?: () => void
}

export const StageView: React.FC<StageViewProps> = ({
  onGoToMemories,
  onOpenPairModal,
  onOpenAudioModal,
  onOpenThemeModal,
  onOpenProfileModal
}) => {
  const { user, space, partner, isPaired } = useAuth()
  const { theme, isDark, toggleDarkLight } = useTheme()
  const { currentTrack, isPlaying } = useAudio()
  const { showToast } = useToast()

  const spaceId = space?.id || 'default_space'
  const moodDocId = `mood_aura_${spaceId}`
  const anniversaryDocId = `anniversary_${spaceId}`

  // 1. Anniversary Date state & Goals Tracker
  const [customAnniversary, setCustomAnniversary] = useState<string | null>(null)
  const [isEditingAnniversary, setIsEditingAnniversary] = useState(false)
  const [anniversaryInput, setAnniversaryInput] = useState('')
  const [isGoalsModalOpen, setIsGoalsModalOpen] = useState(false)

  // 2. Daily Intimate Mood Aura
  const [myMood, setMyMood] = useState<MoodAura | null>(null)
  const [partnerMood, setPartnerMood] = useState<MoodAura | null>(null)
  const [isMoodModalOpen, setIsMoodModalOpen] = useState(false)

  // 3. Pull-to-refresh tactile state
  const [pullY, setPullY] = useState(0)
  const [isRefreshing, setIsRefreshing] = useState(false)
  const startYRef = React.useRef(0)

  // 4. Real-time pulse state
  const [isPulsing, setIsPulsing] = useState(false)

  // Fetch Anniversary and Moods from Supabase
  useEffect(() => {
    const supabase = getSupabaseClient()

    // A. Anniversary Date
    const fetchAnniversary = async () => {
      try {
        const { data } = await supabase
          .from('app_content')
          .select('content')
          .eq('id', anniversaryDocId)
          .maybeSingle()
        if (data?.content?.anniversaryDate) {
          setCustomAnniversary(data.content.anniversaryDate)
        }
      } catch (err) {
        console.warn('Error fetching anniversary:', err)
      }
    }

    // B. Mood Aura
    const fetchMoods = async () => {
      try {
        const { data } = await supabase
          .from('app_content')
          .select('content')
          .eq('id', moodDocId)
          .maybeSingle()
        if (data?.content) {
          if (user?.id && data.content[user.id]) {
            const m = MOOD_AURA_OPTIONS.find((o) => o.id === data.content[user.id]?.id)
            setMyMood(m || null)
          }
          if (partner?.id && data.content[partner.id]) {
            const p = MOOD_AURA_OPTIONS.find((o) => o.id === data.content[partner.id]?.id)
            setPartnerMood(p || null)
          }
        }
      } catch (err) {
        console.warn('Error fetching moods:', err)
      }
    }

    fetchAnniversary()
    fetchMoods()

    // Realtime channel for app_content
    const channel = supabase
      .channel(`stage_content_${spaceId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'app_content'
        },
        (payload: any) => {
          if (payload.new?.id === anniversaryDocId && payload.new?.content?.anniversaryDate) {
            setCustomAnniversary(payload.new.content.anniversaryDate)
          }
          if (payload.new?.id === moodDocId && payload.new?.content) {
            if (user?.id) {
              const m = MOOD_AURA_OPTIONS.find((o) => o.id === payload.new.content[user.id]?.id)
              setMyMood(m || null)
            }
            if (partner?.id) {
              const p = MOOD_AURA_OPTIONS.find((o) => o.id === payload.new.content[partner.id]?.id)
              setPartnerMood(p || null)
            }
          }
        }
      )
      .subscribe()

    // Realtime WebSocket pulse
    realtimeBridge.connect(spaceId)
    const unsubscribePulse = realtimeBridge.subscribe((event) => {
      if (event.type === 'PULSE') {
        setIsPulsing(true)
        setTimeout(() => setIsPulsing(false), 2000)
      }
      if (event.type === 'MOOD_UPDATE') {
        if (event.senderId !== user?.id) {
          const m = event.data ? MOOD_AURA_OPTIONS.find((o) => o.id === event.data.id) : null
          setPartnerMood(m || null)
          if (m) {
            showToast(`${event.senderNickname || 'Your partner'} is feeling ${m.label} ${m.emoji}`)
            try {
              if (navigator.vibrate) navigator.vibrate([30, 60, 30])
            } catch {}
          }
        }
      }
    })

    return () => {
      supabase.removeChannel(channel)
      unsubscribePulse()
    }
  }, [spaceId, moodDocId, anniversaryDocId, user?.id, partner?.id, showToast])

  // Handle Save Anniversary Date
  const handleSaveAnniversary = async () => {
    if (!anniversaryInput || !user) return
    setCustomAnniversary(anniversaryInput)
    setIsEditingAnniversary(false)
    confetti({ particleCount: 30, spread: 60, origin: { y: 0.6 } })
    showToast('Anniversary date updated! ✨')

    try {
      const supabase = getSupabaseClient()
      const nowIso = new Date().toISOString()
      await supabase.from('app_content').upsert({
        id: anniversaryDocId,
        content: { anniversaryDate: anniversaryInput, updatedBy: user.nickname, updatedAt: nowIso },
        updated_at: nowIso
      })

      const db = getFirebaseDb()
      if (db && spaceId) {
        try {
          await setDoc(doc(db, 'spaces', spaceId, 'features', 'anniversary'), { anniversaryDate: anniversaryInput }, { merge: true })
        } catch {}
      }
    } catch (err) {
      console.warn('Error saving anniversary:', err)
    }
  }

  // Handle Select Mood Aura
  const handleSelectMood = async (mood: MoodAura | null) => {
    if (!user) return
    setMyMood(mood)
    if (mood) {
      showToast(`Aura set to ${mood.label} ${mood.emoji}`)
      try {
        if (navigator.vibrate) navigator.vibrate(30)
      } catch {}
    } else {
      showToast('Aura cleared.')
    }

    try {
      const supabase = getSupabaseClient()
      const { data: existing } = await supabase
        .from('app_content')
        .select('content')
        .eq('id', moodDocId)
        .maybeSingle()
      const prev = existing?.content || {}
      const updated = {
        ...prev,
        [user.id]: mood
          ? { id: mood.id, emoji: mood.emoji, label: mood.label, updatedAt: new Date().toISOString() }
          : null
      }
      await supabase.from('app_content').upsert({
        id: moodDocId,
        content: updated,
        updated_at: new Date().toISOString()
      })

      // Sync to Firebase Firestore
      const db = getFirebaseDb()
      if (db && spaceId) {
        try {
          await setDoc(doc(db, 'spaces', spaceId, 'features', 'mood_aura'), { mood: updated }, { merge: true })
        } catch {}
      }

      await realtimeBridge.broadcast({
        type: 'MOOD_UPDATE',
        senderId: user.id,
        senderNickname: user.nickname,
        timestamp: Date.now(),
        data: mood ? { id: mood.id, emoji: mood.emoji, label: mood.label } : null
      })
    } catch (err) {
      console.warn('Error syncing mood aura:', err)
    }
  }

  // Pull-To-Refresh Handlers
  const handleTouchStart = (e: React.TouchEvent) => {
    if (window.scrollY <= 5) {
      startYRef.current = e.touches[0].clientY
    } else {
      startYRef.current = 0
    }
  }

  const handleTouchMove = (e: React.TouchEvent) => {
    if (startYRef.current > 0 && window.scrollY <= 5 && !isRefreshing) {
      const currentY = e.touches[0].clientY
      const diff = currentY - startYRef.current
      if (diff > 0) {
        setPullY(Math.min(diff * 0.45, 70))
      }
    }
  }

  const handleTouchEnd = async () => {
    if (pullY > 50 && !isRefreshing) {
      setIsRefreshing(true)
      setPullY(50)
      try {
        if (navigator.vibrate) navigator.vibrate(35)
      } catch {}
      // Refresh content
      const supabase = getSupabaseClient()
      try {
        const [annivRes, moodRes] = await Promise.all([
          supabase.from('app_content').select('content').eq('id', anniversaryDocId).maybeSingle(),
          supabase.from('app_content').select('content').eq('id', moodDocId).maybeSingle()
        ])
        if (annivRes.data?.content?.anniversaryDate) {
          setCustomAnniversary(annivRes.data.content.anniversaryDate)
        }
        const moodContent = moodRes.data?.content
        if (moodContent && user?.id) {
          const m = MOOD_AURA_OPTIONS.find((o) => o.id === moodContent[user.id]?.id)
          setMyMood(m || null)
        }
        if (moodContent && partner?.id) {
          const p = MOOD_AURA_OPTIONS.find((o) => o.id === moodContent[partner.id]?.id)
          setPartnerMood(p || null)
        }
      } catch {}
      showToast('Sanctuary connection refreshed 🌿')
      setTimeout(() => {
        setIsRefreshing(false)
        setPullY(0)
      }, 500)
    } else {
      setPullY(0)
    }
    startYRef.current = 0
  }

  // Handle Tether Pulse
  const handleSendPulse = async () => {
    if (!user) return
    setIsPulsing(true)
    showToast(partner ? `A little hello sent to ${partner.nickname}.` : 'Connect your partner to send a live hello.')

    confetti({
      particleCount: 35,
      spread: 60,
      origin: { y: 0.55 }
    })

    await realtimeBridge.broadcast({
      type: 'PULSE',
      senderId: user.id,
      senderNickname: user.nickname,
      timestamp: Date.now()
    })

    setTimeout(() => setIsPulsing(false), 1800)
  }

  const currentDateFormatted = new Date().toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'long',
    day: 'numeric'
  }).toUpperCase()

  // Calculate actual anniversary start date and days together
  const anniversaryDate = customAnniversary || space?.createdAt
  const startDate = React.useMemo(() => {
    if (anniversaryDate) {
      const d = new Date(anniversaryDate)
      if (!isNaN(d.getTime())) return d
    }
    return new Date('2024-01-01')
  }, [anniversaryDate])

  const togetherYear = startDate.getFullYear()

  const daysTogether = React.useMemo(() => {
    const diffTime = Math.max(0, Date.now() - startDate.getTime())
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))
    return Math.max(1, diffDays)
  }, [startDate])

  return (
    <div
      className="page active"
      id="stage"
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
    >
      {/* Pull-To-Refresh Banner */}
      <div
        className="w-full flex items-center justify-center transition-all duration-200 overflow-hidden"
        style={{
          height: `${pullY}px`,
          opacity: pullY > 10 ? Math.min(pullY / 45, 1) : 0
        }}
      >
        <div className="flex items-center gap-1.5 py-1 px-3 rounded-full bg-[var(--paper)] text-[var(--app-accent)] text-[11px] shadow-2xs font-medium border border-[var(--line)]">
          <RefreshCw className={`w-3.5 h-3.5 ${isRefreshing ? 'animate-spin' : ''}`} />
          <span>{isRefreshing ? 'Refreshing sanctuary...' : pullY > 45 ? 'Release to refresh' : 'Pull down to refresh'}</span>
        </div>
      </div>

      {/* 1. TOPBAR - Elegant, Spacious, Uncrowded */}
      <header className="topbar">
        <h1 className="wordmark">Pages of Us</h1>
        <div className="top-actions">
          <button
            type="button"
            className="music-pill flex items-center gap-1.5 shrink-0"
            onClick={onOpenAudioModal}
            title="Music and Atmosphere"
          >
            <span>♫</span>
            <span className="max-w-[80px] truncate">
              {isPlaying ? (currentTrack?.title || 'Atmosphere') : 'Atmosphere'}
            </span>
          </button>

          {/* Quick Light / Dark Mode Toggle */}
          <button
            type="button"
            className="music-pill flex items-center justify-center w-8 h-8 !p-0 shrink-0"
            onClick={toggleDarkLight}
            title={isDark ? 'Switch to Light Sanctuary (☀️)' : 'Switch to Dark Sanctuary (🌙)'}
          >
            {isDark ? '☀️' : '🌙'}
          </button>

          {/* User Profile Avatar Pill */}
          <button
            type="button"
            className="w-8 h-8 rounded-full p-0.5 bg-gradient-to-tr from-[#8a9b85] to-[#b77e6b] shrink-0 cursor-pointer shadow-xs hover:scale-105 transition"
            onClick={onOpenProfileModal}
            title="Customize your profile and note"
          >
            <div className="w-full h-full rounded-full bg-[var(--white)] overflow-hidden flex items-center justify-center text-[10px] font-bold text-[var(--ink)]">
              {user?.avatarUrl ? (
                <img src={user.avatarUrl} alt="Me" className="w-full h-full object-cover" />
              ) : (
                <span>{user?.nickname?.charAt(0).toUpperCase() || 'Y'}</span>
              )}
            </div>
          </button>
        </div>
      </header>

      {/* 2. GREETING */}
      <div className="greeting">
        <div className="min-w-0">
          <small>{currentDateFormatted}</small>
        </div>
        <div
          className="flex flex-col items-end shrink-0 cursor-pointer hover:opacity-80 transition"
          onClick={() => {
            setAnniversaryInput(anniversaryDate ? new Date(anniversaryDate).toISOString().split('T')[0] : '')
            setIsEditingAnniversary(true)
          }}
          title="Tap to adjust your anniversary date"
        >
          <span className="date">Together since {togetherYear} ✎</span>
          <span className="text-[10px] font-mono tracking-wide text-[#738276] mt-0.5">
            Day {daysTogether} together ✦
          </span>
        </div>
      </div>

      {/* 3. PRESENCE (Avatars, Thoughts, Aura & Tether) */}
      <div className="presence">
        {/* You */}
        <div
          className="presence-person cursor-pointer min-w-0"
          onClick={onOpenProfileModal}
          title="Tap to customize your profile & note"
        >
          <div
            className="avatar-wrap shrink-0 relative transition-all duration-300"
            style={{
              borderRadius: '9999px',
              boxShadow: myMood ? `0 0 16px 3px ${myMood.glowColor}` : undefined
            }}
          >
            <div className="avatar overflow-hidden">
              {user?.avatarUrl ? (
                <img src={user.avatarUrl} alt="You" className="w-full h-full object-cover" />
              ) : (
                <span>{user?.nickname ? user.nickname.charAt(0).toUpperCase() : '☁️'}</span>
              )}
            </div>
            {/* Mood Emoji Badge */}
            {myMood && (
              <div
                className="absolute -bottom-1 -right-1 w-5 h-5 rounded-full bg-[var(--white)] shadow-md border border-[var(--line)] flex items-center justify-center text-[10px]"
                title={`Aura: ${myMood.label}`}
              >
                {myMood.emoji}
              </div>
            )}
          </div>
          <div className="presence-copy min-w-0">
            <b className="truncate block text-sm font-semibold">{user?.nickname || 'You'}</b>
            <span className="thought">{user?.presenceStatus || 'Tap profile to set status note...'}</span>
          </div>
        </div>

        {/* Tether Button */}
        <button
          type="button"
          className={`tether shrink-0 ${isPulsing ? 'scale-125' : ''}`}
          onClick={handleSendPulse}
          aria-label="Send a tether hello to partner"
          title="Tap to send a gentle pulse"
        >
          ↔
        </button>

        {/* Partner / Invite State */}
        {isPaired && partner ? (
          <div className="presence-person min-w-0">
            <div className="presence-copy min-w-0 text-right">
              <b className="truncate block text-sm font-semibold">{partner.nickname}</b>
              <span className="thought">{partner.presenceStatus || 'Thinking of you'}</span>
            </div>
            <div
              className="avatar-wrap shrink-0 relative transition-all duration-300"
              style={{
                borderRadius: '9999px',
                boxShadow: partnerMood ? `0 0 16px 3px ${partnerMood.glowColor}` : undefined
              }}
            >
              <div className="avatar overflow-hidden">
                {partner.avatarUrl ? (
                  <img src={partner.avatarUrl} alt={partner.nickname} className="w-full h-full object-cover" />
                ) : (
                  <span>{partner.nickname.charAt(0).toUpperCase()}</span>
                )}
              </div>
              {partnerMood && (
                <div
                  className="absolute -bottom-1 -right-1 w-5 h-5 rounded-full bg-[var(--white)] shadow-md border border-[var(--line)] flex items-center justify-center text-[10px]"
                  title={`${partner.nickname}: ${partnerMood.label}`}
                >
                  {partnerMood.emoji}
                </div>
              )}
            </div>
          </div>
        ) : (
          <div
            className="presence-person min-w-0 cursor-pointer"
            onClick={onOpenPairModal}
            title="Invite your partner to connect"
          >
            <div className="presence-copy min-w-0 text-right">
              <b className="truncate text-[#4d655a]">Connect partner</b>
              <span className="thought text-[#8a8b83]">Tap to pair ＋</span>
            </div>
            <div className="avatar-wrap shrink-0">
              <div className="avatar border-dashed border-[#8a9b85] text-[#4d655a] bg-[#eef3eb]">
                ＋
              </div>
            </div>
          </div>
        )}
      </div>

      {/* 3.5. RELATIONSHIP MILESTONES & GOALS BENTO TILE (Inspired by Image 1) */}
      <div
        className="w-full py-3.5 px-2 mb-2 border-b border-[var(--line)] flex items-center justify-between cursor-pointer hover:opacity-85 transition active:scale-[0.99]"
        onClick={() => setIsGoalsModalOpen(true)}
        role="button"
        title="Open Relationship Story & Goals Tracker"
      >
        <div className="flex items-center gap-3.5 min-w-0">
          <div className="w-11 h-11 rounded-2xl bg-gradient-to-tr from-[#e07a5f]/20 to-[#f4a261]/20 text-[#e07a5f] flex items-center justify-center text-xl shrink-0 shadow-2xs border border-[#e07a5f]/15">
            🎯
          </div>
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <span className="text-[11px] font-bold tracking-wider text-[var(--terra)] uppercase">
                Milestones & Goals
              </span>
              <span className="text-[10px] px-2 py-0.5 rounded-full bg-[var(--app-accent)]/10 text-[var(--app-accent)] font-semibold border border-[var(--app-accent)]/20">
                Day {daysTogether}
              </span>
            </div>
            <p className="text-xs font-medium text-[var(--ink)] mt-0.5 truncate">
              Celebrate couple firsts & set new dreams ✦
            </p>
          </div>
        </div>
        <div className="flex items-center gap-1 text-[var(--soft)] text-xs shrink-0 ml-2">
          <span className="hidden sm:inline text-[11px]">View</span>
          <ChevronRight className="w-4 h-4" />
        </div>
      </div>

      {/* 4. SHARED MOMENT HERO SPOTLIGHT & STORY DECK (Multi-moment carousel + card flip + voice player) */}
      <StageMemoryHeroDeck onGoToMemories={onGoToMemories} />

      {/* 5. MIDNIGHT THOUGHTS (BLIND REVEAL) */}
      <BlindPromptCard />

      {/* 6. DAILY CHECK-IN & SCHEDULED CARE CHECKS (Spacious elevated card with dual answers + care series) */}
      <StageDailyCheckin />

      {/* 7. PINNED CORKBOARD FOR TODAY (Dual partner sticky notes with author stamps & strict edit lockdown) */}
      <StagePinnedCorkboard />

      {/* 8. LIVE PARTNER LOCATION TRACKER */}
      <PartnerLocationCard />

      {/* MODAL: Customize Anniversary Date */}
      {isEditingAnniversary && (
        <div
          className="modal-backdrop show"
          onClick={(e) => {
            if (e.target === e.currentTarget) setIsEditingAnniversary(false)
          }}
        >
          <div className="modal max-w-xs">
            <div className="modal-handle" />
            <button
              type="button"
              className="close"
              onClick={() => setIsEditingAnniversary(false)}
            >
              ×
            </button>
            <div className="modal-date">ANNIVERSARY & DAYS TOGETHER</div>
            <h3>When did you meet?</h3>
            <p style={{ fontStyle: 'normal', fontSize: '11px', color: '#777a76', marginBottom: '12px' }}>
              Set your actual couple anniversary so your days together counter is 100% accurate.
            </p>
            <input
              type="date"
              value={anniversaryInput}
              onChange={(e) => setAnniversaryInput(e.target.value)}
              className="w-full p-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] text-xs font-mono outline-none mb-4"
              autoFocus
            />
            <div className="flex gap-2">
              <button
                type="button"
                onClick={() => setIsEditingAnniversary(false)}
                className="py-2.5 px-4 rounded-xl border border-[var(--line)] text-xs text-[var(--soft)] hover:bg-[var(--line)]/30 transition cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleSaveAnniversary}
                className="flex-1 py-2.5 rounded-xl bg-[var(--app-accent)] text-white text-xs font-medium cursor-pointer hover:opacity-90"
              >
                Save Anniversary
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Mood Aura Modal */}
      <MoodAuraModal
        isOpen={isMoodModalOpen}
        onClose={() => setIsMoodModalOpen(false)}
        currentMoodId={myMood?.id}
        onSelectMood={handleSelectMood}
      />

      {/* Couple Goals & Story Modal */}
      <GoalTrackerModal
        isOpen={isGoalsModalOpen}
        onClose={() => setIsGoalsModalOpen(false)}
        daysTogether={daysTogether}
        startDate={startDate}
        onUpdateAnniversary={async (newDateStr) => {
          setCustomAnniversary(newDateStr)
          const supabase = getSupabaseClient()
          try {
            await supabase.from('app_content').upsert({
              id: anniversaryDocId,
              content: { anniversaryDate: newDateStr },
              updated_at: new Date().toISOString()
            })
          } catch (e) {
            console.warn('Error saving anniversary:', e)
          }
        }}
      />
    </div>
  )
}
