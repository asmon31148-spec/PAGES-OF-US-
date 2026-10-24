import { getSupabaseClient } from '../storage/supabase'
import { RealtimeEventPayload } from './types'
import { RealtimeChannel } from '@supabase/supabase-js'

type EventCallback = (event: RealtimeEventPayload) => void

class SpaceRealtimeBridge {
  private currentChannel: RealtimeChannel | null = null
  private currentSpaceId: string | null = null
  private listeners: Set<EventCallback> = new Set()

  public connect(spaceId: string, onEventReceived?: EventCallback) {
    if (this.currentSpaceId === spaceId && this.currentChannel) {
      if (onEventReceived) this.listeners.add(onEventReceived)
      return
    }

    this.disconnect()
    this.currentSpaceId = spaceId
    if (onEventReceived) this.listeners.add(onEventReceived)

    const supabase = getSupabaseClient()
    const channelName = `realtime:${spaceId}`

    this.currentChannel = supabase.channel(channelName, {
      config: {
        broadcast: { self: false } // Only receive events from the other partner
      }
    })

    this.currentChannel
      .on('broadcast', { event: 'space_signal' }, (payload: any) => {
        if (payload?.payload) {
          const event = payload.payload as RealtimeEventPayload

          // Trigger native vibration if available for tactile connection
          if (event.type === 'PULSE') {
            try {
              if (navigator.vibrate) {
                navigator.vibrate([120, 80, 180])
              }
            } catch {}
          } else if (event.type === 'LIVE_TOUCH_START') {
            try {
              if (navigator.vibrate) {
                navigator.vibrate([40, 50, 40])
              }
            } catch {}
          }

          this.listeners.forEach((listener) => listener(event))
        }
      })
      .subscribe((status) => {
        console.log(`[RealtimeBridge] Channel status for ${spaceId}:`, status)
      })
  }

  public subscribe(callback: EventCallback): () => void {
    this.listeners.add(callback)
    return () => this.listeners.delete(callback)
  }

  public async broadcast(payload: RealtimeEventPayload) {
    if (!this.currentChannel) {
      console.warn('[RealtimeBridge] Cannot broadcast, channel not connected')
      return
    }

    try {
      await this.currentChannel.send({
        type: 'broadcast',
        event: 'space_signal',
        payload
      })
    } catch (err) {
      console.warn('[RealtimeBridge] Error broadcasting event:', err)
    }
  }

  public disconnect() {
    if (this.currentChannel) {
      const supabase = getSupabaseClient()
      supabase.removeChannel(this.currentChannel)
      this.currentChannel = null
    }
    this.currentSpaceId = null
    this.listeners.clear()
  }
}

export const realtimeBridge = new SpaceRealtimeBridge()
