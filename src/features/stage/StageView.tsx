import React, { useState, useEffect } from 'react'
import { useAuth } from '@/core/auth'
import { useTheme } from '@/core/theme'
import { useAudio } from '@/core/audio'
import { useToast } from '@/core/toast'
import { getSupabaseClient, formatLocalDate } from '@/core/storage'
import { getFirebaseDb } from '@/core/storage/firebase'
import { doc, setDoc } from 'firebase/firestore'
import { realtimeBridge } from '@/core/realtime'
import { dispatchPartnerInteraction } from '@/core/ai'
import { BlindPromptCard } from './BlindPromptCard'
import { PartnerLocationCard } from './PartnerLocationCard'
import { MoodAuraModal, MoodAura, MOOD_AURA_OPTIONS } from './MoodAuraModal'
import { StageMemoryHeroDeck } from './StageMemoryHeroDeck'
import { StageDailyCheckin } from './StageDailyCheckin'
import { StagePinnedCorkboard } from './StagePinnedCorkboard'
import confetti from 'canvas-confetti'
import { RefreshCw } from 'lucide-react'

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
  const notesDocId = `notes_${spaceId}`
  const moodDocId = `mood_aura_${spaceId}`

  // 1. Thought status state (Instagram note style, synced to Supabase)
  const [myThought, setMyThought] = useState('Listening to rain 🌧')
  const [partnerThought, setPartnerThought] = useState('')
  const [isEditingThought, setIsEditingThought] = useState(false)
  const [tempThought, setTempThought] = useState('')

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

  // Fetch Thoughts and Moods from Supabase
  useEffect(() => {
    const supabase = getSupabaseClient()

    // A. Thoughts
    const fetchThoughts = async () => {
      try {
        const { data } = await supabase
          .from('app_content')
          .select('content')
          .eq('id', notesDocId)
          .maybeSingle()

        if (data?.content) {
          if (user?.id && data.content[user.id]?.text) {
            setMyThought(data.content[user.id].text)
          }
          if (partner?.id && data.content[partner.id]?.text) {
            setPartnerThought(data.content[partner.id].text)
          }
        }
      } catch (err) {
        console.warn('Error fetching thoughts:', err)
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

    fetchThoughts()
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
          if (payload.new?.id === notesDocId && payload.new?.content) {
            if (user?.id && payload.new.content[user.id]?.text) {
              setMyThought(payload.new.content[user.id].text)
            }
            if (partner?.id && payload.new.content[partner.id]?.text) {
              setPartnerThought(payload.new.content[partner.id].text)
            }
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
      if (event.type === 'PINNED_NOTE_CHANGED' && event.data?.notes) {
        fetchThoughts()
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
  }, [spaceId, notesDocId, moodDocId, user?.id, partner?.id, showToast])

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
        const [thoughtsRes, moodRes] = await Promise.all([
          supabase.from('app_content').select('content').eq('id', notesDocId).maybeSingle(),
          supabase.from('app_content').select('content').eq('id', moodDocId).maybeSingle()
        ])
        if (thoughtsRes.data?.content && user?.id) setMyThought(thoughtsRes.data.content[user.id]?.text || '')
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

  // Save Thought
  const handleSaveThought = async () => {
    if (!tempThought.trim() || !user) return
    setMyThought(tempThought.trim())
    setIsEditingThought(false)
    showToast('Your thought has been updated.')

    try {
      const supabase = getSupabaseClient()
      const { data } = await supabase
        .from('app_content')
        .select('content')
        .eq('id', notesDocId)
        .maybeSingle()

      const current = data?.content || {}
      current[user.id] = {
        text: tempThought.slice(0, 50),
        author: user.nickname,
        updatedAt: new Date().toISOString()
      }

      await supabase.from('app_content').upsert({
        id: notesDocId,
        content: current,
        updated_at: new Date().toISOString()
      })

      // Sync to Firebase Firestore
      const db = getFirebaseDb()
      if (db && spaceId) {
        try {
          await setDoc(doc(db, 'spaces', spaceId, 'features', 'notes'), { notes: current }, { merge: true })
        } catch {}
      }

      // Realtime peer broadcast
      await realtimeBridge.broadcast({
        type: 'PINNED_NOTE_CHANGED',
        senderId: user.id,
        senderNickname: user.nickname,
        timestamp: Date.now(),
        data: { notes: current }
      }).catch(() => {})

      dispatchPartnerInteraction(user, space, 'THOUGHT_POSTED', {
        thought: tempThought.slice(0, 50)
      }).catch(() => {})
    } catch (err) {
      console.warn('Error saving thought:', err)
    }
  }

  // Delete Thought Note
  const handleDeleteThought = async () => {
    if (!user) return
    setMyThought('')
    setTempThought('')
    setIsEditingThought(false)
    showToast('Thought status cleared.')

    try {
      const supabase = getSupabaseClient()
      const { data } = await supabase
        .from('app_content')
        .select('content')
        .eq('id', notesDocId)
        .maybeSingle()

      const current = data?.content || {}
      delete current[user.id]

      await supabase.from('app_content').upsert({
        id: notesDocId,
        content: current,
        updated_at: new Date().toISOString()
      })
    } catch (err) {
      console.warn('Error clearing thought:', err)
    }
  }

  const currentDateFormatted = new Date().toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'long',
    day: 'numeric'
  }).toUpperCase()

  const togetherYear = space?.createdAt ? new Date(space.createdAt).getFullYear() : 2024

  const daysTogether = React.useMemo(() => {
    const startDate = space?.createdAt ? new Date(space.createdAt) : new Date('2024-01-01')
    const diffTime = Math.abs(Date.now() - startDate.getTime())
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))
    return Math.max(1, diffDays)
  }, [space?.createdAt])

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
        <div className="flex flex-col items-end shrink-0">
          <span className="date">Together since {togetherYear}</span>
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
          onClick={onOpenProfileModal || (() => {
            setTempThought(myThought)
            setIsEditingThought(true)
          })}
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
            <div className="flex items-center gap-1.5 flex-wrap">
              <b className="truncate">{user?.nickname || 'You'}</b>
              <button
                type="button"
                onClick={(e) => {
                  e.stopPropagation()
                  setIsMoodModalOpen(true)
                }}
                className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-full bg-[var(--paper)] hover:opacity-85 border border-[var(--line)] text-[9.5px] text-[var(--ink)] font-medium transition cursor-pointer"
                title="Tap to change your daily mood aura"
              >
                {myMood ? `${myMood.emoji} ${myMood.label}` : '✦ Aura'}
              </button>
            </div>
            <span className="thought">{user?.presenceStatus || myThought || 'Tap to set note...'}</span>
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
              <div className="flex items-center justify-end gap-1.5 flex-wrap">
                {partnerMood && (
                  <span
                    className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-full bg-[var(--paper)] border border-[var(--line)] text-[9.5px] text-[var(--ink)] font-medium"
                    title={`${partner.nickname} is feeling: ${partnerMood.label}`}
                  >
                    {partnerMood.emoji} {partnerMood.label}
                  </span>
                )}
                <b className="truncate">{partner.nickname}</b>
              </div>
              <span className="thought">{partner.presenceStatus || partnerThought || 'Thinking of you'}</span>
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
      <div className="pt-6 pb-2 text-center select-none opacity-80">
        <div className="flex items-center justify-center gap-2 text-[#b0b3ab] text-[11px]">
          <span className="w-8 h-px bg-[#deddd7]" />
          <span className="font-serif italic text-xs text-[#7a7d76]">pages of us</span>
          <span className="w-8 h-px bg-[#deddd7]" />
        </div>
        <p className="text-[9px] text-[#93968d] mt-1 tracking-wider uppercase">
          A quiet digital sanctuary for two
        </p>
      </div>

      {/* MODAL: Edit Thought Note */}
      {isEditingThought && (
        <div
          className="modal-backdrop"
          onClick={(e) => {
            if (e.target === e.currentTarget) setIsEditingThought(false)
          }}
        >
          <div className="modal">
            <div className="modal-handle" />
            <button
              type="button"
              className="close"
              onClick={() => setIsEditingThought(false)}
            >
              ×
            </button>
            <div className="modal-date">YOUR STATUS NOTE</div>
            <h3>What's on your mind?</h3>
            <input
              type="text"
              maxLength={45}
              value={tempThought}
              onChange={(e) => setTempThought(e.target.value)}
              placeholder="e.g. Listening to rain 🌧 or Craving ramen 🍜"
              className="w-full p-3 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] text-xs outline-none font-sans"
              autoFocus
            />
            <div className="flex justify-between text-[10px] text-[var(--soft)] mt-2">
              <span>Visible to your partner right now</span>
              <span>{tempThought.length}/45</span>
            </div>
            <div className="flex gap-2 mt-4">
              {myThought && (
                <button
                  type="button"
                  onClick={handleDeleteThought}
                  className="py-2.5 px-4 rounded-xl border border-red-300 dark:border-red-900 text-red-600 dark:text-red-400 text-xs font-medium cursor-pointer hover:bg-red-500/10 transition"
                >
                  Clear
                </button>
              )}
              <button
                type="button"
                onClick={handleSaveThought}
                className="flex-1 py-2.5 rounded-xl bg-[var(--app-accent)] text-white text-xs font-medium cursor-pointer hover:opacity-90"
              >
                Update thought
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
    </div>
  )
}
