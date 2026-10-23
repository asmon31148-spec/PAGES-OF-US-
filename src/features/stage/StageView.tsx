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
import { RefreshCw, Calendar, Heart } from 'lucide-react'

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

      {/* 1. TOPBAR */}
      <header className="topbar">
        <div className="wordmark">Pages of Us</div>
        <div className="top-actions">
          <div
            className={`connection ${isPaired ? 'paired' : 'unpaired cursor-pointer hover:opacity-85'}`}
            onClick={onOpenPairModal}
            role="button"
            title={isPaired ? `Connected with ${partner?.nickname}` : 'Tap to pair with your partner'}
          >
            <i
              className={`w-1.5 h-1.5 rounded-full shrink-0 ${
                isPaired ? 'bg-emerald-600' : 'bg-amber-500 animate-pulse'
              }`}
            />
            <span className="truncate max-w-[100px]">
              {isPaired && partner ? partner.nickname : 'Connect partner ＋'}
            </span>
          </div>

          <button
            type="button"
            className="music-pill flex items-center gap-1.5 shrink-0"
            onClick={onOpenAudioModal}
            title="Music & Atmosphere"
          >
            <span>♫</span>
            <span className="max-w-[75px] truncate">
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
            className="w-7 h-7 rounded-full p-0.5 bg-gradient-to-tr from-[#8a9b85] to-[#b77e6b] shrink-0 cursor-pointer shadow-xs hover:scale-105 transition"
            onClick={onOpenProfileModal}
            title="Customize your profile & note"
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
          <h2>A place for us.</h2>
        </div>
        <div
          className="flex flex-col items-end shrink-0 cursor-pointer hover:opacity-80 active:scale-95 transition"
          onClick={() => setIsGoalsModalOpen(true)}
          title="Tap to view our relationship story, firsts & goals"
        >
          <span className="date">Together since {togetherYear} ✎</span>
          <span className="text-[10px] font-mono tracking-wide text-[#738276] mt-0.5">
            Day {daysTogether} together ✦
          </span>
        </div>
      </div>

      {/* 3. INTIMATE AVATAR TETHER & SPEECH BUBBLES (Image 2 Style) */}
      <div className="relative p-5 rounded-3xl bg-[var(--white)] border border-[var(--line)] shadow-xs my-4">
        <div className="flex items-center justify-between relative z-10">
          {/* You / Left Avatar */}
          <div
            className="flex flex-col items-center cursor-pointer min-w-0"
            onClick={onOpenProfileModal}
            title="Tap to customize your profile & thought note"
          >
            {/* Speech Bubble */}
            <div className="relative mb-2 px-2.5 py-1 rounded-2xl bg-[var(--paper)] text-[var(--ink)] text-[10px] font-medium shadow-2xs border border-[var(--line)] max-w-[120px] truncate animate-bubble-float">
              {user?.presenceStatus || 'Thinking of you 💕'}
              <div className="absolute -bottom-1 left-1/2 -translate-x-1/2 w-2 h-2 bg-[var(--paper)] rotate-45 border-r border-b border-[var(--line)]"></div>
            </div>

            <div
              className="w-16 h-16 rounded-full p-0.5 bg-gradient-to-tr from-[#8a9b85] to-[#b77e6b] shadow-md relative transition-transform active:scale-95"
              style={{
                boxShadow: myMood ? `0 0 16px 3px ${myMood.glowColor}` : undefined
              }}
            >
              <div className="w-full h-full rounded-full overflow-hidden bg-[var(--paper)] flex items-center justify-center font-bold text-lg text-[var(--ink)]">
                {user?.avatarUrl ? (
                  <img src={user.avatarUrl} alt="You" className="w-full h-full object-cover" />
                ) : (
                  <span>{user?.nickname ? user.nickname.charAt(0).toUpperCase() : 'Y'}</span>
                )}
              </div>
              <span className="absolute bottom-0 right-0 w-3.5 h-3.5 rounded-full bg-emerald-500 border-2 border-white shadow-xs"></span>
            </div>
            <b className="text-xs font-semibold text-[var(--ink)] mt-1.5 truncate max-w-[85px]">
              {user?.nickname || 'You'}
            </b>
          </div>

          {/* Dotted Tether Line & Interactive Center Pulse (Image 2) */}
          <div className="flex-1 flex flex-col items-center px-2 relative">
            <div className="w-full border-t-2 border-dashed border-[#b3b7af] absolute top-1/2 -translate-y-1/2 z-0"></div>
            <button
              type="button"
              onClick={handleSendPulse}
              className={`relative z-10 px-3 py-1.5 rounded-full bg-[var(--white)] border border-[var(--line)] shadow-sm text-xs font-semibold text-[var(--ink)] hover:border-[var(--app-accent)] transition-all cursor-pointer flex items-center gap-1.5 ${
                isPulsing ? 'scale-110 bg-rose-50 border-rose-300 text-rose-600' : 'active:scale-95'
              }`}
              title="Tap to send a gentle pulse to your partner"
            >
              <Heart className={`w-3.5 h-3.5 ${isPulsing ? 'fill-rose-500 text-rose-500 animate-ping' : 'text-rose-500 fill-rose-500'}`} />
              <span className="text-[10px] font-mono">Tether</span>
            </button>
          </div>

          {/* Partner / Right Avatar */}
          {isPaired && partner ? (
            <div className="flex flex-col items-center min-w-0">
              {/* Partner Speech Bubble */}
              <div className="relative mb-2 px-2.5 py-1 rounded-2xl bg-[var(--paper)] text-[var(--ink)] text-[10px] font-medium shadow-2xs border border-[var(--line)] max-w-[120px] truncate animate-bubble-float">
                {partner.presenceStatus || 'Thinking of you ✨'}
                <div className="absolute -bottom-1 left-1/2 -translate-x-1/2 w-2 h-2 bg-[var(--paper)] rotate-45 border-r border-b border-[var(--line)]"></div>
              </div>

              <div
                className="w-16 h-16 rounded-full p-0.5 bg-gradient-to-tr from-[#b77e6b] to-[#8a9b85] shadow-md relative"
                style={{
                  boxShadow: partnerMood ? `0 0 16px 3px ${partnerMood.glowColor}` : undefined
                }}
              >
                <div className="w-full h-full rounded-full overflow-hidden bg-[var(--paper)] flex items-center justify-center font-bold text-lg text-[var(--ink)]">
                  {partner.avatarUrl ? (
                    <img src={partner.avatarUrl} alt={partner.nickname} className="w-full h-full object-cover" />
                  ) : (
                    <span>{partner.nickname.charAt(0).toUpperCase()}</span>
                  )}
                </div>
                <span className="absolute bottom-0 right-0 w-3.5 h-3.5 rounded-full bg-emerald-500 border-2 border-white shadow-xs"></span>
              </div>
              <b className="text-xs font-semibold text-[var(--ink)] mt-1.5 truncate max-w-[85px]">
                {partner.nickname}
              </b>
            </div>
          ) : (
            <div
              className="flex flex-col items-center cursor-pointer min-w-0"
              onClick={onOpenPairModal}
              title="Tap to connect with your partner"
            >
              <div className="relative mb-2 px-2.5 py-1 rounded-2xl bg-amber-50 text-amber-800 text-[10px] font-medium border border-amber-200">
                Connect partner ＋
                <div className="absolute -bottom-1 left-1/2 -translate-x-1/2 w-2 h-2 bg-amber-50 rotate-45 border-r border-b border-amber-200"></div>
              </div>
              <div className="w-16 h-16 rounded-full border-2 border-dashed border-[#8a9b85] flex items-center justify-center text-xl text-[#4d655a] bg-[#eef3eb]">
                ＋
              </div>
              <span className="text-xs font-semibold text-[#4d655a] mt-1.5">Pair Space</span>
            </div>
          )}
        </div>
      </div>

      {/* 4. COUPLE STATS ROW (Image 2 Style) */}
      <div className="grid grid-cols-2 gap-3 mb-4">
        {/* Days Together */}
        <div
          onClick={() => setIsGoalsModalOpen(true)}
          className="p-3.5 rounded-3xl bg-rose-500/10 border border-rose-500/20 shadow-xs cursor-pointer hover:opacity-90 active:scale-[0.98] transition flex items-center justify-between"
          title="Tap to view relationship goals and milestones"
        >
          <div>
            <span className="text-[10px] font-semibold uppercase tracking-wider text-rose-700 block">
              Days Together
            </span>
            <div className="text-xl font-extrabold text-[var(--ink)] mt-0.5">
              {daysTogether}
            </div>
          </div>
          <div className="w-9 h-9 rounded-2xl bg-[var(--white)] shadow-2xs border border-rose-200 flex items-center justify-center text-base text-rose-500">
            ❤️
          </div>
        </div>

        {/* Milestone Goals Quick Progress */}
        <div
          onClick={() => setIsGoalsModalOpen(true)}
          className="p-3.5 rounded-3xl bg-amber-500/10 border border-amber-500/20 shadow-xs cursor-pointer hover:opacity-90 active:scale-[0.98] transition flex items-center justify-between"
          title="Tap to view relationship goals"
        >
          <div>
            <span className="text-[10px] font-semibold uppercase tracking-wider text-amber-800 block">
              Story & Goals
            </span>
            <div className="text-xs font-bold text-[var(--ink)] mt-0.5">
              Our Journey ✦
            </div>
          </div>
          <div className="w-9 h-9 rounded-2xl bg-[var(--white)] shadow-2xs border border-amber-200 flex items-center justify-center text-base text-amber-600">
            ✨
          </div>
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

      {/* 9. Commercial Sanctuary Footer Mark */}
      <div className="pt-3 pb-1 text-center select-none opacity-80">
        <div className="flex items-center justify-center gap-2 text-[#b0b3ab] text-[11px]">
          <span className="w-8 h-px bg-[#deddd7]" />
          <span className="font-serif italic text-xs text-[#7a7d76]">pages of us</span>
          <span className="w-8 h-px bg-[#deddd7]" />
        </div>
        <p className="text-[9px] text-[#93968d] mt-1 tracking-wider uppercase">
          A private shared space for two
        </p>
      </div>

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
