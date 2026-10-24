import React from 'react'
import { PartnerLocationCard } from '../stage/PartnerLocationCard'
import { AppTopBar } from '@/components/ui/AppTopBar'

export interface WorldViewProps {
  onOpenAudioModal?: () => void
  onOpenThemeModal?: () => void
  onOpenProfileModal?: () => void
}

export const WorldView: React.FC<WorldViewProps> = ({
  onOpenAudioModal,
  onOpenThemeModal,
  onOpenProfileModal
}) => {
  return (
    <div className="page active !p-0 flex flex-col min-h-screen bg-[var(--app-bg)] text-[var(--ink)]" id="world-view">
      {/* Universal Topbar */}
      <div className="pt-safe px-4 pt-4 border-b border-[var(--line)] bg-[var(--white)] shadow-2xs">
        <AppTopBar
          title="Our World"
          subtitle="Realtime tether & mutual presence"
          onOpenAudioModal={onOpenAudioModal}
          onOpenThemeModal={onOpenThemeModal}
          onOpenProfileModal={onOpenProfileModal}
        />
      </div>

      {/* Main Full-Fitted Content */}
      <div className="flex-1 w-full max-w-lg mx-auto px-4 py-4 space-y-4 pb-28">
        <PartnerLocationCard />
      </div>
    </div>
  )
}
