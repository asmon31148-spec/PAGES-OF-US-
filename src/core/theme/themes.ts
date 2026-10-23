export interface ThemePalette {
  id: string
  name: string
  description: string
  bg: string
  bgGradient: string
  bgSecondary: string
  surface: string
  surfaceBorder: string
  textPrimary: string
  textSecondary: string
  textMuted: string
  accent: string
  accentGradient: string
  accentText: string // Guaranteed contrast color for buttons (#000000 or #ffffff)
  badgeBg: string
  isDark: boolean
}

// Sophisticated, eye-friendly editorial themes with true contrast & harmony in both light and dark
export const THEMES: Record<string, ThemePalette> = {
  // 1. Quiet Linen (Flagship Light Sanctuary — tactile warm paper & ink)
  paper: {
    id: 'paper',
    name: 'Quiet Linen',
    description: 'Warm tactile paper, soft sage, and classic editorial typography',
    bg: '#f4f1ea',
    bgGradient: '#f4f1ea',
    bgSecondary: '#ece8de',
    surface: '#ffffff',
    surfaceBorder: '#dedad0',
    textPrimary: '#1f231e',
    textSecondary: '#4a6354',
    textMuted: '#73776e',
    accent: '#425b4d',
    accentGradient: 'linear-gradient(135deg, #5b7968 0%, #3a5245 100%)',
    accentText: '#ffffff',
    badgeBg: '#e2ebe4',
    isDark: false
  },

  // 2. Rose Linen (Alternative Soft Light Sanctuary)
  rose: {
    id: 'rose',
    name: 'Rose Linen',
    description: 'Soft porcelain rose, warm blush paper, and tender terracota',
    bg: '#f7f2f0',
    bgGradient: '#f7f2f0',
    bgSecondary: '#eee4e1',
    surface: '#ffffff',
    surfaceBorder: '#e5d7d4',
    textPrimary: '#2c1e1e',
    textSecondary: '#8e5858',
    textMuted: '#8a7473',
    accent: '#a35555',
    accentGradient: 'linear-gradient(135deg, #b86767 0%, #8c4242 100%)',
    accentText: '#ffffff',
    badgeBg: '#f2dede',
    isDark: false
  },

  // 3. Midnight Obsidian (Flagship Dark Sanctuary — rich charcoal slate & starlight ivory)
  noir: {
    id: 'noir',
    name: 'Midnight Obsidian',
    description: 'Deep obsidian slate, elevated cards, and soft luminous ivory starlight',
    bg: '#0d0f13',
    bgGradient: 'linear-gradient(180deg, #111419 0%, #0d0f13 100%)',
    bgSecondary: '#141820',
    surface: '#1a1e28',
    surfaceBorder: '#272d3b',
    textPrimary: '#f5f4ef',
    textSecondary: '#b0b6aa',
    textMuted: '#747a6e',
    accent: '#6da584',
    accentGradient: 'linear-gradient(135deg, #7eb896 0%, #508565 100%)',
    accentText: '#0d0f13',
    badgeBg: 'rgba(109, 165, 132, 0.16)',
    isDark: true
  },

  // 4. Sunset Ember (Dark Rose & Charcoal)
  sunset: {
    id: 'sunset',
    name: 'Sunset Ember',
    description: 'Warm dark twilight, roasted rosewood, and glowing amber',
    bg: '#130d12',
    bgGradient: 'linear-gradient(180deg, #191118 0%, #130d12 100%)',
    bgSecondary: '#1c131a',
    surface: '#241822',
    surfaceBorder: '#3a2637',
    textPrimary: '#fcf0f6',
    textSecondary: '#e2b3ce',
    textMuted: '#967188',
    accent: '#e673a5',
    accentGradient: 'linear-gradient(135deg, #f08cb9 0%, #c95286 100%)',
    accentText: '#130d12',
    badgeBg: 'rgba(230, 115, 165, 0.16)',
    isDark: true
  },

  // 5. Midnight Velvet (Royal Indigo & Lavender Starlight)
  midnight: {
    id: 'midnight',
    name: 'Midnight Velvet',
    description: 'Deep royal indigo, cosmic plum, and starlight lavender',
    bg: '#0a0b16',
    bgGradient: 'linear-gradient(180deg, #101222 0%, #0a0b16 100%)',
    bgSecondary: '#12152a',
    surface: '#181c36',
    surfaceBorder: '#282f58',
    textPrimary: '#f5f4ff',
    textSecondary: '#bcc2ee',
    textMuted: '#7c84b4',
    accent: '#9d84f5',
    accentGradient: 'linear-gradient(135deg, #b09cf8 0%, #7d5ee6 100%)',
    accentText: '#0a0b16',
    badgeBg: 'rgba(157, 132, 245, 0.16)',
    isDark: true
  },

  // 6. Deep Abyss (Moody Marine Navy & Cyan)
  ocean: {
    id: 'ocean',
    name: 'Deep Abyss',
    description: 'Marine slate shadow, dark teal depth, and soft cyan starlight',
    bg: '#090e16',
    bgGradient: 'linear-gradient(180deg, #0e1622 0%, #090e16 100%)',
    bgSecondary: '#101b2a',
    surface: '#162438',
    surfaceBorder: '#223854',
    textPrimary: '#f0f7ff',
    textSecondary: '#a6cbe8',
    textMuted: '#68849f',
    accent: '#38bdf8',
    accentGradient: 'linear-gradient(135deg, #5ecaff 0%, #0ea5e9 100%)',
    accentText: '#090e16',
    badgeBg: 'rgba(56, 189, 248, 0.16)',
    isDark: true
  },

  // 7. Forest Moss (Botanical Evergreen & Sage)
  forest: {
    id: 'forest',
    name: 'Forest Moss',
    description: 'Deep evergreen night, dark pine shadow, and sage starlight',
    bg: '#090f0c',
    bgGradient: 'linear-gradient(180deg, #0f1814 0%, #090f0c 100%)',
    bgSecondary: '#111e18',
    surface: '#172820',
    surfaceBorder: '#243e32',
    textPrimary: '#f0fdf4',
    textSecondary: '#a9d6bc',
    textMuted: '#698e79',
    accent: '#4ade80',
    accentGradient: 'linear-gradient(135deg, #6ee79d 0%, #22c55e 100%)',
    accentText: '#090f0c',
    badgeBg: 'rgba(74, 222, 128, 0.16)',
    isDark: true
  }
}
