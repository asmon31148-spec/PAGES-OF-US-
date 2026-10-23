import React, { useState, useRef } from 'react'
import { useAuth } from '@/core/auth'
import { useToast } from '@/core/toast'
import { uploadMediaFile } from '@/core/storage/uploader'
import { sendTestNotification } from '@/core/notifications'
import { Camera, LogOut, Sparkles, User, Mail, Quote, Check, RefreshCw, X, Bell, BellRing } from 'lucide-react'

interface ProfileModalProps {
  isOpen: boolean
  onClose: () => void
}

const QUICK_NOTES = [
  'Thinking of you 🌿',
  'Listening to rain 🌧',
  'Coffee break ☕',
  'Late night thoughts ✨',
  'Missing your smile 🤍',
  'Out exploring 🌙'
]

export const ProfileModal: React.FC<ProfileModalProps> = ({ isOpen, onClose }) => {
  const { user, partner, updateProfile, logout } = useAuth()
  const { showToast } = useToast()

  const [nickname, setNickname] = useState(user?.nickname || '')
  const [bio, setBio] = useState(user?.bio || '')
  const [presenceStatus, setPresenceStatus] = useState(user?.presenceStatus || '')
  const [avatarUrl, setAvatarUrl] = useState(user?.avatarUrl || '')

  const [isUploadingPhoto, setIsUploadingPhoto] = useState(false)
  const [isSaving, setIsSaving] = useState(false)
  const [isTestingNotif, setIsTestingNotif] = useState(false)

  const fileInputRef = useRef<HTMLInputElement>(null)

  if (!isOpen || !user) return null

  const handleSendTestNotification = async () => {
    setIsTestingNotif(true)
    try {
      const ok = await sendTestNotification()
      if (ok) {
        showToast('Test notification sent! Check your notification bar ✨')
      } else {
        showToast('Please allow notifications in your phone settings.')
      }
    } catch {
      showToast('Could not send notification.')
    } finally {
      setIsTestingNotif(false)
    }
  }

  // Handle Photo Picker & Direct Cloud Upload
  const handlePhotoSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    setIsUploadingPhoto(true)
    showToast('Uploading profile photo to cloud...')

    try {
      const uploadRes = await uploadMediaFile(file, 'avatars')
      setAvatarUrl(uploadRes.url)
      showToast('Photo uploaded successfully!')
    } catch (err: any) {
      console.warn('Avatar upload failed:', err)
      showToast('Could not upload photo. Please check your internet.')
    } finally {
      setIsUploadingPhoto(false)
    }
  }

  // Handle Save
  const handleSave = async () => {
    if (!nickname.trim()) {
      showToast('Nickname cannot be empty.')
      return
    }

    setIsSaving(true)
    try {
      await updateProfile({
        nickname: nickname.trim(),
        bio: bio.trim(),
        presenceStatus: presenceStatus.trim(),
        avatarUrl
      })
      showToast('Profile updated & synced to your partner!')
      onClose()
    } catch (err: any) {
      showToast(err.message || 'Error updating profile.')
    } finally {
      setIsSaving(false)
    }
  }

  const handleLogout = async () => {
    if (!window.confirm('Are you sure you want to log out of Pages of Us?')) return
    await logout()
    showToast('Logged out.')
    onClose()
  }

  const initial = (nickname || user.nickname || 'Y').charAt(0).toUpperCase()

  return (
    <div className="fixed inset-0 z-50 flex flex-col justify-start overflow-y-auto px-4 py-5 sm:p-8 bg-[var(--bg)] text-[var(--ink)] animate-in fade-in transition-colors duration-200">
      <div className="w-full max-w-md mx-auto flex-1 flex flex-col my-auto space-y-4">
        {/* Top Header Bar */}
        <div className="flex items-center justify-between pb-3 border-b border-[var(--line)]">
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 rounded-full cursor-pointer hover:bg-[var(--paper)] transition flex items-center gap-1.5 text-xs font-medium text-[var(--soft)]"
          >
            <X className="w-4 h-4" />
            <span>Close</span>
          </button>
          <div className="text-center">
            <h3 className="text-sm font-semibold tracking-tight">Your Profile</h3>
          </div>
          <div className="w-12" />
        </div>

        <div className="p-6 rounded-3xl border border-[var(--line)] bg-[var(--white)] shadow-md space-y-5 flex-1 my-auto">
          <div>
            <div className="text-[10px] tracking-widest font-semibold uppercase text-[var(--app-accent)]">
              ACCOUNT & PRESENCE
            </div>
            <h2 className="text-lg font-bold text-[var(--ink)] mt-0.5">Edit Profile</h2>
            <p className="text-xs text-[var(--soft)] mt-0.5">
              Your profile, avatar photo, and daily thoughts sync instantly with your partner.
            </p>
          </div>

          {/* 1. Avatar Photo Section */}
        <div className="flex flex-col items-center justify-center mb-5">
          <div className="relative group cursor-pointer" onClick={() => fileInputRef.current?.click()}>
            <div className="w-20 h-20 rounded-full p-1 bg-gradient-to-tr from-[#8a9b85] to-[#b77e6b] shadow-md">
              <div className="w-full h-full rounded-full overflow-hidden bg-[var(--paper)] flex items-center justify-center text-xl font-bold font-serif text-[var(--ink)]">
                {avatarUrl ? (
                  <img src={avatarUrl} alt="Avatar" className="w-full h-full object-cover" />
                ) : (
                  <span>{initial}</span>
                )}
              </div>
            </div>

            <button
              type="button"
              disabled={isUploadingPhoto}
              className="absolute bottom-0 right-0 w-7 h-7 rounded-full bg-[var(--app-accent)] text-white flex items-center justify-center shadow-xs hover:opacity-90 transition border-2 border-[var(--white)] cursor-pointer"
              title="Upload photo"
            >
              {isUploadingPhoto ? (
                <RefreshCw className="w-3.5 h-3.5 animate-spin" />
              ) : (
                <Camera className="w-3.5 h-3.5" />
              )}
            </button>
          </div>

          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            className="hidden"
            onChange={handlePhotoSelect}
          />

          <span className="text-[9px] text-[var(--soft)] mt-2">
            Tap camera to upload a photo
          </span>
        </div>

        {/* 2. Profile Fields */}
        <div className="space-y-3.5">
          {/* Nickname */}
          <div>
            <label className="text-[10px] font-semibold text-[var(--soft)] uppercase tracking-wider block mb-1">
              Your Nickname
            </label>
            <div className="relative">
              <input
                type="text"
                value={nickname}
                onChange={(e) => setNickname(e.target.value)}
                placeholder="How your partner sees you"
                className="w-full text-xs py-2 px-3 pl-8 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] focus:outline-none focus:border-[var(--app-accent)]"
              />
              <User className="w-3.5 h-3.5 text-[var(--soft)] absolute left-2.5 top-2.5" />
            </div>
          </div>

          {/* Instagram-style Note / Thought Status */}
          <div>
            <div className="flex items-center justify-between mb-1">
              <label className="text-[10px] font-semibold text-[var(--soft)] uppercase tracking-wider block">
                Instagram Note / Thought
              </label>
              <span className="text-[9px] text-[var(--soft)]">Shown above avatar</span>
            </div>
            <div className="relative">
              <input
                type="text"
                value={presenceStatus}
                onChange={(e) => setPresenceStatus(e.target.value)}
                placeholder="e.g. Thinking of you 🌿"
                maxLength={45}
                className="w-full text-xs py-2 px-3 pl-8 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] focus:outline-none focus:border-[var(--app-accent)]"
              />
              <Sparkles className="w-3.5 h-3.5 text-[var(--terra)] absolute left-2.5 top-2.5" />
            </div>

            {/* Quick Note Chips */}
            <div className="flex flex-wrap gap-1 mt-1.5">
              {QUICK_NOTES.map((note) => (
                <button
                  key={note}
                  type="button"
                  onClick={() => setPresenceStatus(note)}
                  className="text-[9px] px-2 py-0.5 rounded-full border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] hover:opacity-85 transition cursor-pointer"
                >
                  {note}
                </button>
              ))}
            </div>
          </div>

          {/* Bio / Personal Quote */}
          <div>
            <label className="text-[10px] font-semibold text-[var(--soft)] uppercase tracking-wider block mb-1">
              Personal Bio / Quote
            </label>
            <div className="relative">
              <textarea
                value={bio}
                onChange={(e) => setBio(e.target.value)}
                rows={2}
                placeholder="A quiet favorite memory or note for your partner..."
                className="w-full text-xs py-2 px-3 pl-8 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] focus:outline-none focus:border-[var(--app-accent)] resize-none"
              />
              <Quote className="w-3.5 h-3.5 text-[var(--soft)] absolute left-2.5 top-2.5" />
            </div>
          </div>

          {/* Account Details Box */}
          <div className="p-2.5 rounded-xl bg-[var(--paper)] border border-[var(--line)] text-[10px] text-[var(--soft)] space-y-1">
            <div className="flex items-center justify-between">
              <span className="flex items-center gap-1.5">
                <Mail className="w-3 h-3 text-[var(--app-accent)]" />
                <span className="font-medium text-[var(--ink)]">{user.email || 'Cloud Account'}</span>
              </span>
              <span className="text-[9px] text-[var(--soft)]">Verified</span>
            </div>
            {partner && (
              <div className="text-[9px] text-[var(--soft)]">
                Paired with: <b className="text-[var(--app-accent)]">{partner.nickname}</b>
              </div>
            )}
          </div>

          {/* Phone Notifications & Test Trigger */}
          <div className="p-3 rounded-2xl bg-[var(--paper)] border border-[var(--line)] space-y-2">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-1.5 text-xs font-semibold text-[var(--ink)]">
                <Bell className="w-3.5 h-3.5 text-[var(--app-accent)]" />
                <span>Phone Notifications</span>
              </div>
              <span className="text-[10px] px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-600 font-medium">
                Active
              </span>
            </div>
            <p className="text-[11px] text-[var(--soft)]">
              Instant alerts for partner pulses, love letters, and daily questions.
            </p>
            <button
              type="button"
              onClick={handleSendTestNotification}
              disabled={isTestingNotif}
              className="w-full py-2 px-3 rounded-xl border border-[var(--line)] bg-[var(--white)] text-[var(--ink)] text-xs font-medium hover:bg-[var(--line)]/30 transition flex items-center justify-center gap-1.5 cursor-pointer disabled:opacity-50"
            >
              <BellRing className="w-3.5 h-3.5 text-[var(--app-accent)]" />
              <span>{isTestingNotif ? 'Sending alert...' : 'Send Test Notification to Phone'}</span>
            </button>
          </div>
        </div>

          {/* Buttons */}
          <div className="flex gap-2 pt-2">
            <button
              type="button"
              onClick={handleSave}
              disabled={isSaving}
              className="flex-1 py-3 rounded-2xl bg-[var(--app-accent)] text-white text-xs font-semibold cursor-pointer hover:opacity-90 transition shadow-xs flex items-center justify-center gap-1.5 disabled:opacity-50"
            >
              {isSaving ? (
                <RefreshCw className="w-3.5 h-3.5 animate-spin" />
              ) : (
                <Check className="w-3.5 h-3.5" />
              )}
              <span>Save Profile</span>
            </button>

            <button
              type="button"
              onClick={handleLogout}
              className="py-3 px-4 rounded-2xl border border-rose-300 dark:border-rose-900 bg-rose-50 dark:bg-rose-950/30 text-rose-600 dark:text-rose-400 text-xs font-semibold cursor-pointer hover:opacity-85 transition flex items-center gap-1"
              title="Log out of account"
            >
              <LogOut className="w-3.5 h-3.5" />
              <span>Logout</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
