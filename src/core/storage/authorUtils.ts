import { UserProfile } from '../auth/types'

/**
 * Format author string to preserve both nickname and user ID in Supabase 'author' column
 * Format: "Nickname:::userId"
 */
export const formatAuthor = (user: UserProfile | null, fallbackNickname = 'Partner'): string => {
  if (!user) return fallbackNickname
  return `${user.nickname || fallbackNickname}:::${user.id}`
}

/**
 * Parse raw author string from Supabase
 */
export const parseAuthor = (
  rawAuthor?: string | null
): { name: string; id?: string } => {
  if (!rawAuthor) return { name: 'Partner', id: undefined }
  if (rawAuthor.includes(':::')) {
    const [name, id] = rawAuthor.split(':::')
    return { name: name || 'Partner', id: id || undefined }
  }
  return { name: rawAuthor, id: undefined }
}

/**
 * Check if the author is the current authenticated user
 */
export const getAuthorAttribution = (
  rawAuthor: string | null | undefined,
  currentUser: UserProfile | null,
  partnerNickname?: string
): { authorName: string; isMine: boolean; label: string } => {
  const parsed = parseAuthor(rawAuthor)
  
  let isMine = false
  if (currentUser?.id && parsed.id) {
    isMine = parsed.id === currentUser.id
  } else if (currentUser?.nickname && parsed.name) {
    isMine = parsed.name.toLowerCase() === currentUser.nickname.toLowerCase()
  }

  const authorName = isMine
    ? (currentUser?.nickname || 'You')
    : (parsed.name === 'You' ? (partnerNickname || 'Partner') : (parsed.name || partnerNickname || 'Partner'))

  return {
    authorName,
    isMine,
    label: isMine ? 'You' : authorName
  }
}

/**
 * Generate a collision-free ID for Supabase rows
 */
export const generateEntityId = (prefix: string): string => {
  return `${prefix}_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`
}

/**
 * Format a date string (YYYY-MM-DD or ISO 8601) in local time without UTC off-by-one day rollback
 */
export const formatLocalDate = (
  dateStr?: string | null,
  options?: Intl.DateTimeFormatOptions
): string => {
  if (!dateStr) return ''
  try {
    // If dateStr is "YYYY-MM-DD", avoid Date(string) UTC midnight conversion
    if (/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) {
      const [year, month, day] = dateStr.split('-').map(Number)
      const localDate = new Date(year, month - 1, day)
      return localDate.toLocaleDateString('en-US', options || { day: 'numeric', month: 'short' })
    }

    const d = new Date(dateStr)
    if (isNaN(d.getTime())) return dateStr
    return d.toLocaleDateString('en-US', options || { day: 'numeric', month: 'short' })
  } catch {
    return dateStr
  }
}

/**
 * Encode seal and category cleanly into envelope_color column
 */
export const encodeEnvelopeMetadata = (
  seal: string,
  category: string
): string => {
  return JSON.stringify({ seal, category })
}

/**
 * Decode seal and category from envelope_color column
 */
export const decodeEnvelopeMetadata = (
  rawColor?: string | null
): { seal: 'green' | 'terra' | 'slate' | 'rose'; category: string } => {
  if (!rawColor) {
    return { seal: 'green', category: 'For a quiet day' }
  }

  if (rawColor.startsWith('{')) {
    try {
      const parsed = JSON.parse(rawColor)
      const validSeals = ['green', 'terra', 'slate', 'rose']
      const seal = validSeals.includes(parsed.seal) ? parsed.seal : 'green'
      const category = parsed.category || 'For a quiet day'
      return { seal, category }
    } catch {}
  }

  // Fallback for legacy single color/seal string
  const validSeals: Record<string, 'green' | 'terra' | 'slate' | 'rose'> = {
    '#334155': 'slate',
    slate: 'slate',
    green: 'green',
    terra: 'terra',
    rose: 'rose'
  }

  return {
    seal: validSeals[rawColor] || 'green',
    category: 'For a quiet day'
  }
}
