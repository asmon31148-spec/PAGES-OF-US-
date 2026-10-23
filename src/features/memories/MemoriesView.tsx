import React, { useState, useEffect, useCallback } from 'react'
import { useAuth } from '@/core/auth'
import { useTheme } from '@/core/theme'
import { useToast } from '@/core/toast'
import { uploadMediaFile, getSupabaseClient, getAuthorAttribution, formatAuthor, generateEntityId, formatLocalDate } from '@/core/storage'
import { realtimeBridge } from '@/core/realtime'
import { dispatchPartnerInteraction } from '@/core/ai'
import { useAudioRecorder } from '@/core/audio'
import confetti from 'canvas-confetti'
import { Plus, X, Mic, Square, Play, Pause, Loader2, Image as ImageIcon, Trash2, Maximize2, Download, ChevronLeft, ChevronRight, Heart } from 'lucide-react'

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
}


export const MemoriesView: React.FC = () => {
  const { user, space, partner } = useAuth()
  const { theme, isDark, toggleDarkLight } = useTheme()
  const { showToast } = useToast()

  const [memories, setMemories] = useState<MemoryItem[]>([])
  const [flippedCards, setFlippedCards] = useState<Record<string, boolean>>({})
  const [showTimeline, setShowTimeline] = useState(false)

  // Lightbox & Heart Reaction State
  const [activeLightboxIndex, setActiveLightboxIndex] = useState<number | null>(null)
  const [heartAnimations, setHeartAnimations] = useState<Record<string, boolean>>({})
  const lastTapRef = React.useRef<Record<string, number>>({})

  // Voice memo playback
  const [playingVoiceId, setPlayingVoiceId] = useState<string | null>(null)
  const [voiceAudio, setVoiceAudio] = useState<HTMLAudioElement | null>(null)

  // Add memory modal state
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
    startRecording,
    stopRecording,
    clearRecording,
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
            title: row.title,
            caption: row.caption || '',
            mediaUrl: row.media_url,
            voiceUrl: row.thumbnail_url?.includes('voice') ? row.thumbnail_url : undefined,
            rawDate: row.created_at,
            createdAt: formatLocalDate(row.created_at, {
              day: 'numeric',
              month: 'short'
            }).toUpperCase(),
            addedBy: isMine ? 'You' : authorName,
            isMine,
            rotation: row.rotation || (idx % 2 === 0 ? '-1deg' : '1deg')
          }
        })
        setMemories(mapped)
      } else {
        setMemories([])
      }
    } catch (err) {
      console.warn('Error fetching memories:', err)
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

    // Realtime WebSocket bridge listener for instant partner sync
    const unsubBridge = realtimeBridge.subscribe((event) => {
      if (event.type === 'MEMORY_ADDED') {
        fetchMemories()
      }
    })

    return () => {
      supabase.removeChannel(channel)
      unsubBridge()
    }
  }, [spaceId, fetchMemories])

  const handleToggleFlip = (id: string) => {
    setFlippedCards((prev) => ({
      ...prev,
      [id]: !prev[id]
    }))
  }

  const handlePlayVoice = (voiceUrl?: string, id?: string) => {
    if (!voiceUrl) {
      showToast('No voice memo recorded for this moment.')
      return
    }

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
    setPlayingVoiceId(id || null)

    audio.play().catch(() => {
      showToast('Unable to play audio memo.')
      setPlayingVoiceId(null)
    })

    audio.onended = () => {
      setPlayingVoiceId(null)
    }
  }

  const handleDeleteMemory = async (id: string) => {
    if (!window.confirm('Delete this moment from your shared vault?')) return

    setMemories((prev) => prev.filter((m) => m.id !== id))
    showToast('Moment deleted from vault.')

    try {
      const supabase = getSupabaseClient()
      const { error } = await supabase.from('memories').delete().eq('id', id)
      if (error) {
        console.warn('Error deleting memory from Supabase:', error.message)
      }
    } catch (err) {
      console.warn('Error deleting memory from Supabase:', err)
    }
  }

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) {
      setSelectedFile(file)
      const objectUrl = URL.createObjectURL(file)
      setPreviewUrl(objectUrl)
    }
  }

  const handleSaveMemory = async () => {
    if (!title.trim() || !user) {
      showToast('Please give your memory a title.')
      return
    }

    setIsUploading(true)
    try {
      let finalMediaUrl = ''
      let finalVoiceUrl: string | undefined = undefined

      if (selectedFile) {
        const uploadRes = await uploadMediaFile(selectedFile, spaceId)
        finalMediaUrl = uploadRes.url
      }

      if (recordedAudio) {
        const uploaded = await uploadVoiceMemo(spaceId)
        if (uploaded) finalVoiceUrl = uploaded
      }

      const supabase = getSupabaseClient()
      const newMemId = generateEntityId('memory')
      const authorEncoded = formatAuthor(user)
      const nowIso = new Date().toISOString()
      const chosenRotation = Math.random() > 0.5 ? '1deg' : '-1deg'

      const newRow = {
        id: newMemId,
        space_id: spaceId,
        title: title.trim(),
        caption: caption.trim(),
        media_url: finalMediaUrl || '',
        thumbnail_url: finalVoiceUrl || '',
        author: authorEncoded,
        rotation: chosenRotation,
        created_at: nowIso
      }

      const { error } = await supabase.from('memories').insert(newRow)
      if (error) {
        console.error('Supabase memory insert error:', error)
        throw new Error(error.message || 'Failed to save moment to database')
      }

      // Optimistically add to UI state
      const optimisticMem: MemoryItem = {
        id: newMemId,
        title: title.trim(),
        caption: caption.trim(),
        mediaUrl: finalMediaUrl || '',
        voiceUrl: finalVoiceUrl || undefined,
        createdAt: formatLocalDate(nowIso, { day: 'numeric', month: 'short' }).toUpperCase(),
        addedBy: 'You',
        isMine: true,
        rotation: chosenRotation
      }
      setMemories((prev) => [optimisticMem, ...prev.filter((m) => m.id !== newMemId)])

      // Broadcast event and dispatch contextual partner notification
      realtimeBridge.broadcast({
        type: 'MEMORY_ADDED',
        senderId: user.id,
        senderNickname: user.nickname,
        timestamp: Date.now(),
        data: { memoryId: newMemId, title: title.trim() }
      }).catch(() => {})

      dispatchPartnerInteraction(user, space, 'MEMORY_CREATED', {
        noteTitle: title.trim()
      }).catch(() => {})

      showToast('New moment saved to your shared vault.')
      setIsAdding(false)
      setSelectedFile(null)
      setPreviewUrl(null)
      setTitle('')
      setCaption('')
      clearRecording()
    } catch (err: any) {
      console.error('Failed to save memory:', err)
      showToast(err.message || 'Error saving moment. Please try again.')
    } finally {
      setIsUploading(false)
    }
  }

  // Lightbox & Double-tap Heart Handlers
  const handlePrevPhoto = (e: React.MouseEvent) => {
    e.stopPropagation()
    if (activeLightboxIndex !== null && activeLightboxIndex > 0) {
      setActiveLightboxIndex(activeLightboxIndex - 1)
    }
  }

  const handleNextPhoto = (e: React.MouseEvent) => {
    e.stopPropagation()
    if (activeLightboxIndex !== null && activeLightboxIndex < memories.length - 1) {
      setActiveLightboxIndex(activeLightboxIndex + 1)
    }
  }

  const handlePhotoClick = (m: MemoryItem, idx: number, e: React.MouseEvent) => {
    e.stopPropagation()
    const now = Date.now()
    const last = lastTapRef.current[m.id] || 0
    if (now - last < 320) {
      // Double tap!
      setHeartAnimations((prev) => ({ ...prev, [m.id]: true }))
      try {
        if (navigator.vibrate) navigator.vibrate(28)
      } catch {}
      confetti({
        particleCount: 22,
        spread: 50,
        origin: { y: 0.6 }
      })
      showToast(`Loved "${m.title}" ❦`)
      setTimeout(() => {
        setHeartAnimations((prev) => ({ ...prev, [m.id]: false }))
      }, 1000)
      lastTapRef.current[m.id] = 0
    } else {
      lastTapRef.current[m.id] = now
      handleToggleFlip(m.id)
    }
  }

  // Dynamic Year Grouping for Memories Timeline View
  const groupedMemories = React.useMemo(() => {
    const groups: Record<number, MemoryItem[]> = {}
    memories.forEach((item) => {
      let year = new Date().getFullYear()
      if (item.rawDate) {
        const parsed = new Date(item.rawDate).getFullYear()
        if (!isNaN(parsed) && parsed > 1900) {
          year = parsed
        }
      }
      if (!groups[year]) groups[year] = []
      groups[year].push(item)
    })
    return Object.entries(groups)
      .map(([y, list]) => ({ year: Number(y), items: list }))
      .sort((a, b) => b.year - a.year)
  }, [memories])

  return (
    <div className="page active" id="memories">
      {/* 1. TOPBAR */}
      <header className="topbar">
        <div className="wordmark">Pages of Us</div>
        <div className="flex items-center gap-2">
          <button
            type="button"
            className="music-pill flex items-center justify-center w-8 h-8 !p-0"
            onClick={toggleDarkLight}
            title={isDark ? 'Switch to Light Sanctuary (☀️)' : 'Switch to Dark Sanctuary (🌙)'}
          >
            {isDark ? '☀️' : '🌙'}
          </button>
          <button
            type="button"
            className="privacy-chip"
            onClick={() =>
              showToast(
                partner
                  ? `Only you and ${partner.nickname} can see this gallery.`
                  : 'Your private memory gallery. Only you and your connected partner can see this.'
              )
            }
          >
            ♙ &nbsp; Only us
          </button>
        </div>
      </header>

      {/* 2. TITLE */}
      <h2 className="screen-title">Memory vault</h2>
      <p className="screen-subtitle">Little pieces of a life you made together.</p>

      {/* 3. CONTROLS */}
      <div className="memory-controls">
        <button
          type="button"
          className="privacy-chip"
          onClick={() => showToast('Your memories stay private to the two of you.')}
        >
          Private by default
        </button>
        <button
          type="button"
          className="view-toggle"
          onClick={() => setShowTimeline(!showTimeline)}
        >
          {showTimeline ? 'VIEW GRID  →' : 'VIEW TIMELINE  →'}
        </button>
      </div>

      {/* 4. TIMELINE OR POLAROIDS */}
      {showTimeline ? (
        <div className="space-y-6">
          {groupedMemories.map(({ year, items }) => (
            <div key={year} className="timeline-panel">
              <div className="timeline-year">{year} · THE DAYS YOU KEPT</div>
              {items.map((m) => (
                <div key={m.id} className="timeline-item">
                  <span className="timeline-date">{m.createdAt}</span>
                  <div className="timeline-card flex items-center justify-between">
                    <div>
                      <b>{m.title}</b>
                      <span>{m.caption || `${m.addedBy} · saved together`}</span>
                    </div>
                    <button
                      type="button"
                      onClick={(e) => {
                        e.stopPropagation()
                        handleDeleteMemory(m.id)
                      }}
                      className="text-[#888a82] hover:text-red-600 p-1 cursor-pointer transition ml-2"
                      title="Delete moment"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          ))}
        </div>
      ) : memories.length === 0 ? (
        <div className="p-8 text-center border border-dashed border-[var(--line)] rounded-2xl bg-[var(--white)] my-6 space-y-3 shadow-xs">
          <div className="w-12 h-12 rounded-full bg-[var(--paper)] text-[var(--app-accent)] flex items-center justify-center mx-auto text-xl">
            📷
          </div>
          <h3 className="font-serif text-sm font-semibold text-[var(--ink)]">No memories saved yet</h3>
          <p className="text-xs text-[var(--soft)] max-w-xs mx-auto leading-relaxed">
            Capture your favorite moments, late-night photos, and voice notes here. Only you and your partner can see them.
          </p>
          <button
            type="button"
            onClick={() => setIsAdding(true)}
            className="py-2 px-4 rounded-xl bg-[var(--app-accent)] text-[var(--app-accent-text)] text-xs font-medium hover:opacity-90 transition shadow-xs cursor-pointer"
          >
            ＋ Add Your First Memory
          </button>
        </div>
      ) : (
        <div className="polaroids">
          {memories.map((m, index) => {
            const isFlipped = Boolean(flippedCards[m.id])
            const sceneClass =
              index % 4 === 1
                ? 'scene-two'
                : index % 4 === 2
                ? 'scene-three'
                : index % 4 === 3
                ? 'scene-four'
                : ''

            return (
              <div
                key={m.id}
                className={`polaroid ${isFlipped ? 'flipped' : ''}`}
                onClick={() => handleToggleFlip(m.id)}
              >
                <div className="polaroid-inner">
                  {/* FRONT */}
                  <div className="paper">
                    {m.mediaUrl ? (
                      <div
                        className="h-[157px] rounded-[2px] overflow-hidden bg-[#242724] relative group cursor-pointer"
                        onClick={(e) => handlePhotoClick(m, index, e)}
                      >
                        <img
                          src={m.mediaUrl}
                          alt={m.title}
                          className="w-full h-full object-cover transition-transform duration-300 group-hover:scale-105"
                          loading="lazy"
                        />
                        {/* Floating Heart Burst overlay */}
                        {heartAnimations[m.id] && (
                          <div className="absolute inset-0 flex items-center justify-center pointer-events-none z-10 animate-in zoom-in-50 duration-200">
                            <Heart className="w-12 h-12 text-rose-500 fill-rose-500 drop-shadow-xl animate-pulse" />
                          </div>
                        )}
                        {/* Fullscreen Expand Icon Button */}
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation()
                            setActiveLightboxIndex(index)
                          }}
                          className="absolute top-2 right-2 w-7 h-7 rounded-full bg-black/55 backdrop-blur-xs text-white flex items-center justify-center opacity-80 hover:opacity-100 hover:scale-110 transition cursor-pointer shadow-md"
                          title="Open fullscreen view"
                        >
                          <Maximize2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    ) : (
                      <div className={`photo-art ${sceneClass}`}></div>
                    )}
                    <div className="paper-title">{m.title}</div>
                    <div className="paper-meta">
                      <span>{m.createdAt}</span>
                      <span>{m.voiceUrl ? '◉ Voice memo' : '✦ Photo'}</span>
                    </div>
                  </div>

                  {/* BACK */}
                  <div className="paper-back">
                    <span className="overline">A little more</span>
                    <h3>{m.title}</h3>
                    <p>{m.caption || 'A small, unhurried moment kept between the two of you.'}</p>

                    {m.voiceUrl ? (
                      <div
                        className="voice-row cursor-pointer"
                        onClick={(e) => {
                          e.stopPropagation()
                          handlePlayVoice(m.voiceUrl, m.id)
                        }}
                      >
                        {playingVoiceId === m.id
                          ? '⏸ Pause audio'
                          : `▶ Listen to ${m.addedBy} · Voice Note`}
                      </div>
                    ) : (
                      <div className="text-[10px] text-[#8a8b83] italic py-1">
                        Photo moment · No voice memo
                      </div>
                    )}

                    <div className="flex items-center justify-between mt-auto pt-2 border-t border-[#dedbd2]">
                      <button
                        type="button"
                        className="lock-item m-0"
                        onClick={(e) => {
                          e.stopPropagation()
                          showToast('This moment is just for you two.')
                        }}
                      >
                        ⌑ &nbsp; Keep private
                      </button>

                      <button
                        type="button"
                        className="text-[8px] text-[#a96b6b] hover:text-red-600 flex items-center gap-1 cursor-pointer py-1 px-1 rounded transition"
                        onClick={(e) => {
                          e.stopPropagation()
                          handleDeleteMemory(m.id)
                        }}
                        title="Delete this moment"
                      >
                        <Trash2 className="w-2.5 h-2.5" />
                        <span>Delete</span>
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      )}

      {/* 5. ADD A MOMENT BUTTON */}
      <button
        type="button"
        className="add-moment"
        onClick={() => setIsAdding(true)}
      >
        ＋ Add a moment
      </button>

      {/* 6. ADD MEMORY MODAL */}
      {isAdding && (
        <div
          className="modal-backdrop"
          onClick={(e) => {
            if (e.target === e.currentTarget) setIsAdding(false)
          }}
        >
          <div className="modal">
            <div className="modal-handle"></div>
            <button
              type="button"
              className="close"
              onClick={() => setIsAdding(false)}
            >
              ×
            </button>
            <div className="modal-date">NEW POLAROID MOMENT</div>
            <h3>Add a moment</h3>

            {/* Photo Picker */}
            <div className="mb-3">
              {previewUrl ? (
                <div className="relative h-36 rounded-xl overflow-hidden border border-[var(--line)] mb-2">
                  <img
                    src={previewUrl}
                    alt="Preview"
                    className="w-full h-full object-cover"
                  />
                  <button
                    type="button"
                    onClick={() => {
                      setSelectedFile(null)
                      setPreviewUrl(null)
                    }}
                    className="absolute top-2 right-2 p-1 rounded-full bg-black/60 text-white"
                  >
                    <X className="w-4 h-4" />
                  </button>
                </div>
              ) : (
                <label className="flex items-center justify-center gap-2 p-4 border border-dashed border-[var(--line)] rounded-xl cursor-pointer bg-[var(--paper)] text-xs text-[var(--soft)] hover:opacity-85">
                  <ImageIcon className="w-4 h-4" />
                  <span>Choose a photo for your Polaroid</span>
                  <input
                    type="file"
                    accept="image/*"
                    onChange={handleFileSelect}
                    className="hidden"
                  />
                </label>
              )}
            </div>

            {/* Title & Caption */}
            <div className="space-y-2">
              <input
                type="text"
                placeholder="Title (e.g. Sunday, slowly)"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                className="w-full p-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] text-xs font-serif outline-none"
              />
              <textarea
                rows={2}
                placeholder="The story behind this photo (handwritten on the back)..."
                value={caption}
                onChange={(e) => setCaption(e.target.value)}
                className="w-full p-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] text-xs font-serif italic outline-none resize-none leading-relaxed"
              />
            </div>

            {/* Voice Whisper Recorder */}
            <div className="mt-3 p-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] flex items-center justify-between">
              <div className="flex items-center gap-2 text-xs text-[var(--ink)]">
                <Mic className="w-3.5 h-3.5 text-[var(--app-accent)]" />
                <span>
                  {isRecording
                    ? `Recording whisper... ${recordingTime}s`
                    : recordedAudio
                    ? 'Whisper voice note attached'
                    : 'Add a 30s voice whisper'}
                </span>
              </div>

              {isRecording ? (
                <button
                  type="button"
                  onClick={stopRecording}
                  className="px-2.5 py-1 rounded-lg bg-red-600 text-white text-[10px] font-bold"
                >
                  Stop
                </button>
              ) : recordedAudio ? (
                <button
                  type="button"
                  onClick={clearRecording}
                  className="text-[10px] text-red-500 underline"
                >
                  Remove
                </button>
              ) : (
                <button
                  type="button"
                  onClick={startRecording}
                  className="px-2.5 py-1 rounded-lg bg-[var(--app-accent)] text-white text-[10px] font-medium cursor-pointer hover:opacity-90"
                >
                  Record
                </button>
              )}
            </div>

            {/* Save Button */}
            <button
              type="button"
              onClick={handleSaveMemory}
              disabled={isUploading || !title.trim()}
              className="mt-4 w-full py-2.5 rounded-xl bg-[var(--app-accent)] text-white text-xs font-medium cursor-pointer disabled:opacity-50 hover:opacity-90 flex items-center justify-center gap-2"
            >
              {isUploading ? (
                <>
                  <Loader2 className="w-3.5 h-3.5 animate-spin" />
                  <span>Uploading to shared vault...</span>
                </>
              ) : (
                <span>Save to Memory Vault</span>
              )}
            </button>
          </div>
        </div>
      )}

      {/* 6. FULLSCREEN PHOTO LIGHTBOX MODAL */}
      {activeLightboxIndex !== null && memories[activeLightboxIndex] && (
        <div
          className="fixed inset-0 z-50 bg-black/92 backdrop-blur-md flex flex-col justify-between p-4 sm:p-6 animate-in fade-in duration-200"
          onClick={() => setActiveLightboxIndex(null)}
        >
          {/* Top Bar */}
          <div
            className="flex items-center justify-between text-white/80 py-2 border-b border-white/10"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="min-w-0 pr-4">
              <span className="text-[10px] tracking-widest font-mono text-white/50 uppercase">
                {memories[activeLightboxIndex].createdAt} · {memories[activeLightboxIndex].addedBy}
              </span>
              <h3 className="font-serif text-base sm:text-lg text-white font-medium truncate">
                {memories[activeLightboxIndex].title}
              </h3>
            </div>
            <div className="flex items-center gap-3 shrink-0">
              {memories[activeLightboxIndex].mediaUrl && (
                <a
                  href={memories[activeLightboxIndex].mediaUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  download={`memory-${memories[activeLightboxIndex].id}.jpg`}
                  className="p-2 rounded-full bg-white/10 hover:bg-white/20 text-white transition cursor-pointer"
                  title="Download / View Original Photo"
                  onClick={(e) => e.stopPropagation()}
                >
                  <Download className="w-4 h-4" />
                </a>
              )}
              <button
                type="button"
                onClick={() => setActiveLightboxIndex(null)}
                className="p-2 rounded-full bg-white/10 hover:bg-white/20 text-white transition cursor-pointer"
                title="Close"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
          </div>

          {/* Main Media Showcase */}
          <div
            className="flex-1 flex items-center justify-center relative my-4 overflow-hidden"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Left Chevron */}
            {activeLightboxIndex > 0 && (
              <button
                type="button"
                onClick={handlePrevPhoto}
                className="absolute left-2 sm:left-4 z-10 w-10 h-10 rounded-full bg-black/60 text-white flex items-center justify-center hover:bg-black/80 transition cursor-pointer shadow-lg"
                title="Previous photo"
              >
                <ChevronLeft className="w-6 h-6" />
              </button>
            )}

            {/* Photo / Artwork */}
            {memories[activeLightboxIndex].mediaUrl ? (
              <img
                src={memories[activeLightboxIndex].mediaUrl}
                alt={memories[activeLightboxIndex].title}
                className="max-h-[68vh] max-w-full object-contain rounded-xl shadow-2xl border border-white/10"
              />
            ) : (
              <div className="w-72 h-80 rounded-2xl bg-[#242724] border border-white/20 flex flex-col items-center justify-center text-center p-6 text-white/70">
                <span className="text-4xl mb-3">❦</span>
                <span className="font-serif text-sm">Quiet Moment</span>
              </div>
            )}

            {/* Right Chevron */}
            {activeLightboxIndex < memories.length - 1 && (
              <button
                type="button"
                onClick={handleNextPhoto}
                className="absolute right-2 sm:right-4 z-10 w-10 h-10 rounded-full bg-black/60 text-white flex items-center justify-center hover:bg-black/80 transition cursor-pointer shadow-lg"
                title="Next photo"
              >
                <ChevronRight className="w-6 h-6" />
              </button>
            )}
          </div>

          {/* Bottom Caption & Audio */}
          <div
            className="w-full max-w-xl mx-auto bg-white/10 backdrop-blur-md rounded-2xl p-4 border border-white/15 text-white/90"
            onClick={(e) => e.stopPropagation()}
          >
            {memories[activeLightboxIndex].caption && (
              <p className="text-xs sm:text-sm font-serif italic text-white/90 leading-relaxed mb-2">
                "{memories[activeLightboxIndex].caption}"
              </p>
            )}

            {memories[activeLightboxIndex].voiceUrl && (
              <div
                className="flex items-center gap-2 py-1.5 px-3 rounded-xl bg-white/10 hover:bg-white/15 text-amber-300 text-xs cursor-pointer transition w-fit"
                onClick={() => handlePlayVoice(memories[activeLightboxIndex].voiceUrl!, memories[activeLightboxIndex].id)}
              >
                {playingVoiceId === memories[activeLightboxIndex].id ? (
                  <>
                    <Pause className="w-3.5 h-3.5" />
                    <span>Pause voice note</span>
                  </>
                ) : (
                  <>
                    <Play className="w-3.5 h-3.5" />
                    <span>Play voice note</span>
                  </>
                )}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
