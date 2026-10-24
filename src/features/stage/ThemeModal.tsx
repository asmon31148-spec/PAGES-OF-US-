import React, { useState } from 'react'
import { useTheme } from '@/core/theme'
import { Check, X, Palette, Sparkles, Sun, Moon } from 'lucide-react'

interface ThemeModalProps {
  isOpen: boolean
  onClose: () => void
}

export const ThemeModal: React.FC<ThemeModalProps> = ({ isOpen, onClose }) => {
  const { theme, themeId, setThemeId, availableThemes, isDark, toggleDarkLight } = useTheme()
  const [activeTab, setActiveTab] = useState<'light' | 'dark'>(() => (isDark ? 'dark' : 'light'))

  if (!isOpen) return null

  const filteredThemes = availableThemes.filter((t) => (activeTab === 'dark' ? t.isDark : !t.isDark))

  return (
    <div
      className="fixed inset-0 z-[1000] flex flex-col overflow-hidden"
      style={{
        backgroundColor: theme.bg,
        color: theme.textPrimary
      }}
    >
      {/* Top Header Bar */}
      <div className="pt-safe px-4 py-3 flex items-center justify-between border-b border-[var(--line)] bg-[var(--white)] shrink-0">
        <button
          type="button"
          onClick={onClose}
          className="p-1.5 -ml-1.5 rounded-full cursor-pointer hover:bg-[var(--paper)] transition flex items-center gap-1.5 text-xs font-medium text-[var(--ink)]"
        >
          <X className="w-4 h-4" />
          <span>Close</span>
        </button>
        <div className="text-center">
          <h3 className="text-sm font-semibold tracking-tight">Appearance & Themes</h3>
        </div>
        <div className="w-12" />
      </div>

      <div className="flex-1 overflow-y-auto px-4 py-6 max-w-md mx-auto w-full space-y-5">
          <div className="flex items-center gap-2.5">
            <div
              className="p-2 rounded-xl"
              style={{ backgroundColor: theme.badgeBg, color: theme.accent }}
            >
              <Palette className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-base font-bold">Theme & Atmosphere</h2>
              <p className="text-xs" style={{ color: theme.textMuted }}>
                Choose your light and dark visual style
              </p>
            </div>
          </div>

          {/* Quick Segmented Light / Dark Switcher */}
          <div
            className="grid grid-cols-2 p-1 rounded-2xl border"
            style={{
              backgroundColor: theme.surface,
              borderColor: theme.surfaceBorder
            }}
          >
            <button
              type="button"
              onClick={() => {
                setActiveTab('light')
                if (isDark) setThemeId('paper')
              }}
              className="py-2 px-3 rounded-xl text-xs font-semibold flex items-center justify-center gap-1.5 transition-all cursor-pointer"
              style={{
                backgroundColor: activeTab === 'light' ? theme.accent : 'transparent',
                color: activeTab === 'light' ? theme.accentText : theme.textMuted
              }}
            >
              <Sun className="w-3.5 h-3.5" />
              <span>Light Mode</span>
            </button>

            <button
              type="button"
              onClick={() => {
                setActiveTab('dark')
                if (!isDark) setThemeId('noir')
              }}
              className="py-2 px-3 rounded-xl text-xs font-semibold flex items-center justify-center gap-1.5 transition-all cursor-pointer"
              style={{
                backgroundColor: activeTab === 'dark' ? theme.accent : 'transparent',
                color: activeTab === 'dark' ? theme.accentText : theme.textMuted
              }}
            >
              <Moon className="w-3.5 h-3.5" />
              <span>Dark Mode</span>
            </button>
          </div>

          {/* Available Themes in Active Mode */}
          <div className="space-y-2 pt-1">
            {filteredThemes.map((t) => {
              const isSelected = t.id === themeId

              return (
                <button
                  key={t.id}
                  onClick={() => {
                    setThemeId(t.id)
                    onClose()
                  }}
                  className="w-full p-3 rounded-2xl border text-left transition-all flex items-center justify-between active:scale-[0.98] group cursor-pointer"
                  style={{
                    backgroundColor: isSelected ? theme.badgeBg : theme.surface,
                    borderColor: isSelected ? theme.accent : theme.surfaceBorder
                  }}
                >
                  <div className="flex items-center gap-3">
                    {/* Atmospheric Preview Badge */}
                    <div
                      className="w-10 h-10 rounded-2xl border shadow-md flex items-center justify-center relative overflow-hidden shrink-0"
                      style={{
                        background: t.accentGradient,
                        borderColor: t.surfaceBorder
                      }}
                    >
                      <div
                        className="w-3.5 h-3.5 rounded-full shadow-sm"
                        style={{ backgroundColor: t.bg }}
                      />
                    </div>

                    <div>
                      <h4 className="text-xs font-bold flex items-center gap-1.5">
                        <span>{t.name}</span>
                        {isSelected && <Sparkles className="w-3 h-3" style={{ color: theme.accent }} />}
                      </h4>
                      <p className="text-[10px] mt-0.5 line-clamp-1" style={{ color: theme.textMuted }}>
                        {t.description}
                      </p>
                    </div>
                  </div>

                  {isSelected && (
                    <div
                      className="w-6 h-6 rounded-full flex items-center justify-center shadow-sm shrink-0"
                      style={{ backgroundColor: theme.accent, color: theme.accentText }}
                    >
                      <Check className="w-3.5 h-3.5 stroke-[3]" />
                    </div>
                  )}
                </button>
              )
            })}
          </div>
      </div>
    </div>
  )
}
