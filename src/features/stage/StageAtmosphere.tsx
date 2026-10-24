import React, { useState, useEffect } from 'react'
import { useAuth } from '@/core/auth'
import { getSupabaseClient } from '@/core/storage/supabase'
import { fetchLiveWeather, WeatherInfo } from '@/core/services/weatherService'
import { CloudRain, Sun, Moon, Cloud, Wind, Sparkles } from 'lucide-react'

export const StageAtmosphere: React.FC = () => {
  const { user, space, partner } = useAuth()
  const [weather, setWeather] = useState<WeatherInfo | null>(null)
  const [partnerCity, setPartnerCity] = useState<string>('')
  const [partnerLocalTime, setPartnerLocalTime] = useState<string>('')

  const spaceId = space?.id || 'default_space'
  const locationDocId = `location_${spaceId}`

  useEffect(() => {
    if (!partner?.id) return
    const supabase = getSupabaseClient()

    const loadPartnerAtmosphere = async () => {
      try {
        const { data } = await supabase
          .from('app_content')
          .select('content')
          .eq('id', locationDocId)
          .maybeSingle()

        const locMap = data?.content || {}
        const pLoc = locMap[partner.id]

        if (pLoc && pLoc.lat && pLoc.lng) {
          if (pLoc.city || pLoc.placeName) {
            setPartnerCity(pLoc.city || pLoc.placeName.split(',')[0])
          }

          const w = await fetchLiveWeather(pLoc.lat, pLoc.lng)
          setWeather(w)
        }
      } catch (err) {
        console.warn('Atmosphere load error:', err)
      }
    }

    loadPartnerAtmosphere()

    // 1-minute interval for local time calculation & weather refresh
    const timer = setInterval(() => {
      loadPartnerAtmosphere()
    }, 60000)

    return () => clearInterval(timer)
  }, [partner?.id, spaceId, locationDocId])

  if (!partner || !weather) return null

  const isRaining = weather.condition === 'rain' || weather.condition === 'drizzle'
  const isNight = !weather.isDay

  return (
    <>
      {/* 1. Subtle Atmospheric Status Pill on Stage */}
      <div className="w-full flex items-center justify-center -mt-1 mb-3">
        <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[var(--white)]/70 backdrop-blur-md border border-[var(--line)] shadow-2xs text-[11px] text-[var(--soft)] font-medium transition hover:opacity-100">
          <span className="text-xs">{weather.emoji}</span>
          <span className="font-semibold text-[var(--ink)]">
            {partnerCity || partner.nickname}&rsquo;s Sky:
          </span>
          <span>{weather.label} &bull; {weather.temperature}°C</span>
          {isRaining && (
            <span className="text-[10px] text-sky-600 dark:text-sky-400 font-semibold flex items-center gap-0.5">
              <CloudRain className="w-3 h-3 animate-bounce" /> Raining
            </span>
          )}
        </div>
      </div>

      {/* 2. Soft Falling Rain Overlay (if it's raining where partner is) */}
      {isRaining && (
        <div className="fixed inset-0 pointer-events-none z-0 overflow-hidden opacity-30">
          <div className="rain-canvas w-full h-full" />
          <style>{`
            .rain-canvas {
              background: linear-gradient(to bottom, rgba(255,255,255,0) 0%, rgba(186,215,242,0.15) 100%);
              background-size: 20px 20px;
            }
          `}</style>
        </div>
      )}

      {/* 3. Celestial Starlight Glow (if night at partner's location) */}
      {isNight && (
        <div className="fixed -top-24 left-1/2 -translate-x-1/2 w-96 h-48 bg-indigo-900/10 dark:bg-indigo-500/10 rounded-full blur-3xl pointer-events-none z-0" />
      )}
    </>
  )
}
