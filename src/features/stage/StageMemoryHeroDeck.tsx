import React, { useState, useEffect, useCallback, useRef } from 'react'
import { useAuth } from '@/core/auth'
import { useTheme } from '@/core/theme'
import { useToast } from '@/core/toast'
import { getSupabaseClient, formatLocalDate, getAuthorAttribution } from '@/core/storage'
import { getFirebaseDb } from '@/core/storage/firebase'
import { doc, setDoc } from 'firebase/firestore'
import { realtimeBridge } from '@/core/realtime'
import confetti from 'canvas-confetti'
import {
  ChevronLeft,
  ChevronRight,
  RotateCw,
  Plus,
  Heart,
  Volume2,
  VolumeX,
  Play,
  Pause,
  Image as ImageIcon,
  Sparkles,
  Calendar,
  User
} from 'lucide-react'

export interface DeckMemoryItem {
  id: string
  title: string
  caption: string
  mediaUrl: string
  voiceUrl?: string
  date: string
  authorName: string
  isMine: boolean
  createdAtIso: string
}

interface StageMemoryHeroDeckProps {
  onGoToMemories?: () => void
}

export const StageMemoryHeroDeck: React.FC<StageMemoryHeroDeckProps> = ({
  onGoToMemories
}) => {
  const { user, space, partner } = useAuth()
  const { theme } = useTheme()
  const { showToast } = useToast()

  const spaceId = space?.id || 'default_space'
  const likeDocId = `hero_like_${spaceId}`

  const [memories, setMemories] = useState<DeckMemoryItem[]>([])
  const [currentIndex, setCurrentIndex] = useState(0)
  const [isFlipped, setIsFlipped] = useState(false)
  const [likesState, setLikesState] = useState<Record<string, boolean>>({})

  // Audio voice memo playback state
  const [isPlayingVoice, setIsPlayingVoice] = useState(false)
  const audioRef = useRef<HTMLAudioElement | null>(null)

  // Touch swipe tracking
  const touchStartX = useRef<number>(0)
  const touchEndX = useRef<number>(0)

  // Fetch recent memories from Supabase
  const fetchMemories = useCallback(async () => {
    try {
      const supabase = getSupabaseClient()
      const { data, error } = await supabase
        .from('memories')
        .select('*')
        .eq('space_id', spaceId)
        .order('created_at', { ascending: false })
        .limit(8)

      if (error) {
        console.warn('Error fetching deck memories:', error.message)
        return
      }

      if (data && data.length > 0) {
        const mapped: DeckMemoryItem[] = data.map((row) => {
          const { authorName, isMine } = getAuthorAttribution(row.author, user, partner?.nickname)
          const voiceUrl = row.thumbnail_url && (row.thumbnail_url.startsWith('data:audio') || row.thumbnail_url.startsWith('http'))
            ? row.thumbnail_url
            : undefined

          return {
            id: row.id,
            title: row.title || 'Untitled Moment',
            caption: row.caption || '',
            mediaUrl: row.media_url,
            voiceUrl,
            date: formatLocalDate(row.created_at, {
              day: 'numeric',
              month: 'short'
            }).toUpperCase(),
            authorName: isMine ? 'You' : authorName,
            isMine,
            createdAtIso: row.created_at
          }
        })
        setMemories(mapped)
      } else {
        setMemories([])
      }
    } catch (err) {
      console.warn('Error in fetchMemories:', err)
    }
  }, [spaceId, user, partner?.nickname])

  // Fetch likes from app_content
  const fetchLikes = useCallback(async () => {
    try {
      const supabase = getSupabaseClient()
      const { data } = await supabase
        .from('app_content')
        .select('content')
        .eq('id', likeDocId)
        .maybeSingle()

      if (data?.content) {
        setLikesState(data.content.likes || {})
      }
    } catch (err) {
      console.warn('Error fetching likes:', err)
    }
  }, [likeDocId])

  useEffect(() => {
    fetchMemories()
    fetchLikes()

    const supabase = getSupabaseClient()

    // Realtime changes to memories
    const memChannel = supabase
      .channel(`deck_memories_${spaceId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'memories',
          filter: `space_id=eq.${spaceId}`
        },
        () => {
          fetchMemories()
        }
      )
      .subscribe()

    // Realtime changes to likes
    const likeChannel = supabase
      .channel(`deck_likes_${spaceId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'app_content',
          filter: `id=eq.${likeDocId}`
        },
        (payload: any) => {
          if (payload.new?.content?.likes) {
            setLikesState(payload.new.content.likes)
          }
        }
      )
      .subscribe()

    // WebSocket realtime bridge
    const unsubBridge = realtimeBridge.subscribe((event) => {
      if (event.type === 'MEMORY_ADDED') {
        fetchMemories()
      }
      if (event.type === 'PULSE' && event.data?.reason === 'hero_like') {
        fetchLikes()
      }
    })

    return () => {
      supabase.removeChannel(memChannel)
      supabase.removeChannel(likeChannel)
      unsubBridge()
      if (audioRef.current) {
        audioRef.current.pause()
        audioRef.current = null
      }
    }
  }, [spaceId, likeDocId, fetchMemories, fetchLikes])

  // Stop voice note when changing slide or flipping
  const stopVoiceNote = () => {
    if (audioRef.current) {
      audioRef.current.pause()
      audioRef.current = null
    }
    setIsPlayingVoice(false)
  }

  const handleNext = (e?: React.MouseEvent) => {
    e?.stopPropagation()
    stopVoiceNote()
    setIsFlipped(false)
    setCurrentIndex((prev) => (prev + 1) % memories.length)
  }

  const handlePrev = (e?: React.MouseEvent) => {
    e?.stopPropagation()
    stopVoiceNote()
    setIsFlipped(false)
    setCurrentIndex((prev) => (prev - 1 + memories.length) % memories.length)
  }

  const handleToggleFlip = (e?: React.MouseEvent) => {
    e?.stopPropagation()
    stopVoiceNote()
    setIsFlipped((prev) => !prev)
  }

  // Voice note play/pause handler
  const handleToggleVoice = (voiceUrl: string, e: React.MouseEvent) => {
    e.stopPropagation()
    if (isPlayingVoice) {
      stopVoiceNote()
    } else {
      stopVoiceNote()
      const audio = new Audio(voiceUrl)
      audioRef.current = audio
      audio.onended = () => {
        setIsPlayingVoice(false)
      }
      audio.onerror = () => {
        setIsPlayingVoice(false)
        showToast('Could not play voice note.')
      }
      audio.play().then(() => {
        setIsPlayingVoice(true)
      }).catch((err) => {
        console.warn('Audio play error:', err)
        setIsPlayingVoice(false)
      })
    }
  }

  // Heart toggle
  const activeMemory = memories[currentIndex] || null
  const isCurrentLiked = activeMemory ? Boolean(likesState[activeMemory.id]) : false

  const handleToggleLike = async (e: React.MouseEvent) => {
    e.stopPropagation()
    if (!activeMemory || !user) return

    const nextLiked = !isCurrentLiked
    const updatedLikes = {
      ...likesState,
      [activeMemory.id]: nextLiked
    }
    setLikesState(updatedLikes)

    if (nextLiked) {
      confetti({
        particleCount: 36,
        spread: 60,
        origin: { y: 0.6 }
      })
      showToast('Heart sent on this shared moment 💕')
    } else {
      showToast('Reaction removed.')
    }

    try {
      const supabase = getSupabaseClient()
      const nowIso = new Date().toISOString()
      await supabase.from('app_content').upsert({
        id: likeDocId,
        content: {
          likes: updatedLikes,
          lastLikedBy: user.nickname,
          lastLikedById: user.id,
          updatedAt: nowIso
        },
        updated_at: nowIso
      })

      const db = getFirebaseDb()
      if (db && spaceId) {
        try {
          await setDoc(doc(db, 'spaces', spaceId, 'features', 'hero_like'), {
            likes: updatedLikes,
            lastLikedBy: user.nickname,
            lastLikedById: user.id,
            updatedAt: nowIso
          }, { merge: true })
        } catch {}
      }

      await realtimeBridge.broadcast({
        type: 'PULSE',
        senderId: user.id,
        senderNickname: user.nickname,
        timestamp: Date.now(),
        data: { reason: 'hero_like', memoryId: activeMemory.id, isLiked: nextLiked }
      })
    } catch (err) {
      console.warn('Error saving like state:', err)
    }
  }

  // Touch Swipe Handlers
  const handleTouchStart = (e: React.TouchEvent) => {
    touchStartX.current = e.touches[0].clientX
  }

  const handleTouchMove = (e: React.TouchEvent) => {
    touchEndX.current = e.touches[0].clientX
  }

  const handleTouchEnd = () => {
    const diffX = touchStartX.current - touchEndX.current
    if (Math.abs(diffX) > 45 && memories.length > 1) {
      if (diffX > 0) {
        // Swiped left -> next
        handleNext()
      } else {
        // Swiped right -> prev
        handlePrev()
      }
    }
    touchStartX.current = 0
    touchEndX.current = 0
  }

  // Empty State
  if (memories.length === 0) {
    return (
      <div
        className="w-full py-6 px-2 border-b border-[var(--line)] transition-all flex flex-col items-center text-center my-2 relative overflow-hidden"
      >
        <div className="w-12 h-12 rounded-full bg-[var(--app-accent)]/10 text-[var(--app-accent)] flex items-center justify-center mb-3">
          <Sparkles className="w-6 h-6" />
        </div>
        <span className="text-[10px] tracking-widest uppercase font-mono text-[var(--soft)] font-semibold mb-1">
          Shared Moments
        </span>
        <h3 className="font-serif text-lg font-medium text-[var(--ink)] mb-1.5">
          Our Story Deck
        </h3>
        <p className="text-xs text-[var(--soft)] max-w-[280px] leading-relaxed mb-4">
          Save your favourite photos, handwritten stories, and voice notes here to relive together.
        </p>
        <button
          type="button"
          onClick={onGoToMemories}
          className="inline-flex items-center gap-2 px-4 py-2.5 rounded-full bg-[var(--app-accent)] text-white text-xs font-medium shadow-xs hover:opacity-90 active:scale-95 transition cursor-pointer"
        >
          <Plus className="w-3.5 h-3.5" />
          <span>Add Our First Memory</span>
        </button>
      </div>
    )
  }

  return (
    <div
      className="relative w-full rounded-2xl overflow-hidden my-3 border border-[var(--line)]/60 select-none transition-all duration-300"
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
      style={{ minHeight: '230px' }}
    >
      {/* FRONT SIDE: Photo, Title, Date, Reactions */}
      {!isFlipped ? (
        <div
          className="relative w-full min-h-[230px] flex flex-col justify-between p-4 sm:p-5 text-white"
          style={{
            backgroundImage: activeMemory.mediaUrl
              ? `linear-gradient(180deg, rgba(0,0,0,0.3) 0%, rgba(0,0,0,0.1) 40%, rgba(0,0,0,0.85) 100%), url(${activeMemory.mediaUrl})`
              : 'linear-gradient(135deg, #3d4a41 0%, #202522 100%)',
            backgroundSize: 'cover',
            backgroundPosition: 'center'
          }}
        >
          {/* Top Row: Tag, Counter Pill, Flip Pill, Add Button */}
          <div className="flex items-center justify-between gap-2 z-10">
            <div className="flex items-center gap-1.5">
              <span className="px-2.5 py-1 rounded-full bg-black/40 backdrop-blur-md text-[9.5px] uppercase tracking-wider font-medium text-white/90 border border-white/15">
                {activeMemory.date}
              </span>
              {memories.length > 1 && (
                <span className="px-2 py-1 rounded-full bg-black/35 backdrop-blur-md text-[9px] font-mono text-white/80 border border-white/10">
                  {currentIndex + 1} / {memories.length}
                </span>
              )}
            </div>

            <div className="flex items-center gap-1.5">
              {/* 1-Tap Front Voice Note Button */}
              {activeMemory.voiceUrl && (
                <button
                  type="button"
                  onClick={(e) => {
                    e.stopPropagation()
                    handleToggleVoice(activeMemory.voiceUrl!, e)
                  }}
                  className={`flex items-center gap-1 px-2.5 py-1 rounded-full backdrop-blur-md text-[10px] font-medium border active:scale-95 transition cursor-pointer shadow-xs ${
                    isPlayingVoice
                      ? 'bg-rose-600 text-white border-rose-400 animate-pulse'
                      : 'bg-white/20 hover:bg-white/30 text-white border-white/25'
                  }`}
                  title={isPlayingVoice ? 'Pause voice memo' : 'Play voice memo'}
                >
                  {isPlayingVoice ? (
                    <>
                      <Pause className="w-3 h-3 fill-current" />
                      <span>Pause ♫</span>
                    </>
                  ) : (
                    <>
                      <Play className="w-3 h-3 fill-current" />
                      <span>Voice ♫</span>
                    </>
                  )}
                </button>
              )}

              {/* Flip to story button */}
              <button
                type="button"
                onClick={handleToggleFlip}
                className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-white/20 hover:bg-white/30 backdrop-blur-md text-[10px] font-medium text-white border border-white/25 active:scale-95 transition cursor-pointer"
                title="Tap to read the story and listen to voice note"
              >
                <RotateCw className="w-3 h-3" />
                <span>Story ↺</span>
              </button>

              {/* Add Memory Shortcut */}
              <button
                type="button"
                onClick={onGoToMemories}
                className="w-7 h-7 rounded-full bg-white/20 hover:bg-white/30 backdrop-blur-md text-white flex items-center justify-center border border-white/25 active:scale-95 transition cursor-pointer"
                title="Add a new photo or voice note"
              >
                <Plus className="w-3.5 h-3.5" />
              </button>
            </div>
          </div>

          {/* Carousel Arrows (if > 1 memory) */}
          {memories.length > 1 && (
            <div className="absolute inset-y-0 left-2 right-2 flex items-center justify-between pointer-events-none z-10">
              <button
                type="button"
                onClick={handlePrev}
                className="w-8 h-8 rounded-full bg-black/35 hover:bg-black/55 backdrop-blur-md text-white flex items-center justify-center pointer-events-auto border border-white/15 active:scale-90 transition cursor-pointer"
                title="Previous memory"
              >
                <ChevronLeft className="w-4 h-4" />
              </button>
              <button
                type="button"
                onClick={handleNext}
                className="w-8 h-8 rounded-full bg-black/35 hover:bg-black/55 backdrop-blur-md text-white flex items-center justify-center pointer-events-auto border border-white/15 active:scale-90 transition cursor-pointer"
                title="Next memory"
              >
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          )}

          {/* Bottom Row: Memory Caption, Author Attribution & Heart */}
          <div className="z-10 mt-auto pt-8 flex items-end justify-between gap-3">
            <div
              className="min-w-0 cursor-pointer"
              onClick={handleToggleFlip}
              title="Tap to flip card and view story"
            >
              <h2 className="font-serif text-xl sm:text-2xl font-medium tracking-tight text-white drop-shadow-sm truncate">
                {activeMemory.title}
              </h2>
              <div className="flex items-center gap-2 text-[11px] text-white/80 mt-1">
                <span>By {activeMemory.authorName}</span>
                {activeMemory.voiceUrl && (
                  <span className="inline-flex items-center gap-1 text-[10px] text-emerald-300 font-medium">
                    • 🎙 Voice note
                  </span>
                )}
                {activeMemory.caption && (
                  <span className="text-white/60 truncate max-w-[150px] hidden sm:inline">
                    • {activeMemory.caption}
                  </span>
                )}
              </div>
            </div>

            {/* Heart Button */}
            <button
              type="button"
              onClick={handleToggleLike}
              className={`w-9 h-9 rounded-full flex items-center justify-center shrink-0 backdrop-blur-md border transition-all active:scale-90 cursor-pointer ${
                isCurrentLiked
                  ? 'bg-rose-500/90 text-white border-rose-400 shadow-md'
                  : 'bg-white/20 text-white/90 border-white/30 hover:bg-white/30'
              }`}
              title={isCurrentLiked ? 'Hearted' : 'Send heart reaction'}
            >
              <Heart className={`w-4 h-4 ${isCurrentLiked ? 'fill-current' : ''}`} />
            </button>
          </div>
        </div>
      ) : (
        /* BACK SIDE: Story, Voice Note Player, Card Flip */
        <div
          className="relative w-full min-h-[230px] flex flex-col justify-between p-5 bg-[var(--paper)] text-[var(--ink)] border border-[var(--line)]"
        >
          {/* Header Row */}
          <div className="flex items-center justify-between gap-2 border-b border-[var(--line)] pb-2.5">
            <div className="flex items-center gap-2">
              <span className="text-[10px] uppercase font-mono tracking-wider font-semibold text-[var(--app-accent)]">
                The Story Behind
              </span>
              <span className="text-[10px] text-[var(--soft)]">• {activeMemory.date}</span>
            </div>

            <button
              type="button"
              onClick={handleToggleFlip}
              className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-[var(--white)] hover:opacity-85 text-[10px] font-medium text-[var(--ink)] border border-[var(--line)] shadow-2xs active:scale-95 transition cursor-pointer"
              title="Flip back to photo"
            >
              <RotateCw className="w-3 h-3" />
              <span>Photo ↺</span>
            </button>
          </div>

          {/* Story Body */}
          <div className="my-auto py-3">
            <h3 className="font-serif text-lg font-medium text-[var(--ink)] mb-1.5">
              {activeMemory.title}
            </h3>
            {activeMemory.caption ? (
              <p className="font-serif italic text-sm text-[var(--ink)]/90 leading-relaxed bg-[var(--white)] p-3 rounded-xl border border-[var(--line)]/60 shadow-2xs">
                “{activeMemory.caption}”
              </p>
            ) : (
              <p className="text-xs text-[var(--soft)] italic">
                No handwritten story was attached to this moment yet.
              </p>
            )}

            {/* Voice Memo Audio Player (if attached) */}
            {activeMemory.voiceUrl && (
              <div className="mt-3 flex items-center justify-between p-2.5 rounded-xl bg-emerald-500/10 border border-emerald-500/25">
                <div className="flex items-center gap-2 min-w-0">
                  <div className="w-7 h-7 rounded-full bg-emerald-600 text-white flex items-center justify-center shrink-0">
                    {isPlayingVoice ? <Volume2 className="w-3.5 h-3.5 animate-pulse" /> : <VolumeX className="w-3.5 h-3.5" />}
                  </div>
                  <div className="min-w-0">
                    <p className="text-[11px] font-semibold text-[var(--ink)] truncate">Voice Memo</p>
                    <p className="text-[9px] text-[var(--soft)]">Recorded with this memory</p>
                  </div>
                </div>

                <button
                  type="button"
                  onClick={(e) => handleToggleVoice(activeMemory.voiceUrl!, e)}
                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-emerald-600 hover:bg-emerald-700 text-white text-[10px] font-medium shadow-xs active:scale-95 transition cursor-pointer"
                >
                  {isPlayingVoice ? (
                    <>
                      <Pause className="w-3 h-3 fill-current" />
                      <span>Pause</span>
                    </>
                  ) : (
                    <>
                      <Play className="w-3 h-3 fill-current" />
                      <span>Play Note</span>
                    </>
                  )}
                </button>
              </div>
            )}
          </div>

          {/* Footer Attribution */}
          <div className="flex items-center justify-between text-[10px] text-[var(--soft)] border-t border-[var(--line)] pt-2.5">
            <span>Captured by {activeMemory.authorName}</span>
            <button
              type="button"
              onClick={onGoToMemories}
              className="text-[var(--app-accent)] font-medium hover:underline cursor-pointer"
            >
              Open Gallery →
            </button>
          </div>
        </div>
      )}

      {/* Slide Dot Indicators (at bottom if > 1) */}
      {memories.length > 1 && !isFlipped && (
        <div className="absolute bottom-1.5 left-0 right-0 flex items-center justify-center gap-1.5 z-20 pointer-events-none">
          {memories.map((_, idx) => (
            <span
              key={idx}
              className={`h-1.5 rounded-full transition-all duration-300 ${
                idx === currentIndex ? 'w-5 bg-white' : 'w-1.5 bg-white/40'
              }`}
            />
          ))}
        </div>
      )}
    </div>
  )
}
