import React from 'react'
import { useAuth } from '@/core/auth'
import { useTheme } from '@/core/theme'
import { useSyncStatus } from '@/core/storage'
import { useAudio } from '@/core/audio'
import { WifiOff, RefreshCw, Palette, Music, Sparkles } from 'lucide-react'

interface AppHeaderProps {
  onOpenThemeModal: () => void
  onOpenAudioModal: () => void
  onOpenPairModal: () => void
}

export const AppHeader: React.FC<AppHeaderProps> = ({
  onOpenThemeModal,
  onOpenAudioModal,
  onOpenPairModal
}) => {
  const { user, space, partner, isPaired } = useAuth()
  const { theme } = useTheme()
  const syncStatus = useSyncStatus()
  const { isPlaying } = useAudio()

  return (
    <header
      className="sticky top-0 z-40 px-4 py-3 border-b transition-colors backdrop-blur-xl"
      style={{
        backgroundColor: theme.bgSecondary,
        borderColor: theme.surfaceBorder
      }}
    >
      <div className="max-w-md mx-auto flex items-center justify-between">
        {/* Left: User Avatar with Instagram Story-style Gradient Ring */}
        <div className="flex items-center gap-2.5">
          <div className="p-[2px] rounded-full bg-gradient-to-tr from-amber-500 via-rose-500 to-purple-600 shadow-sm">
            <div
              className="w-8 h-8 rounded-full flex items-center justify-center font-bold text-xs"
              style={{
                backgroundColor: theme.bgSecondary,
                color: theme.textPrimary
              }}
            >
              {user ? user.nickname.charAt(0).toUpperCase() : '✦'}
            </div>
          </div>

          <div>
            <h1
              className="text-xs font-bold tracking-tight"
              style={{ color: theme.textPrimary }}
            >
              {space?.spaceName || 'Pages of Us'}
            </h1>
            {/* Live Sync Status Indicator */}
            <div className="flex items-center gap-1.5 text-[10px]">
              {syncStatus.status === 'synced' && (
                <>
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-400" />
                  <span style={{ color: theme.textMuted }}>Connected</span>
                </>
              )}
              {syncStatus.status === 'syncing' && (
                <>
                  <RefreshCw className="w-2.5 h-2.5 animate-spin text-amber-400" />
                  <span className="text-amber-400">Syncing...</span>
                </>
              )}
              {syncStatus.status === 'offline' && (
                <>
                  <WifiOff className="w-2.5 h-2.5 text-neutral-400" />
                  <span style={{ color: theme.textMuted }}>Offline Mode</span>
                </>
              )}
            </div>
          </div>
        </div>

        {/* Center: Partner Connection Pill */}
        <button
          onClick={onOpenPairModal}
          className="flex items-center gap-1.5 px-3 py-1 rounded-full text-xs transition active:scale-95 border"
          style={{
            backgroundColor: theme.surface,
            borderColor: theme.surfaceBorder
          }}
        >
          {isPaired && partner ? (
            <>
              <span className="w-2 h-2 rounded-full bg-emerald-400 shadow-[0_0_8px_rgba(52,211,153,0.8)]" />
              <span
                className="font-semibold truncate max-w-[80px]"
                style={{ color: theme.textPrimary }}
              >
                {partner.nickname}
              </span>
            </>
          ) : (
            <>
              <Sparkles className="w-3 h-3 text-amber-400 animate-spin" />
              <span className="text-[11px] font-semibold" style={{ color: theme.accent }}>
                Link Partner
              </span>
            </>
          )}
        </button>

        {/* Right: Quick Action Controls */}
        <div className="flex items-center gap-1">
          {/* Music Quick Button */}
          <button
            onClick={onOpenAudioModal}
            className={`p-2 rounded-full transition relative ${isPlaying ? 'animate-pulse' : ''}`}
            style={{
              backgroundColor: isPlaying ? theme.badgeBg : 'transparent',
              color: isPlaying ? theme.accent : theme.textSecondary
            }}
            title="Soundtrack & Ambient Lounge"
          >
            <Music className="w-4 h-4" />
            {isPlaying && (
              <span
                className="absolute top-1 right-1 w-2 h-2 rounded-full"
                style={{ backgroundColor: theme.accent }}
              />
            )}
          </button>

          {/* Theme Switcher */}
          <button
            onClick={onOpenThemeModal}
            className="p-2 rounded-full transition active:scale-90 opacity-70 hover:opacity-100"
            style={{ color: theme.textSecondary }}
            title="Switch Aesthetic Theme"
          >
            <Palette className="w-4 h-4" />
          </button>
        </div>
      </div>
    </header>
  )
}
