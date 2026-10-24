export function syncAndroidWidget(
  partnerName?: string,
  partnerThought?: string,
  daysTogether?: number | string
) {
  try {
    if (typeof window !== 'undefined' && (window as any).AndroidWidget?.updateWidget) {
      (window as any).AndroidWidget.updateWidget(
        partnerName || 'Partner',
        partnerThought || 'Thinking of you...',
        daysTogether ? `Day ${daysTogether} ✦` : 'Together ✦'
      )
    }
  } catch (err) {
    // Graceful fallback on web or non-Android environments
  }
}
