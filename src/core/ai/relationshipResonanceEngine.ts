import { UserProfile, SharedSpace } from '../auth/types'
import { realtimeBridge } from '../realtime'
import { getFirebaseDb } from '../storage/firebase'
import { collection, addDoc } from 'firebase/firestore'

export type RelationshipStatus = 'romantic' | 'best_friends' | 'long_distance' | 'dating'

export type InteractionType =
  | 'LETTER_SENT'
  | 'THOUGHT_POSTED'
  | 'MEMORY_CREATED'
  | 'MILESTONE_ADDED'
  | 'PINNED_NOTE_POSTED'
  | 'VAULT_PHOTO_SAVED'
  | 'PRESENCE_PULSED'
  | 'MUSIC_PLAYED'

export interface VibeConfig {
  label: string
  emojis: string[]
  cadence: 'high' | 'balanced' | 'gentle'
  tone: 'intimate' | 'playful' | 'comforting'
}

export const RELATIONSHIP_VIBES: Record<RelationshipStatus, VibeConfig> = {
  romantic: {
    label: 'In a Relationship',
    emojis: ['💕', '💌', '✨', '🤍', '💍', '🥰'],
    cadence: 'high',
    tone: 'intimate'
  },
  best_friends: {
    label: 'Best Friends',
    emojis: ['🌿', '☕', '⚡', '✌️', '💫', '🌻'],
    cadence: 'balanced',
    tone: 'playful'
  },
  long_distance: {
    label: 'Long Distance',
    emojis: ['✈️', '🌙', '⏳', '💭', '🗺️', '🤍'],
    cadence: 'gentle',
    tone: 'comforting'
  },
  dating: {
    label: 'Newly Dating',
    emojis: ['🦋', '🌸', '🥂', '💌', '✨', '🎈'],
    cadence: 'balanced',
    tone: 'playful'
  }
}

export interface GeneratedNotification {
  title: string
  body: string
  emoji: string
  type: InteractionType
  createdAt: string
}

// 1. Generate Contextual Couple Notification based on Relationship Status & Interaction
export const generateContextualNotification = (
  senderNickname: string,
  type: InteractionType,
  status: RelationshipStatus = 'romantic',
  details?: { thought?: string; distanceKm?: number; noteTitle?: string }
): GeneratedNotification => {
  const vibe = RELATIONSHIP_VIBES[status] || RELATIONSHIP_VIBES.romantic
  const randomEmoji = vibe.emojis[Math.floor(Math.random() * vibe.emojis.length)]

  switch (type) {
    case 'LETTER_SENT':
      if (status === 'best_friends') {
        return {
          title: `${senderNickname} dropped a note for you ${randomEmoji}`,
          body: details?.noteTitle ? `"${details.noteTitle}"` : "Check your Letterbox when you get a second!",
          emoji: randomEmoji,
          type,
          createdAt: new Date().toISOString()
        }
      }
      return {
        title: `${senderNickname} left a handwritten letter ${randomEmoji}`,
        body: details?.noteTitle ? `"${details.noteTitle}"` : 'Something tender is waiting for you in your sanctuary.',
        emoji: randomEmoji,
        type,
        createdAt: new Date().toISOString()
      }

    case 'THOUGHT_POSTED':
      if (status === 'best_friends') {
        return {
          title: `${senderNickname} updated their vibe ${randomEmoji}`,
          body: details?.thought ? `"${details.thought}"` : 'Check out what they are up to!',
          emoji: randomEmoji,
          type,
          createdAt: new Date().toISOString()
        }
      }
      return {
        title: `${senderNickname} is thinking of you ${randomEmoji}`,
        body: details?.thought ? `"${details.thought}"` : 'A quiet thought was left on your stage.',
        emoji: randomEmoji,
        type,
        createdAt: new Date().toISOString()
      }

    case 'MEMORY_CREATED':
      return {
        title: `New shared memory tucked away ${randomEmoji}`,
        body: details?.noteTitle ? `${senderNickname} added "${details.noteTitle}" to your vault.` : `${senderNickname} added a moment to your vault.`,
        emoji: randomEmoji,
        type,
        createdAt: new Date().toISOString()
      }

    case 'MILESTONE_ADDED':
      return {
        title: `New chapter in your journey ${randomEmoji}`,
        body: details?.noteTitle ? `${senderNickname} added "${details.noteTitle}" to your timeline.` : `${senderNickname} added a new milestone to your journey.`,
        emoji: randomEmoji,
        type,
        createdAt: new Date().toISOString()
      }

    case 'PINNED_NOTE_POSTED':
      return {
        title: `${senderNickname} pinned a note for today ${randomEmoji}`,
        body: details?.thought ? `"${details.thought}"` : `${senderNickname} left a new pinned note on your stage.`,
        emoji: randomEmoji,
        type,
        createdAt: new Date().toISOString()
      }

    case 'VAULT_PHOTO_SAVED':
      return {
        title: `Vault surprise locked in ${randomEmoji}`,
        body: `${senderNickname} tucked a private snapshot into your Vault.`,
        emoji: randomEmoji,
        type,
        createdAt: new Date().toISOString()
      }

    case 'PRESENCE_PULSED':
      return {
        title: `${senderNickname} touched your tether ${randomEmoji}`,
        body: details?.distanceKm
          ? `Holding close across ${Math.round(details.distanceKm)} km.`
          : 'A soft pulse was sent your way.',
        emoji: randomEmoji,
        type,
        createdAt: new Date().toISOString()
      }

    case 'MUSIC_PLAYED':
      return {
        title: `Music playing in your sanctuary ${randomEmoji}`,
        body: `${senderNickname} tuned into your shared audio frequency.`,
        emoji: randomEmoji,
        type,
        createdAt: new Date().toISOString()
      }
  }
}

// 2. Dispatch Interaction to Partner
export const dispatchPartnerInteraction = async (
  sender: UserProfile,
  space: SharedSpace | null,
  type: InteractionType,
  details?: { thought?: string; distanceKm?: number; noteTitle?: string }
): Promise<GeneratedNotification> => {
  const notif = generateContextualNotification(
    sender.nickname,
    type,
    'romantic', // Default to romantic, configurable in space settings
    details
  )

  // 1. Broadcast to partner via Realtime bridge
  try {
    await realtimeBridge.broadcast({
      type: 'NOTIFICATION_TRIGGER',
      senderId: sender.id,
      senderNickname: sender.nickname,
      timestamp: Date.now(),
      data: notif
    })
  } catch {}

  // 2. Save notification to Firestore if connected
  const db = getFirebaseDb()
  if (db && space?.id) {
    try {
      await addDoc(collection(db, 'spaces', space.id, 'notifications'), {
        ...notif,
        senderId: sender.id,
        senderNickname: sender.nickname,
        timestamp: Date.now()
      })
    } catch {}
  }

  // Native notification will be triggered on the RECIPIENT's device upon receiving the event

  return notif
}
