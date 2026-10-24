import React, { useState, useEffect, useRef, useCallback } from 'react'
import { realtimeBridge } from '@/core/realtime'
import { useAuth } from '@/core/auth'
import confetti from 'canvas-confetti'

interface StageLiveTouchPadProps {
  isPulsing: boolean
  onQuickPulse: () => void
  disabled?: boolean
}

export const StageLiveTouchPad: React.FC<StageLiveTouchPadProps> = ({
  isPulsing,
  onQuickPulse,
  disabled = false
}) => {
  const { user, partner } = useAuth()
  const [isLocalTouching, setIsLocalTouching] = useState(false)
  const [isPartnerTouching, setIsPartnerTouching] = useState(false)
  const [showConnectedAura, setShowConnectedAura] = useState(false)

  const pressStartRef = useRef<number>(0)
  const partnerTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const heartbeatIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null)

  // Listen for Partner Live Touch Events via RealtimeBridge
  useEffect(() => {
    const unsubscribe = realtimeBridge.subscribe((event) => {
      if (event.senderId === user?.id) return

      if (event.type === 'LIVE_TOUCH_START') {
        setIsPartnerTouching(true)

        // Clear any existing fallback watchdog timer
        if (partnerTimeoutRef.current) clearTimeout(partnerTimeoutRef.current)
        // Reset after 7s watchdog if no release event is received
        partnerTimeoutRef.current = setTimeout(() => {
          setIsPartnerTouching(false)
        }, 7000)
      } else if (event.type === 'LIVE_TOUCH_END') {
        setIsPartnerTouching(false)
        if (partnerTimeoutRef.current) clearTimeout(partnerTimeoutRef.current)
      }
    })

    return () => {
      unsubscribe()
      if (partnerTimeoutRef.current) clearTimeout(partnerTimeoutRef.current)
      if (heartbeatIntervalRef.current) clearInterval(heartbeatIntervalRef.current)
    }
  }, [user?.id])

  // Synchronized Heartbeat Trigger (When BOTH are touching)
  const bothTouching = isLocalTouching && isPartnerTouching

  useEffect(() => {
    if (bothTouching) {
      setShowConnectedAura(true)

      // Start looping rhythmic heartbeat vibration
      const playHeartbeat = () => {
        try {
          if (typeof navigator !== 'undefined' && navigator.vibrate) {
            navigator.vibrate([60, 90, 60, 180])
          }
        } catch {}
      }

      playHeartbeat()
      heartbeatIntervalRef.current = setInterval(playHeartbeat, 1400)

      // Confetti burst of hearts
      confetti({
        particleCount: 25,
        spread: 60,
        origin: { y: 0.5 },
        shapes: ['circle'],
        colors: ['#e07a5f', '#f4a261', '#e76f51', '#f28482']
      })
    } else {
      setShowConnectedAura(false)
      if (heartbeatIntervalRef.current) {
        clearInterval(heartbeatIntervalRef.current)
        heartbeatIntervalRef.current = null
      }
    }

    return () => {
      if (heartbeatIntervalRef.current) {
        clearInterval(heartbeatIntervalRef.current)
        heartbeatIntervalRef.current = null
      }
    }
  }, [bothTouching])

  // Pointer Down (User starts touching)
  const handlePointerDown = useCallback(
    (e: React.PointerEvent) => {
      if (disabled || !user) return
      e.preventDefault()

      pressStartRef.current = Date.now()
      setIsLocalTouching(true)

      // Initial gentle haptic feedback
      try {
        if (typeof navigator !== 'undefined' && navigator.vibrate) {
          navigator.vibrate(35)
        }
      } catch {}

      // Broadcast LIVE_TOUCH_START
      realtimeBridge.broadcast({
        type: 'LIVE_TOUCH_START',
        senderId: user.id,
        senderNickname: user.nickname || 'Partner',
        timestamp: Date.now()
      })
    },
    [disabled, user]
  )

  // Pointer Up / Leave (User releases touch)
  const handlePointerUp = useCallback(
    (e: React.PointerEvent) => {
      if (!isLocalTouching || !user) return
      e.preventDefault()

      const duration = Date.now() - pressStartRef.current
      setIsLocalTouching(false)

      // Broadcast LIVE_TOUCH_END
      realtimeBridge.broadcast({
        type: 'LIVE_TOUCH_END',
        senderId: user.id,
        senderNickname: user.nickname || 'Partner',
        timestamp: Date.now()
      })

      // If duration < 280ms, treat as quick tap hello
      if (duration < 280) {
        onQuickPulse()
      }
    },
    [isLocalTouching, user, onQuickPulse]
  )

  const handlePointerCancel = useCallback(
    (e: React.PointerEvent) => {
      if (!isLocalTouching || !user) return
      e.preventDefault()
      setIsLocalTouching(false)

      realtimeBridge.broadcast({
        type: 'LIVE_TOUCH_END',
        senderId: user.id,
        senderNickname: user.nickname || 'Partner',
        timestamp: Date.now()
      })
    },
    [isLocalTouching, user]
  )

  return (
    <div className="relative flex flex-col items-center justify-center shrink-0 mx-2">
      {/* 1. Live Touching Floating Indicator */}
      {isPartnerTouching && !isLocalTouching && (
        <div className="absolute -top-7 whitespace-nowrap px-2.5 py-0.5 rounded-full bg-gradient-to-r from-[#e07a5f] to-[#e76f51] text-white text-[10px] font-semibold tracking-wide shadow-md animate-bounce pointer-events-none z-20">
          {partner?.nickname || 'Partner'} is touching... hold back! 💓
        </div>
      )}

      {bothTouching && (
        <div className="absolute -top-7 whitespace-nowrap px-3 py-0.5 rounded-full bg-gradient-to-r from-[#e76f51] via-[#e07a5f] to-[#f4a261] text-white text-[10px] font-bold tracking-wide shadow-lg animate-pulse pointer-events-none z-20">
          Holding hands across the distance 💓
        </div>
      )}

      {/* 2. Expanding Halo Ring when Partner is Touching or Both Connected */}
      <div
        className={`absolute inset-0 -m-3 rounded-full pointer-events-none transition-all duration-700 ${
          bothTouching
            ? 'scale-175 bg-gradient-to-r from-[#e07a5f]/40 to-[#f4a261]/40 blur-md animate-pulse'
            : isPartnerTouching
            ? 'scale-150 bg-[#e07a5f]/25 blur-sm animate-ping'
            : isLocalTouching
            ? 'scale-125 bg-[var(--app-accent)]/20 blur-sm'
            : isPulsing
            ? 'scale-150 bg-[#e07a5f]/30 blur-sm'
            : 'opacity-0'
        }`}
      />

      {/* 3. The Interactive Touch Pad Orb */}
      <button
        type="button"
        onPointerDown={handlePointerDown}
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerCancel}
        onPointerLeave={handlePointerCancel}
        disabled={disabled}
        className={`relative z-10 w-11 h-11 rounded-full flex items-center justify-center select-none touch-none transition-all duration-300 shadow-sm ${
          bothTouching
            ? 'bg-gradient-to-tr from-[#e76f51] to-[#f4a261] text-white scale-120 shadow-lg shadow-[#e07a5f]/50 ring-4 ring-[#e07a5f]/30'
            : isLocalTouching
            ? 'bg-[var(--app-accent)] text-white scale-110 shadow-md ring-2 ring-[var(--app-accent)]/40'
            : isPartnerTouching
            ? 'bg-white text-[#e07a5f] border-2 border-[#e07a5f] scale-110 animate-pulse shadow-md shadow-[#e07a5f]/30'
            : isPulsing
            ? 'bg-gradient-to-tr from-[#e07a5f] to-[#f4a261] text-white scale-125'
            : 'bg-[var(--chip-bg)] text-[var(--soft)] hover:text-[var(--ink)] hover:bg-[var(--line)] border border-[var(--line)]'
        }`}
        aria-label="Synchronized Live Touch Pad"
        title={partner ? 'Hold to touch partner · Tap to send hello' : 'Connect partner to use Live Touch'}
      >
        <span
          className={`text-base font-bold transition-transform duration-300 ${
            bothTouching ? 'scale-125 animate-bounce' : isLocalTouching ? 'scale-90' : ''
          }`}
        >
          {bothTouching ? '♥' : isPartnerTouching ? '💓' : isLocalTouching ? '✦' : '↔'}
        </span>
      </button>

      {/* Subtext Guide */}
      <span className="text-[9px] font-mono text-[var(--soft)] mt-1 tracking-tight text-center select-none">
        {bothTouching ? 'synced' : isPartnerTouching ? 'holding' : isLocalTouching ? 'holding...' : 'hold touch'}
      </span>
    </div>
  )
}
