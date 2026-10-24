import React from 'react'
import { motion } from 'framer-motion'

export type TabType = 'stage' | 'world' | 'memories' | 'vault'

interface BottomNavProps {
  activeTab: TabType
  onSelectTab: (tab: TabType) => void
}

const TABS: { id: TabType; label: string; icon: React.ReactNode }[] = [
  {
    id: 'stage',
    label: 'Stage',
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d="m3 10 9-7 9 7M5 9v11h14V9M9 20v-6h6v6" />
      </svg>
    )
  },
  {
    id: 'world',
    label: 'World',
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="12" cy="12" r="10" />
        <path d="M12 2a14.5 14.5 0 0 0 0 20M12 2a14.5 14.5 0 0 1 0 20M2 12h20" />
      </svg>
    )
  },
  {
    id: 'memories',
    label: 'Memories',
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <rect x="3" y="3" width="18" height="18" rx="3" />
        <circle cx="8.5" cy="8.5" r="1.5" />
        <path d="m21 15-5-5L5 21" />
      </svg>
    )
  },
  {
    id: 'vault',
    label: 'Vault',
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
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
                className="absolute -bottom-1 w-1.5 h-1.5 rounded-full bg-[var(--app-accent)]"
                transition={{ type: 'spring', stiffness: 500, damping: 35 }}
              />
            )}
          </motion.button>
        )
      })}
    </nav>
  )
}
