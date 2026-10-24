import React from 'react'
import { useAuth } from '@/core/auth'
import { useTheme } from '@/core/theme'
import { useAudio } from '@/core/audio'

interface AppTopBarProps {
  title: string
  subtitle?: string
  onOpenAudioModal?: () => void
  onOpenThemeModal?: () => void
  onOpenProfileModal?: () => void
}

export const AppTopBar: React.FC<AppTopBarProps> = ({
  title,
  subtitle,
  onOpenAudioModal,
  onOpenThemeModal,
  onOpenProfileModal
}) => {
  const { user } = useAuth()
  const { isDark, toggleDarkLight } = useTheme()
  const { isPlaying, currentTrack } = useAudio()

  return (
    <header className="topbar">
      <div className="min-w-0">
        <h1 className="wordmark text-2xl font-serif">{title}</h1>
        {subtitle && (
          <p className="text-[11px] text-[var(--soft)] mt-0.5 truncate">{subtitle}</p>
        )}
      </div>

      <div className="top-actions">
        {/* Music & Atmosphere Toggle */}
        <button
          type="button"
          className={`music-pill flex items-center gap-1.5 shrink-0 ${
            isPlaying ? 'ring-1 ring-[var(--app-accent)]/50' : ''
          }`}
          onClick={onOpenAudioModal}
          title="Music and Atmosphere"
        >
          <span className={isPlaying ? 'animate-bounce' : ''}>♫</span>
          <span className="max-w-[75px] truncate text-[11px]">
            {isPlaying ? currentTrack?.title || 'Atmosphere' : 'Atmosphere'}
          </span>
        </button>

        {/* Quick Light / Dark Mode Toggle */}
        <button
          type="button"
          className="music-pill flex items-center justify-center w-8 h-8 !p-0 shrink-0"
          onClick={toggleDarkLight}
          title={isDark ? 'Switch to Light Sanctuary (☀️)' : 'Switch to Dark Sanctuary (🌙)'}
        >
          <span>{isDark ? '☀️' : '🌙'}</span>
        </button>

        {/* User Profile Avatar Pill */}
        <button
          type="button"
          className="w-8 h-8 rounded-full p-0.5 bg-gradient-to-tr from-[#8a9b85] to-[#b77e6b] shrink-0 cursor-pointer shadow-xs hover:scale-105 transition"
          onClick={onOpenProfileModal}
          title="Customize profile & note"
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
  )
}
