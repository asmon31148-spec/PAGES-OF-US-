import React, { createContext, useContext, useEffect, useState } from 'react'
import { THEMES, ThemePalette } from './themes'

interface ThemeContextType {
  theme: ThemePalette
  themeId: string
  setThemeId: (id: string) => void
  availableThemes: ThemePalette[]
  isDark: boolean
  toggleDarkLight: () => void
}

const STORAGE_KEY = 'pages_of_us_theme'

const ThemeContext = createContext<ThemeContextType | null>(null)

export const ThemeProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [themeId, setThemeIdState] = useState<string>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY)
      if (saved && THEMES[saved]) return saved
    } catch {}
    return 'paper' // Default to authentic Quiet Linen editorial aesthetic
  })

  const currentTheme = THEMES[themeId] || THEMES.paper
  const isDark = Boolean(currentTheme.isDark)

  const setThemeId = (id: string) => {
    if (THEMES[id]) {
      setThemeIdState(id)
      try {
        localStorage.setItem(STORAGE_KEY, id)
      } catch {}
    }
  }

  // 1-Tap Toggle between Flagship Light (Quiet Linen) and Flagship Dark (Midnight Obsidian)
  const toggleDarkLight = () => {
    if (isDark) {
      setThemeId('paper')
    } else {
      setThemeId('noir')
    }
  }

  // Inject CSS variables to document root for smooth runtime styling
  useEffect(() => {
    const root = document.documentElement
    root.style.setProperty('--app-bg', currentTheme.bg)
    root.style.setProperty('--app-bg-gradient', currentTheme.bgGradient)
    root.style.setProperty('--app-bg-secondary', currentTheme.bgSecondary)
    root.style.setProperty('--app-surface', currentTheme.surface)
    root.style.setProperty('--app-surface-border', currentTheme.surfaceBorder)
    root.style.setProperty('--app-text-primary', currentTheme.textPrimary)
    root.style.setProperty('--app-text-secondary', currentTheme.textSecondary)
    root.style.setProperty('--app-text-muted', currentTheme.textMuted)
    root.style.setProperty('--app-accent', currentTheme.accent)
    root.style.setProperty('--app-accent-gradient', currentTheme.accentGradient)
    root.style.setProperty('--app-accent-text', currentTheme.accentText)

    // Bridge all legacy/core CSS variables so every component automatically adapts
    root.style.setProperty('--ink', currentTheme.textPrimary)
    root.style.setProperty('--white', currentTheme.surface)
    root.style.setProperty('--paper', currentTheme.bgSecondary)
    root.style.setProperty('--line', currentTheme.surfaceBorder)
    root.style.setProperty('--soft', currentTheme.textMuted)

    if (currentTheme.isDark) {
      root.classList.add('dark')
      root.setAttribute('data-theme', 'dark')
    } else {
      root.classList.remove('dark')
      root.setAttribute('data-theme', 'light')
    }

    document.body.style.background = currentTheme.bgGradient
    document.body.style.backgroundColor = currentTheme.bg
    document.body.style.color = currentTheme.textPrimary

    // Update meta theme-color for Android status bar
    const metaThemeColor = document.querySelector('meta[name="theme-color"]')
    if (metaThemeColor) {
      metaThemeColor.setAttribute('content', currentTheme.bg)
    }
  }, [currentTheme])

  return (
    <ThemeContext.Provider
      value={{
        theme: currentTheme,
        themeId,
        setThemeId,
        availableThemes: Object.values(THEMES),
        isDark,
        toggleDarkLight
      }}
    >
      {children}
    </ThemeContext.Provider>
  )
}

export const useTheme = () => {
  const context = useContext(ThemeContext)
  if (!context) {
    throw new Error('useTheme must be used within a ThemeProvider')
  }
  return context
}
