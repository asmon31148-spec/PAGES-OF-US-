export interface WeatherInfo {
  temperature: number
  weatherCode: number
  isDay: boolean
  condition: 'clear' | 'partly_cloudy' | 'rain' | 'drizzle' | 'snow' | 'thunderstorm' | 'fog'
  emoji: string
  label: string
}

const cache = new Map<string, { data: WeatherInfo; timestamp: number }>()
const CACHE_TTL = 5 * 60 * 1000 // 5 minutes

export async function fetchLiveWeather(lat: number, lng: number): Promise<WeatherInfo | null> {
  const cacheKey = `${lat.toFixed(2)},${lng.toFixed(2)}`
  const cached = cache.get(cacheKey)
  if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
    return cached.data
  }

  try {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lng}&current=temperature_2m,relative_humidity_2m,is_day,precipitation,weather_code`
    const res = await fetch(url)
    if (!res.ok) return null
    const json = await res.json()
    const current = json.current
    if (!current) return null

    const code = current.weather_code ?? 0
    const isDay = current.is_day === 1
    const temp = Math.round(current.temperature_2m ?? 20)

    let condition: WeatherInfo['condition'] = 'clear'
    let emoji = isDay ? '☀️' : '🌙'
    let label = isDay ? 'Sunny' : 'Clear Sky'

    if (code === 0) {
      condition = 'clear'
      emoji = isDay ? '☀️' : '🌙'
      label = isDay ? 'Clear Sky' : 'Clear Night'
    } else if (code >= 1 && code <= 3) {
      condition = 'partly_cloudy'
      emoji = isDay ? '⛅' : '☁️'
      label = code === 3 ? 'Overcast' : 'Partly Cloudy'
    } else if (code === 45 || code === 48) {
      condition = 'fog'
      emoji = '🌫️'
      label = 'Misty Fog'
    } else if (code >= 51 && code <= 55) {
      condition = 'drizzle'
      emoji = '🌧️'
      label = 'Soft Drizzle'
    } else if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
      condition = 'rain'
      emoji = '🌧️'
      label = 'Rain'
    } else if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) {
      condition = 'snow'
      emoji = '❄️'
      label = 'Snow'
    } else if (code >= 95) {
      condition = 'thunderstorm'
      emoji = '⛈️'
      label = 'Thunderstorm'
    }

    const info: WeatherInfo = {
      temperature: temp,
      weatherCode: code,
      isDay,
      condition,
      emoji,
      label
    }

    cache.set(cacheKey, { data: info, timestamp: Date.now() })
    return info
  } catch (err) {
    console.warn('[WeatherService] Error fetching weather:', err)
    return null
  }
}
