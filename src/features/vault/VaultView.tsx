import React, { useState, useEffect } from 'react'
import { useAuth } from '@/core/auth'
import { useTheme } from '@/core/theme'
import { useToast } from '@/core/toast'
import { getSupabaseClient } from '@/core/storage/supabase'
import { getFirebaseDb } from '@/core/storage/firebase'
import { doc, setDoc, onSnapshot } from 'firebase/firestore'
import { realtimeBridge } from '@/core/realtime'
import { uploadMediaFile } from '@/core/storage/uploader'
import { AppTopBar } from '@/components/ui/AppTopBar'
import { audioManager } from '@/core/audio'
import confetti from 'canvas-confetti'
import { Lock, Unlock, Play, Edit3, X, Loader2, Delete, Upload, Video } from 'lucide-react'

export interface VaultConfig {
  isLocked: boolean
  passcode: string
  title: string
  subtitle: string
  videoUrl?: string
  personalNote: string
}

export interface VaultViewProps {
  onOpenAudioModal?: () => void
  onOpenThemeModal?: () => void
  onOpenProfileModal?: () => void
}

export const VaultView: React.FC<VaultViewProps> = ({
  onOpenAudioModal,
  onOpenThemeModal,
  onOpenProfileModal
}) => {
  const { user, space, partner } = useAuth()
  const { theme, isDark, toggleDarkLight } = useTheme()
  const { showToast } = useToast()

  const spaceId = space?.id || 'default_space'
  const vaultDocId = `vault_${spaceId}`

  const [vaultConfig, setVaultConfig] = useState<VaultConfig>({
    isLocked: true,
    passcode: '2512',
    title: 'Just for us',
    subtitle: 'A moment from the night we promised.',
    videoUrl: '',
    personalNote: '“No matter how many places we go, this is still my favorite view.”'
  })

  const [enteredPin, setEnteredPin] = useState('')
  const [isUnlocked, setIsUnlocked] = useState(false)
  const [isPlayingVideo, setIsPlayingVideo] = useState(false)

  // Configure modal state
  const [isConfiguring, setIsConfiguring] = useState(false)
  const [editTitle, setEditTitle] = useState('')
  const [editSubtitle, setEditSubtitle] = useState('')
  const [editPasscode, setEditPasscode] = useState('')
  const [editVideoUrl, setEditVideoUrl] = useState('')
  const [editNote, setEditNote] = useState('')
  const [isSaving, setIsSaving] = useState(false)
  const [isUploadingMedia, setIsUploadingMedia] = useState(false)
  const fileInputRef = React.useRef<HTMLInputElement | null>(null)

  const handleSelectMediaFile = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    setIsUploadingMedia(true)
    showToast('Uploading video/photo to secure vault...')
    try {
      const result = await uploadMediaFile(file, 'vault')
      setEditVideoUrl(result.url)
      showToast('Media attached successfully! 🎬')
    } catch (err: any) {
      console.warn('Upload error, using local base64:', err)
      try {
        const reader = new FileReader()
        reader.onload = () => {
          if (typeof reader.result === 'string') {
            setEditVideoUrl(reader.result)
            showToast('Media loaded from device! 🎬')
          }
        }
        reader.readAsDataURL(file)
      } catch {
        showToast('Could not read selected file.')
      }
    } finally {
      setIsUploadingMedia(false)
      if (fileInputRef.current) fileInputRef.current.value = ''
    }
  }

  // 1. Fetch cloud vault config from Supabase & Firestore, and subscribe
  useEffect(() => {
    const supabase = getSupabaseClient()
    const db = getFirebaseDb()

    const fetchVault = async () => {
      try {
        const { data, error } = await supabase
          .from('app_content')
          .select('content')
          .eq('id', vaultDocId)
          .maybeSingle()

        if (!error && data?.content) {
          setVaultConfig(data.content as VaultConfig)
        }
      } catch (err) {
        console.warn('Error fetching vault from Supabase:', err)
      }
    }

    fetchVault()

    const channel = supabase
      .channel(`vault_channel_${spaceId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'app_content',
          filter: `id=eq.${vaultDocId}`
        },
        (payload: any) => {
          if (payload.new?.content) {
            setVaultConfig(payload.new.content as VaultConfig)
          }
        }
      )
      .subscribe()

    // Firestore listener for cross-platform peer synchronization
    let unsubFirestore: (() => void) | undefined
    if (db && spaceId) {
      try {
        unsubFirestore = onSnapshot(doc(db, 'spaces', spaceId, 'features', 'vault'), (snapshot) => {
          if (snapshot.exists()) {
            const data = snapshot.data()
            if (data?.vault) {
              setVaultConfig(data.vault as VaultConfig)
            }
          }
        }, (err) => {
          console.warn('Firestore vault snapshot error:', err)
        })
      } catch (err) {
        console.warn('Failed to listen to Firestore vault:', err)
      }
    }

    // Peer broadcast listener
    const unsubBroadcast = realtimeBridge.subscribe((event) => {
      if (event.type === 'VAULT_UPDATE' && event.data?.vault) {
        setVaultConfig(event.data.vault as VaultConfig)
      }
    })

    return () => {
      supabase.removeChannel(channel)
      if (unsubFirestore) unsubFirestore()
      unsubBroadcast()
    }
  }, [spaceId, vaultDocId])

  const handleBackspace = () => {
    setEnteredPin((prev) => prev.slice(0, -1))
  }

  const handleKeyPress = (digit: string) => {
    if (enteredPin.length < 4) {
      const nextPin = enteredPin + digit
      setEnteredPin(nextPin)

      if (nextPin.length === 4) {
        setTimeout(() => {
          // Strictly verify entered PIN against stored passcode
          if (nextPin === (vaultConfig.passcode || '2512')) {
            setIsUnlocked(true)
            setEnteredPin('')
            confetti({
              particleCount: 50,
              spread: 60,
              origin: { y: 0.5 }
            })
            showToast('Secret capsule unlocked.')
          } else {
            showToast('Incorrect passcode. Try again.')
            setEnteredPin('')
          }
        }, 220)
      }
    }
  }

  const handleLockCapsule = () => {
    setIsUnlocked(false)
    setEnteredPin('')
    setIsPlayingVideo(false)
    audioManager.restoreFromMedia()
    showToast('Capsule locked.')
  }

  // Restore ambient music on unmount
  useEffect(() => {
    return () => {
      audioManager.restoreFromMedia()
    }
  }, [])

  const handleOpenConfig = () => {
    setEditTitle(vaultConfig.title)
    setEditSubtitle(vaultConfig.subtitle)
    setEditPasscode(vaultConfig.passcode)
    setEditVideoUrl(vaultConfig.videoUrl || '')
    setEditNote(vaultConfig.personalNote)
    setIsConfiguring(true)
  }

  const handleSaveConfig = async () => {
    setIsSaving(true)
    const updated: VaultConfig = {
      isLocked: true,
      passcode: editPasscode.trim() || '2512',
      title: editTitle.trim() || 'Just for us',
      subtitle: editSubtitle.trim() || 'A moment from the night we promised.',
      videoUrl: editVideoUrl.trim(),
      personalNote: editNote.trim() || '“No matter how many places we go, this is still my favorite view.”'
    }

    setVaultConfig(updated)
    setIsConfiguring(false)
    showToast('Capsule configuration saved.')

    try {
      const supabase = getSupabaseClient()
      await supabase.from('app_content').upsert({
        id: vaultDocId,
        content: updated,
        updated_at: new Date().toISOString()
      })

      // Sync to Firebase Firestore
      const db = getFirebaseDb()
      if (db && spaceId) {
        try {
          await setDoc(doc(db, 'spaces', spaceId, 'features', 'vault'), { vault: updated }, { merge: true })
        } catch {}
      }

      // Realtime broadcast to partner
      await realtimeBridge.broadcast({
        type: 'VAULT_UPDATE',
        senderId: user?.id || '',
        senderNickname: user?.nickname || 'Partner',
        timestamp: Date.now(),
        data: { vault: updated }
      }).catch(() => {})
    } catch (err) {
      console.warn('Error saving vault config:', err)
    } finally {
      setIsSaving(false)
    }
  }

  return (
    <div className={`page vault-page active ${isUnlocked ? 'unlocked' : ''}`} id="capsule">
      {/* 1. TOPBAR - Universal Consistent Header */}
      <AppTopBar
        title="Secret Vault"
        subtitle="Private couple time capsule"
        onOpenAudioModal={onOpenAudioModal}
        onOpenThemeModal={onOpenThemeModal}
        onOpenProfileModal={onOpenProfileModal}
      />

      {/* 2. LOCKED VIEW */}
      {!isUnlocked ? (
        <div className="locked-view">
          <div className="vault-lock-card">
            <div className="vault-lock-icon">♙</div>
            <h2>Our secret capsule</h2>
            <div className="vault-sub">Some things are just for us.</div>

            {/* 4 PIN DOTS */}
            <div className="pin-dots">
              {[0, 1, 2, 3].map((idx) => (
                <i
                  key={idx}
                  className={`pin-dot ${idx < enteredPin.length ? 'filled' : ''}`}
                />
              ))}
            </div>

            {/* NUMERIC KEYPAD */}
            <div className="keypad">
              <button type="button" className="key" onClick={() => handleKeyPress('1')}>
                1<small>·</small>
              </button>
              <button type="button" className="key" onClick={() => handleKeyPress('2')}>
                2<small>ABC</small>
              </button>
              <button type="button" className="key" onClick={() => handleKeyPress('3')}>
                3<small>DEF</small>
              </button>
              <button type="button" className="key" onClick={() => handleKeyPress('4')}>
                4<small>GHI</small>
              </button>
              <button type="button" className="key" onClick={() => handleKeyPress('5')}>
                5<small>JKL</small>
              </button>
              <button type="button" className="key" onClick={() => handleKeyPress('6')}>
                6<small>MNO</small>
              </button>
              <button type="button" className="key" onClick={() => handleKeyPress('7')}>
                7<small>PQRS</small>
              </button>
              <button type="button" className="key" onClick={() => handleKeyPress('8')}>
                8<small>TUV</small>
              </button>
              <button type="button" className="key" onClick={() => handleKeyPress('9')}>
                9<small>WXYZ</small>
              </button>
              <div className="w-[52px] h-[46px]" />
              <button type="button" className="key zero" onClick={() => handleKeyPress('0')}>
                0
              </button>
              <button
                type="button"
                className="key flex items-center justify-center text-[var(--soft)] hover:text-[var(--ink)] active:scale-95 transition cursor-pointer"
                onClick={handleBackspace}
                title="Backspace"
              >
                <Delete className="w-4 h-4" />
              </button>
            </div>

            <div className="pin-help">Your shared four-digit code</div>
            {vaultConfig.passcode === '2512' && (
              <div className="mt-2.5 text-[10.5px] text-[var(--soft)] bg-[var(--paper)] px-3 py-1.5 rounded-full border border-[var(--line)] inline-block">
                First time? Default PIN is <b className="text-[var(--ink)]">2512</b>
              </div>
            )}
          </div>

          {/* Reserved Bottom Section for Vault Custom Additions & Security Status */}
          <div className="vault-bottom-section w-full mt-6 text-center space-y-1.5">
            <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[var(--paper)] border border-[var(--line)] text-[10px] text-[var(--ink)] shadow-2xs">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
              <span className="font-medium">Encrypted Shared Capsule</span>
            </div>
            <p className="text-[9px] text-[var(--soft)] max-w-[260px] mx-auto leading-relaxed">
              Only accessible by you and {partner?.nickname || 'your connected partner'}.
            </p>
          </div>
        </div>
      ) : (
        /* 3. UNLOCKED VIEW */
        <div className="unlocked-view block">
          <div className="vault-lock-icon" style={{ margin: '30px auto 12px' }}>
            ✦
          </div>
          <h2 style={{ textAlign: 'center' }}>{vaultConfig.title}</h2>
          <p className="vault-sub" style={{ textAlign: 'center' }}>
            {vaultConfig.subtitle}
          </p>

          {/* Private Video */}
          <div className="private-video">
            {vaultConfig.videoUrl && isPlayingVideo ? (
              <video
                src={vaultConfig.videoUrl}
                controls
                autoPlay
                onPlay={() => audioManager.duckForMedia()}
                onPause={() => audioManager.restoreFromMedia()}
                onEnded={() => audioManager.restoreFromMedia()}
                className="w-full h-full object-cover"
              />
            ) : (
              <>
                <button
                  type="button"
                  className="play-button"
                  onClick={() => {
                    if (vaultConfig.videoUrl) setIsPlayingVideo(true)
                    else showToast('No video attached yet. Tap "Edit Capsule" to add one.')
                  }}
                >
                  ▶
                </button>
                <span className="video-caption">
                  {vaultConfig.videoUrl
                    ? 'Private shared video memory · Tap to play'
                    : 'No video attached · Tap Edit Capsule below'}
                </span>
              </>
            )}
          </div>

          {/* Private Letter */}
          <div className="private-letter">
            <small>A letter for you</small>
            <p>{vaultConfig.personalNote}</p>
          </div>

          <div className="flex gap-2 justify-center mt-3">
            <button
              type="button"
              className="lock-capsule"
              onClick={handleOpenConfig}
            >
              Edit capsule
            </button>
            <button
              type="button"
              className="lock-capsule"
              onClick={handleLockCapsule}
            >
              Lock capsule
            </button>
          </div>
        </div>
      )}

      {/* EDIT CAPSULE MODAL - Full Screen Solid Smooth Page */}
      {isConfiguring && (
        <div
          className="fixed inset-0 z-50 bg-[var(--app-bg)] text-[var(--ink)] flex flex-col overflow-hidden"
        >
          <div className="pt-safe px-4 py-3 flex items-center justify-between border-b border-[var(--line)] bg-[var(--white)] shrink-0">
            <button
              type="button"
              onClick={() => setIsConfiguring(false)}
              className="p-1.5 -ml-1.5 rounded-full hover:bg-[var(--paper)] transition flex items-center gap-1 text-xs font-medium text-[var(--ink)] cursor-pointer"
            >
              <X className="w-4 h-4" />
              <span>Cancel</span>
            </button>
            <h3 className="text-sm font-semibold tracking-tight text-[var(--ink)]">Configure Capsule</h3>
            <div className="w-12" />
          </div>

          <div className="flex-1 overflow-y-auto px-4 py-6 max-w-md mx-auto w-full space-y-4">

            <div className="space-y-3">
              <div>
                <label className="text-[10px] text-[var(--soft)] block mb-1">Passcode (4 digits)</label>
                <input
                  type="text"
                  maxLength={4}
                  value={editPasscode}
                  onChange={(e) => setEditPasscode(e.target.value)}
                  className="w-full p-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] text-xs font-mono outline-none"
                />
              </div>

              <div>
                <label className="text-[10px] text-[var(--soft)] block mb-1">Title</label>
                <input
                  type="text"
                  value={editTitle}
                  onChange={(e) => setEditTitle(e.target.value)}
                  className="w-full p-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] text-xs font-serif outline-none"
                />
              </div>

              <div>
                <label className="text-[10px] text-[var(--soft)] block mb-1">Subtitle</label>
                <input
                  type="text"
                  value={editSubtitle}
                  onChange={(e) => setEditSubtitle(e.target.value)}
                  className="w-full p-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] text-xs font-serif outline-none"
                />
              </div>

              <div>
                <label className="text-[10px] text-[var(--soft)] font-medium block mb-1.5">Attach Video or Photo</label>
                <input
                  type="file"
                  ref={fileInputRef}
                  accept="video/*,image/*"
                  className="hidden"
                  onChange={handleSelectMediaFile}
                />
                <div className="flex gap-2 items-center mb-2">
                  <button
                    type="button"
                    disabled={isUploadingMedia}
                    onClick={() => fileInputRef.current?.click()}
                    className="flex-1 py-2.5 px-3 rounded-xl border border-[var(--line)] bg-[var(--paper)] hover:bg-[var(--line)]/40 text-[var(--ink)] text-xs font-medium flex items-center justify-center gap-2 transition cursor-pointer"
                  >
                    {isUploadingMedia ? (
                      <>
                        <Loader2 className="w-3.5 h-3.5 animate-spin text-[var(--app-accent)]" />
                        <span>Attaching media...</span>
                      </>
                    ) : (
                      <>
                        <Upload className="w-3.5 h-3.5 text-[var(--app-accent)]" />
                        <span>Choose from Files / Google Photos</span>
                      </>
                    )}
                  </button>
                  {editVideoUrl && (
                    <button
                      type="button"
                      onClick={() => setEditVideoUrl('')}
                      className="py-2.5 px-3 rounded-xl border border-red-500/20 text-red-500 hover:bg-red-500/10 text-xs transition cursor-pointer"
                    >
                      Clear
                    </button>
                  )}
                </div>

                {editVideoUrl && (
                  <div className="mb-2 p-2 rounded-xl bg-[var(--paper)] border border-[var(--line)] flex items-center justify-between text-[11px] text-[var(--ink)]">
                    <span className="truncate max-w-[240px] font-mono text-[10px]">{editVideoUrl.substring(0, 40)}...</span>
                    <span className="text-[10px] text-emerald-600 font-medium shrink-0 ml-2">✓ Media Attached</span>
                  </div>
                )}

                <input
                  type="url"
                  placeholder="Or paste external video link (https://...)"
                  value={editVideoUrl}
                  onChange={(e) => setEditVideoUrl(e.target.value)}
                  className="w-full p-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] text-xs outline-none"
                />
              </div>

              <div>
                <label className="text-[10px] text-[var(--soft)] block mb-1">Secret Message / Letter</label>
                <textarea
                  rows={3}
                  value={editNote}
                  onChange={(e) => setEditNote(e.target.value)}
                  className="w-full p-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] text-xs font-serif italic outline-none resize-none"
                />
              </div>
            </div>

            <div className="flex gap-2 mt-4">
              {(editVideoUrl || editNote) && (
                <button
                  type="button"
                  onClick={() => {
                    setEditVideoUrl('')
                    setEditNote('')
                    showToast('Media and note cleared. Tap Save to apply.')
                  }}
                  className="py-2.5 px-3 rounded-xl border border-red-300 dark:border-red-900 text-red-600 dark:text-red-400 text-xs font-medium cursor-pointer hover:bg-red-500/10 transition"
                  title="Clear secret media and note"
                >
                  Clear content
                </button>
              )}
              <button
                type="button"
                onClick={handleSaveConfig}
                disabled={isSaving}
                className="flex-1 py-2.5 rounded-xl bg-[var(--app-accent)] text-white text-xs font-medium cursor-pointer hover:opacity-90 transition disabled:opacity-50"
              >
                {isSaving ? 'Saving...' : 'Save Capsule'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
