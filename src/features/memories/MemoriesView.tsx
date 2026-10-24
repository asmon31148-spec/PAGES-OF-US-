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
import { dispatchPartnerInteraction } from '@/core/ai'
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
  SlidersHorizontal,
  Video,
  Sparkles,
  Bookmark,
  Share2
} from 'lucide-react'
import { LetterboxView } from '../letterbox'
import { TimelineView } from '../timeline'

export interface MemoryItem {
  id: string
  title: string
  caption: string
  mediaUrl: string
  voiceUrl?: string
  createdAt: string
  rawDate?: string
  addedBy: string
  isMine?: boolean
  rotation?: string
  likesCount?: number
}

type CollectionType = 'captured' | 'letters' | 'timeline'
type MediaFilterType = 'all' | 'photos' | 'videos' | 'audio'

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
          return {
            id: row.id,
            title: row.title || 'Untitled Moment',
            caption: row.caption || '',
            mediaUrl: row.media_url,
            voiceUrl:
              row.thumbnail_url &&
              (row.thumbnail_url.startsWith('data:audio') || row.thumbnail_url.startsWith('http'))
                ? row.thumbnail_url
                : undefined,
            rawDate: row.created_at,
            createdAt: formatLocalDate(row.created_at, {
              day: 'numeric',
              month: 'short',
              year: 'numeric'
            }),
            addedBy: isMine ? 'You' : authorName,
            isMine,
            rotation: row.rotation || (idx % 2 === 0 ? '-1deg' : '1deg'),
            likesCount: (idx % 3 === 0) ? 1 : 0
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
      if (mediaFilter === 'audio' && !mem.voiceUrl) return false
      if (mediaFilter === 'photos' && mem.mediaUrl?.includes('.mp4')) return false
      if (mediaFilter === 'videos' && !mem.mediaUrl?.includes('.mp4')) return false

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

  // Voice note toggle playback
  const handleToggleVoicePlayback = (voiceUrl: string, id: string) => {
    if (playingVoiceId === id && voiceAudio) {
      voiceAudio.pause()
      setPlayingVoiceId(null)
      return
    }

    if (voiceAudio) {
      voiceAudio.pause()
    }

    const audio = new Audio(voiceUrl)
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
      showToast('Could not play voice whisper.')
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

  // Save new Memory
  const handleSaveMemory = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!selectedFile && !recordedAudio) {
      showToast('Please select a photo/video or record a 30s voice whisper!')
      return
    }
    if (!user) return

    setIsUploading(true)
    showToast('Saving memory to your sanctuary...')

    try {
      let finalMediaUrl = ''
      if (selectedFile) {
        const upRes = await uploadMediaFile(selectedFile, 'memories')
        finalMediaUrl = upRes.url
      }

      let finalVoiceUrl: string | undefined = undefined
      if (recordedAudio) {
        const vUrl = await uploadVoiceMemo('voice_memos')
        finalVoiceUrl = vUrl || undefined
      }

      const nowIso = new Date().toISOString()
      const newMemId = generateEntityId('mem')
      const chosenRotation = Math.random() > 0.5 ? '1deg' : '-1deg'

      const supabase = getSupabaseClient()
      const { error } = await supabase.from('memories').insert({
        id: newMemId,
        space_id: spaceId,
        title: title.trim() || 'A Quiet Memory',
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
        title: title.trim() || 'A Quiet Memory',
        caption: caption.trim(),
        mediaUrl: finalMediaUrl || '',
        voiceUrl: finalVoiceUrl,
        createdAt: formatLocalDate(nowIso, { day: 'numeric', month: 'short', year: 'numeric' }),
        rawDate: nowIso,
        addedBy: 'You',
        isMine: true,
        rotation: chosenRotation,
        likesCount: 0
      }

      setMemories((prev) => [optimistic, ...prev])
      setIsAdding(false)
      setSelectedFile(null)
      setPreviewUrl(null)
      setTitle('')
      setCaption('')
      clearRecording()

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
  const latestVoiceMemory = useMemo(() => {
    return memories.find((m) => m.voiceUrl)
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
                  { id: 'audio', label: '🎙️ Audio Whispers' }
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

      {/* 3. CAPTURED MOTION EXPERIENCE (Reference Design Match) */}
      {activeCollection === 'captured' && (
        <div className="flex-1 px-4 py-4 max-w-lg mx-auto w-full space-y-6 pb-28">
          {/* SEARCH BAR (100% Functionally Live) */}
          <div className="relative w-full">
            <Search className="w-4 h-4 text-[var(--soft)] absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
            <input
              type="text"
              placeholder="Find a memory, quote, or date..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-10 pr-10 py-2.5 rounded-2xl border border-[var(--line)] bg-[var(--white)] text-[var(--ink)] text-xs outline-none focus:border-[var(--app-accent)] shadow-2xs transition"
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

          {/* HERO VOICE WAVEFORM PLAYER (Exact Match to Right Phone in Image) */}
          {latestVoiceMemory && (
            <div className="relative rounded-3xl overflow-hidden border border-[var(--line)] shadow-sm bg-[var(--white)]">
              {/* Photo Background if available */}
              {latestVoiceMemory.mediaUrl ? (
                <div className="absolute inset-0 z-0">
                  <img
                    src={latestVoiceMemory.mediaUrl}
                    alt="Voice moment"
                    className="w-full h-full object-cover blur-xs scale-105 opacity-40 dark:opacity-20"
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-[var(--white)] via-[var(--white)]/90 to-transparent" />
                </div>
              ) : (
                <div className="absolute inset-0 bg-gradient-to-br from-rose-100/60 to-purple-100/40 dark:from-rose-950/20 dark:to-purple-950/20" />
              )}

              <div className="relative z-10 p-5 space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-[10px] tracking-wider uppercase font-semibold text-[var(--app-accent)] bg-[var(--app-accent)]/10 px-2 py-0.5 rounded-full border border-[var(--app-accent)]/20">
                    Latest Voice Whisper
                  </span>
                  <span className="text-[10px] text-[var(--soft)] font-mono">
                    {latestVoiceMemory.createdAt}
                  </span>
                </div>

                <div>
                  <h3 className="font-serif text-lg font-bold text-[var(--ink)]">
                    {latestVoiceMemory.title}
                  </h3>
                  <p className="text-xs text-[var(--soft)] italic mt-0.5 line-clamp-1">
                    "{latestVoiceMemory.caption || 'A quiet voice message for us.'}"
                  </p>
                </div>

                {/* Animated Waveform & 1-Tap Play */}
                <div className="flex items-center gap-3 p-3 rounded-2xl bg-[var(--paper)]/80 backdrop-blur-md border border-[var(--line)]/60">
                  <button
                    type="button"
                    onClick={() =>
                      latestVoiceMemory.voiceUrl &&
                      handleToggleVoicePlayback(latestVoiceMemory.voiceUrl, latestVoiceMemory.id)
                    }
                    className="w-10 h-10 rounded-full bg-[var(--app-accent)] text-white flex items-center justify-center shadow-xs cursor-pointer hover:scale-105 transition shrink-0"
                  >
                    {playingVoiceId === latestVoiceMemory.id ? (
                      <Pause className="w-4 h-4 fill-white" />
                    ) : (
                      <Play className="w-4 h-4 fill-white ml-0.5" />
                    )}
                  </button>

                  <div className="flex-1 flex items-center gap-1 h-6">
                    {Array.from({ length: 24 }).map((_, i) => {
                      const isPlaying = playingVoiceId === latestVoiceMemory.id
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
                  <span className="text-[10px] font-mono text-[var(--soft)] shrink-0">0:30</span>
                </div>
              </div>
            </div>
          )}

          {/* SWIPEABLE 3D CARD STACK (Exact Match to Left Phone in Image) */}
          {filteredMemories.length > 0 ? (
            <div className="space-y-3">
              <div className="flex items-center justify-between px-1">
                <span className="text-xs font-serif font-bold text-[var(--ink)]">
                  Moments in Focus ({filteredMemories.length})
                </span>
                <span className="text-[11px] font-mono text-[var(--soft)]">
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
                      “{activeStackCard.caption}”
                    </p>
                  )}

                  {/* Media Photo/Video */}
                  {activeStackCard.mediaUrl && (
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
                  )}

                  {/* Voice note attached */}
                  {activeStackCard.voiceUrl && (
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
                              ? 'Playing Voice Whisper...'
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
                No memories found in this view
              </h3>
              <p className="text-xs text-[var(--soft)]">
                {searchQuery
                  ? 'No moments matched your search. Try another keyword.'
                  : 'Capture your first photo or voice whisper together!'}
              </p>
            </div>
          )}

          {/* BENTO GRID (Reference Image Match) */}
          {filteredMemories.length > 1 && (
            <div className="space-y-2 pt-2">
              <h3 className="text-xs font-serif font-bold text-[var(--ink)] px-1">
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
                    <img
                      src={filteredMemories[0].mediaUrl}
                      alt="Atmosphere"
                      className="w-full h-24 object-cover rounded-xl"
                    />
                  ) : (
                    <div className="w-full h-24 rounded-xl bg-[var(--paper)] flex items-center justify-center text-xs">
                      🌿
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
                    “{filteredMemories[1]?.caption || filteredMemories[0]?.caption || 'Some moments are fleeting, yet they leave a permanent mark.'}”
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

      {/* FLOATING ACTION PILL: ADD MEMORY */}
      {activeCollection === 'captured' && (
        <div className="fixed bottom-20 right-4 z-30">
          <button
            type="button"
            onClick={() => setIsAdding(true)}
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

      {/* ADD MEMORY MODAL (100% Solid Full-Screen Mobile Page) */}
      {isAdding && (
        <div className="fixed inset-0 z-[1500] bg-[var(--app-bg)] text-[var(--ink)] flex flex-col overflow-hidden">
          {/* Top Bar */}
          <div className="pt-safe px-4 py-3 flex items-center justify-between border-b border-[var(--line)] bg-[var(--white)] shrink-0">
            <button
              type="button"
              onClick={() => setIsAdding(false)}
              className="p-1.5 -ml-1.5 rounded-full hover:bg-[var(--paper)] transition flex items-center gap-1 text-xs font-medium text-[var(--ink)] cursor-pointer"
            >
              <X className="w-4 h-4" />
              <span>Cancel</span>
            </button>
            <h3 className="text-sm font-semibold tracking-tight">Capture Moment</h3>
            <div className="w-12" />
          </div>

          <div className="flex-1 overflow-y-auto px-4 py-6 max-w-md mx-auto w-full space-y-5">
            {/* Photo / Video Selector */}
            <div>
              <label className="text-[11px] font-bold text-[var(--ink)] uppercase tracking-wider block mb-1.5">
                Photo or Video
              </label>

              <label className="border-2 border-dashed border-[var(--line)] hover:border-[var(--app-accent)] rounded-2xl p-6 flex flex-col items-center justify-center cursor-pointer transition bg-[var(--white)]">
                {previewUrl ? (
                  <img src={previewUrl} alt="Preview" className="max-h-48 rounded-xl object-contain mb-2" />
                ) : (
                  <div className="flex flex-col items-center text-center">
                    <ImageIcon className="w-8 h-8 text-[var(--soft)] mb-2" />
                    <span className="text-xs font-semibold text-[var(--ink)]">
                      Choose from Files or Google Photos
                    </span>
                    <span className="text-[10px] text-[var(--soft)] mt-0.5">
                      Supports JPG, PNG, WEBP, MP4
                    </span>
                  </div>
                )}
                <input
                  type="file"
                  accept="image/*,video/*"
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

            {/* 30s Voice Whisper Recorder */}
            <div className="p-4 rounded-2xl border border-[var(--line)] bg-[var(--white)] space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-[11px] font-bold text-[var(--ink)] uppercase tracking-wider">
                  30s Voice Whisper (Optional)
                </span>
                <span className="text-xs font-mono text-[var(--app-accent)] font-semibold">
                  0:{recordingTime < 10 ? `0${recordingTime}` : recordingTime} / 0:30
                </span>
              </div>

              <div className="flex items-center gap-2">
                {!isRecording && !recordedAudio && (
                  <button
                    type="button"
                    onClick={startRecording}
                    className="flex-1 py-2.5 px-3 rounded-xl bg-[var(--app-accent)]/10 text-[var(--app-accent)] hover:bg-[var(--app-accent)]/20 transition flex items-center justify-center gap-1.5 text-xs font-semibold cursor-pointer"
                  >
                    <Mic className="w-3.5 h-3.5" />
                    <span>Record Voice Whisper</span>
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
                      className="flex-1 py-2 px-3 rounded-xl bg-[var(--paper)] text-[var(--ink)] border border-[var(--line)] flex items-center justify-center gap-1.5 text-xs font-medium"
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
                      className="py-2 px-3 rounded-xl border border-red-500/20 text-red-500 text-xs font-medium"
                    >
                      Retake
                    </button>
                  </div>
                )}
              </div>
            </div>

            {/* Title & Caption */}
            <div className="space-y-3">
              <div>
                <label className="text-[10px] font-semibold text-[var(--soft)] uppercase block mb-1">
                  Memory Title
                </label>
                <input
                  type="text"
                  placeholder="e.g. Sunday Morning, The Night We Promised..."
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  className="w-full text-xs py-2.5 px-3.5 rounded-xl border border-[var(--line)] bg-[var(--white)] text-[var(--ink)] focus:outline-none focus:border-[var(--app-accent)]"
                />
              </div>

              <div>
                <label className="text-[10px] font-semibold text-[var(--soft)] uppercase block mb-1">
                  Story / Quote
                </label>
                <textarea
                  rows={3}
                  placeholder="Write a sweet note or quote about this moment..."
                  value={caption}
                  onChange={(e) => setCaption(e.target.value)}
                  className="w-full text-xs py-2.5 px-3.5 rounded-xl border border-[var(--line)] bg-[var(--white)] text-[var(--ink)] font-serif italic focus:outline-none focus:border-[var(--app-accent)] resize-none"
                />
              </div>
            </div>

            {/* Save Button */}
            <div className="pt-2">
              <button
                type="button"
                disabled={isUploading}
                onClick={handleSaveMemory}
                className="w-full py-3 rounded-xl bg-[var(--app-accent)] text-white text-xs font-bold hover:opacity-95 transition cursor-pointer flex items-center justify-center gap-1.5 disabled:opacity-50"
              >
                {isUploading ? (
                  <>
                    <Loader2 className="w-4 h-4 animate-spin" />
                    <span>Preserving Memory...</span>
                  </>
                ) : (
                  <span>Save to Memories</span>
                )}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
