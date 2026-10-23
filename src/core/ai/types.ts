export type RelationshipStage =
  | 'new' // Just started / Sweet sparks
  | 'deep' // Deeply in love / Inseparable
  | 'long_distance' // Miles apart / Missing each other
  | 'years' // Cozy familiar / Long term
  | 'soft_reconnect' // Reconnecting / Gentle tenderness

export type MoodVibe =
  | 'vulnerable' // Intimate & raw 🕯️
  | 'playful' // Silly & lighthearted ☀️
  | 'nostalgic' // Memory lane & firsts 🌙
  | 'philosophical' // Big thoughts & worldview 🌌
  | 'comforting' // Soft, safe & reassuring 🌧️

export interface PromptGenerationRequest {
  userNickname: string
  partnerNickname: string
  relationshipStage: RelationshipStage
  mood: MoodVibe
  customTopic?: string
}

export interface GeneratedPrompt {
  id: string
  question: string
  vibeTag: string
  category: MoodVibe
}
