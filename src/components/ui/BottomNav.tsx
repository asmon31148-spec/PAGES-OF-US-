import React from 'react'

export type TabType = 'stage' | 'memories' | 'letters' | 'timeline' | 'vault'

interface BottomNavProps {
  activeTab: TabType
  onSelectTab: (tab: TabType) => void
}

export const BottomNav: React.FC<BottomNavProps> = ({ activeTab, onSelectTab }) => {
  return (
    <nav className="bottom-nav" aria-label="App Navigation">
      {/* 1. Stage */}
      <button
        type="button"
        className={`nav-btn ${activeTab === 'stage' ? 'active' : ''}`}
        onClick={() => onSelectTab('stage')}
        aria-label="Stage"
      >
        <svg viewBox="0 0 24 24">
          <path d="m3 10 9-7 9 7M5 9v11h14V9M9 20v-6h6v6" />
        </svg>
        <span>Stage</span>
      </button>

      {/* 2. Memories */}
      <button
        type="button"
        className={`nav-btn ${activeTab === 'memories' ? 'active' : ''}`}
        onClick={() => onSelectTab('memories')}
        aria-label="Memories"
      >
        <svg viewBox="0 0 24 24">
          <rect x="4" y="4" width="16" height="16" rx="2" />
          <circle cx="9" cy="9" r="1.5" />
          <path d="m20 15-5-5L5 20" />
        </svg>
        <span>Memories</span>
      </button>

      {/* 3. Letters */}
      <button
        type="button"
        className={`nav-btn ${activeTab === 'letters' ? 'active' : ''}`}
        onClick={() => onSelectTab('letters')}
        aria-label="Letters"
      >
        <svg viewBox="0 0 24 24">
          <rect x="3" y="5" width="18" height="14" rx="2" />
          <path d="m4 7 8 6 8-6" />
        </svg>
        <span>Letters</span>
      </button>

      {/* 4. Journey */}
      <button
        type="button"
        className={`nav-btn ${activeTab === 'timeline' ? 'active' : ''}`}
        onClick={() => onSelectTab('timeline')}
        aria-label="Journey"
      >
        <svg viewBox="0 0 24 24">
          <path d="M4 18c3-8 5 2 8-6s5 2 8-6" />
          <circle cx="4" cy="18" r="1" />
          <circle cx="20" cy="6" r="1" />
        </svg>
        <span>Journey</span>
      </button>

      {/* 5. Vault */}
      <button
        type="button"
        className={`nav-btn ${activeTab === 'vault' ? 'active' : ''}`}
        onClick={() => onSelectTab('vault')}
        aria-label="Vault"
      >
        <svg viewBox="0 0 24 24">
          <rect x="5" y="10" width="14" height="11" rx="2" />
          <path d="M8 10V7a4 4 0 0 1 8 0v3m-4 5v2" />
        </svg>
        <span>Vault</span>
      </button>
    </nav>
  )
}
