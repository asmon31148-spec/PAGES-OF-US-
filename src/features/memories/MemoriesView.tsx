import React, { useState, useEffect, useCallback, useMemo } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { useAuth } from '@/core/auth'
import { useTheme } from '@/core/theme'
import { useToast } from '@/core/toast'
import {
  uploadMediaFile,
  getSupabaseClient,
  getAuthorAttribution,
  formatAuthor,
  generateEntityId,
  formatLocalDate
} from '@/core/storage'
import { realtimeBridge } from '@/core/realtime'
import { useAudioRecorder } from '@/core/audio'
import confetti from 'canvas-confetti'
import {
  Plus,
  X,
  Mic,
  Square,
  Play,
  Pause,
  Loader2,
  Image as ImageIcon,
  Trash2,
  Maximize2,
  ChevronLeft,
  ChevronRight,
  Heart,
  Volume2,
  Search,
  Video,
  Sparkles,
  Bookmark,
  Share2,
  Film
} from 'lucide-react'
import { LetterboxView } from '../letterbox'
import { TimelineView } from '../timeline'

export type MemoryMediaType = 'photo' | 'video' | 'audio'

export interface MemoryItem {
  id: string
  title: string
  caption: string
  mediaUrl: string
  voiceUrl?: string
  mediaType: MemoryMediaType
  createdAt: string
  rawDate?: string
  addedBy: string
  isMine?: boolean
  rotation?: string
  likesCount?: number
}

type CollectionType = 'captured' | 'letters' | 'timeline'
type MediaFilterType = 'all' | 'photos' | 'videos' | 'audio'
type AddMemoryMode = 'chooser' | 'photo' | 'video' | 'voice'

export const MemoriesView: React.FC = () => {
  const { user, space, partner } = useAuth()
  const { theme, isDark } = useTheme()
  const { showToast } = useToast()

  // 1. Primary Collection Switcher
  const [activeCollection, setActiveCollection] = useState<CollectionType>('captured')
  const [mediaFilter, setMediaFilter] = useState<MediaFilterType>('all')
  const [searchQuery, setSearchQuery] = useState('')

  // 2. Real memories data
  const [memories, setMemories] = useState<MemoryItem[]>([])
  const [currentStackIndex, setCurrentStackIndex] = useState(0)

  // 3. Audio & Voice Whisper Playback
  const [playingVoiceId, setPlayingVoiceId] = useState<string | null>(null)
  const [voiceAudio, setVoiceAudio] = useState<HTMLAudioElement | null>(null)
  const [voiceProgress, setVoiceProgress] = useState(0)

  // 4. Lightbox & Likes
  const [activeLightboxMedia, setActiveLightboxMedia] = useState<string | null>(null)
  const [likedMap, setLikedMap] = useState<Record<string, boolean>>({})

  // 5. Add Memory Modal
  const [isAdding, setIsAdding] = useState(false)
  const [addMode, setAddMode] = useState<AddMemoryMode>('chooser')
  const [selectedFile, setSelectedFile] = useState<File | null>(null)
  const [previewUrl, setPreviewUrl] = useState<string | null>(null)
  const [title, setTitle] = useState('')
  const [caption, setCaption] = useState('')
  const [isUploading, setIsUploading] = useState(false)

  const {
    isRecording,
    recordingTime,
    recordedAudio,
    isPlayingPreview,
    startRecording,
    stopRecording,
    clearRecording,
    togglePlayPreview,
    uploadVoiceMemo
  } = useAudioRecorder()

  const spaceId = space?.id || 'default_space'

  // Fetch real memories from Supabase
  const fetchMemories = useCallback(async () => {
    try {
      const supabase = getSupabaseClient()
      const { data, error } = await supabase
        .from('memories')
        .select('*')
        .eq('space_id', spaceId)
        .order('created_at', { ascending: false })

      if (error) {
        console.warn('Error fetching memories:', error.message)
        return
      }

      if (data && data.length > 0) {
        const mapped: MemoryItem[] = data.map((row, idx) => {
          const { authorName, isMine } = getAuthorAttribution(row.author, user, partner?.nickname)

          const mUrl = row.media_url || ''
          const isVideo =
            mUrl.includes('.mp4') ||
            mUrl.includes('.mov') ||
            mUrl.includes('.webm') ||
            mUrl.startsWith('data:video') ||
            mUrl.includes('video/')

          const isAudioOnly = (!mUrl || mUrl === '') && !!row.thumbnail_url
          const mediaType: MemoryMediaType = isAudioOnly ? 'audio' : isVideo ? 'video' : 'photo'

          return {
            id: row.id,
            title: row.title || (isAudioOnly ? 'Voice Whisper' : isVideo ? 'Video Moment' : 'Photo Moment'),
            caption: row.caption || '',
            mediaUrl: mUrl,
            voiceUrl:
              row.thumbnail_url &&
              (row.thumbnail_url.startsWith('data:audio') || row.thumbnail_url.startsWith('http'))
                ? row.thumbnail_url
                : undefined,
            mediaType,
            rawDate: row.created_at,
            createdAt: formatLocalDate(row.created_at, {
              day: 'numeric',
              month: 'short',
              year: 'numeric'
            }),
            addedBy: isMine ? 'You' : authorName,
            isMine,
            rotation: row.rotation || (idx % 2 === 0 ? '-1deg' : '1deg'),
            likesCount: idx % 3 === 0 ? 1 : 0
          }
        })
        setMemories(mapped)
      } else {
        setMemories([])
      }
    } catch (err) {
      console.warn('Failed to load memories:', err)
    }
  }, [spaceId, user, partner?.nickname])

  useEffect(() => {
    fetchMemories()

    const supabase = getSupabaseClient()
    const channel = supabase
      .channel(`memories_feed_${spaceId}`)
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

    const unsubRealtime = realtimeBridge.subscribe((event) => {
      if (event.type === 'MEMORY_ADDED') {
        fetchMemories()
      }
    })

    return () => {
      supabase.removeChannel(channel)
      unsubRealtime()
      if (voiceAudio) {
        voiceAudio.pause()
      }
    }
  }, [spaceId, fetchMemories, voiceAudio])

  // Filter memories based on search and media tags
  const filteredMemories = useMemo(() => {
    return memories.filter((mem) => {
      // 1. Media Type Filter
      if (mediaFilter === 'photos' && mem.mediaType !== 'photo') return false
      if (mediaFilter === 'videos' && mem.mediaType !== 'video') return false
      if (mediaFilter === 'audio' && mem.mediaType !== 'audio') return false

      // 2. Search Query Filter (Title, Caption, Date, Author)
      if (searchQuery.trim()) {
        const query = searchQuery.trim().toLowerCase()
        const matchTitle = mem.title.toLowerCase().includes(query)
        const matchCaption = mem.caption.toLowerCase().includes(query)
        const matchAuthor = mem.addedBy.toLowerCase().includes(query)
        const matchDate = mem.createdAt.toLowerCase().includes(query)
        if (!matchTitle && !matchCaption && !matchAuthor && !matchDate) {
          return false
        }
      }

      return true
    })
  }, [memories, mediaFilter, searchQuery])

  // Audio Playback Controller
  const handleToggleVoicePlayback = (url: string, id: string) => {
    if (playingVoiceId === id) {
      if (voiceAudio) {
        voiceAudio.pause()
      }
      setPlayingVoiceId(null)
      return
    }

    if (voiceAudio) {
      voiceAudio.pause()
    }

    const audio = new Audio(url)
    setVoiceAudio(audio)
    setPlayingVoiceId(id)

    audio.ontimeupdate = () => {
      if (audio.duration) {
        setVoiceProgress((audio.currentTime / audio.duration) * 100)
      }
    }

    audio.onended = () => {
      setPlayingVoiceId(null)
      setVoiceProgress(0)
    }

    audio.play().catch((e) => {
      console.warn('Playback error:', e)
      showToast('Could not play audio.')
      setPlayingVoiceId(null)
    })
  }

  // Toggle Heart
  const handleToggleLike = (id: string, e?: React.MouseEvent) => {
    e?.stopPropagation()
    const isNowLiked = !likedMap[id]
    setLikedMap((prev) => ({ ...prev, [id]: isNowLiked }))

    if (isNowLiked) {
      confetti({ particleCount: 20, spread: 45, origin: { y: 0.6 } })
      showToast('Sent love to this memory 💕')
      try {
        realtimeBridge.broadcast({
          type: 'PULSE',
          senderId: user?.id || '',
          senderNickname: user?.nickname || 'Partner',
          timestamp: Date.now()
        })
      } catch {}
    }
  }

  // Reset Modal Form
  const resetAddForm = () => {
    setSelectedFile(null)
    setPreviewUrl(null)
    setTitle('')
    setCaption('')
    clearRecording()
    setAddMode('chooser')
    setIsAdding(false)
  }

  // Save new Memory
  const handleSaveMemory = async (e: React.FormEvent) => {
    e.preventDefault()

    if (addMode === 'photo' && !selectedFile) {
      showToast('Please select a photo from your gallery!')
      return
    }
    if (addMode === 'video' && !selectedFile) {
      showToast('Please select a video file!')
      return
    }
    if (addMode === 'voice' && !recordedAudio) {
      showToast('Please record a voice message first!')
      return
    }

    if (!user) return
    setIsUploading(true)
    showToast('Saving memory to your sanctuary...')

    try {
      let finalMediaUrl = ''
      let finalVoiceUrl: string | undefined = undefined

      if (addMode === 'photo' && selectedFile) {
        const upRes = await uploadMediaFile(selectedFile, 'memories')
        finalMediaUrl = upRes.url
        if (recordedAudio) {
          const vUrl = await uploadVoiceMemo('voice_memos')
          finalVoiceUrl = vUrl || undefined
        }
      } else if (addMode === 'video' && selectedFile) {
        const upRes = await uploadMediaFile(selectedFile, 'memories')
        finalMediaUrl = upRes.url
      } else if (addMode === 'voice' && recordedAudio) {
        const vUrl = await uploadVoiceMemo('voice_memos')
        finalVoiceUrl = vUrl || undefined
      }

      const nowIso = new Date().toISOString()
      const newMemId = generateEntityId('mem')
      const chosenRotation = Math.random() > 0.5 ? '1deg' : '-1deg'

      const defaultTitle =
        addMode === 'voice'
          ? 'Quiet Voice Whisper'
          : addMode === 'video'
          ? 'Special Video'
          : 'A Captured Moment'

      const supabase = getSupabaseClient()
      const { error } = await supabase.from('memories').insert({
        id: newMemId,
        space_id: spaceId,
        title: title.trim() || defaultTitle,
        caption: caption.trim(),
        media_url: finalMediaUrl || '',
        thumbnail_url: finalVoiceUrl || '',
        author: formatAuthor(user),
        rotation: chosenRotation,
        created_at: nowIso
      })

      if (error) {
        throw new Error(error.message)
      }

      const optimistic: MemoryItem = {
        id: newMemId,
        title: title.trim() || defaultTitle,
        caption: caption.trim(),
        mediaUrl: finalMediaUrl || '',
        voiceUrl: finalVoiceUrl,
        mediaType: addMode === 'voice' ? 'audio' : addMode === 'video' ? 'video' : 'photo',
        createdAt: formatLocalDate(nowIso, { day: 'numeric', month: 'short', year: 'numeric' }),
        rawDate: nowIso,
        addedBy: 'You',
        isMine: true,
        rotation: chosenRotation,
        likesCount: 0
      }

      setMemories((prev) => [optimistic, ...prev])
      resetAddForm()

      confetti({ particleCount: 35, spread: 60, origin: { y: 0.6 } })
      showToast('Moment captured & preserved forever ✨')

      realtimeBridge.broadcast({
        type: 'MEMORY_ADDED',
        senderId: user.id,
        senderNickname: user.nickname,
        timestamp: Date.now()
      })
    } catch (err: any) {
      showToast(err.message || 'Error saving moment.')
    } finally {
      setIsUploading(false)
    }
  }

  // Active stack card
  const activeStackCard = filteredMemories[currentStackIndex] || filteredMemories[0]

  // STANDALONE VOICE MESSAGES ONLY for Upper Hero Waveform Player (Never photo whispers!)
  const latestStandaloneVoiceMemory = useMemo(() => {
    return memories.find((m) => m.mediaType === 'audio' && m.voiceUrl)
  }, [memories])

  return (
    <div className="page active !p-0 flex flex-col min-h-screen bg-[var(--app-bg)] text-[var(--ink)]">
      {/* 1. TOP HEADER & ETHEREAL BLURRED ATMOSPHERE */}
      <div className="relative pt-safe px-4 pt-10 pb-4 overflow-hidden bg-gradient-to-b from-rose-200/40 via-purple-100/20 to-transparent dark:from-rose-950/30 dark:via-purple-950/15 dark:to-transparent border-b border-[var(--line)]/40">
        {/* Soft background aura sphere */}
        <div className="absolute -top-12 -left-12 w-48 h-48 rounded-full bg-rose-300/30 dark:bg-rose-600/10 blur-3xl pointer-events-none" />
        <div className="absolute top-0 -right-12 w-48 h-48 rounded-full bg-indigo-300/25 dark:bg-indigo-600/10 blur-3xl pointer-events-none" />

        <div className="relative z-10 max-w-lg mx-auto w-full">
          {/* Main Title from Reference Image */}
          <div className="mb-3">
            <h1 className="font-serif text-3xl sm:text-4xl font-medium tracking-tight text-[var(--ink)] leading-[1.15]">
              Memories <br />
              <span className="opacity-90 italic">don't begin in focus.</span>
            </h1>
          </div>

          {/* Top Collection Switcher: Captured | Letters | Timeline */}
          <div className="flex items-center gap-1 p-1 rounded-2xl bg-[var(--white)]/80 dark:bg-black/30 backdrop-blur-md border border-[var(--line)]/60 shadow-2xs mb-3">
            <button
              type="button"
              onClick={() => setActiveCollection('captured')}
              className={`flex-1 py-1.5 px-3 rounded-xl text-xs font-semibold transition-all cursor-pointer flex items-center justify-center gap-1.5 ${
                activeCollection === 'captured'
                  ? 'bg-[var(--app-accent)] text-white shadow-xs'
                  : 'text-[var(--soft)] hover:text-[var(--ink)]'
              }`}
            >
              <span>📷</span>
              <span>Captured</span>
            </button>

            <button
              type="button"
              onClick={() => setActiveCollection('letters')}
              className={`flex-1 py-1.5 px-3 rounded-xl text-xs font-semibold transition-all cursor-pointer flex items-center justify-center gap-1.5 ${
                activeCollection === 'letters'
                  ? 'bg-[var(--app-accent)] text-white shadow-xs'
                  : 'text-[var(--soft)] hover:text-[var(--ink)]'
              }`}
            >
              <span>💌</span>
              <span>Letters</span>
            </button>

            <button
              type="button"
              onClick={() => setActiveCollection('timeline')}
              className={`flex-1 py-1.5 px-3 rounded-xl text-xs font-semibold transition-all cursor-pointer flex items-center justify-center gap-1.5 ${
                activeCollection === 'timeline'
                  ? 'bg-[var(--app-accent)] text-white shadow-xs'
                  : 'text-[var(--soft)] hover:text-[var(--ink)]'
              }`}
            >
              <span>⏳</span>
              <span>Journey</span>
            </button>
          </div>

          {/* Quick Media Filter Pills (only when in Captured) */}
          {activeCollection === 'captured' && (
            <div className="flex items-center gap-2 overflow-x-auto no-scrollbar py-0.5">
              {(
                [
                  { id: 'all', label: 'All Moments' },
                  { id: 'photos', label: '📷 Photos' },
                  { id: 'videos', label: '📹 Videos' },
                  { id: 'audio', label: '🎙️ Voice Whispers' }
                ] as const
              ).map((f) => (
                <button
                  key={f.id}
                  type="button"
                  onClick={() => setMediaFilter(f.id)}
                  className={`py-1 px-3 rounded-full text-[11px] font-medium shrink-0 transition cursor-pointer border ${
                    mediaFilter === f.id
                      ? 'border-[var(--app-accent)] bg-[var(--app-accent)]/10 text-[var(--app-accent)] font-semibold'
                      : 'border-[var(--line)]/70 bg-[var(--white)]/60 text-[var(--soft)] hover:text-[var(--ink)]'
                  }`}
                >
                  {f.label}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* 2. SUB-COLLECTION VIEWS: Letters & Journey */}
      {activeCollection === 'letters' && (
        <div className="flex-1 w-full max-w-md mx-auto">
          <LetterboxView />
        </div>
      )}

      {activeCollection === 'timeline' && (
        <div className="flex-1 w-full max-w-md mx-auto">
          <TimelineView />
        </div>
      )}

      {/* 3. CAPTURED FEED (3D Stack + Waveform Player + Bento Grid) */}
      {activeCollection === 'captured' && (
        <div className="flex-1 px-4 py-5 max-w-lg mx-auto w-full space-y-6 pb-28">
          {/* SEARCH BAR (Instant multi-filter search) */}
          <div className="relative">
            <Search className="w-4 h-4 text-[var(--soft)] absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Find a memory, quote, or date..."
              className="w-full pl-10 pr-10 py-2.5 rounded-2xl bg-[var(--white)] border border-[var(--line)] text-xs text-[var(--ink)] placeholder-[var(--soft)] focus:outline-none focus:ring-2 focus:ring-[var(--app-accent)] transition shadow-2xs"
            />
            {searchQuery && (
              <button
                type="button"
                onClick={() => setSearchQuery('')}
                className="absolute right-3 top-1/2 -translate-y-1/2 p-1 text-[var(--soft)] hover:text-[var(--ink)]"
              >
                <X className="w-3.5 h-3.5" />
              </button>
            )}
          </div>

          {/* UPPER HERO VOICE WAVEFORM PLAYER (Plays STANDALONE voice messages only!) */}
          {latestStandaloneVoiceMemory ? (
            <div className="relative rounded-3xl overflow-hidden border border-[var(--line)] shadow-sm bg-[var(--white)]">
              <div className="absolute inset-0 bg-gradient-to-br from-rose-100/60 to-purple-100/40 dark:from-rose-950/20 dark:to-purple-950/20" />

              <div className="relative z-10 p-5 space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-[10px] tracking-wider uppercase font-semibold text-[var(--app-accent)] bg-[var(--app-accent)]/10 px-2 py-0.5 rounded-full border border-[var(--app-accent)]/20">
                    Latest Voice Whisper
                  </span>
                  <span className="text-[10px] text-[var(--soft)] font-mono">
                    {latestStandaloneVoiceMemory.createdAt}
                  </span>
                </div>

                <div>
                  <h3 className="font-serif text-lg font-bold text-[var(--ink)]">
                    {latestStandaloneVoiceMemory.title}
                  </h3>
                  <p className="text-xs text-[var(--soft)] italic mt-0.5 line-clamp-1">
                    &ldquo;{latestStandaloneVoiceMemory.caption || 'A quiet voice message for us.'}&rdquo;
                  </p>
                </div>

                {/* Animated Waveform & 1-Tap Play */}
                <div className="flex items-center gap-3 p-3 rounded-2xl bg-[var(--paper)]/80 backdrop-blur-md border border-[var(--line)]/60">
                  <button
                    type="button"
                    onClick={() =>
                      latestStandaloneVoiceMemory.voiceUrl &&
                      handleToggleVoicePlayback(latestStandaloneVoiceMemory.voiceUrl, latestStandaloneVoiceMemory.id)
                    }
                    className="w-10 h-10 rounded-full bg-[var(--app-accent)] text-white flex items-center justify-center shadow-xs cursor-pointer hover:scale-105 transition shrink-0"
                    aria-label="Play Voice Whisper"
                  >
                    {playingVoiceId === latestStandaloneVoiceMemory.id ? (
                      <Pause className="w-4 h-4 fill-white" />
                    ) : (
                      <Play className="w-4 h-4 fill-white ml-0.5" />
                    )}
                  </button>

                  <div className="flex-1 flex items-center gap-1 h-6">
                    {Array.from({ length: 24 }).map((_, i) => {
                      const isPlaying = playingVoiceId === latestStandaloneVoiceMemory.id
                      const barHeight = isPlaying
                        ? Math.sin(i * 0.5 + Date.now() * 0.005) * 10 + 14
                        : 4 + (i % 5) * 3
                      return (
                        <div
                          key={i}
                          className="flex-1 rounded-full transition-all duration-150"
                          style={{
                            height: `${Math.max(4, barHeight)}px`,
                            backgroundColor:
                              i * 4 < voiceProgress
                                ? 'var(--app-accent)'
                                : 'var(--line)'
                          }}
                        />
                      )
                    })}
                  </div>

                  <span className="text-[11px] font-mono text-[var(--soft)] shrink-0">
                    {playingVoiceId === latestStandaloneVoiceMemory.id
                      ? `${Math.round(voiceProgress)}%`
                      : 'Voice'}
                  </span>
                </div>
              </div>
            </div>
          ) : (
            /* Empty state encouraging recording a voice whisper */
            <div
              onClick={() => {
                setIsAdding(true)
                setAddMode('voice')
              }}
              className="p-4 rounded-3xl border border-dashed border-[var(--line)] bg-[var(--white)]/60 flex items-center justify-between cursor-pointer hover:border-[var(--app-accent)] transition shadow-2xs"
            >
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-2xl bg-[var(--app-accent)]/10 text-[var(--app-accent)] flex items-center justify-center text-lg">
                  🎙️
                </div>
                <div>
                  <h4 className="text-xs font-bold text-[var(--ink)]">Record a Voice Whisper</h4>
                  <p className="text-[11px] text-[var(--soft)] mt-0.5">
                    Leave a private spoken memo for {partner?.nickname || 'your partner'}
                  </p>
                </div>
              </div>
              <span className="text-xs font-semibold text-[var(--app-accent)] flex items-center gap-0.5">
                Record <ChevronRight className="w-3.5 h-3.5" />
              </span>
            </div>
          )}

          {/* 3D SWIPEABLE CARD STACK (Moments in Focus) */}
          {filteredMemories.length > 0 ? (
            <div className="space-y-3">
              <div className="flex items-center justify-between px-1">
                <h3 className="font-serif text-sm font-bold text-[var(--ink)]">
                  Moments in Focus ({filteredMemories.length})
                </h3>
                <span className="text-[10px] text-[var(--soft)] font-mono">
                  {currentStackIndex + 1} of {filteredMemories.length}
                </span>
              </div>

              {/* Top 3D Stack Card */}
              {activeStackCard && (
                <motion.div
                  key={activeStackCard.id}
                  initial={{ opacity: 0, scale: 0.96 }}
                  animate={{ opacity: 1, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.94 }}
                  transition={{ duration: 0.25 }}
                  className="rounded-3xl border border-[var(--line)] bg-[var(--white)] p-5 shadow-md space-y-4"
                >
                  {/* Card Header: Avatar + Title + Date */}
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2.5">
                      <div className="w-9 h-9 rounded-full bg-gradient-to-tr from-[#8a9b85] to-[#b77e6b] p-0.5">
                        <div className="w-full h-full rounded-full bg-[var(--paper)] flex items-center justify-center text-xs font-bold font-serif text-[var(--ink)]">
                          {activeStackCard.addedBy.charAt(0)}
                        </div>
                      </div>
                      <div>
                        <h4 className="text-xs font-bold text-[var(--ink)]">
                          {activeStackCard.title}
                        </h4>
                        <span className="text-[10px] text-[var(--soft)]">
                          {activeStackCard.createdAt} · By {activeStackCard.addedBy}
                        </span>
                      </div>
                    </div>

                    <button
                      type="button"
                      onClick={() => handleToggleLike(activeStackCard.id)}
                      className="p-2 rounded-full hover:bg-[var(--paper)] transition cursor-pointer text-[var(--soft)] hover:text-rose-500"
                    >
                      <Heart
                        className={`w-4 h-4 ${
                          likedMap[activeStackCard.id]
                            ? 'fill-rose-500 text-rose-500'
                            : 'text-[var(--soft)]'
                        }`}
                      />
                    </button>
                  </div>

                  {/* Caption / Quote */}
                  {activeStackCard.caption && (
                    <p className="font-serif italic text-xs text-[var(--ink)] leading-relaxed bg-[var(--paper)]/50 p-3 rounded-2xl border border-[var(--line)]/50">
                      &ldquo;{activeStackCard.caption}&rdquo;
                    </p>
                  )}

                  {/* Media Rendering based on type */}
                  {activeStackCard.mediaType === 'video' && activeStackCard.mediaUrl ? (
                    <div className="relative rounded-2xl overflow-hidden aspect-[4/3] bg-black shadow-inner">
                      <video
                        src={activeStackCard.mediaUrl}
                        controls
                        playsInline
                        className="w-full h-full object-cover"
                      />
                    </div>
                  ) : activeStackCard.mediaType === 'photo' && activeStackCard.mediaUrl ? (
                    <div
                      className="relative rounded-2xl overflow-hidden aspect-[4/3] bg-[var(--paper)] cursor-pointer group"
                      onClick={() => setActiveLightboxMedia(activeStackCard.mediaUrl)}
                    >
                      <img
                        src={activeStackCard.mediaUrl}
                        alt={activeStackCard.title}
                        className="w-full h-full object-cover group-hover:scale-102 transition duration-300"
                      />
                      <div className="absolute bottom-2.5 right-2.5 p-1.5 rounded-full bg-black/60 text-white backdrop-blur-xs">
                        <Maximize2 className="w-3.5 h-3.5" />
                      </div>
                    </div>
                  ) : activeStackCard.mediaType === 'audio' && activeStackCard.voiceUrl ? (
                    /* Standalone Audio Card in Stack */
                    <div className="p-4 rounded-2xl bg-gradient-to-tr from-rose-50 to-purple-50 dark:from-rose-950/20 dark:to-purple-950/20 border border-[var(--line)] flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <button
                          type="button"
                          onClick={() =>
                            handleToggleVoicePlayback(activeStackCard.voiceUrl!, activeStackCard.id)
                          }
                          className="w-10 h-10 rounded-full bg-[var(--app-accent)] text-white flex items-center justify-center shadow-xs"
                        >
                          {playingVoiceId === activeStackCard.id ? (
                            <Pause className="w-4 h-4 fill-white" />
                          ) : (
                            <Play className="w-4 h-4 fill-white ml-0.5" />
                          )}
                        </button>
                        <div>
                          <span className="text-[10px] font-bold text-[var(--app-accent)] uppercase">
                            Voice Whisper
                          </span>
                          <p className="text-xs font-semibold text-[var(--ink)]">Tap to listen</p>
                        </div>
                      </div>
                      <Volume2 className="w-4 h-4 text-[var(--soft)]" />
                    </div>
                  ) : null}

                  {/* 30s Voice note attached to photo ONLY */}
                  {activeStackCard.mediaType === 'photo' && activeStackCard.voiceUrl && (
                    <div className="pt-1">
                      <button
                        type="button"
                        onClick={() =>
                          handleToggleVoicePlayback(
                            activeStackCard.voiceUrl!,
                            activeStackCard.id
                          )
                        }
                        className="w-full py-2 px-3 rounded-xl bg-[var(--app-accent)]/10 text-[var(--app-accent)] border border-[var(--app-accent)]/20 hover:bg-[var(--app-accent)]/20 transition flex items-center justify-between text-xs font-semibold cursor-pointer"
                      >
                        <span className="flex items-center gap-1.5">
                          {playingVoiceId === activeStackCard.id ? (
                            <Pause className="w-3.5 h-3.5" />
                          ) : (
                            <Play className="w-3.5 h-3.5" />
                          )}
                          <span>
                            {playingVoiceId === activeStackCard.id
                              ? 'Playing Photo Voice Whisper...'
                              : 'Listen to Voice Whisper'}
                          </span>
                        </span>
                        <Volume2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  )}

                  {/* Card Navigation Footer */}
                  <div className="flex items-center justify-between pt-2 border-t border-[var(--line)]/60">
                    <button
                      type="button"
                      disabled={currentStackIndex === 0}
                      onClick={() => setCurrentStackIndex((p) => Math.max(0, p - 1))}
                      className="p-2 rounded-xl border border-[var(--line)] hover:bg-[var(--paper)] transition cursor-pointer disabled:opacity-40"
                    >
                      <ChevronLeft className="w-4 h-4" />
                    </button>

                    <button
                      type="button"
                      onClick={() => showToast('Saved to your private couple favorites ✨')}
                      className="py-1.5 px-4 rounded-xl border border-[var(--line)] text-xs font-medium text-[var(--ink)] hover:bg-[var(--paper)] transition cursor-pointer flex items-center gap-1.5"
                    >
                      <Bookmark className="w-3.5 h-3.5 text-[var(--app-accent)]" />
                      <span>Bookmark</span>
                    </button>

                    <button
                      type="button"
                      disabled={currentStackIndex >= filteredMemories.length - 1}
                      onClick={() =>
                        setCurrentStackIndex((p) =>
                          Math.min(filteredMemories.length - 1, p + 1)
                        )
                      }
                      className="p-2 rounded-xl border border-[var(--line)] hover:bg-[var(--paper)] transition cursor-pointer disabled:opacity-40"
                    >
                      <ChevronRight className="w-4 h-4" />
                    </button>
                  </div>
                </motion.div>
              )}
            </div>
          ) : (
            <div className="p-8 text-center rounded-3xl border border-dashed border-[var(--line)] bg-[var(--white)]/50 space-y-2">
              <span className="text-3xl">🌸</span>
              <h3 className="font-serif text-sm font-bold text-[var(--ink)]">
                No memories match your filter
              </h3>
              <p className="text-xs text-[var(--soft)]">
                Capture a photo, upload a video, or record a quiet voice whisper.
              </p>
            </div>
          )}

          {/* BENTO GRID: Atmosphere & Highlights */}
          {filteredMemories.length > 0 && (
            <div className="space-y-3 pt-4">
              <h3 className="font-serif text-sm font-bold text-[var(--ink)] px-1">
                Sanctuary Highlights
              </h3>
              <div className="grid grid-cols-2 gap-3">
                {/* Tile 1: Atmosphere */}
                <div
                  className="rounded-2xl p-3.5 border border-[var(--line)] bg-[var(--white)] shadow-2xs space-y-2 cursor-pointer hover:border-[var(--app-accent)] transition"
                  onClick={() => setCurrentStackIndex(0)}
                >
                  <span className="text-[10px] uppercase font-bold text-[var(--app-accent)] tracking-wider">
                    Atmosphere
                  </span>
                  {filteredMemories[0]?.mediaUrl ? (
                    filteredMemories[0].mediaType === 'video' ? (
                      <div className="w-full h-24 rounded-xl bg-black flex items-center justify-center text-white text-xs">
                        <Video className="w-6 h-6" />
                      </div>
                    ) : (
                      <img
                        src={filteredMemories[0].mediaUrl}
                        alt="Atmosphere"
                        className="w-full h-24 object-cover rounded-xl"
                      />
                    )
                  ) : (
                    <div className="w-full h-24 rounded-xl bg-[var(--paper)] flex items-center justify-center text-xs">
                      🎙️
                    </div>
                  )}
                  <p className="font-serif text-xs font-semibold text-[var(--ink)] truncate">
                    {filteredMemories[0]?.title}
                  </p>
                </div>

                {/* Tile 2: Thought of the Day */}
                <div
                  className="rounded-2xl p-3.5 border border-[var(--line)] bg-[var(--white)] shadow-2xs space-y-2 flex flex-col justify-between cursor-pointer hover:border-[var(--app-accent)] transition"
                  onClick={() => setCurrentStackIndex(Math.min(1, filteredMemories.length - 1))}
                >
                  <span className="text-[10px] uppercase font-bold text-[var(--soft)] tracking-wider">
                    Thought of the Day
                  </span>
                  <p className="font-serif italic text-xs text-[var(--ink)] line-clamp-3 leading-relaxed">
                    &ldquo;{filteredMemories[1]?.caption || filteredMemories[0]?.caption || 'Some moments are fleeting, yet they leave a permanent mark.'}&rdquo;
                  </p>
                  <span className="text-[10px] text-[var(--soft)] font-mono">
                    {filteredMemories[1]?.createdAt || filteredMemories[0]?.createdAt}
                  </span>
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {/* FLOATING ACTION BUTTON: ADD MEMORY */}
      {activeCollection === 'captured' && (
        <div className="fixed bottom-20 right-4 z-30">
          <button
            type="button"
            onClick={() => {
              setAddMode('chooser')
              setIsAdding(true)
            }}
            className="h-12 px-5 rounded-full bg-[var(--app-accent)] text-white shadow-lg flex items-center gap-2 text-xs font-bold hover:scale-105 active:scale-95 transition cursor-pointer"
          >
            <Plus className="w-4 h-4" />
            <span>Capture Moment</span>
          </button>
        </div>
      )}

      {/* LIGHTBOX MODAL */}
      {activeLightboxMedia && (
        <div
          className="fixed inset-0 z-[2000] bg-black/90 flex items-center justify-center p-4 backdrop-blur-md"
          onClick={() => setActiveLightboxMedia(null)}
        >
          <button
            type="button"
            onClick={() => setActiveLightboxMedia(null)}
            className="absolute top-5 right-5 p-2 rounded-full bg-white/20 text-white hover:bg-white/30"
          >
            <X className="w-5 h-5" />
          </button>
          <img
            src={activeLightboxMedia}
            alt="Full memory"
            className="max-w-full max-h-[85vh] object-contain rounded-2xl shadow-2xl"
          />
        </div>
      )}

      {/* ================================================================= */}
      {/* ADD MEMORY MODAL (Solid Full-Screen Page with 3 Distinct Options) */}
      {/* ================================================================= */}
      {isAdding && (
        <div className="fixed inset-0 z-[1500] bg-[var(--app-bg)] text-[var(--ink)] flex flex-col overflow-hidden">
          {/* Top Bar */}
          <div className="pt-safe px-4 py-3 flex items-center justify-between border-b border-[var(--line)] bg-[var(--white)] shrink-0">
            {addMode === 'chooser' ? (
              <button
                type="button"
                onClick={resetAddForm}
                className="p-1.5 -ml-1.5 rounded-full hover:bg-[var(--paper)] transition flex items-center gap-1 text-xs font-medium text-[var(--ink)] cursor-pointer"
              >
                <X className="w-4 h-4" />
                <span>Cancel</span>
              </button>
            ) : (
              <button
                type="button"
                onClick={() => setAddMode('chooser')}
                className="p-1.5 -ml-1.5 rounded-full hover:bg-[var(--paper)] transition flex items-center gap-1 text-xs font-medium text-[var(--ink)] cursor-pointer"
              >
                <ChevronLeft className="w-4 h-4" />
                <span>Back</span>
              </button>
            )}

            <h3 className="text-sm font-semibold tracking-tight">
              {addMode === 'chooser'
                ? 'Capture a Memory'
                : addMode === 'photo'
                ? 'Add Photo Memory'
                : addMode === 'video'
                ? 'Add Video Memory'
                : 'Record Voice Whisper'}
            </h3>
            <div className="w-12" />
          </div>

          {/* STEP 1: CHOOSER (3 Distinct Options: Photo, Video, Voice Message) */}
          {addMode === 'chooser' && (
            <div className="flex-1 overflow-y-auto px-4 py-8 max-w-md mx-auto w-full flex flex-col justify-center space-y-4">
              <div className="text-center mb-4">
                <span className="text-2xl">✨</span>
                <h4 className="font-serif text-lg font-bold text-[var(--ink)] mt-1">
                  How would you like to save this moment?
                </h4>
                <p className="text-xs text-[var(--soft)] mt-1">
                  Choose a format to preserve your memory forever
                </p>
              </div>

              {/* Option 1: Photo Memory */}
              <button
                type="button"
                onClick={() => setAddMode('photo')}
                className="p-4 rounded-2xl border border-[var(--line)] bg-[var(--white)] hover:border-[var(--app-accent)] transition shadow-2xs flex items-center gap-4 text-left active:scale-[0.99] cursor-pointer"
              >
                <div className="w-12 h-12 rounded-2xl bg-rose-500/10 text-rose-600 flex items-center justify-center text-xl shrink-0">
                  <ImageIcon className="w-6 h-6" />
                </div>
                <div className="flex-1 min-w-0">
                  <h5 className="text-sm font-bold text-[var(--ink)]">Photo Memory</h5>
                  <p className="text-xs text-[var(--soft)] mt-0.5">
                    Upload from Google Photos or Files with optional 30s voice whisper
                  </p>
                </div>
                <ChevronRight className="w-4 h-4 text-[var(--soft)] shrink-0" />
              </button>

              {/* Option 2: Video Memory */}
              <button
                type="button"
                onClick={() => setAddMode('video')}
                className="p-4 rounded-2xl border border-[var(--line)] bg-[var(--white)] hover:border-[var(--app-accent)] transition shadow-2xs flex items-center gap-4 text-left active:scale-[0.99] cursor-pointer"
              >
                <div className="w-12 h-12 rounded-2xl bg-amber-500/10 text-amber-600 flex items-center justify-center text-xl shrink-0">
                  <Film className="w-6 h-6" />
                </div>
                <div className="flex-1 min-w-0">
                  <h5 className="text-sm font-bold text-[var(--ink)]">Video Moment</h5>
                  <p className="text-xs text-[var(--soft)] mt-0.5">
                    Upload a video clip from your device or Google Photos with caption
                  </p>
                </div>
                <ChevronRight className="w-4 h-4 text-[var(--soft)] shrink-0" />
              </button>

              {/* Option 3: Standalone Voice Whisper */}
              <button
                type="button"
                onClick={() => setAddMode('voice')}
                className="p-4 rounded-2xl border border-[var(--line)] bg-[var(--white)] hover:border-[var(--app-accent)] transition shadow-2xs flex items-center gap-4 text-left active:scale-[0.99] cursor-pointer"
              >
                <div className="w-12 h-12 rounded-2xl bg-emerald-500/10 text-emerald-600 flex items-center justify-center text-xl shrink-0">
                  <Mic className="w-6 h-6" />
                </div>
                <div className="flex-1 min-w-0">
                  <h5 className="text-sm font-bold text-[var(--ink)]">Voice Whisper</h5>
                  <p className="text-xs text-[var(--soft)] mt-0.5">
                    Record a standalone voice note directly from your mic for the top player
                  </p>
                </div>
                <ChevronRight className="w-4 h-4 text-[var(--soft)] shrink-0" />
              </button>
            </div>
          )}

          {/* STEP 2: FORM SUBMISSION (For Photo, Video, or Voice) */}
          {addMode !== 'chooser' && (
            <form onSubmit={handleSaveMemory} className="flex-1 flex flex-col overflow-hidden">
              <div className="flex-1 overflow-y-auto px-4 py-6 max-w-md mx-auto w-full space-y-5">
                {/* 1. PHOTO MODE UPLOADER */}
                {addMode === 'photo' && (
                  <>
                    <div>
                      <label className="text-[11px] font-bold text-[var(--ink)] uppercase tracking-wider block mb-1.5">
                        Select Photo
                      </label>
                      <label className="border-2 border-dashed border-[var(--line)] hover:border-[var(--app-accent)] rounded-2xl p-6 flex flex-col items-center justify-center cursor-pointer transition bg-[var(--white)]">
                        {previewUrl ? (
                          <img
                            src={previewUrl}
                            alt="Preview"
                            className="max-h-48 rounded-xl object-contain mb-2"
                          />
                        ) : (
                          <div className="flex flex-col items-center text-center">
                            <ImageIcon className="w-8 h-8 text-[var(--soft)] mb-2" />
                            <span className="text-xs font-semibold text-[var(--ink)]">
                              Choose from Files or Google Photos
                            </span>
                            <span className="text-[10px] text-[var(--soft)] mt-0.5">
                              Supports JPG, PNG, WEBP, GIF
                            </span>
                          </div>
                        )}
                        <input
                          type="file"
                          accept="image/*"
                          className="hidden"
                          onChange={(e) => {
                            const f = e.target.files?.[0]
                            if (f) {
                              setSelectedFile(f)
                              setPreviewUrl(URL.createObjectURL(f))
                            }
                          }}
                        />
                      </label>
                    </div>

                    {/* Optional 30s Voice Whisper for this specific photo */}
                    <div className="p-4 rounded-2xl border border-[var(--line)] bg-[var(--white)] space-y-2">
                      <div className="flex items-center justify-between">
                        <span className="text-[11px] font-bold text-[var(--ink)] uppercase tracking-wider">
                          30s Photo Voice Whisper (Optional)
                        </span>
                        <span className="text-xs font-mono text-[var(--app-accent)] font-semibold">
                          0:{recordingTime < 10 ? `0${recordingTime}` : recordingTime} / 0:30
                        </span>
                      </div>
                      <p className="text-[11px] text-[var(--soft)]">
                        Attach a voice story played only by the &ldquo;Listen to Voice Whisper&rdquo; button on this photo.
                      </p>

                      <div className="flex items-center gap-2 pt-1">
                        {!isRecording && !recordedAudio && (
                          <button
                            type="button"
                            onClick={startRecording}
                            className="flex-1 py-2.5 px-3 rounded-xl bg-[var(--app-accent)]/10 text-[var(--app-accent)] hover:bg-[var(--app-accent)]/20 transition flex items-center justify-center gap-1.5 text-xs font-semibold cursor-pointer"
                          >
                            <Mic className="w-3.5 h-3.5" />
                            <span>Record Whisper for Photo</span>
                          </button>
                        )}

                        {isRecording && (
                          <button
                            type="button"
                            onClick={stopRecording}
                            className="flex-1 py-2.5 px-3 rounded-xl bg-red-500 text-white transition flex items-center justify-center gap-1.5 text-xs font-semibold cursor-pointer animate-pulse"
                          >
                            <Square className="w-3.5 h-3.5 fill-white" />
                            <span>Stop Recording</span>
                          </button>
                        )}

                        {recordedAudio && (
                          <div className="flex-1 flex items-center gap-2">
                            <button
                              type="button"
                              onClick={togglePlayPreview}
                              className="flex-1 py-2 px-3 rounded-xl bg-[var(--paper)] text-[var(--ink)] border border-[var(--line)] flex items-center justify-center gap-1.5 text-xs font-medium cursor-pointer"
                            >
                              {isPlayingPreview ? (
                                <>
                                  <Pause className="w-3.5 h-3.5" />
                                  <span>Pause Preview</span>
                                </>
                              ) : (
                                <>
                                  <Play className="w-3.5 h-3.5" />
                                  <span>Listen Preview</span>
                                </>
                              )}
                            </button>
                            <button
                              type="button"
                              onClick={clearRecording}
                              className="py-2 px-3 rounded-xl border border-red-500/20 text-red-500 text-xs font-medium cursor-pointer"
                            >
                              Retake
                            </button>
                          </div>
                        )}
                      </div>
                    </div>
                  </>
                )}

                {/* 2. VIDEO MODE UPLOADER */}
                {addMode === 'video' && (
                  <div>
                    <label className="text-[11px] font-bold text-[var(--ink)] uppercase tracking-wider block mb-1.5">
                      Select Video
                    </label>
                    <label className="border-2 border-dashed border-[var(--line)] hover:border-[var(--app-accent)] rounded-2xl p-6 flex flex-col items-center justify-center cursor-pointer transition bg-[var(--white)]">
                      {previewUrl ? (
                        <video
                          src={previewUrl}
                          controls
                          className="max-h-56 rounded-xl object-contain mb-2 bg-black"
                        />
                      ) : (
                        <div className="flex flex-col items-center text-center">
                          <Film className="w-8 h-8 text-amber-600 mb-2" />
                          <span className="text-xs font-semibold text-[var(--ink)]">
                            Choose Video from Files or Google Photos
                          </span>
                          <span className="text-[10px] text-[var(--soft)] mt-0.5">
                            Supports MP4, MOV, WEBM (Plays with its own sound)
                          </span>
                        </div>
                      )}
                      <input
                        type="file"
                        accept="video/*"
                        className="hidden"
                        onChange={(e) => {
                          const f = e.target.files?.[0]
                          if (f) {
                            setSelectedFile(f)
                            setPreviewUrl(URL.createObjectURL(f))
                          }
                        }}
                      />
                    </label>
                  </div>
                )}

                {/* 3. STANDALONE VOICE WHISPER RECORDER */}
                {addMode === 'voice' && (
                  <div className="p-6 rounded-3xl border border-[var(--line)] bg-[var(--white)] text-center space-y-4">
                    <div>
                      <span className="text-[10px] font-bold uppercase tracking-wider text-[var(--app-accent)]">
                        Voice Whisper Studio
                      </span>
                      <h4 className="font-serif text-base font-bold text-[var(--ink)] mt-1">
                        Spoken directly from your heart
                      </h4>
                      <p className="text-xs text-[var(--soft)] mt-0.5">
                        Will appear on the top audio player with animated waveforms
                      </p>
                    </div>

                    {/* Microphone Visualizer */}
                    <div className="py-4 flex flex-col items-center justify-center">
                      <div
                        className={`w-20 h-20 rounded-full flex items-center justify-center transition-all duration-300 ${
                          isRecording
                            ? 'bg-red-500 text-white scale-110 shadow-lg shadow-red-500/30 animate-pulse'
                            : recordedAudio
                            ? 'bg-emerald-500 text-white shadow-md'
                            : 'bg-[var(--app-accent)] text-white shadow-md'
                        }`}
                      >
                        <Mic className="w-8 h-8" />
                      </div>

                      <span className="font-mono text-base font-bold text-[var(--ink)] mt-3">
                        0:{recordingTime < 10 ? `0${recordingTime}` : recordingTime}
                      </span>
                    </div>

                    {/* Controls */}
                    <div className="flex items-center justify-center gap-3">
                      {!isRecording && !recordedAudio && (
                        <button
                          type="button"
                          onClick={startRecording}
                          className="px-6 py-2.5 rounded-full bg-[var(--app-accent)] text-white text-xs font-bold shadow-md hover:scale-105 active:scale-95 transition cursor-pointer"
                        >
                          Start Recording
                        </button>
                      )}

                      {isRecording && (
                        <button
                          type="button"
                          onClick={stopRecording}
                          className="px-6 py-2.5 rounded-full bg-red-500 text-white text-xs font-bold shadow-md hover:scale-105 active:scale-95 transition cursor-pointer animate-pulse"
                        >
                          Stop Recording
                        </button>
                      )}

                      {recordedAudio && (
                        <div className="flex items-center gap-2">
                          <button
                            type="button"
                            onClick={togglePlayPreview}
                            className="px-4 py-2 rounded-xl bg-[var(--paper)] text-[var(--ink)] border border-[var(--line)] text-xs font-medium flex items-center gap-1.5 cursor-pointer"
                          >
                            {isPlayingPreview ? (
                              <>
                                <Pause className="w-3.5 h-3.5" />
                                <span>Pause</span>
                              </>
                            ) : (
                              <>
                                <Play className="w-3.5 h-3.5" />
                                <span>Listen</span>
                              </>
                            )}
                          </button>
                          <button
                            type="button"
                            onClick={clearRecording}
                            className="px-4 py-2 rounded-xl border border-red-500/20 text-red-500 text-xs font-medium cursor-pointer"
                          >
                            Retake
                          </button>
                        </div>
                      )}
                    </div>
                  </div>
                )}

                {/* Common Title & Caption fields for all modes */}
                <div className="space-y-3">
                  <div>
                    <label className="text-[10px] font-semibold text-[var(--soft)] uppercase block mb-1">
                      Title
                    </label>
                    <input
                      type="text"
                      value={title}
                      onChange={(e) => setTitle(e.target.value)}
                      placeholder={
                        addMode === 'voice'
                          ? 'e.g. Good morning my love...'
                          : addMode === 'video'
                          ? 'e.g. Cooking together over FaceTime...'
                          : 'e.g. Our cozy cafe date...'
                      }
                      className="w-full px-3.5 py-2.5 rounded-xl bg-[var(--white)] border border-[var(--line)] text-xs text-[var(--ink)] placeholder-[var(--soft)] focus:outline-none focus:ring-2 focus:ring-[var(--app-accent)]"
                    />
                  </div>

                  <div>
                    <label className="text-[10px] font-semibold text-[var(--soft)] uppercase block mb-1">
                      Caption / Thought
                    </label>
                    <textarea
                      value={caption}
                      onChange={(e) => setCaption(e.target.value)}
                      placeholder="Write a sweet note or quote to remember this moment..."
                      className="w-full h-24 p-3.5 rounded-xl bg-[var(--white)] border border-[var(--line)] text-xs text-[var(--ink)] placeholder-[var(--soft)] focus:outline-none focus:ring-2 focus:ring-[var(--app-accent)] resize-none"
                    />
                  </div>
                </div>
              </div>

              {/* Bottom Submit Bar */}
              <div className="p-4 border-t border-[var(--line)] bg-[var(--white)] shrink-0 max-w-md mx-auto w-full">
                <button
                  type="submit"
                  disabled={isUploading}
                  className="w-full py-3 rounded-2xl bg-[var(--app-accent)] text-white text-xs font-bold shadow-md hover:scale-[1.01] active:scale-[0.99] transition disabled:opacity-50 flex items-center justify-center gap-2 cursor-pointer"
                >
                  {isUploading ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" />
                      <span>Preserving to Sanctuary...</span>
                    </>
                  ) : (
                    <span>
                      {addMode === 'photo'
                        ? 'Save Photo Memory'
                        : addMode === 'video'
                        ? 'Save Video Memory'
                        : 'Save Voice Whisper'}
                    </span>
                  )}
                </button>
              </div>
            </form>
          )}
        </div>
      )}
    </div>
  )
}
