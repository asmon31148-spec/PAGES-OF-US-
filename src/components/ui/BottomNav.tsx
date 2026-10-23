import React from 'react'
import { motion } from 'framer-motion'

export type TabType = 'stage' | 'memories' | 'letters' | 'timeline' | 'vault'

interface BottomNavProps {
  activeTab: TabType
  onSelectTab: (tab: TabType) => void
}

const TABS: { id: TabType; label: string; icon: React.ReactNode }[] = [
  {
    id: 'stage',
    label: 'Stage',
    icon: (
      <svg viewBox="0 0 24 24">
        <path d="m3 10 9-7 9 7M5 9v11h14V9M9 20v-6h6v6" />
      </svg>
    )
  },
  {
    id: 'memories',
    label: 'Memories',
    icon: (
      <svg viewBox="0 0 24 24">
        <rect x="4" y="4" width="16" height="16" rx="2" />
        <circle cx="9" cy="9" r="1.5" />
        <path d="m20 15-5-5L5 20" />
      </svg>
    )
  },
  {
    id: 'letters',
    label: 'Letters',
    icon: (
      <svg viewBox="0 0 24 24">
        <rect x="3" y="5" width="18" height="14" rx="2" />
        <path d="m4 7 8 6 8-6" />
      </svg>
    )
  },
  {
    id: 'timeline',
    label: 'Journey',
    icon: (
      <svg viewBox="0 0 24 24">
        <path d="M4 18c3-8 5 2 8-6s5 2 8-6" />
        <circle cx="4" cy="18" r="1" />
        <circle cx="20" cy="6" r="1" />
      </svg>
    )
  },
  {
    id: 'vault',
    label: 'Vault',
    icon: (
      <svg viewBox="0 0 24 24">
        <rect x="5" y="10" width="14" height="11" rx="2" />
        <path d="M8 10V7a4 4 0 0 1 8 0v3m-4 5v2" />
      </svg>
    )
  }
]

export const BottomNav: React.FC<BottomNavProps> = ({ activeTab, onSelectTab }) => {
  return (
    <nav className="bottom-nav" aria-label="App Navigation">
      {TABS.map((tab) => {
        const isActive = activeTab === tab.id
        return (
          <motion.button
            key={tab.id}
            type="button"
            className={`nav-btn relative ${isActive ? 'active' : ''}`}
            onClick={() => onSelectTab(tab.id)}
            aria-label={tab.label}
            whileTap={{ scale: 0.86 }}
            transition={{ type: 'spring', stiffness: 500, damping: 30 }}
          >
            {tab.icon}
            <span>{tab.label}</span>
            {isActive && (
              <motion.div
                layoutId="activeNavDot"
                className="absolute -bottom-1 w-1 h-1 rounded-full bg-[var(--app-accent)]"
                transition={{ type: 'spring', stiffness: 500, damping: 35 }}
              />
            )}
          </motion.button>
        )
      })}
    </nav>
  )
}
