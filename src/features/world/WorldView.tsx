import React from 'react'
import { PartnerLocationCard } from '../stage/PartnerLocationCard'

export const WorldView: React.FC = () => {
  return (
    <div className="page active" id="world-view">
      <header className="topbar">
        <div>
          <h1 className="wordmark">Our World</h1>
          <p className="text-[11px] text-[var(--soft)] mt-0.5">
            Realtime tether, distance & live mutual presence
          </p>
        </div>
      </header>

      <div className="w-full flex-1">
        <PartnerLocationCard />
      </div>
    </div>
  )
}
