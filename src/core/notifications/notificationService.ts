import { LocalNotifications, Channel } from '@capacitor/local-notifications'
import { Capacitor } from '@capacitor/core'

export const NOTIFICATION_CHANNEL_ID = 'pages_of_us_alerts'

/**
 * Initialize Android High-Priority Notification Channel
 */
export const initNotificationChannels = async (): Promise<void> => {
  if (!Capacitor.isNativePlatform()) return

  try {
    const channel: Channel = {
      id: NOTIFICATION_CHANNEL_ID,
      name: 'Pages of Us Alerts',
      description: 'Notifications for love letters, partner pulses, and shared moments',
      importance: 5, // High priority (pops up heads-up banner on screen with sound)
      visibility: 1, // Visible on lockscreen
      vibration: true,
      lights: true,
      lightColor: '#e07a5f'
    }
    await LocalNotifications.createChannel(channel)
  } catch (err) {
    console.warn('[NotificationService] Channel creation warning:', err)
  }
}

/**
 * Check and Request Real Native System Notification Permission
 */
export const requestNativeNotificationPermission = async (): Promise<'granted' | 'denied' | 'unavailable'> => {
  if (Capacitor.isNativePlatform()) {
    try {
      const check = await LocalNotifications.checkPermissions()
      if (check.display === 'granted') return 'granted'

      const req = await LocalNotifications.requestPermissions()
      return req.display === 'granted' ? 'granted' : 'denied'
    } catch (err) {
      console.warn('[NotificationService] Native permission request error:', err)
      return 'denied'
    }
  }

  // Web Browser fallback
  if ('Notification' in window) {
    try {
      const res = await Notification.requestPermission()
      return res === 'granted' ? 'granted' : 'denied'
    } catch {
      return 'denied'
    }
  }

  return 'unavailable'
}

/**
 * Trigger an Immediate Native Notification (Status Bar & Heads-up Banner)
 */
export const triggerNativeNotification = async (options: {
  title: string
  body: string
  id?: number
  scheduleAt?: Date
}): Promise<boolean> => {
  const notifId = options.id ?? Math.floor(Math.random() * 2147483640) + 1

  if (Capacitor.isNativePlatform()) {
    try {
      await LocalNotifications.schedule({
        notifications: [
          {
            id: notifId,
            title: options.title,
            body: options.body,
            channelId: NOTIFICATION_CHANNEL_ID,
            schedule: options.scheduleAt
              ? { at: options.scheduleAt, allowWhileIdle: true }
              : { at: new Date(Date.now() + 100), allowWhileIdle: true },
            smallIcon: 'ic_launcher_round'
          }
        ]
      })
      return true
    } catch (err) {
      console.warn('[NotificationService] Native schedule error:', err)
    }
  }

  // Browser / Web fallback
  if ('Notification' in window && Notification.permission === 'granted') {
    try {
      new Notification(options.title, {
        body: options.body,
        icon: '/favicon.svg'
      })
      return true
    } catch {}
  }

  return false
}

/**
 * Send an Instant Test Notification to verify on phone
 */
export const sendTestNotification = async (): Promise<boolean> => {
  await initNotificationChannels()

  const perm = await requestNativeNotificationPermission()
  if (perm !== 'granted') {
    return false
  }

  return triggerNativeNotification({
    title: '💌 Pages of Us Notification Test',
    body: 'Your phone notifications are working perfectly! You will receive partner alerts here. ✨'
  })
}

/**
 * Schedule a Daily Gentle Couple Reminder (e.g. 8:30 PM)
 */
export const scheduleDailyCoupleReminder = async (): Promise<void> => {
  if (!Capacitor.isNativePlatform()) return

  try {
    const pending = await LocalNotifications.getPending()
    const alreadyScheduled = pending.notifications.some((n) => n.id === 99999)
    if (alreadyScheduled) return

    const scheduledTime = new Date()
    scheduledTime.setHours(20, 30, 0, 0)
    if (scheduledTime.getTime() <= Date.now()) {
      scheduledTime.setDate(scheduledTime.getDate() + 1)
    }

    await LocalNotifications.schedule({
      notifications: [
        {
          id: 99999,
          title: '✨ Daily Question for Two',
          body: 'A new daily thought is waiting for you and your partner.',
          channelId: NOTIFICATION_CHANNEL_ID,
          schedule: {
            at: scheduledTime,
            repeats: true,
            every: 'day',
            allowWhileIdle: true
          },
          smallIcon: 'ic_launcher_round'
        }
      ]
    })
  } catch (err) {
    console.warn('[NotificationService] Daily reminder schedule error:', err)
  }
}
