import { requestNativeNotificationPermission, initNotificationChannels } from '@/core/notifications'

export interface PermissionStatusMap {
  notifications: 'granted' | 'denied' | 'prompt' | 'unavailable'
  camera: 'granted' | 'denied' | 'prompt' | 'unavailable'
  microphone: 'granted' | 'denied' | 'prompt' | 'unavailable'
  location: 'granted' | 'denied' | 'prompt' | 'unavailable'
}

const ONBOARDING_KEY = 'pages_of_us_permissions_onboarding_done'

export const hasCompletedPermissionsOnboarding = (): boolean => {
  return localStorage.getItem(ONBOARDING_KEY) === 'true'
}

export const markPermissionsOnboardingComplete = () => {
  localStorage.setItem(ONBOARDING_KEY, 'true')
}

// 1. Request Notification Permission (Native Android & Web)
export const requestNotificationPermission = async (): Promise<'granted' | 'denied' | 'unavailable'> => {
  await initNotificationChannels()
  return requestNativeNotificationPermission()
}

// 2. Request Camera & Microphone Permission
export const requestMediaPermissions = async (): Promise<{
  camera: 'granted' | 'denied' | 'unavailable'
  microphone: 'granted' | 'denied' | 'unavailable'
}> => {
  if (!navigator.mediaDevices?.getUserMedia) {
    return { camera: 'unavailable', microphone: 'unavailable' }
  }

  let camera: 'granted' | 'denied' | 'unavailable' = 'denied'
  let microphone: 'granted' | 'denied' | 'unavailable' = 'denied'

  try {
    const stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true })
    camera = 'granted'
    microphone = 'granted'
    // Stop all tracks immediately so camera and mic indicators turn off
    stream.getTracks().forEach((track) => track.stop())
  } catch (err: any) {
    // If combined failed, attempt audio and video separately
    try {
      const vidStream = await navigator.mediaDevices.getUserMedia({ video: true })
      camera = 'granted'
      vidStream.getTracks().forEach((track) => track.stop())
    } catch {}

    try {
      const audStream = await navigator.mediaDevices.getUserMedia({ audio: true })
      microphone = 'granted'
      audStream.getTracks().forEach((track) => track.stop())
    } catch {}
  }

  return { camera, microphone }
}

// 3. Request Location Permission
export const requestLocationPermission = async (): Promise<'granted' | 'denied' | 'unavailable'> => {
  if (!navigator.geolocation) return 'unavailable'
  return new Promise((resolve) => {
    navigator.geolocation.getCurrentPosition(
      () => resolve('granted'),
      () => resolve('denied'),
      { timeout: 8000, enableHighAccuracy: true }
    )
  })
}

// Sequence all permissions on initial install
export const requestAllSanctuaryPermissions = async (
  onProgress?: (step: 'notifications' | 'media' | 'location') => void
): Promise<PermissionStatusMap> => {
  onProgress?.('notifications')
  const notifications = await requestNotificationPermission()

  onProgress?.('media')
  const { camera, microphone } = await requestMediaPermissions()

  onProgress?.('location')
  const location = await requestLocationPermission()

  markPermissionsOnboardingComplete()

  return {
    notifications,
    camera,
    microphone,
    location
  }
}
