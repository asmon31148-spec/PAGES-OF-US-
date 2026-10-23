export interface UserProfile {
  id: string
  email?: string
  nickname: string
  avatarUrl?: string
  bio?: string // Personal bio / favorite quote
  presenceStatus?: string // Instagram-style status note (e.g. "Thinking of you 🌿")
  spaceId?: string
  lastActiveAt?: string
  createdAt?: string
}

export interface SharedSpace {
  id: string
  spaceName: string
  pairCode: string
  creatorId: string
  partnerId?: string
  members: Record<string, UserProfile>
  createdAt: string
  themeId?: string
}

export interface AuthSession {
  currentUser: UserProfile | null
  currentSpace: SharedSpace | null
  isPaired: boolean
  isAuthenticated: boolean
}
