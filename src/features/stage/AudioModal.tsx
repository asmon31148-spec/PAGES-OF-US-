import React, { useState, useEffect, useRef } from 'react'
import { useAudio, Track } from '@/core/audio'
import { useAuth } from '@/core/auth'
import { useTheme } from '@/core/theme'
import { useToast } from '@/core/toast'
import { getSupabaseClient, uploadMediaFile, generateEntityId } from '@/core/storage'
import { realtimeBridge } from '@/core/realtime'
import confetti from 'canvas-confetti'
import {
  Play,
  Pause,
  SkipForward,
  SkipBack,
  Volume2,
  VolumeX,
  X,
  Plus,
  CloudRain,
  Flame,
  Moon,
  Music2,
  Radio,
  Trash2,
  Upload,
  Loader2,
  Check,
  Headphones
} from 'lucide-react'

interface AudioModalProps {
  isOpen: boolean
  onClose: () => void
}

interface PartnerListeningState {
  track: Track
  partnerName: string
  timestamp: number
  isPlaying: boolean
}

export const AudioModal: React.FC<AudioModalProps> = ({ isOpen, onClose }) => {
  const {
    currentTrack,
    isPlaying,
    volume,
    progress,
    duration,
    isMuted,
    playlist,
    ambientSounds,
    togglePlay,
    nextTrack,
    prevTrack,
    seek,
    setVolume,
    toggleMute,
    toggleAmbient,
    setAmbientVolume,
    playTrack,
    setPlaylist
  } = useAudio()

  const { user, space, partner } = useAuth()
  const { theme } = useTheme()
  const { showToast } = useToast()

  const spaceId = space?.id || 'default_space'
  const playlistDocId = `playlist_${spaceId}`

  // Track upload state
  const [showAddForm, setShowAddForm] = useState(false)
  const [selectedAudioFile, setSelectedAudioFile] = useState<File | null>(null)
  const [newTitle, setNewTitle] = useState('')
  const [newArtist, setNewArtist] = useState('')
  const [newUrl, setNewUrl] = useState('')
  const [isUploading, setIsUploading] = useState(false)
  const [uploadProgress, setUploadProgress] = useState(0)
  const [showManualUrl, setShowManualUrl] = useState(false)
  const fileInputRef = useRef<HTMLInputElement | null>(null)

  // Partner live sync state
  const [partnerListening, setPartnerListening] = useState<PartnerListeningState | null>(null)
  const [autoSyncEnabled, setAutoSyncEnabled] = useState<boolean>(() => {
    try {
      return localStorage.getItem('pages_of_us_audio_autosync') === 'true'
    } catch {
      return false
    }
  })

  // 1. Fetch real shared playlist from Supabase on mount & listen to changes
  useEffect(() => {
    const supabase = getSupabaseClient()

    const fetchCloudPlaylist = async () => {
      try {
        const { data } = await supabase
          .from('app_content')
          .select('content')
          .eq('id', playlistDocId)
          .maybeSingle()

        if (data?.content?.tracks && Array.isArray(data.content.tracks)) {
          setPlaylist(data.content.tracks)
        }
      } catch (err) {
        console.warn('Error loading shared playlist from cloud:', err)
      }
    }

    fetchCloudPlaylist()

    // Realtime Postgres sync for playlist
    const channel = supabase
      .channel(`playlist_chan_${spaceId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'app_content',
          filter: `id=eq.${playlistDocId}`
        },
        (payload: any) => {
          if (payload.new?.content?.tracks) {
            setPlaylist(payload.new.content.tracks)
          }
        }
      )
      .subscribe()

    // Realtime WebSocket bridge listener for Listen Together & Audio Sync
    const unsubBridge = realtimeBridge.subscribe((event) => {
      if (event.type === 'AUDIO_SYNC' && event.data) {
        // Ignore self-broadcasts
        if (user?.id && event.senderId === user.id) return

        const { action, track, tracks } = event.data

        if (action === 'PLAYLIST_UPDATE' && Array.isArray(tracks)) {
          setPlaylist(tracks)
        } else if (action === 'PLAY' && track) {
          setPartnerListening({
            track,
            partnerName: event.senderNickname || partner?.nickname || 'Your partner',
            timestamp: event.timestamp || Date.now(),
            isPlaying: true
          })

          // If auto-sync is enabled, automatically tune in
          if (autoSyncEnabled) {
            playTrack(track)
          }
        } else if (action === 'PAUSE') {
          setPartnerListening((prev) => (prev ? { ...prev, isPlaying: false } : null))
          if (autoSyncEnabled && isPlaying) {
            togglePlay()
          }
        }
      }
    })

    return () => {
      supabase.removeChannel(channel)
      unsubBridge()
    }
  }, [spaceId, playlistDocId, autoSyncEnabled, isPlaying, user?.id, partner?.nickname, playTrack, setPlaylist, togglePlay])

  if (!isOpen) return null

  const formatTime = (secs: number) => {
    const mins = Math.floor(secs / 60)
    const remaining = Math.floor(secs % 60)
    return `${mins}:${remaining < 10 ? '0' : ''}${remaining}`
  }

  // Handle Play with partner broadcast
  const handlePlayTrack = (track: Track) => {
    playTrack(track)
    realtimeBridge.broadcast({
      type: 'AUDIO_SYNC',
      senderId: user?.id || '',
      senderNickname: user?.nickname || 'Partner',
      timestamp: Date.now(),
      data: { action: 'PLAY', track, progress }
    }).catch(() => {})
  }

  // Handle Play/Pause toggle with broadcast
  const handleTogglePlay = () => {
    togglePlay()
    if (currentTrack) {
      realtimeBridge.broadcast({
        type: 'AUDIO_SYNC',
        senderId: user?.id || '',
        senderNickname: user?.nickname || 'Partner',
        timestamp: Date.now(),
        data: { action: isPlaying ? 'PAUSE' : 'PLAY', track: currentTrack, progress }
      }).catch(() => {})
    }
  }

  // Tune into Partner's live song
  const handleTuneInTogether = () => {
    if (!partnerListening?.track) return
    playTrack(partnerListening.track)
    confetti({
      particleCount: 30,
      spread: 60,
      origin: { y: 0.6 }
    })
    showToast(`Listening together with ${partnerListening.partnerName} 💕`)
  }

  // Toggle Live Auto-Sync
  const handleToggleAutoSync = () => {
    const next = !autoSyncEnabled
    setAutoSyncEnabled(next)
    try {
      localStorage.setItem('pages_of_us_audio_autosync', next.toString())
    } catch {}
    if (next) {
      showToast('Live Sync enabled: You will automatically sync music when your partner plays.')
      if (partnerListening?.track) {
        playTrack(partnerListening.track)
      }
    } else {
      showToast('Independent playback mode enabled.')
    }
  }

  // Handle file picker selection
  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    setSelectedAudioFile(file)

    // Clean file name to suggest title and artist
    const nameWithoutExt = file.name.replace(/\.[^/.]+$/, '')
    if (nameWithoutExt.includes(' - ')) {
      const parts = nameWithoutExt.split(' - ')
      setNewArtist(parts[0].trim())
      setNewTitle(parts.slice(1).join(' - ').trim())
    } else {
      setNewTitle(nameWithoutExt.trim())
      setNewArtist(user?.nickname || 'Shared Song')
    }
  }

  // Save new track (file upload or manual URL)
  const handleAddTrack = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!newTitle.trim()) {
      showToast('Please provide a song title.')
      return
    }

    if (!selectedAudioFile && !newUrl.trim()) {
      showToast('Please choose an audio file from your device or enter a link.')
      return
    }

    setIsUploading(true)
    setUploadProgress(10)

    try {
      let finalAudioUrl = newUrl.trim()

      if (selectedAudioFile) {
        const uploadRes = await uploadMediaFile(selectedAudioFile, 'audio', (pct) => {
          setUploadProgress(pct)
        })
        finalAudioUrl = uploadRes.url
      }

      if (!finalAudioUrl) {
        throw new Error('Audio upload failed. Please try again.')
      }

      const newTrack: Track = {
        id: generateEntityId('track'),
        title: newTitle.trim(),
        artist: newArtist.trim() || user?.nickname || 'Unknown Artist',
        audioUrl: finalAudioUrl,
        addedBy: user?.nickname || 'Partner'
      }

      const updated = [...playlist, newTrack]
      setPlaylist(updated)

      // Save permanently to Supabase cloud
      const supabase = getSupabaseClient()
      const { error } = await supabase.from('app_content').upsert({
        id: playlistDocId,
        content: { tracks: updated },
        updated_at: new Date().toISOString()
      })

      if (error) {
        console.warn('Playlist save error:', error.message)
      }

      // Broadcast playlist update to partner
      realtimeBridge.broadcast({
        type: 'AUDIO_SYNC',
        senderId: user?.id || '',
        senderNickname: user?.nickname || 'Partner',
        timestamp: Date.now(),
        data: { action: 'PLAYLIST_UPDATE', tracks: updated }
      }).catch(() => {})

      showToast(`"${newTrack.title}" added to your shared mixtape!`)
      setSelectedAudioFile(null)
      setNewTitle('')
      setNewArtist('')
      setNewUrl('')
      setShowAddForm(false)
    } catch (err: any) {
      console.error('Audio upload error:', err)
      showToast(err.message || 'Error saving track. Please try again.')
    } finally {
      setIsUploading(false)
      setUploadProgress(0)
    }
  }

  const handleDeleteTrack = async (trackId: string, e: React.MouseEvent) => {
    e.stopPropagation()
    if (!window.confirm('Remove this track from your shared mixtape?')) return

    const updated = playlist.filter((t) => t.id !== trackId)
    setPlaylist(updated)
    showToast('Track removed.')

    try {
      const supabase = getSupabaseClient()
      await supabase.from('app_content').upsert({
        id: playlistDocId,
        content: { tracks: updated },
        updated_at: new Date().toISOString()
      })

      realtimeBridge.broadcast({
        type: 'AUDIO_SYNC',
        senderId: user?.id || '',
        senderNickname: user?.nickname || 'Partner',
        timestamp: Date.now(),
        data: { action: 'PLAYLIST_UPDATE', tracks: updated }
      }).catch(() => {})
    } catch (err) {
      console.warn('Error deleting track from Supabase:', err)
    }
  }

  const getAmbientIcon = (iconName: string) => {
    switch (iconName) {
      case 'CloudRain':
        return <CloudRain className="w-4 h-4" />
      case 'Flame':
        return <Flame className="w-4 h-4" />
      case 'Moon':
        return <Moon className="w-4 h-4" />
      default:
        return <Music2 className="w-4 h-4" />
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex flex-col justify-start overflow-y-auto px-4 py-5 sm:p-8 transition-colors duration-200 animate-in fade-in"
      style={{
        backgroundColor: theme.bg,
        color: theme.textPrimary
      }}
    >
      <div className="w-full max-w-md mx-auto flex-1 flex flex-col my-auto space-y-4">
        {/* Top Header Bar */}
        <div className="flex items-center justify-between pb-3 border-b border-[var(--line)]">
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 rounded-full cursor-pointer hover:bg-[var(--paper)] transition flex items-center gap-1.5 text-xs font-medium"
            style={{ color: theme.textPrimary }}
          >
            <X className="w-4 h-4" />
            <span>Close</span>
          </button>
          <div className="text-center">
            <h3 className="text-sm font-semibold tracking-tight">Atmosphere & Music</h3>
          </div>
          <div className="w-12" />
        </div>

        <div className="space-y-5 flex-1">
          {/* Subtitle */}
          <div className="text-center space-y-0.5">
            <p className="text-xs" style={{ color: theme.textMuted }}>
              Shared music & soothing nature soundscapes for two.
            </p>
          </div>

          {/* PARTNER "LISTEN TOGETHER" BANNER */}
          {partnerListening && partnerListening.track && (
            <div className="p-3 rounded-2xl bg-gradient-to-r from-emerald-500/10 via-teal-500/10 to-emerald-500/10 border border-emerald-500/30 flex items-center justify-between gap-3 shadow-xs animate-in fade-in">
              <div className="flex items-center gap-2.5 min-w-0">
                <Radio className="w-4 h-4 text-emerald-500 animate-pulse shrink-0" />
                <div className="min-w-0">
                  <div className="text-[10px] text-emerald-600 dark:text-emerald-400 font-bold uppercase tracking-wider">
                    {partnerListening.partnerName} is listening now
                  </div>
                  <div className="text-xs font-serif font-medium truncate text-[var(--ink)]">
                    {partnerListening.track.title} · {partnerListening.track.artist}
                  </div>
                </div>
              </div>
              <button
                type="button"
                onClick={handleTuneInTogether}
                className="py-1.5 px-3 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-[11px] font-semibold shrink-0 cursor-pointer shadow-xs transition flex items-center gap-1 active:scale-95"
              >
                <Headphones className="w-3.5 h-3.5" />
                <span>Listen Together</span>
              </button>
            </div>
          )}

          {/* Current Playing Track Box */}
          <div
            className="p-4 rounded-2xl border space-y-3 shadow-xs"
            style={{
              backgroundColor: theme.surface,
              borderColor: theme.surfaceBorder
            }}
          >
            <div className="flex items-center gap-3">
              <div
                className="w-12 h-12 rounded-xl flex items-center justify-center shrink-0 shadow-xs"
                style={{
                  backgroundColor: theme.badgeBg,
                  color: theme.accent
                }}
              >
                <Music2 className="w-6 h-6" />
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-xs font-bold truncate">
                  {currentTrack?.title || 'No track selected'}
                </p>
                <p className="text-[11px] truncate" style={{ color: theme.textMuted }}>
                  {currentTrack?.artist || 'Pick a song from your mixtape'}
                </p>
              </div>
            </div>

            {/* Scrubber Progress Bar */}
            <div className="space-y-1">
              <input
                type="range"
                min="0"
                max={duration || 100}
                value={progress}
                onChange={(e) => seek(parseFloat(e.target.value))}
                className="w-full h-1.5 rounded-lg cursor-pointer"
                style={{ accentColor: theme.accent }}
              />
              <div
                className="flex justify-between text-[10px] font-mono"
                style={{ color: theme.textMuted }}
              >
                <span>{formatTime(progress)}</span>
                <span>{formatTime(duration)}</span>
              </div>
            </div>

            {/* Playback Controls */}
            <div className="flex items-center justify-center gap-4 pt-1">
              <button
                type="button"
                onClick={prevTrack}
                className="p-2 rounded-full transition active:scale-90 opacity-70 hover:opacity-100 cursor-pointer"
                style={{ color: theme.textSecondary }}
                title="Previous track"
              >
                <SkipBack className="w-5 h-5" />
              </button>

              <button
                type="button"
                onClick={handleTogglePlay}
                className="w-12 h-12 rounded-full flex items-center justify-center shadow-lg transition active:scale-95 cursor-pointer"
                style={{
                  background: theme.accentGradient || theme.accent,
                  color: theme.accentText
                }}
                title={isPlaying ? 'Pause' : 'Play'}
              >
                {isPlaying ? (
                  <Pause className="w-5 h-5 fill-current" />
                ) : (
                  <Play className="w-5 h-5 fill-current ml-0.5" />
                )}
              </button>

              <button
                type="button"
                onClick={nextTrack}
                className="p-2 rounded-full transition active:scale-90 opacity-70 hover:opacity-100 cursor-pointer"
                style={{ color: theme.textSecondary }}
                title="Next track"
              >
                <SkipForward className="w-5 h-5" />
              </button>
            </div>

            {/* Master Volume Slider */}
            <div className="flex items-center gap-2 px-2 pt-2 border-t border-[var(--line)]/50">
              <button type="button" onClick={toggleMute} className="cursor-pointer" style={{ color: theme.textMuted }}>
                {isMuted || volume === 0 ? <VolumeX className="w-4 h-4" /> : <Volume2 className="w-4 h-4" />}
              </button>
              <input
                type="range"
                min="0"
                max="100"
                value={isMuted ? 0 : volume}
                onChange={(e) => setVolume(parseInt(e.target.value, 10))}
                className="w-full h-1.5 rounded-lg cursor-pointer"
                style={{ accentColor: theme.accent }}
              />
              <span className="text-[10px] w-7 text-right font-mono" style={{ color: theme.textMuted }}>
                {isMuted ? '0%' : `${volume}%`}
              </span>
            </div>
          </div>

          {/* Ambient Room Sound Layers (Loud & Clear Nature Sounds) */}
          <div className="space-y-2.5">
            <div className="flex items-center justify-between">
              <h4 className="text-[11px] font-bold tracking-wider uppercase" style={{ color: theme.textMuted }}>
                Calm Nature Atmosphere
              </h4>
              <span className="text-[10px] text-[var(--soft)]">Mix multiple</span>
            </div>
            <div className="space-y-2">
              {ambientSounds.map((sound) => (
                <div
                  key={sound.id}
                  className="flex items-center justify-between p-2.5 rounded-xl border transition-all"
                  style={{
                    backgroundColor: sound.isPlaying ? theme.badgeBg : theme.surface,
                    borderColor: sound.isPlaying ? theme.accent : theme.surfaceBorder
                  }}
                >
                  <button
                    type="button"
                    onClick={() => toggleAmbient(sound.id)}
                    className="flex items-center gap-2.5 text-xs font-semibold text-left flex-1 cursor-pointer"
                    style={{ color: sound.isPlaying ? theme.accent : theme.textPrimary }}
                  >
                    <div
                      className="p-1.5 rounded-lg shrink-0"
                      style={{
                        backgroundColor: sound.isPlaying ? theme.accent : theme.surface,
                        color: sound.isPlaying ? theme.accentText : theme.textMuted
                      }}
                    >
                      {getAmbientIcon(sound.icon)}
                    </div>
                    <span>{sound.name}</span>
                  </button>

                  {sound.isPlaying && (
                    <div className="flex items-center gap-2 ml-2">
                      <input
                        type="range"
                        min="0"
                        max="1"
                        step="0.05"
                        value={sound.volume}
                        onChange={(e) => setAmbientVolume(sound.id, parseFloat(e.target.value))}
                        className="w-24 h-1.5 rounded-lg cursor-pointer"
                        style={{ accentColor: theme.accent }}
                      />
                      <span className="text-[9px] font-mono text-[var(--soft)] w-7 text-right">
                        {Math.round(sound.volume * 100)}%
                      </span>
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>

          {/* Shared Mixtape Section */}
          <div className="space-y-2.5">
            <div className="flex items-center justify-between">
              <h4 className="text-[11px] font-bold tracking-wider uppercase" style={{ color: theme.textMuted }}>
                Shared Mixtape ({playlist.length})
              </h4>
              <button
                type="button"
                onClick={() => setShowAddForm(!showAddForm)}
                className="flex items-center gap-1 text-[11px] font-bold cursor-pointer hover:opacity-85 transition"
                style={{ color: theme.accent }}
              >
                <Plus className="w-3.5 h-3.5" />
                <span>Add Song</span>
              </button>
            </div>

            {/* DIRECT AUDIO FILE UPLOAD FORM */}
            {showAddForm && (
              <form
                onSubmit={handleAddTrack}
                className="p-3.5 rounded-2xl border space-y-3 text-xs shadow-sm animate-in fade-in"
                style={{ backgroundColor: theme.surface, borderColor: theme.surfaceBorder }}
              >
                <div className="flex items-center justify-between">
                  <span className="font-semibold text-xs">Add a Song to Mixtape</span>
                  <button
                    type="button"
                    onClick={() => setShowManualUrl(!showManualUrl)}
                    className="text-[10px] text-[var(--soft)] underline cursor-pointer"
                  >
                    {showManualUrl ? 'Switch to file upload' : 'Enter URL instead'}
                  </button>
                </div>

                {!showManualUrl ? (
                  <div>
                    <input
                      ref={fileInputRef}
                      type="file"
                      accept="audio/*,.mp3,.m4a,.wav,.ogg,.aac"
                      onChange={handleFileSelect}
                      className="hidden"
                    />
                    <div
                      onClick={() => fileInputRef.current?.click()}
                      className={`border-2 border-dashed rounded-xl p-3.5 text-center cursor-pointer transition flex flex-col items-center justify-center gap-1.5 ${
                        selectedAudioFile
                          ? 'border-[var(--app-accent)] bg-[var(--app-accent)]/5'
                          : 'border-[var(--line)] hover:bg-[var(--paper)]'
                      }`}
                    >
                      {selectedAudioFile ? (
                        <>
                          <div className="w-8 h-8 rounded-full bg-emerald-500 text-white flex items-center justify-center">
                            <Check className="w-4 h-4" />
                          </div>
                          <span className="font-semibold text-xs text-[var(--ink)] truncate max-w-[240px]">
                            {selectedAudioFile.name}
                          </span>
                          <span className="text-[10px] text-[var(--soft)]">
                            {(selectedAudioFile.size / (1024 * 1024)).toFixed(1)} MB · Tap to change file
                          </span>
                        </>
                      ) : (
                        <>
                          <div className="w-8 h-8 rounded-full bg-[var(--paper)] text-[var(--app-accent)] flex items-center justify-center">
                            <Upload className="w-4 h-4" />
                          </div>
                          <span className="font-semibold text-xs text-[var(--ink)]">
                            Choose MP3 / Audio from Device
                          </span>
                          <span className="text-[10px] text-[var(--soft)]">
                            Direct upload from phone or computer storage
                          </span>
                        </>
                      )}
                    </div>
                  </div>
                ) : (
                  <div>
                    <label className="text-[10px] text-[var(--soft)] block mb-1">Direct Audio Stream / MP3 URL</label>
                    <input
                      type="url"
                      placeholder="https://... (.mp3, .ogg)"
                      value={newUrl}
                      onChange={(e) => setNewUrl(e.target.value)}
                      className="w-full px-3 py-2 rounded-xl border outline-none"
                      style={{ backgroundColor: theme.bgSecondary, borderColor: theme.surfaceBorder, color: theme.textPrimary }}
                    />
                  </div>
                )}

                <div className="space-y-2 pt-1">
                  <input
                    type="text"
                    placeholder="Song Title (e.g. Yellow)"
                    value={newTitle}
                    onChange={(e) => setNewTitle(e.target.value)}
                    className="w-full px-3 py-2 rounded-xl border outline-none text-xs"
                    style={{ backgroundColor: theme.bgSecondary, borderColor: theme.surfaceBorder, color: theme.textPrimary }}
                    required
                  />
                  <input
                    type="text"
                    placeholder="Artist (e.g. Coldplay)"
                    value={newArtist}
                    onChange={(e) => setNewArtist(e.target.value)}
                    className="w-full px-3 py-2 rounded-xl border outline-none text-xs"
                    style={{ backgroundColor: theme.bgSecondary, borderColor: theme.surfaceBorder, color: theme.textPrimary }}
                  />
                </div>

                {isUploading && uploadProgress > 0 && (
                  <div className="space-y-1 py-1">
                    <div className="flex justify-between text-[10px] text-[var(--soft)]">
                      <span>Uploading to cloud...</span>
                      <span>{uploadProgress}%</span>
                    </div>
                    <div className="w-full h-1.5 rounded-full bg-[var(--line)] overflow-hidden">
                      <div
                        className="h-full bg-[var(--app-accent)] transition-all duration-300"
                        style={{ width: `${uploadProgress}%` }}
                      />
                    </div>
                  </div>
                )}

                <button
                  type="submit"
                  disabled={isUploading}
                  className="w-full py-2.5 rounded-xl font-bold transition active:scale-95 shadow-sm flex items-center justify-center gap-1.5 cursor-pointer disabled:opacity-50"
                  style={{
                    background: theme.accentGradient || theme.accent,
                    color: theme.accentText
                  }}
                >
                  {isUploading ? (
                    <>
                      <Loader2 className="w-3.5 h-3.5 animate-spin" />
                      <span>Uploading song...</span>
                    </>
                  ) : (
                    <>
                      <Upload className="w-3.5 h-3.5" />
                      <span>Save to Shared Mixtape</span>
                    </>
                  )}
                </button>
              </form>
            )}

            {/* Playlist Track List */}
            <div className="space-y-1.5 max-h-48 overflow-y-auto no-scrollbar">
              {playlist.length === 0 ? (
                <p className="text-xs text-center py-4 text-[var(--soft)] leading-relaxed">
                  Your mixtape is empty. Tap "Add Song" to upload music from your phone or PC.
                </p>
              ) : (
                playlist.map((track) => {
                  const isCurrent = currentTrack?.id === track.id
                  return (
                    <div
                      key={track.id}
                      className="w-full p-2.5 rounded-xl border flex items-center justify-between text-xs transition group"
                      style={{
                        backgroundColor: isCurrent ? theme.badgeBg : theme.surface,
                        borderColor: isCurrent ? theme.accent : theme.surfaceBorder,
                        color: isCurrent ? theme.accent : theme.textPrimary
                      }}
                    >
                      <button
                        type="button"
                        onClick={() => handlePlayTrack(track)}
                        className="truncate pr-2 text-left flex-1 cursor-pointer flex items-center gap-2"
                      >
                        <div
                          className={`w-6 h-6 rounded-lg flex items-center justify-center shrink-0 ${
                            isCurrent && isPlaying ? 'bg-[var(--app-accent)] text-white' : 'bg-[var(--paper)] text-[var(--soft)]'
                          }`}
                        >
                          {isCurrent && isPlaying ? (
                            <Pause className="w-3 h-3 fill-current" />
                          ) : (
                            <Play className="w-3 h-3 fill-current ml-0.5" />
                          )}
                        </div>
                        <div className="min-w-0">
                          <p className="font-semibold truncate">{track.title}</p>
                          <p className="text-[10px] truncate" style={{ color: theme.textMuted }}>
                            {track.artist}
                            {track.addedBy && ` · added by ${track.addedBy}`}
                          </p>
                        </div>
                      </button>

                      <div className="flex items-center gap-2">
                        {isCurrent && isPlaying && (
                          <span
                            className="w-2 h-2 rounded-full animate-ping"
                            style={{ backgroundColor: theme.accent }}
                          />
                        )}
                        <button
                          type="button"
                          onClick={(e) => handleDeleteTrack(track.id, e)}
                          className="text-[#888a82] hover:text-red-500 p-1 rounded cursor-pointer opacity-70 hover:opacity-100 transition"
                          title="Remove track"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>
                  )
                })
              )}
            </div>
          </div>

          {/* Sync Playback Mode Toggle */}
          <div className="pt-2 border-t border-[var(--line)]/50 flex items-center justify-between">
            <div className="pr-2">
              <span className="text-xs font-semibold block text-[var(--ink)]">Sync with Partner</span>
              <span className="text-[10px] text-[var(--soft)] block">Auto-tune to your partner's music in real-time</span>
            </div>
            <button
              type="button"
              onClick={handleToggleAutoSync}
              className={`w-11 h-6 rounded-full transition-colors p-0.5 cursor-pointer shrink-0 ${
                autoSyncEnabled ? 'bg-emerald-500' : 'bg-[var(--line)]'
              }`}
            >
              <div
                className={`w-5 h-5 rounded-full bg-white transition-transform ${
                  autoSyncEnabled ? 'translate-x-5' : 'translate-x-0'
                }`}
              />
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
