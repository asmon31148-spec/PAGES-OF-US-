import React, { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { ThemeProvider, useTheme } from '@/core/theme'
import { AudioProvider } from '@/core/audio'
import { AuthProvider, useAuth } from '@/core/auth'
import { ToastProvider, useToast } from '@/core/toast'
import { realtimeBridge } from '@/core/realtime'
import confetti from 'canvas-confetti'
import { BottomNav, TabType } from '@/components/ui/BottomNav'
import {
  StageView,
  PairingModal,
  ThemeModal,
  AudioModal,
  ProfileModal,
  AuthModal,
  PermissionsOnboardingModal
} from '@/features/stage'
import { hasCompletedPermissionsOnboarding } from '@/core/permissions/permissionsService'
import {
  initNotificationChannels,
  scheduleDailyCoupleReminder,
  triggerNativeNotification
} from '@/core/notifications'
import { getFirebaseDb } from '@/core/storage/firebase'
import { collection, query, orderBy, limit, onSnapshot } from 'firebase/firestore'
import { MemoriesView } from '@/features/memories'
import { WorldView } from '@/features/world'
import { VaultView } from '@/features/vault'

const AppContent: React.FC = () => {
  const { user, space } = useAuth()
  const { theme } = useTheme()
  const { showToast } = useToast()

  const [activeTab, setActiveTab] = useState<TabType>('stage')
  const [isThemeModalOpen, setIsThemeModalOpen] = useState(false)
  const [isAudioModalOpen, setIsAudioModalOpen] = useState(false)
  const [isPairModalOpen, setIsPairModalOpen] = useState(false)
  const [isProfileModalOpen, setIsProfileModalOpen] = useState(false)
  const [isPermissionsModalOpen, setIsPermissionsModalOpen] = useState(
    () => !hasCompletedPermissionsOnboarding()
  )

  // 1. Initialize native notification channels and daily reminder on startup
  useEffect(() => {
    initNotificationChannels()
    scheduleDailyCoupleReminder()
  }, [])

  // 2. Maintain global real-time pulse and partner signal connection across all tabs
  useEffect(() => {
    if (!space?.id) return
    realtimeBridge.connect(space.id)

    const unsub = realtimeBridge.subscribe((event) => {
      // Ignore self-broadcasts if any leak through
      if (user?.id && event.senderId === user.id) return

      if (event.type === 'PULSE') {
        confetti({
          particleCount: 25,
          spread: 50,
          origin: { y: 0.6 }
        })
        showToast(`${event.senderNickname || 'Your partner'} sent you a gentle pulse ✨`)
        triggerNativeNotification({
          title: `${event.senderNickname || 'Your partner'} sent a pulse ✨`,
          body: 'A soft pulse was felt on your stage.'
        })
      } else if (event.type === 'NOTIFICATION_TRIGGER' && event.data) {
        showToast(event.data.title)

        // Native Android & Web notification
        triggerNativeNotification({
          title: event.data.title,
          body: event.data.body
        })

        try {
          if (navigator.vibrate) navigator.vibrate([80, 50, 80])
        } catch {}
      }
    })

    return () => {
      unsub()
    }
  }, [space?.id, user?.id, showToast])

  // 3. Persistent Firestore notification listener (double redundancy for background/reconnect)
  useEffect(() => {
    if (!space?.id || !user?.id) return
    const db = getFirebaseDb()
    if (!db) return

    const notifsRef = collection(db, 'spaces', space.id, 'notifications')
    const q = query(notifsRef, orderBy('timestamp', 'desc'), limit(5))

    const mountTime = Date.now()
    const unsub = onSnapshot(q, (snapshot) => {
      snapshot.docChanges().forEach((change) => {
        if (change.type === 'added') {
          const data = change.doc.data()
          if (data.senderId !== user.id && data.timestamp > mountTime) {
            triggerNativeNotification({
              title: data.title || 'Partner Alert ✨',
              body: data.body || 'Something new was shared in Pages of Us.'
            })
          }
        }
      })
    })

    return () => unsub()
  }, [space?.id, user?.id])

  // If user is not yet logged in, show permanent true Auth Screen (Log in / Sign up)
  if (!user) {
    return <AuthModal isOpen={true} />
  }

  return (
    <div
      className="min-h-[100dvh] w-full flex flex-col font-sans selection:bg-[#4d655a]/20 overflow-x-hidden transition-colors duration-300"
      style={{ backgroundColor: theme.bg, color: theme.textPrimary }}
    >
      {/* Mobile-First Centered App Container */}
      <div
        className="w-full max-w-md mx-auto min-h-[100dvh] relative flex flex-col sm:border-x sm:shadow-lg overflow-x-hidden transition-colors duration-300"
        style={{ backgroundColor: theme.bg, borderColor: theme.surfaceBorder }}
      >
        {/* Main Active Page View with Silky Smooth Framer Motion Page Transition */}
        <main className="flex-1 w-full flex flex-col">
          <AnimatePresence mode="wait">
            <motion.div
              key={activeTab}
              initial={{ opacity: 0, y: 10, scale: 0.995 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: -8, scale: 0.995 }}
              transition={{ duration: 0.22, ease: [0.16, 1, 0.3, 1] }}
              className="flex-1 w-full flex flex-col"
            >
              {activeTab === 'stage' && (
                <StageView
                  onGoToMemories={() => setActiveTab('memories')}
                  onOpenPairModal={() => setIsPairModalOpen(true)}
                  onOpenAudioModal={() => setIsAudioModalOpen(true)}
                  onOpenThemeModal={() => setIsThemeModalOpen(true)}
                  onOpenProfileModal={() => setIsProfileModalOpen(true)}
                />
              )}
              {activeTab === 'world' && <WorldView />}
              {activeTab === 'memories' && <MemoriesView />}
              {activeTab === 'vault' && <VaultView />}
            </motion.div>
          </AnimatePresence>
        </main>

        {/* Bottom Floating Navigation */}
        <BottomNav activeTab={activeTab} onSelectTab={setActiveTab} />
      </div>

      {/* Global Modals */}
      <ThemeModal
        isOpen={isThemeModalOpen}
        onClose={() => setIsThemeModalOpen(false)}
      />
      <AudioModal
        isOpen={isAudioModalOpen}
        onClose={() => setIsAudioModalOpen(false)}
      />
      <PairingModal
        isOpen={isPairModalOpen}
        onClose={() => setIsPairModalOpen(false)}
      />
      <ProfileModal
        isOpen={isProfileModalOpen}
        onClose={() => setIsProfileModalOpen(false)}
      />
      <PermissionsOnboardingModal
        isOpen={isPermissionsModalOpen}
        onComplete={() => setIsPermissionsModalOpen(false)}
      />
    </div>
  )
}

export default function App() {
  return (
    <ThemeProvider>
      <AudioProvider>
        <AuthProvider>
          <ToastProvider>
            <AppContent />
          </ToastProvider>
        </AuthProvider>
      </AudioProvider>
    </ThemeProvider>
  )
}
