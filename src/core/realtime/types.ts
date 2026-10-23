export type RealtimeEventType =
  | 'PULSE'
  | 'MEMORY_ADDED'
  | 'LETTER_SEALED'
  | 'MILESTONE_ADDED'
  | 'PINNED_NOTE_CHANGED'
  | 'CHECKIN_ANSWERED'
  | 'CARE_CHECK_UPDATED'
  | 'AUDIO_SYNC'
  | 'LOCATION_UPDATE'
  | 'PROFILE_UPDATE'
  | 'NOTIFICATION_TRIGGER'
  | 'MOOD_UPDATE'
  | 'BLIND_PROMPT_UPDATE'
  | 'VAULT_UPDATE'

export interface RealtimeEventPayload {
  type: RealtimeEventType
  senderId: string
  senderNickname: string
  timestamp: number
  data?: any
}
