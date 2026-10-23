import React, { useState, useEffect, useRef, useCallback } from 'react'
import { useAuth } from '@/core/auth'
import { useToast } from '@/core/toast'
import { getSupabaseClient } from '@/core/storage/supabase'
import { getFirebaseDb } from '@/core/storage/firebase'
import { doc, setDoc, getDoc, collection, onSnapshot } from 'firebase/firestore'
import { realtimeBridge } from '@/core/realtime'
import L from 'leaflet'
import {
  Navigation,
  MapPin,
  Battery,
  BatteryCharging,
  RefreshCw,
  Plus,
  Trash2,
  Compass,
  Sparkles,
  Maximize2,
  Minimize2,
  ZoomIn,
  ZoomOut,
  Layers,
  ShieldCheck,
  Lock,
  Unlock,
  Eye,
  EyeOff,
  Info,
  Search,
  Crosshair,
  Sliders,
  CheckCircle2,
  AlertCircle
} from 'lucide-react'

export interface UserLocationData {
  userId: string
  nickname: string
  avatarUrl?: string
  lat: number
  lng: number
  placeName?: string
  neighborhood?: string
  city?: string
  customLabel?: string
  battery?: number
  isCharging?: boolean
  accuracy?: number
  isSharingEnabled: boolean
  updatedAt: string
}

export interface SharedLocationsMap {
  [userId: string]: UserLocationData
}

export interface PinnedPlace {
  id: string
  name: string
  icon: string // e.g. '🏡', '☕', '🎓', '💼', '🌳', '🏋️'
  lat: number
  lng: number
  radiusMeters: number // e.g. 100 meters
  createdById: string
  createdAt: string
}

// Haversine formula to calculate distance between two GPS coordinates in kilometers
function calculateDistanceKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371 // Earth radius in km
  const dLat = ((lat2 - lat1) * Math.PI) / 180
  const dLon = ((lon2 - lon1) * Math.PI) / 180
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return Math.round(R * c * 100) / 100
}

const PLACE_TAGS = ['Home 🏡', 'Work 💼', 'Cafe ☕', 'Transit 🚇', 'Gym 🏋️', 'Out Exploring ✨']

const CUTE_PLACE_ICONS = [
  { icon: '🏡', label: 'Home' },
  { icon: '☕', label: 'Cafe' },
  { icon: '🎓', label: 'School' },
  { icon: '💼', label: 'Work' },
  { icon: '🌳', label: 'Park' },
  { icon: '🏋️', label: 'Gym' },
  { icon: '🛒', label: 'Shops' },
  { icon: '✨', label: 'Special' }
]

export const PartnerLocationCard: React.FC = () => {
  const { user, space, partner } = useAuth()
  const { showToast } = useToast()

  const spaceId = space?.id || 'default_space'
  const locationDocId = `location_${spaceId}`
  const placesDocId = `places_${spaceId}`

  const [locations, setLocations] = useState<SharedLocationsMap>({})
  const [pinnedPlaces, setPinnedPlaces] = useState<PinnedPlace[]>([])
  const [isUpdating, setIsUpdating] = useState(false)
  const [isSearchingAddress, setIsSearchingAddress] = useState(false)
  const [searchResults, setSearchResults] = useState<Array<{ display_name: string; lat: string; lon: string }>>([])
  const [searchQuery, setSearchQuery] = useState('')

  // Modals & Panels
  const [showTagModal, setShowTagModal] = useState(false)
  const [showConsentModal, setShowConsentModal] = useState(false)
  const [showPrivacyNoteModal, setShowPrivacyNoteModal] = useState(false)
  const [showCalibrateModal, setShowCalibrateModal] = useState(false)
  const [showAddPlaceModal, setShowAddPlaceModal] = useState(false)

  // New Pinned Place Form State
  const [newPlaceName, setNewPlaceName] = useState('')
  const [newPlaceIcon, setNewPlaceIcon] = useState('🏡')
  const [newPlaceRadius, setNewPlaceRadius] = useState(150)

  const [selectedTag, setSelectedTag] = useState('')
  const [isExpandedMap, setIsExpandedMap] = useState(false)
  const [gpsStatus, setGpsStatus] = useState<string>('Standby')

  const mapContainerRef = useRef<HTMLDivElement>(null)
  const mapInstanceRef = useRef<L.Map | null>(null)
  const markersRef = useRef<{ [key: string]: L.Marker }>({})
  const placeMarkersRef = useRef<{ [key: string]: { marker: L.Marker; circle: L.Circle } }>({})
  const polylineRef = useRef<L.Polyline | null>(null)
  const accuracyCirclesRef = useRef<{ [key: string]: L.Circle }>({})
  const lastGeocodedCoordRef = useRef<{ lat: number; lng: number; address: { neighborhood: string; city: string; display: string } } | null>(null)
  const lastBroadcastTimeRef = useRef<number>(0)
  const insidePlacesRef = useRef<{ [placeId: string]: boolean }>({})
  const locationsRef = useRef<SharedLocationsMap>(locations)
  locationsRef.current = locations

  // 1. Fetch & Listen to Realtime updates on shared locations & places
  useEffect(() => {
    const supabase = getSupabaseClient()
    const db = getFirebaseDb()

    const fetchLocationsAndPlaces = async () => {
      try {
        const [locRes, placesRes] = await Promise.all([
          supabase.from('app_content').select('content').eq('id', locationDocId).maybeSingle(),
          supabase.from('app_content').select('content').eq('id', placesDocId).maybeSingle()
        ])

        if (locRes.data?.content) {
          setLocations(locRes.data.content as SharedLocationsMap)
        }
        if (placesRes.data?.content && Array.isArray(placesRes.data.content)) {
          setPinnedPlaces(placesRes.data.content as PinnedPlace[])
        } else if (db && spaceId) {
          // Fallback to Firestore for places if Supabase has no record yet
          try {
            const placesSnap = await getDoc(doc(db, 'spaces', spaceId, 'features', 'pinned_places'))
            if (placesSnap.exists() && Array.isArray(placesSnap.data()?.places)) {
              setPinnedPlaces(placesSnap.data().places)
            }
          } catch {}
        }
      } catch (err) {
        console.warn('Error fetching shared location/places:', err)
      }
    }

    fetchLocationsAndPlaces()

    // Postgres Realtime channels
    const locChannel = supabase
      .channel(`location_chan_${spaceId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'app_content',
          filter: `id=eq.${locationDocId}`
        },
        (payload: any) => {
          if (payload.new?.content) {
            setLocations(payload.new.content as SharedLocationsMap)
          }
        }
      )
      .subscribe()

    const placesChannel = supabase
      .channel(`places_chan_${spaceId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'app_content',
          filter: `id=eq.${placesDocId}`
        },
        (payload: any) => {
          if (payload.new?.content && Array.isArray(payload.new.content)) {
            setPinnedPlaces(payload.new.content as PinnedPlace[])
          }
        }
      )
      .subscribe()

    // Firestore Realtime fallback listener for multi-device sync
    let unsubFirestoreLoc: (() => void) | undefined
    if (db && spaceId) {
      try {
        const locationsCol = collection(db, 'spaces', spaceId, 'locations')
        unsubFirestoreLoc = onSnapshot(locationsCol, (snapshot) => {
          setLocations((prev) => {
            const next = { ...prev }
            let hasChanged = false
            snapshot.docChanges().forEach((change) => {
              const data = change.doc.data() as UserLocationData
              if (data && data.userId) {
                const existing = prev[data.userId]
                if (!existing || existing.lat !== data.lat || existing.lng !== data.lng || existing.isSharingEnabled !== data.isSharingEnabled) {
                  next[data.userId] = data
                  hasChanged = true
                }
              }
            })
            return hasChanged ? next : prev
          })
        }, (err) => {
          console.warn('Firestore locations snapshot listener error:', err)
        })
      } catch (err) {
        console.warn('Failed to listen to Firestore locations:', err)
      }
    }

    // Peer broadcast listener
    const unsubscribeBroadcast = realtimeBridge.subscribe((event) => {
      if (event.type === 'LOCATION_UPDATE' && event.data) {
        const loc = event.data as UserLocationData
        setLocations((prev) => ({
          ...prev,
          [loc.userId]: loc
        }))
      }
    })

    return () => {
      supabase.removeChannel(locChannel)
      supabase.removeChannel(placesChannel)
      unsubscribeBroadcast()
      if (unsubFirestoreLoc) unsubFirestoreLoc()
    }
  }, [spaceId, locationDocId, placesDocId])

  const myLoc = user?.id ? locations[user.id] : null
  const partnerLoc = partner?.id ? locations[partner.id] : null

  // MUTUAL SHARING RULE:
  // Each partner sees the other's location ONLY when both have sharing enabled.
  const isMySharingOn = Boolean(myLoc?.isSharingEnabled)
  const isPartnerSharingOn = Boolean(partnerLoc?.isSharingEnabled)
  const isMutualSharingActive = isMySharingOn && isPartnerSharingOn

  // 2. Initialize Leaflet Map
  useEffect(() => {
    if (!mapContainerRef.current) return

    if (mapInstanceRef.current) {
      mapInstanceRef.current.remove()
      mapInstanceRef.current = null
    }

    // Default to user's location if available, otherwise partner's, otherwise fallback
    const initialLat = myLoc?.lat ?? partnerLoc?.lat ?? 22.5726
    const initialLng = myLoc?.lng ?? partnerLoc?.lng ?? 88.3639

    const map = L.map(mapContainerRef.current, {
      zoomControl: false,
      attributionControl: false,
      dragging: true,
      scrollWheelZoom: true,
      touchZoom: true
    }).setView([initialLat, initialLng], 14)

    // OpenStreetMap Humanitarian / HOT Layer: 100% Free, NO API Key Required, Zero Watermarks
    // Beautiful warm pastel styling with detailed roads, streets & neighborhood names
    L.tileLayer('https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png', {
      maxZoom: 19,
      subdomains: ['a', 'b', 'c'],
      attribution: '&copy; OpenStreetMap'
    }).addTo(map)

    mapInstanceRef.current = map

    const timer = setTimeout(() => {
      map.invalidateSize()
    }, 150)

    return () => {
      clearTimeout(timer)
      if (mapInstanceRef.current) {
        mapInstanceRef.current.remove()
        mapInstanceRef.current = null
      }
    }
  }, [])

  // Helper: Smooth Marker Gliding Animation (Interpolation)
  const animateMarkerGlide = (
    marker: L.Marker,
    startLatLng: L.LatLng,
    endLatLng: L.LatLng,
    durationMs = 900
  ) => {
    const startTime = performance.now()
    const step = (currentTime: number) => {
      const elapsed = currentTime - startTime
      const progress = Math.min(elapsed / durationMs, 1)
      // Ease-out cubic for smooth deceleration
      const ease = 1 - Math.pow(1 - progress, 3)
      const lat = startLatLng.lat + (endLatLng.lat - startLatLng.lat) * ease
      const lng = startLatLng.lng + (endLatLng.lng - startLatLng.lng) * ease
      marker.setLatLng([lat, lng])

      // Also update tether polyline continuously during glide
      if (polylineRef.current && myLoc && partnerLoc) {
        const uMarker = markersRef.current['user']
        const pMarker = markersRef.current['partner']
        if (uMarker && pMarker) {
          polylineRef.current.setLatLngs([uMarker.getLatLng(), pMarker.getLatLng()])
        }
      }

      if (progress < 1) {
        requestAnimationFrame(step)
      }
    }
    requestAnimationFrame(step)
  }

  // 3. Render Markers, Accuracy Circles, and Tether Line
  useEffect(() => {
    const map = mapInstanceRef.current
    if (!map) return

    // If mutual sharing is NOT active, remove user/partner markers & tether
    if (!isMutualSharingActive || !myLoc || !partnerLoc) {
      Object.values(markersRef.current).forEach((m) => m.remove())
      markersRef.current = {}
      Object.values(accuracyCirclesRef.current).forEach((c) => c.remove())
      accuracyCirclesRef.current = {}
      if (polylineRef.current) {
        polylineRef.current.remove()
        polylineRef.current = null
      }
      return
    }

    // Helper: Create Cute Avatar Marker Icon (Requirement 5)
    const createAvatarIcon = (
      nickname: string,
      avatarUrl?: string,
      isPartner?: boolean
    ) => {
      const initial = nickname.charAt(0).toUpperCase() || (isPartner ? 'P' : 'Y')
      const gradient = isPartner
        ? 'linear-gradient(145deg, #b77e6b, #8a9b85)'
        : 'linear-gradient(145deg, #4d655a, #8a9b85)'
      const ringColor = isPartner ? '#b77e6b' : '#4d655a'

      const photoHtml = avatarUrl
        ? `<img src="${avatarUrl}" alt="${nickname}" style="width: 100%; height: 100%; border-radius: 50%; object-fit: cover;" />`
        : `<div style="width: 100%; height: 100%; border-radius: 50%; background: #fffefa; display: grid; place-items: center; font-family: 'DM Sans', sans-serif; font-weight: 700; font-size: 14px; color: #242724;">${initial}</div>`

      return L.divIcon({
        className: 'custom-avatar-marker',
        html: `
          <div style="position: relative; width: 42px; height: 42px;">
            <!-- Radar Pulse Effect -->
            <div style="
              position: absolute;
              inset: -4px;
              border-radius: 50%;
              background: ${ringColor};
              opacity: 0.25;
              animation: ping 2.5s cubic-bezier(0, 0, 0.2, 1) infinite;
            "></div>
            <!-- Main Circular Avatar -->
            <div style="
              position: relative;
              width: 42px;
              height: 42px;
              border-radius: 50%;
              padding: 2.5px;
              background: ${gradient};
              box-shadow: 0 4px 14px rgba(0,0,0,0.25);
              display: flex;
              align-items: center;
              justify-content: center;
            ">
              ${photoHtml}
              <!-- Live Indicator Dot -->
              <div style="
                position: absolute;
                bottom: -2px;
                right: -2px;
                width: 11px;
                height: 11px;
                border-radius: 50%;
                background: #10b981;
                border: 2px solid #ffffff;
                box-shadow: 0 1px 3px rgba(0,0,0,0.2);
              "></div>
            </div>
          </div>
        `,
        iconSize: [42, 42],
        iconAnchor: [21, 21]
      })
    }

    // 1. User Marker (with smooth glide)
    const userTargetLatLng = L.latLng(myLoc.lat, myLoc.lng)
    if (markersRef.current['user']) {
      const currentPos = markersRef.current['user'].getLatLng()
      if (currentPos.lat !== myLoc.lat || currentPos.lng !== myLoc.lng) {
        animateMarkerGlide(markersRef.current['user'], currentPos, userTargetLatLng)
      }
    } else {
      const myMarker = L.marker(userTargetLatLng, {
        icon: createAvatarIcon(user?.nickname || 'You', user?.avatarUrl, false)
      }).addTo(map)
      const myPlace = myLoc.customLabel || myLoc.neighborhood || myLoc.placeName || 'You'
      myMarker.bindPopup(`<b>You (${user?.nickname || 'You'})</b><br>${myPlace}`)
      markersRef.current['user'] = myMarker
    }

    // Accuracy Circle for User
    if (myLoc.accuracy && myLoc.accuracy < 1000) {
      if (accuracyCirclesRef.current['user']) {
        accuracyCirclesRef.current['user'].setLatLng(userTargetLatLng).setRadius(myLoc.accuracy)
      } else {
        accuracyCirclesRef.current['user'] = L.circle(userTargetLatLng, {
          radius: myLoc.accuracy,
          color: '#4d655a',
          weight: 1,
          opacity: 0.4,
          fillColor: '#4d655a',
          fillOpacity: 0.08
        }).addTo(map)
      }
    }

    // 2. Partner Marker (with smooth glide)
    const partnerTargetLatLng = L.latLng(partnerLoc.lat, partnerLoc.lng)
    if (markersRef.current['partner']) {
      const currentPos = markersRef.current['partner'].getLatLng()
      if (currentPos.lat !== partnerLoc.lat || currentPos.lng !== partnerLoc.lng) {
        animateMarkerGlide(markersRef.current['partner'], currentPos, partnerTargetLatLng)
      }
    } else {
      const pMarker = L.marker(partnerTargetLatLng, {
        icon: createAvatarIcon(partner?.nickname || 'Partner', partner?.avatarUrl, true)
      }).addTo(map)
      const partnerPlace = partnerLoc.customLabel || partnerLoc.neighborhood || partnerLoc.placeName || 'Partner'
      pMarker.bindPopup(`<b>${partner?.nickname || 'Partner'}</b><br>${partnerPlace}`)
      markersRef.current['partner'] = pMarker
    }

    // Accuracy Circle for Partner
    if (partnerLoc.accuracy && partnerLoc.accuracy < 1000) {
      if (accuracyCirclesRef.current['partner']) {
        accuracyCirclesRef.current['partner'].setLatLng(partnerTargetLatLng).setRadius(partnerLoc.accuracy)
      } else {
        accuracyCirclesRef.current['partner'] = L.circle(partnerTargetLatLng, {
          radius: partnerLoc.accuracy,
          color: '#b77e6b',
          weight: 1,
          opacity: 0.4,
          fillColor: '#b77e6b',
          fillOpacity: 0.08
        }).addTo(map)
      }
    }

    // 3. Dotted tether polyline connecting both partners
    if (polylineRef.current) {
      polylineRef.current.setLatLngs([userTargetLatLng, partnerTargetLatLng])
    } else {
      const poly = L.polyline([userTargetLatLng, partnerTargetLatLng], {
        color: '#4d655a',
        weight: 2.5,
        dashArray: '6, 8',
        opacity: 0.85
      }).addTo(map)
      polylineRef.current = poly
    }
  }, [locations, user, partner, isMutualSharingActive])

  // 4. Render Pinned Places on Map (Cute icons & geofence boundary)
  useEffect(() => {
    const map = mapInstanceRef.current
    if (!map) return

    // Clean up removed places
    const currentPlaceIds = new Set(pinnedPlaces.map((p) => p.id))
    Object.keys(placeMarkersRef.current).forEach((id) => {
      if (!currentPlaceIds.has(id)) {
        placeMarkersRef.current[id].marker.remove()
        placeMarkersRef.current[id].circle.remove()
        delete placeMarkersRef.current[id]
      }
    })

    // Add or update places
    pinnedPlaces.forEach((place) => {
      if (!placeMarkersRef.current[place.id]) {
        const placeIcon = L.divIcon({
          className: 'custom-place-marker',
          html: `
            <div style="
              position: relative;
              display: flex;
              flex-direction: column;
              align-items: center;
              transform: translateY(-8px);
            ">
              <div style="
                width: 32px;
                height: 32px;
                border-radius: 50%;
                background: #fffefa;
                border: 2px solid #8a9b85;
                box-shadow: 0 3px 8px rgba(0,0,0,0.18);
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 16px;
              ">
                ${place.icon}
              </div>
              <div style="
                margin-top: 2px;
                background: rgba(255,255,255,0.92);
                border: 1px solid #deddd7;
                border-radius: 6px;
                padding: 1px 5px;
                font-size: 9px;
                font-weight: 600;
                color: #242724;
                white-space: nowrap;
                box-shadow: 0 1px 3px rgba(0,0,0,0.1);
              ">
                ${place.name}
              </div>
            </div>
          `,
          iconSize: [40, 48],
          iconAnchor: [20, 24]
        })

        const marker = L.marker([place.lat, place.lng], { icon: placeIcon }).addTo(map)
        marker.bindPopup(`<b>${place.icon} ${place.name}</b><br>Radius: ${place.radiusMeters}m`)

        const circle = L.circle([place.lat, place.lng], {
          radius: place.radiusMeters,
          color: '#8a9b85',
          weight: 1,
          dashArray: '4, 4',
          fillColor: '#8a9b85',
          fillOpacity: 0.12
        }).addTo(map)

        placeMarkersRef.current[place.id] = { marker, circle }
      }
    })
  }, [pinnedPlaces])

  // Invalidate map size on expand toggle
  useEffect(() => {
    if (mapInstanceRef.current) {
      setTimeout(() => {
        mapInstanceRef.current?.invalidateSize()
      }, 200)
    }
  }, [isExpandedMap])

  // Battery Info Helper
  const getBatteryInfo = async (): Promise<{ level: number; isCharging: boolean } | null> => {
    try {
      if ('getBattery' in navigator) {
        const b = await (navigator as any).getBattery()
        return {
          level: Math.round(b.level * 100),
          isCharging: Boolean(b.charging)
        }
      }
    } catch {}
    return null
  }

  // Reverse Geocoding with Distance-Throttled Cache
  const reverseGeocode = async (
    lat: number,
    lng: number
  ): Promise<{ neighborhood: string; city: string; display: string }> => {
    // If moved less than 50 meters from previous geocoded spot, reuse cache
    if (lastGeocodedCoordRef.current) {
      const distKm = calculateDistanceKm(
        lat,
        lng,
        lastGeocodedCoordRef.current.lat,
        lastGeocodedCoordRef.current.lng
      )
      if (distKm < 0.05) {
        return lastGeocodedCoordRef.current.address
      }
    }

    try {
      const res = await fetch(
        `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lng}&format=json`,
        { headers: { 'Accept-Language': 'en', 'User-Agent': 'PagesOfUs/1.0' } }
      )
      const data = await res.json()
      const addr = data.address || {}

      const neighborhood =
        addr.suburb ||
        addr.neighbourhood ||
        addr.residential ||
        addr.quarter ||
        addr.village ||
        addr.hamlet ||
        'Local Area'

      const city =
        addr.city ||
        addr.town ||
        addr.municipality ||
        addr.county ||
        addr.state ||
        'Current City'

      const road = addr.road ? `${addr.road}, ` : ''
      const address = {
        neighborhood,
        city,
        display: `${road}${neighborhood}, ${city}`
      }

      lastGeocodedCoordRef.current = { lat, lng, address }
      return address
    } catch {
      return {
        neighborhood: 'Nearby Area',
        city: 'Current City',
        display: 'Nearby Area'
      }
    }
  }

  // Sync / Broadcast position to Supabase & Realtime channel
  const syncMyPosition = useCallback(
    async (lat: number, lng: number, accuracy?: number, customTag?: string) => {
      if (!user) return

      const batteryData = await getBatteryInfo()
      const { neighborhood, city, display } = await reverseGeocode(lat, lng)

      const updatedLoc: UserLocationData = {
        userId: user.id,
        nickname: user.nickname,
        avatarUrl: user.avatarUrl,
        lat,
        lng,
        neighborhood,
        city,
        placeName: display,
        customLabel: customTag || selectedTag || undefined,
        battery: batteryData?.level ?? 100,
        isCharging: batteryData?.isCharging ?? false,
        accuracy,
        isSharingEnabled: true,
        updatedAt: new Date().toISOString()
      }

      setLocations((prev) => ({
        ...prev,
        [user.id]: updatedLoc
      }))

      // Check geofence entry / exit for pinned places
      pinnedPlaces.forEach((place) => {
        const distMeters = calculateDistanceKm(lat, lng, place.lat, place.lng) * 1000
        const isInside = distMeters <= place.radiusMeters
        const wasInside = insidePlacesRef.current[place.id]

        if (isInside && !wasInside) {
          insidePlacesRef.current[place.id] = true
          showToast(`📍 Arrived at ${place.icon} ${place.name}!`)
        } else if (!isInside && wasInside) {
          insidePlacesRef.current[place.id] = false
          showToast(`Left ${place.icon} ${place.name}`)
        }
      })

      try {
        const supabase = getSupabaseClient()
        let freshContent: SharedLocationsMap = { ...locationsRef.current }

        // Fetch latest document before writing to prevent race conditions between Phone A & Phone B
        try {
          const { data: latestRow } = await supabase
            .from('app_content')
            .select('content')
            .eq('id', locationDocId)
            .maybeSingle()
          if (latestRow?.content) {
            freshContent = { ...freshContent, ...latestRow.content }
          }
        } catch {}

        const mergedMap = {
          ...freshContent,
          [user.id]: updatedLoc
        }

        await supabase.from('app_content').upsert({
          id: locationDocId,
          content: mergedMap,
          updated_at: new Date().toISOString()
        })

        // Also persist to Firebase Firestore if connected
        const db = getFirebaseDb()
        if (db) {
          try {
            await setDoc(doc(db, 'spaces', spaceId, 'locations', user.id), updatedLoc, { merge: true })
          } catch {}
        }

        await realtimeBridge.broadcast({
          type: 'LOCATION_UPDATE',
          senderId: user.id,
          senderNickname: user.nickname,
          timestamp: Date.now(),
          data: updatedLoc
        })
      } catch (err) {
        console.warn('Error syncing location to cloud:', err)
      }
    },
    [user, selectedTag, spaceId, locationDocId, pinnedPlaces, showToast]
  )

  // 5. REQUIREMENT 3: TRUE LIVE GPS TRACKING (App Open)
  // Continuous watchPosition with High Accuracy and 0 cache age
  useEffect(() => {
    if (!isMySharingOn || !user?.id) {
      setGpsStatus('Sharing paused')
      return
    }

    if (!('geolocation' in navigator)) {
      setGpsStatus('GPS not supported')
      return
    }

    setGpsStatus('Tracking live GPS')

    const watchId = navigator.geolocation.watchPosition(
      (pos) => {
        const lat = pos.coords.latitude
        const lng = pos.coords.longitude
        const accuracy = Math.round(pos.coords.accuracy)

        setGpsStatus(`Live GPS (±${accuracy}m)`)

        // Broadcast throttled to every 1.8 seconds to avoid network saturation
        const now = Date.now()
        if (now - lastBroadcastTimeRef.current > 1800) {
          lastBroadcastTimeRef.current = now
          syncMyPosition(lat, lng, accuracy)
        }
      },
      (err) => {
        console.warn('GPS watch error:', err.message)
        setGpsStatus(err.code === 1 ? 'Permission denied' : 'Locating...')
      },
      {
        enableHighAccuracy: true,
        timeout: 10000,
        maximumAge: 0 // NO STALE CACHE - True Live Fix
      }
    )

    return () => {
      navigator.geolocation.clearWatch(watchId)
    }
  }, [isMySharingOn, user?.id, syncMyPosition])

  // Master Toggle to stop or start sharing
  const handleToggleSharing = async (shouldEnable: boolean) => {
    if (!user) return

    // If enabling and user hasn't consented yet, show consent sheet first
    if (shouldEnable) {
      const hasConsentedLocal = localStorage.getItem('pages_of_us_location_consent') === 'true'
      if (!hasConsentedLocal) {
        setShowConsentModal(true)
        return
      }
      // If already consented, turn ON and force immediate live GPS reading
      handleForceGpsUpdate()
      return
    }

    // If stopping sharing: immediately set isSharingEnabled = false
    const existing = locations[user.id]
    if (!existing) return

    const updatedLoc: UserLocationData = {
      ...existing,
      isSharingEnabled: false,
      updatedAt: new Date().toISOString()
    }

    const updated = {
      ...locations,
      [user.id]: updatedLoc
    }

    setLocations(updated)
    setGpsStatus('Sharing paused')
    showToast('Location sharing turned OFF. Your partner cannot see your location.')

    try {
      const supabase = getSupabaseClient()
      await supabase.from('app_content').upsert({
        id: locationDocId,
        content: updated,
        updated_at: new Date().toISOString()
      })

      await realtimeBridge.broadcast({
        type: 'LOCATION_UPDATE',
        senderId: user.id,
        senderNickname: user.nickname,
        timestamp: Date.now(),
        data: updatedLoc
      })
    } catch (err) {
      console.warn('Error pausing sharing:', err)
    }
  }

  // Force single-shot fresh GPS fix
  const handleForceGpsUpdate = () => {
    if (!user) return
    setIsUpdating(true)
    showToast('Acquiring fresh satellite/Wi-Fi fix...')

    if (!('geolocation' in navigator)) {
      showToast('Geolocation is not supported by your device.')
      setIsUpdating(false)
      return
    }

    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        const lat = pos.coords.latitude
        const lng = pos.coords.longitude
        const accuracy = Math.round(pos.coords.accuracy)

        await syncMyPosition(lat, lng, accuracy)
        setIsUpdating(false)
        showToast(`📍 Live GPS acquired (±${accuracy}m)`)

        // Center map on user
        if (mapInstanceRef.current) {
          mapInstanceRef.current.flyTo([lat, lng], 15, { duration: 1.2 })
        }
      },
      (err) => {
        console.warn('Geolocation error:', err)
        setIsUpdating(false)
        showToast('GPS unavailable. You can search or pinpoint your real address.')
        setShowCalibrateModal(true)
      },
      { enableHighAccuracy: true, timeout: 12000, maximumAge: 0 }
    )
  }

  // Address Search using Nominatim (Solves false location on desktop)
  const handleSearchAddress = async () => {
    if (!searchQuery.trim()) return
    setIsSearchingAddress(true)
    try {
      const res = await fetch(
        `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(
          searchQuery
        )}&format=json&limit=5`,
        { headers: { 'User-Agent': 'PagesOfUs/1.0', 'Accept-Language': 'en' } }
      )
      const data = await res.json()
      setSearchResults(data || [])
    } catch {
      showToast('Error searching address. Please check your internet.')
    } finally {
      setIsSearchingAddress(false)
    }
  }

  // Select searched address as real location
  const handleSelectSearchedLocation = async (item: { display_name: string; lat: string; lon: string }) => {
    const lat = parseFloat(item.lat)
    const lng = parseFloat(item.lon)

    await syncMyPosition(lat, lng, 10, item.display_name.split(',')[0])
    setShowCalibrateModal(false)
    setSearchResults([])
    setSearchQuery('')
    showToast(`📍 Location set to: ${item.display_name.split(',')[0]}`)

    if (mapInstanceRef.current) {
      mapInstanceRef.current.flyTo([lat, lng], 15, { duration: 1.2 })
    }
  }

  // Add a Shared Pinned Place
  const handleSaveNewPlace = async () => {
    if (!newPlaceName.trim() || !user) return

    // Default place location to user's current location or map center
    const center = mapInstanceRef.current?.getCenter()
    const lat = myLoc?.lat ?? center?.lat ?? 22.5726
    const lng = myLoc?.lng ?? center?.lng ?? 88.3639

    const newPlace: PinnedPlace = {
      id: `place_${Date.now()}`,
      name: newPlaceName.trim(),
      icon: newPlaceIcon,
      lat,
      lng,
      radiusMeters: newPlaceRadius,
      createdById: user.id,
      createdAt: new Date().toISOString()
    }

    const updated = [...pinnedPlaces, newPlace]
    setPinnedPlaces(updated)
    setShowAddPlaceModal(false)
    setNewPlaceName('')
    showToast(`Pinned place "${newPlace.name}" added for both!`)

    try {
      const supabase = getSupabaseClient()
      await supabase.from('app_content').upsert({
        id: placesDocId,
        content: updated,
        updated_at: new Date().toISOString()
      })

      const db = getFirebaseDb()
      if (db && spaceId) {
        try {
          await setDoc(doc(db, 'spaces', spaceId, 'features', 'pinned_places'), { places: updated }, { merge: true })
        } catch {}
      }
    } catch (err) {
      console.warn('Error saving pinned place:', err)
    }
  }

  // Delete a Shared Pinned Place
  const handleDeletePlace = async (placeId: string) => {
    const updated = pinnedPlaces.filter((p) => p.id !== placeId)
    setPinnedPlaces(updated)
    showToast('Pinned place removed.')

    try {
      const supabase = getSupabaseClient()
      await supabase.from('app_content').upsert({
        id: placesDocId,
        content: updated,
        updated_at: new Date().toISOString()
      })

      const db = getFirebaseDb()
      if (db && spaceId) {
        try {
          await setDoc(doc(db, 'spaces', spaceId, 'features', 'pinned_places'), { places: updated }, { merge: true })
        } catch {}
      }
    } catch (err) {
      console.warn('Error deleting pinned place:', err)
    }
  }

  // Delete / Clear Location History (Purge Requirement 8)
  const handleDeleteMyLocation = async () => {
    if (!user || !locations[user.id]) return
    if (!window.confirm('Purge all saved location coordinates and stop sharing?')) return

    const updated = { ...locations }
    delete updated[user.id]

    setLocations(updated)
    showToast('Your location history has been purged and cleared.')

    try {
      const supabase = getSupabaseClient()
      await supabase.from('app_content').upsert({
        id: locationDocId,
        content: updated,
        updated_at: new Date().toISOString()
      })
    } catch (err) {
      console.warn('Error deleting location:', err)
    }
  }

  // Map Controls
  const handleZoomIn = () => mapInstanceRef.current?.zoomIn()
  const handleZoomOut = () => mapInstanceRef.current?.zoomOut()
  const handleRecenter = () => {
    const map = mapInstanceRef.current
    if (!map) return
    if (myLoc && partnerLoc) {
      const b = L.latLngBounds([[myLoc.lat, myLoc.lng], [partnerLoc.lat, partnerLoc.lng]])
      map.fitBounds(b, { padding: [45, 45], maxZoom: 16 })
    } else if (myLoc) {
      map.flyTo([myLoc.lat, myLoc.lng], 15)
    }
  }

  // REQUIREMENT 6: Live Haversine Distance
  const distanceKm =
    isMutualSharingActive && myLoc && partnerLoc
      ? calculateDistanceKm(myLoc.lat, myLoc.lng, partnerLoc.lat, partnerLoc.lng)
      : null

  // Geofence Place Status for Partner
  const partnerCurrentPlace = pinnedPlaces.find((p) => {
    if (!partnerLoc) return false
    const dMeters = calculateDistanceKm(partnerLoc.lat, partnerLoc.lng, p.lat, p.lng) * 1000
    return dMeters <= p.radiusMeters
  })

  const formatLastSeen = (isoString?: string) => {
    if (!isoString) return ''
    const diffMins = Math.round((Date.now() - new Date(isoString).getTime()) / 60000)
    if (diffMins <= 1) return 'Live now'
    if (diffMins < 60) return `${diffMins}m ago`
    const diffHours = Math.round(diffMins / 60)
    if (diffHours < 24) return `${diffHours}h ago`
    return 'Earlier'
  }

  return (
    <div className="mt-4 p-4 rounded-2xl border border-[var(--line)] bg-[var(--white)] space-y-3.5 shadow-sm text-[var(--ink)] transition-colors duration-200">
      {/* 1. Header with Master Toggle & Privacy Info */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="w-6 h-6 rounded-lg bg-[var(--paper)] text-[var(--app-accent)] flex items-center justify-center">
            <Compass className="w-3.5 h-3.5" />
          </div>
          <div>
            <div className="flex items-center gap-1.5">
              <span
                className={`w-1.5 h-1.5 rounded-full ${
                  isMutualSharingActive
                    ? 'bg-emerald-500 animate-pulse'
                    : isMySharingOn
                    ? 'bg-amber-500'
                    : 'bg-neutral-400'
                }`}
              />
              <span className="text-[9px] font-semibold tracking-wider uppercase text-[var(--app-accent)]">
                Live Tether · {gpsStatus}
              </span>
            </div>
            <h3 className="text-xs font-serif font-medium text-[var(--ink)]">
              Where we are right now
            </h3>
          </div>
        </div>

        {/* Master Sharing Toggle Switch */}
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => setShowPrivacyNoteModal(true)}
            className="text-[#7a8178] hover:text-[#4d655a] transition cursor-pointer p-1"
            title="Privacy policy & how sharing works"
          >
            <Info className="w-3.5 h-3.5" />
          </button>

          <button
            type="button"
            onClick={() => handleToggleSharing(!isMySharingOn)}
            className={`relative inline-flex h-5 w-9 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none ${
              isMySharingOn ? 'bg-[#4d655a]' : 'bg-[#deddd7]'
            }`}
            title={isMySharingOn ? 'Turn location sharing OFF' : 'Turn location sharing ON'}
          >
            <span
              className={`pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white shadow-xs ring-0 transition duration-200 ease-in-out ${
                isMySharingOn ? 'translate-x-4' : 'translate-x-0'
              }`}
            />
          </button>
        </div>
      </div>

      {/* 2. REAL INTERACTIVE MAP + MUTUAL CONSENT SHIELD */}
      <div
        className={`relative rounded-xl overflow-hidden border border-[var(--line)] bg-[var(--paper)] transition-all duration-300 isolate ${
          isExpandedMap ? 'h-72' : 'h-52'
        }`}
        style={{ isolation: 'isolate' }}
      >
        <div ref={mapContainerRef} className="w-full h-full z-0" />

        {/* Mutual Sharing Rule Overlay (When either or both have sharing paused) */}
        {!isMutualSharingActive && (
          <div className="absolute inset-0 z-20 bg-[var(--white)]/95 backdrop-blur-md flex flex-col items-center justify-center p-5 text-center space-y-2.5">
            <div className="w-9 h-9 rounded-full bg-[var(--paper)] text-[var(--app-accent)] flex items-center justify-center">
              {!isMySharingOn ? (
                <EyeOff className="w-4 h-4 text-[var(--soft)]" />
              ) : (
                <Lock className="w-4 h-4 text-[var(--terra)]" />
              )}
            </div>

            <div className="space-y-1 max-w-xs">
              <h4 className="text-xs font-serif font-semibold text-[var(--ink)]">
                {!isMySharingOn
                  ? 'Your sharing is turned off'
                  : `Waiting for ${partner?.nickname || 'your partner'}`}
              </h4>
              <p className="text-[10px] text-[var(--soft)] leading-relaxed">
                {!isMySharingOn
                  ? 'Turn on sharing to privately see each other on the map.'
                  : `Your location is ready. Under our mutual consent rule, both partners must turn sharing ON to see each other's pins.`}
              </p>
            </div>

            {!isMySharingOn ? (
              <button
                type="button"
                onClick={() => handleToggleSharing(true)}
                className="py-1.5 px-3 rounded-xl bg-[var(--app-accent)] text-white text-[10px] font-medium cursor-pointer hover:opacity-90 transition shadow-xs flex items-center gap-1.5"
              >
                <Eye className="w-3 h-3" />
                <span>Turn Sharing ON</span>
              </button>
            ) : (
              <div className="text-[9px] font-medium text-[var(--terra)] px-2 py-0.5 rounded-full bg-[var(--paper)] border border-[var(--line)]">
                Waiting for partner's consent 🔒
              </div>
            )}
          </div>
        )}

        {/* Top-Left: Active Neighborhood & City Badge */}
        {isMutualSharingActive && (
          <div className="absolute top-2 left-2 z-10 bg-[var(--white)]/90 backdrop-blur-md px-2.5 py-1 rounded-lg border border-[var(--line)] text-[9px] text-[var(--ink)] shadow-xs flex items-center gap-1.5 max-w-[70%]">
            <MapPin className="w-3 h-3 text-[var(--app-accent)] shrink-0" />
            <span className="truncate font-medium">
              {partnerCurrentPlace
                ? `Partner is at ${partnerCurrentPlace.icon} ${partnerCurrentPlace.name}`
                : partnerLoc?.neighborhood
                ? `${partnerLoc.neighborhood}, ${partnerLoc.city || ''}`
                : myLoc?.neighborhood
                ? `${myLoc.neighborhood}, ${myLoc.city || ''}`
                : 'Interactive street map'}
            </span>
          </div>
        )}

        {/* Top-Right: Zoom & Control Toolbar */}
        {isMutualSharingActive && (
          <div className="absolute top-2 right-2 z-10 flex flex-col gap-1">
            <button
              type="button"
              onClick={handleZoomIn}
              className="w-7 h-7 rounded-lg bg-[var(--white)] border border-[var(--line)] text-[var(--ink)] shadow-xs flex items-center justify-center hover:bg-[var(--paper)] active:scale-95 cursor-pointer"
              title="Zoom in"
            >
              <ZoomIn className="w-3.5 h-3.5" />
            </button>
            <button
              type="button"
              onClick={handleZoomOut}
              className="w-7 h-7 rounded-lg bg-[var(--white)] border border-[var(--line)] text-[var(--ink)] shadow-xs flex items-center justify-center hover:bg-[var(--paper)] active:scale-95 cursor-pointer"
              title="Zoom out"
            >
              <ZoomOut className="w-3.5 h-3.5" />
            </button>
          </div>
        )}

        {/* Bottom-Right: Recenter & Expand Height Buttons */}
        {isMutualSharingActive && (
          <div className="absolute bottom-2 right-2 z-10 flex items-center gap-1">
            <button
              type="button"
              onClick={() => setIsExpandedMap(!isExpandedMap)}
              className="p-1.5 rounded-lg bg-[var(--white)] border border-[var(--line)] text-[var(--app-accent)] shadow-xs hover:bg-[var(--paper)] active:scale-95 cursor-pointer"
              title={isExpandedMap ? 'Collapse map' : 'Expand map height'}
            >
              {isExpandedMap ? (
                <Minimize2 className="w-3.5 h-3.5" />
              ) : (
                <Maximize2 className="w-3.5 h-3.5" />
              )}
            </button>

            <button
              type="button"
              onClick={handleRecenter}
              className="p-1.5 rounded-lg bg-[var(--white)] border border-[var(--line)] text-[var(--app-accent)] shadow-xs hover:bg-[var(--paper)] active:scale-95 cursor-pointer"
              title="Center on markers"
            >
              <Crosshair className="w-3.5 h-3.5" />
            </button>
          </div>
        )}
      </div>

      {/* 3. REQUIREMENT 6: LIVE DISTANCE BADGE */}
      {isMutualSharingActive && myLoc && partnerLoc && (
        <div className="p-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] flex items-center justify-between shadow-xs">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-full bg-[var(--app-accent)] text-[var(--app-accent-text)] flex items-center justify-center font-bold text-xs shadow-xs">
              {distanceKm !== null && distanceKm < 0.05 ? '💕' : '📍'}
            </div>
            <div>
              <div className="text-[9px] uppercase tracking-wider font-semibold text-[var(--app-accent)]">
                {distanceKm !== null && distanceKm < 0.05
                  ? 'Together Right Now'
                  : 'Live Distance Apart'}
              </div>
              <div className="text-xs font-serif font-bold text-[var(--ink)]">
                {distanceKm !== null
                  ? distanceKm < 0.05
                    ? 'You two are together!'
                    : distanceKm < 1
                    ? `${Math.round(distanceKm * 1000)} meters apart`
                    : `${distanceKm.toFixed(1)} km apart`
                  : 'Calculating...'}
              </div>
            </div>
          </div>

          <div className="text-right">
            <span className="text-[8px] font-medium text-[var(--app-accent)] bg-[var(--white)] px-2 py-0.5 rounded-full border border-[var(--line)] shadow-2xs">
              {distanceKm !== null && distanceKm < 0.05 ? 'Same place' : 'Live Tether Active'}
            </span>
          </div>
        </div>
      )}

      {/* 4. Partner & You Live Status Cards */}
      <div className="grid grid-cols-2 gap-2 text-xs">
        {/* Partner Card */}
        <div className="p-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] space-y-1">
          <div className="flex items-center justify-between">
            <span className="font-semibold text-[10px] text-[var(--ink)] truncate">
              {partner?.nickname || 'Partner'}
            </span>
            {isPartnerSharingOn && partnerLoc?.battery !== undefined ? (
              <div
                className="flex items-center gap-0.5 text-[9px] text-[var(--soft)]"
                title="Partner's battery"
              >
                {partnerLoc.isCharging ? (
                  <BatteryCharging className="w-3 h-3 text-emerald-600" />
                ) : (
                  <Battery className="w-3 h-3" />
                )}
                <span>{partnerLoc.battery}%</span>
              </div>
            ) : (
              <span className="text-[8px] font-medium text-[var(--soft)]">
                {isPartnerSharingOn ? 'Active' : 'Sharing Paused'}
              </span>
            )}
          </div>

          <p className="font-serif text-[11px] text-[var(--ink)] truncate font-medium">
            {!isMutualSharingActive
              ? isPartnerSharingOn
                ? 'Location ready (Locked)'
                : 'Sharing is off'
              : partnerCurrentPlace
              ? `at ${partnerCurrentPlace.icon} ${partnerCurrentPlace.name}`
              : partnerLoc
              ? partnerLoc.customLabel || partnerLoc.neighborhood || partnerLoc.placeName || 'Active'
              : 'Waiting for location'}
          </p>

          <span className="text-[8px] text-[var(--soft)] block truncate">
            {isMutualSharingActive && partnerLoc
              ? `${partnerLoc.city ? `${partnerLoc.city} · ` : ''}${formatLastSeen(
                  partnerLoc.updatedAt
                )}`
              : 'Protected by mutual rule'}
          </span>
        </div>

        {/* You Card */}
        <div className="p-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] space-y-1">
          <div className="flex items-center justify-between">
            <span className="font-semibold text-[10px] text-[var(--ink)] truncate">
              You ({user?.nickname || 'You'})
            </span>
            {isMySharingOn && myLoc?.battery !== undefined ? (
              <div
                className="flex items-center gap-0.5 text-[9px] text-[var(--soft)]"
                title="Your battery"
              >
                {myLoc.isCharging ? (
                  <BatteryCharging className="w-3 h-3 text-emerald-600" />
                ) : (
                  <Battery className="w-3 h-3" />
                )}
                <span>{myLoc.battery}%</span>
              </div>
            ) : (
              <span className="text-[8px] font-medium text-[#8a8b83]">
                {isMySharingOn ? 'Sharing ON' : 'Paused'}
              </span>
            )}
          </div>

          <p className="font-serif text-[11px] text-[#3d423c] truncate font-medium">
            {isMySharingOn
              ? myLoc
                ? myLoc.customLabel || myLoc.neighborhood || myLoc.placeName || 'Sharing live'
                : 'Acquiring GPS...'
              : 'Sharing is paused'}
          </p>

          <span className="text-[8px] text-[#8a8b83] block truncate">
            {isMySharingOn && myLoc
              ? `${myLoc.city ? `${myLoc.city} · ` : ''}${formatLastSeen(myLoc.updatedAt)}`
              : 'Tap toggle to turn on'}
          </span>
        </div>
      </div>

      {/* 5. Shared Places Chips (Requirements 4, 5, 7) */}
      <div className="pt-0.5">
        <div className="flex items-center justify-between mb-1.5">
          <span className="text-[9px] font-semibold text-[#666861] uppercase tracking-wider">
            Shared Places ({pinnedPlaces.length})
          </span>
          <button
            type="button"
            onClick={() => setShowAddPlaceModal(true)}
            className="text-[9px] text-[#4d655a] font-medium hover:underline flex items-center gap-0.5 cursor-pointer"
          >
            <Plus className="w-2.5 h-2.5" />
            <span>Pin New Place</span>
          </button>
        </div>

        {pinnedPlaces.length > 0 ? (
          <div className="flex flex-wrap gap-1.5">
            {pinnedPlaces.map((place) => (
              <div
                key={place.id}
                className="px-2 py-1 rounded-lg border border-[var(--line)] bg-[var(--paper)] text-[10px] text-[var(--ink)] flex items-center gap-1.5 shadow-2xs"
              >
                <span>{place.icon}</span>
                <span className="font-medium">{place.name}</span>
                <button
                  type="button"
                  onClick={() => handleDeletePlace(place.id)}
                  className="text-[var(--soft)] hover:text-red-500 transition cursor-pointer ml-0.5"
                  title="Remove place"
                >
                  ×
                </button>
              </div>
            ))}
          </div>
        ) : (
          <p className="text-[9px] text-[var(--soft)]">
            No pinned places yet. Pin your Home 🏡, Cafe ☕ or School 🎓 for arrival alerts!
          </p>
        )}
      </div>

      {/* 6. Controls: Force GPS, Calibrate/Search Address & Clear History */}
      <div className="flex flex-wrap items-center justify-between gap-2 pt-1 border-t border-[var(--line)]">
        <div className="flex items-center gap-1.5">
          {isMySharingOn && (
            <button
              type="button"
              onClick={handleForceGpsUpdate}
              disabled={isUpdating}
              className="py-1.5 px-2.5 rounded-xl bg-[var(--app-accent)] text-white text-[10px] font-medium flex items-center gap-1 cursor-pointer hover:opacity-90 transition disabled:opacity-50 shadow-2xs"
              title="Force fresh GPS satellite/Wi-Fi fix"
            >
              {isUpdating ? (
                <>
                  <RefreshCw className="w-3 h-3 animate-spin" />
                  <span>Locating...</span>
                </>
              ) : (
                <>
                  <Navigation className="w-3 h-3" />
                  <span>Live GPS</span>
                </>
              )}
            </button>
          )}

          {/* Calibrate / Address Search Button (Fixes false IP location on desktop) */}
          <button
            type="button"
            onClick={() => setShowCalibrateModal(true)}
            className="py-1.5 px-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] text-[10px] font-medium cursor-pointer hover:opacity-85 transition flex items-center gap-1"
            title="Set exact real address or search location"
          >
            <Search className="w-3 h-3" />
            <span>Set Address</span>
          </button>

          <button
            type="button"
            onClick={() => setShowTagModal(true)}
            className="py-1.5 px-2 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] text-[10px] font-medium cursor-pointer hover:opacity-85 transition"
          >
            Tag 🏷️
          </button>
        </div>

        {/* Delete / Clear Location History Button */}
        {myLoc && (
          <button
            type="button"
            onClick={handleDeleteMyLocation}
            className="text-[9px] text-rose-500 hover:text-rose-400 flex items-center gap-1 cursor-pointer py-1 px-1.5 rounded transition"
            title="Stop sharing and purge location history"
          >
            <Trash2 className="w-3 h-3" />
            <span>Clear History</span>
          </button>
        )}
      </div>

      {/* MODAL 1: Explicit Consent & Permission Dialog */}
      {showConsentModal && (
        <div
          className="modal-backdrop show"
          onClick={(e) => {
            if (e.target === e.currentTarget) setShowConsentModal(false)
          }}
        >
          <div className="modal">
            <div className="modal-handle"></div>
            <button
              type="button"
              className="close"
              onClick={() => setShowConsentModal(false)}
            >
              ×
            </button>
            <div className="modal-date">LOCATION PRIVACY & PERMISSION</div>
            <h3>Share location with {partner?.nickname || 'your partner'}?</h3>

            <div className="space-y-3 my-3 text-xs text-[var(--soft)]">
              <div className="flex items-start gap-2.5 p-2.5 rounded-xl bg-[var(--paper)] border border-[var(--line)]">
                <ShieldCheck className="w-4 h-4 text-[var(--app-accent)] shrink-0 mt-0.5" />
                <p className="not-italic text-[11px] leading-relaxed text-[var(--ink)]">
                  <b>Private for you two:</b> Your GPS location is shared exclusively with{' '}
                  {partner?.nickname || 'your partner'}. It is never tracked or shared with third parties.
                </p>
              </div>

              <div className="flex items-start gap-2.5 p-2.5 rounded-xl bg-[var(--paper)] border border-[var(--line)]">
                <Lock className="w-4 h-4 text-[var(--terra)] shrink-0 mt-0.5" />
                <p className="not-italic text-[11px] leading-relaxed text-[var(--ink)]">
                  <b>Mutual rule:</b> You will only be able to see their location when both of you
                  have location sharing turned ON.
                </p>
              </div>

              <div className="flex items-start gap-2.5 p-2.5 rounded-xl bg-[var(--paper)] border border-[var(--line)]">
                <EyeOff className="w-4 h-4 text-[var(--soft)] shrink-0 mt-0.5" />
                <p className="not-italic text-[11px] leading-relaxed text-[var(--ink)]">
                  <b>Stop anytime:</b> Tap the toggle switch at any time to immediately stop sharing
                  and remove your pin from the map.
                </p>
              </div>
            </div>

            <div className="flex gap-2 mt-4">
              <button
                type="button"
                onClick={() => setShowConsentModal(false)}
                className="flex-1 py-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-xs font-medium text-[var(--ink)] cursor-pointer hover:opacity-85 transition"
              >
                Not Now
              </button>
              <button
                type="button"
                onClick={() => {
                  localStorage.setItem('pages_of_us_location_consent', 'true')
                  setShowConsentModal(false)
                  handleForceGpsUpdate()
                }}
                className="flex-1 py-2.5 rounded-xl bg-[var(--app-accent)] text-white text-xs font-medium cursor-pointer hover:opacity-90 transition shadow-xs flex items-center justify-center gap-1.5"
              >
                <ShieldCheck className="w-3.5 h-3.5" />
                <span>Agree & Turn ON</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL 2: Calibrate / Search Real Address (Fixes False IP Location) */}
      {showCalibrateModal && (
        <div
          className="modal-backdrop show"
          onClick={(e) => {
            if (e.target === e.currentTarget) setShowCalibrateModal(false)
          }}
        >
          <div className="modal">
            <div className="modal-handle"></div>
            <button
              type="button"
              className="close"
              onClick={() => setShowCalibrateModal(false)}
            >
              ×
            </button>
            <div className="modal-date">REAL LOCATION CALIBRATION</div>
            <h3>Set Your Real Location</h3>
            <p className="not-italic text-[11px] text-[var(--soft)] mb-3">
              On desktop PCs or devices without a GPS chip, browsers sometimes report an inaccurate IP location (e.g. ISP node). Search your real street or city below to set your pin accurately.
            </p>

            {/* Address Search Bar */}
            <div className="flex gap-2 mb-3">
              <div className="relative flex-1">
                <input
                  type="text"
                  placeholder="e.g. Salt Lake, Kolkata or your city/street..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') handleSearchAddress()
                  }}
                  className="w-full text-xs py-2 px-3 pl-8 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] focus:outline-none focus:border-[var(--app-accent)]"
                />
                <Search className="w-3.5 h-3.5 text-[var(--soft)] absolute left-2.5 top-2.5" />
              </div>
              <button
                type="button"
                onClick={handleSearchAddress}
                disabled={isSearchingAddress}
                className="py-2 px-3 rounded-xl bg-[var(--app-accent)] text-white text-xs font-medium hover:opacity-90 transition disabled:opacity-50 cursor-pointer"
              >
                {isSearchingAddress ? 'Searching...' : 'Search'}
              </button>
            </div>

            {/* Search Results Dropdown */}
            {searchResults.length > 0 && (
              <div className="space-y-1.5 max-h-48 overflow-y-auto mb-3 p-1 rounded-xl border border-[var(--line)] bg-[var(--paper)]">
                {searchResults.map((item, idx) => (
                  <button
                    key={idx}
                    type="button"
                    onClick={() => handleSelectSearchedLocation(item)}
                    className="w-full text-left p-2 rounded-lg hover:bg-[var(--white)] transition text-[11px] text-[var(--ink)] border-b border-[var(--line)] last:border-0"
                  >
                    <div className="font-semibold">{item.display_name.split(',')[0]}</div>
                    <div className="text-[9px] text-[var(--soft)] truncate">{item.display_name}</div>
                  </button>
                ))}
              </div>
            )}

            {/* Force Live GPS Button */}
            <div className="border-t border-[var(--line)] pt-3">
              <button
                type="button"
                onClick={() => {
                  setShowCalibrateModal(false)
                  handleForceGpsUpdate()
                }}
                className="w-full py-2 px-3 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-xs font-medium text-[var(--app-accent)] hover:opacity-90 transition flex items-center justify-center gap-1.5 cursor-pointer"
              >
                <Crosshair className="w-3.5 h-3.5" />
                <span>Re-detect Fresh GPS Hardware Sensor</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL 3: Add Shared Pinned Place */}
      {showAddPlaceModal && (
        <div
          className="modal-backdrop show"
          onClick={(e) => {
            if (e.target === e.currentTarget) setShowAddPlaceModal(false)
          }}
        >
          <div className="modal">
            <div className="modal-handle"></div>
            <button
              type="button"
              className="close"
              onClick={() => setShowAddPlaceModal(false)}
            >
              ×
            </button>
            <div className="modal-date">SHARED PLACES</div>
            <h3>Pin a Place for Both of You</h3>
            <p className="not-italic text-[11px] text-[var(--soft)] mb-3">
              Add places like Home, Cafe, or University. When either partner enters or leaves, Page of Us will alert the other!
            </p>

            <div className="space-y-3 mb-4">
              <div>
                <label className="text-[10px] font-semibold text-[var(--soft)] uppercase block mb-1">
                  Place Name
                </label>
                <input
                  type="text"
                  placeholder="e.g. Our Apartment, Cozy Cafe..."
                  value={newPlaceName}
                  onChange={(e) => setNewPlaceName(e.target.value)}
                  className="w-full text-xs py-2 px-3 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] focus:outline-none focus:border-[var(--app-accent)]"
                />
              </div>

              <div>
                <label className="text-[10px] font-semibold text-[var(--soft)] uppercase block mb-1">
                  Choose Cute Icon
                </label>
                <div className="grid grid-cols-4 gap-2">
                  {CUTE_PLACE_ICONS.map((p) => (
                    <button
                      key={p.label}
                      type="button"
                      onClick={() => setNewPlaceIcon(p.icon)}
                      className={`p-2 rounded-xl border text-center transition cursor-pointer ${
                        newPlaceIcon === p.icon
                          ? 'border-[var(--app-accent)] bg-[var(--white)]'
                          : 'border-[var(--line)] bg-[var(--paper)] hover:opacity-85'
                      }`}
                    >
                      <div className="text-base">{p.icon}</div>
                      <div className="text-[9px] font-medium text-[var(--ink)]">{p.label}</div>
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <label className="text-[10px] font-semibold text-[var(--soft)] uppercase block mb-1">
                  Geofence Radius: {newPlaceRadius} meters
                </label>
                <input
                  type="range"
                  min="50"
                  max="500"
                  step="25"
                  value={newPlaceRadius}
                  onChange={(e) => setNewPlaceRadius(Number(e.target.value))}
                  className="w-full accent-[var(--app-accent)]"
                />
                <div className="flex justify-between text-[9px] text-[var(--soft)]">
                  <span>50m (Cozy)</span>
                  <span>150m (Standard)</span>
                  <span>500m (Campus)</span>
                </div>
              </div>
            </div>

            <div className="flex gap-2">
              <button
                type="button"
                onClick={() => setShowAddPlaceModal(false)}
                className="flex-1 py-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-xs font-medium text-[var(--ink)] cursor-pointer hover:opacity-85 transition"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleSaveNewPlace}
                disabled={!newPlaceName.trim()}
                className="flex-1 py-2.5 rounded-xl bg-[var(--app-accent)] text-white text-xs font-medium cursor-pointer hover:opacity-90 transition shadow-xs disabled:opacity-50"
              >
                Save Pinned Place
              </button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL 4: Privacy Note (What is collected and why) */}
      {showPrivacyNoteModal && (
        <div
          className="modal-backdrop show"
          onClick={(e) => {
            if (e.target === e.currentTarget) setShowPrivacyNoteModal(false)
          }}
        >
          <div className="modal">
            <div className="modal-handle"></div>
            <button
              type="button"
              className="close"
              onClick={() => setShowPrivacyNoteModal(false)}
            >
              ×
            </button>
            <div className="modal-date">SECURITY & PRIVACY</div>
            <h3>How Location Works in Pages of Us</h3>

            <div className="space-y-3 my-3 text-xs text-[var(--soft)]">
              <p className="not-italic text-[11px] leading-relaxed text-[var(--ink)]">
                <b>What is collected:</b> GPS latitude and longitude, reverse-geocoded
                neighborhood/city, and battery percentage to let your partner know if your phone is low on charge.
              </p>
              <p className="not-italic text-[11px] leading-relaxed text-[var(--ink)]">
                <b>Why it is collected:</b> Strictly to render your dual presence, tether line, and live distance on your private shared stage.
              </p>
              <p className="not-italic text-[11px] leading-relaxed text-[var(--ink)]">
                <b>Mutual rule:</b> If you turn off sharing, your partner's pin is also hidden from your screen until you re-enable it.
              </p>
              <p className="not-italic text-[11px] leading-relaxed text-[var(--ink)]">
                <b>Data deletion:</b> Tap <i>"Clear History"</i> at the bottom of the card at any time to permanently remove all stored location coordinates.
              </p>
            </div>

            <button
              type="button"
              onClick={() => setShowPrivacyNoteModal(false)}
              className="w-full mt-2 py-2.5 rounded-xl bg-[var(--app-accent)] text-white text-xs font-medium cursor-pointer hover:opacity-90 transition"
            >
              Close Note
            </button>
          </div>
        </div>
      )}

      {/* MODAL 5: Place Tag Modal / Presets */}
      {showTagModal && (
        <div
          className="modal-backdrop show"
          onClick={(e) => {
            if (e.target === e.currentTarget) setShowTagModal(false)
          }}
        >
          <div className="modal">
            <div className="modal-handle"></div>
            <button
              type="button"
              className="close"
              onClick={() => setShowTagModal(false)}
            >
              ×
            </button>
            <div className="modal-date">LOCATION STATUS</div>
            <h3>Where are you right now?</h3>
            <p className="not-italic text-[11px] text-[var(--soft)] mb-3">
              Choose a familiar tag or preset location for your partner to see.
            </p>

            <div className="grid grid-cols-2 gap-2 mb-4">
              {PLACE_TAGS.map((tag) => (
                <button
                  key={tag}
                  type="button"
                  onClick={() => {
                    setSelectedTag(tag)
                    setShowTagModal(false)
                    if (myLoc) {
                      syncMyPosition(myLoc.lat, myLoc.lng, myLoc.accuracy, tag)
                    }
                  }}
                  className="p-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-left text-xs text-[var(--ink)] font-medium hover:opacity-85 cursor-pointer"
                >
                  {tag}
                </button>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
