import React from 'react'
import { PartnerLocationCard } from '../stage/PartnerLocationCard'

export const WorldView: React.FC = () => {
  return (
    <div className="page active !p-0 flex flex-col min-h-screen bg-[var(--app-bg)] text-[var(--ink)]" id="world-view">
      {/* Top Bar Header */}
      <header className="pt-safe px-4 pt-10 pb-3 flex items-center justify-between border-b border-[var(--line)] bg-[var(--white)] shrink-0 shadow-2xs">
        <div>
          <h1 className="wordmark text-2xl font-serif">Our World</h1>
          <p className="text-[11px] text-[var(--soft)] mt-0.5">
            Realtime tether, distance & live mutual presence
          </p>
        </div>
      </header>

      {/* Main Full-Fitted Content */}
      <div className="flex-1 w-full max-w-lg mx-auto px-4 py-4 space-y-4 pb-28">
        <PartnerLocationCard />
      </div>
    </div>
  )
}
