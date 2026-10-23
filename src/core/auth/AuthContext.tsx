import React, { createContext, useContext, useEffect, useState, useMemo } from 'react'
import { UserProfile, SharedSpace } from './types'
import {
  loadStoredUser,
  loadStoredSpace,
  saveLocalSession,
  loginAsGuest,
  cloudSignUp,
  cloudSignIn,
  cloudSignOut,
  cloudUpdateProfile,
  createCloudSpace,
  joinCloudSpace,
  unpairCloudSpace,
  fetchLatestSpace,
  cloudSignInWithGoogle,
  cloudResetPassword,
  cloudInitRecaptcha,
  cloudSendPhoneCode,
  cloudVerifyPhoneCode
} from './authService'
import { getSupabaseClient } from '../storage/supabase'
import { getFirebaseAuth, getFirebaseDb, isFirebaseConfigured } from '../storage/firebase'
import { onAuthStateChanged } from 'firebase/auth'
import { doc, getDoc, onSnapshot } from 'firebase/firestore'
import { updateSyncStatus } from '../storage/syncStatus'
import { realtimeBridge } from '../realtime'

interface AuthContextType {
  user: UserProfile | null
  space: SharedSpace | null
  partner: UserProfile | null
  isPaired: boolean
  isLoading: boolean
  signUp: (email: string, password: string, nickname: string) => Promise<void>
  signIn: (email: string, password: string) => Promise<void>
  signInWithGoogle: () => Promise<void>
  resetPassword: (email: string) => Promise<void>
  initPhoneRecaptcha: (containerId: string) => any
  sendPhoneCode: (phoneNumber: string, verifier: any) => Promise<any>
  verifyPhoneCode: (confirmationResult: any, code: string, nickname?: string) => Promise<void>
  loginGuest: (nickname?: string) => void
  logout: () => Promise<void>
  updateProfile: (updates: Partial<UserProfile>) => Promise<void>
  createSpace: (spaceName: string) => Promise<SharedSpace>
  joinSpace: (code: string) => Promise<SharedSpace>
  unpairSpace: () => Promise<void>
  updatePresence: (status: string) => Promise<void>
}

const AuthContext = createContext<AuthContextType | null>(null)

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<UserProfile | null>(() => loadStoredUser())
  const [space, setSpace] = useState<SharedSpace | null>(() => loadStoredSpace())
  const [isLoading, setIsLoading] = useState<boolean>(false)

  // 1. Auto-check & restore permanent Auth session on mount (Firebase or Supabase fallback)
  useEffect(() => {
    if (isFirebaseConfigured()) {
      const auth = getFirebaseAuth()
      const db = getFirebaseDb()
      if (!auth || !db) return

      let unsubSpace: (() => void) | null = null

      const unsubAuth = onAuthStateChanged(auth, async (firebaseUser) => {
        if (!firebaseUser) {
          const stored = loadStoredUser()
          if (stored) {
            // Keep existing session active across reloads and offline periods!
            setUser(stored)
            const storedSp = loadStoredSpace()
            if (storedSp) setSpace(storedSp)

            // Listen in real-time to partner updates on the space for guest sessions too!
            if (stored.spaceId && db) {
              if (unsubSpace) unsubSpace()
              unsubSpace = onSnapshot(doc(db, 'spaces', stored.spaceId), (spaceSnap) => {
                if (spaceSnap.exists()) {
                  const freshSpace = spaceSnap.data() as SharedSpace
                  setSpace(freshSpace)
                  saveLocalSession(null, freshSpace)
                  updateSyncStatus({ status: 'synced', lastSyncedAt: new Date() })
                }
              })
            }
            return
          }
          setUser(null)
          setSpace(null)
          if (unsubSpace) unsubSpace()
          return
        }

        try {
          const userDocRef = doc(db, 'users', firebaseUser.uid)
          const snap = await getDoc(userDocRef)
          let p: UserProfile | null = snap.exists() ? (snap.data() as UserProfile) : null

          if (!p) {
            p = {
              id: firebaseUser.uid,
              email: firebaseUser.email || '',
              nickname: firebaseUser.displayName || firebaseUser.email?.split('@')[0] || 'Partner',
              avatarUrl: firebaseUser.photoURL || '',
              bio: 'A quiet digital sanctuary for us.',
              presenceStatus: 'Thinking of you 🌿',
              createdAt: new Date().toISOString(),
              lastActiveAt: new Date().toISOString()
            }
          }

          setUser(p)
          saveLocalSession(p, space)

          if (p.spaceId) {
            const sp = await fetchLatestSpace(p.spaceId)
            if (sp) setSpace(sp)

            // Listen in real-time to partner updates on the space
            if (unsubSpace) unsubSpace()
            unsubSpace = onSnapshot(doc(db, 'spaces', p.spaceId), (spaceSnap) => {
              if (spaceSnap.exists()) {
                const freshSpace = spaceSnap.data() as SharedSpace
                setSpace(freshSpace)
                saveLocalSession(null, freshSpace)
                updateSyncStatus({ status: 'synced', lastSyncedAt: new Date() })
              }
            })
          }
        } catch (err) {
          console.warn('Firebase user restore error (using local cache):', err)
        }
      })

      return () => {
        unsubAuth()
        if (unsubSpace) unsubSpace()
      }
    }

    // Fallback: Supabase Auth session listener
    const supabase = getSupabaseClient()

    const initAuthSession = async () => {
      try {
        const { data } = await supabase.auth.getSession()
        if (data?.session?.user) {
          const authUser = data.session.user
          // Fetch cloud profile
          let cloudProfile: UserProfile | null = null
          try {
            const { data: profileDoc } = await supabase
              .from('app_content')
              .select('content')
              .eq('id', `profile_${authUser.id}`)
              .single()

            if (profileDoc?.content) {
              cloudProfile = profileDoc.content as UserProfile
            }
          } catch {}

          if (!cloudProfile) {
            cloudProfile = {
              id: authUser.id,
              email: authUser.email || '',
              nickname: authUser.user_metadata?.nickname || authUser.email?.split('@')[0] || 'Partner',
              avatarUrl: authUser.user_metadata?.avatarUrl || '',
              bio: 'A quiet digital sanctuary for us.',
              presenceStatus: 'Thinking of you 🌿',
              createdAt: authUser.created_at || new Date().toISOString(),
              lastActiveAt: new Date().toISOString()
            }
            try {
              await supabase.from('app_content').upsert({
                id: `profile_${cloudProfile.id}`,
                content: cloudProfile,
                updated_at: new Date().toISOString()
              })
            } catch {}
          }

          setUser(cloudProfile)
          saveLocalSession(cloudProfile, space)

          if (cloudProfile.spaceId) {
            const cloudSpace = await fetchLatestSpace(cloudProfile.spaceId)
            if (cloudSpace) setSpace(cloudSpace)
          }
        }
      } catch (err) {
        console.warn('Error checking Supabase auth session:', err)
      }
    }

    initAuthSession()

    // Listen to Supabase Auth state changes (permanent session listener)
    const { data: authListener } = supabase.auth.onAuthStateChange(
      async (event, session) => {
        if (event === 'SIGNED_OUT') {
          setUser(null)
          setSpace(null)
          saveLocalSession(null, null)
        } else if (session?.user && event === 'SIGNED_IN') {
          const authUser = session.user
          let p: UserProfile | null = null
          try {
            const { data: profileDoc } = await supabase
              .from('app_content')
              .select('content')
              .eq('id', `profile_${authUser.id}`)
              .single()

            if (profileDoc?.content) {
              p = profileDoc.content as UserProfile
            }
          } catch {}

          if (!p) {
            p = {
              id: authUser.id,
              email: authUser.email || '',
              nickname: authUser.user_metadata?.nickname || authUser.email?.split('@')[0] || 'Partner',
              avatarUrl: authUser.user_metadata?.avatarUrl || '',
              bio: 'A quiet digital sanctuary for us.',
              presenceStatus: 'Thinking of you 🌿',
              createdAt: authUser.created_at || new Date().toISOString(),
              lastActiveAt: new Date().toISOString()
            }
          }

          setUser(p)
          saveLocalSession(p, space)

          if (p.spaceId) {
            const sp = await fetchLatestSpace(p.spaceId)
            if (sp) setSpace(sp)
          }
        }
      }
    )

    return () => {
      authListener?.subscription.unsubscribe()
    }
  }, [])

  // Derive partner profile if connected
  const partner = useMemo(() => {
    if (!space || !user) return null
    const partnerId = Object.keys(space.members).find((id) => id !== user.id)
    return partnerId ? space.members[partnerId] : null
  }, [space, user])

  const isPaired = Boolean(partner)

  // Ensure every user has a space with an invite code on startup
  useEffect(() => {
    if (user && !space && !isLoading) {
      createCloudSpace(`${user.nickname}'s Space`, user)
        .then((newSpace) => {
          setSpace(newSpace)
          saveLocalSession(user, newSpace)
        })
        .catch(() => {
          const fallbackSpace: SharedSpace = {
            id: `space_${Date.now()}`,
            spaceName: `${user.nickname}'s Space`,
            pairCode: `PAGE-${Math.floor(1000 + Math.random() * 9000)}`,
            creatorId: user.id,
            members: { [user.id]: user },
            createdAt: new Date().toISOString()
          }
          setSpace(fallbackSpace)
          saveLocalSession(user, fallbackSpace)
        })
    }
  }, [user, space, isLoading])

  // Real-time synchronization for space membership & partner presence
  useEffect(() => {
    if (!space?.id) return

    const supabase = getSupabaseClient()
    const channelName = `space:${space.id}`

    const channel = supabase
      .channel(channelName)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'app_content',
          filter: `id=eq.${space.id}`
        },
        (payload: any) => {
          if (payload.new?.content) {
            const updated = payload.new.content as SharedSpace
            setSpace(updated)
            saveLocalSession(null, updated)
            updateSyncStatus({ status: 'synced', lastSyncedAt: new Date() })
          }
        }
      )
      .subscribe()

    // Realtime broadcast for live profile / note changes
    const unsubBroadcast = realtimeBridge.subscribe((event) => {
      if (event.type === 'PROFILE_UPDATE' && event.data) {
        const updatedProfile = event.data as UserProfile
        if (updatedProfile.id !== user?.id) {
          setSpace((prev) => {
            if (!prev) return prev
            return {
              ...prev,
              members: {
                ...prev.members,
                [updatedProfile.id]: updatedProfile
              }
            }
          })
        }
      }
    })

    // Firestore live snapshot for space changes (members joining / profile updates)
    let unsubFirestoreSpace: (() => void) | null = null
    const db = getFirebaseDb()
    if (db) {
      try {
        unsubFirestoreSpace = onSnapshot(doc(db, 'spaces', space.id), (snap) => {
          if (snap.exists()) {
            const fresh = snap.data() as SharedSpace
            setSpace(fresh)
            saveLocalSession(null, fresh)
            updateSyncStatus({ status: 'synced', lastSyncedAt: new Date() })
          }
        })
      } catch (err) {
        console.warn('Firestore space realtime notice:', err)
      }
    }

    // Periodically sync space state when window regains focus
    const onFocus = () => {
      fetchLatestSpace(space.id).then((fresh) => {
        if (fresh) setSpace(fresh)
      })
    }
    window.addEventListener('focus', onFocus)

    return () => {
      window.removeEventListener('focus', onFocus)
      if (unsubFirestoreSpace) unsubFirestoreSpace()
      supabase.removeChannel(channel)
      unsubBroadcast()
    }
  }, [space?.id, user?.id])

  // True Cloud Sign Up
  const signUp = async (email: string, password: string, nickname: string) => {
    setIsLoading(true)
    try {
      const res = await cloudSignUp(email, password, nickname)
      setUser(res.user)
      setSpace(res.space)
    } finally {
      setIsLoading(false)
    }
  }

  // True Cloud Sign In
  const signIn = async (email: string, password: string) => {
    setIsLoading(true)
    try {
      const res = await cloudSignIn(email, password)
      setUser(res.user)
      if (res.space) setSpace(res.space)
    } finally {
      setIsLoading(false)
    }
  }

  // Google 1-Tap Sign In
  const signInWithGoogle = async () => {
    setIsLoading(true)
    try {
      const res = await cloudSignInWithGoogle()
      setUser(res.user)
      if (res.space) setSpace(res.space)
    } finally {
      setIsLoading(false)
    }
  }

  // Password Reset Link
  const resetPassword = async (email: string) => {
    setIsLoading(true)
    try {
      await cloudResetPassword(email)
    } finally {
      setIsLoading(false)
    }
  }

  // Phone Auth
  const initPhoneRecaptcha = (containerId: string) => {
    return cloudInitRecaptcha(containerId)
  }

  const sendPhoneCode = async (phoneNumber: string, verifier: any) => {
    setIsLoading(true)
    try {
      return await cloudSendPhoneCode(phoneNumber, verifier)
    } finally {
      setIsLoading(false)
    }
  }

  const verifyPhoneCode = async (confirmationResult: any, code: string, nickname?: string) => {
    setIsLoading(true)
    try {
      const res = await cloudVerifyPhoneCode(confirmationResult, code, nickname)
      setUser(res.user)
      if (res.space) setSpace(res.space)
    } finally {
      setIsLoading(false)
    }
  }

  // Instant Guest / Offline access
  const loginGuest = (nickname = 'Maya') => {
    const res = loginAsGuest(nickname)
    setUser(res.user)
    setSpace(res.space)
  }

  // Sign Out
  const logout = async () => {
    setIsLoading(true)
    try {
      await cloudSignOut()
      setUser(null)
      setSpace(null)
    } finally {
      setIsLoading(false)
    }
  }

  // Customize Profile (Instagram-style permanent account attributes)
  const updateProfile = async (updates: Partial<UserProfile>) => {
    if (!user) return
    setIsLoading(true)
    try {
      const res = await cloudUpdateProfile(user, space, updates)
      setUser(res.user)
      if (res.space) setSpace(res.space)
    } finally {
      setIsLoading(false)
    }
  }

  const createSpace = async (spaceName: string): Promise<SharedSpace> => {
    if (!user) throw new Error('Must be logged in to create a space')
    setIsLoading(true)
    try {
      const newSpace = await createCloudSpace(spaceName, user)
      const updatedUser: UserProfile = { ...user, spaceId: newSpace.id }
      setUser(updatedUser)
      setSpace(newSpace)
      saveLocalSession(updatedUser, newSpace)
      return newSpace
    } finally {
      setIsLoading(false)
    }
  }

  const joinSpace = async (code: string): Promise<SharedSpace> => {
    if (!user) throw new Error('Must be logged in to join a space')
    setIsLoading(true)
    try {
      const joinedSpace = await joinCloudSpace(code, user)
      const updatedUser: UserProfile = { ...user, spaceId: joinedSpace.id }
      setUser(updatedUser)
      setSpace(joinedSpace)
      saveLocalSession(updatedUser, joinedSpace)
      return joinedSpace
    } finally {
      setIsLoading(false)
    }
  }

  const unpairSpace = async (): Promise<void> => {
    if (!user) return
    setIsLoading(true)
    try {
      const freshSpace = await unpairCloudSpace(user, space)
      const updatedUser: UserProfile = { ...user, spaceId: freshSpace.id }
      setUser(updatedUser)
      setSpace(freshSpace)
      saveLocalSession(updatedUser, freshSpace)
    } finally {
      setIsLoading(false)
    }
  }

  const updatePresence = async (presenceStatus: string) => {
    if (!user) return
    await updateProfile({ presenceStatus })
  }

  return (
    <AuthContext.Provider
      value={{
        user,
        space,
        partner,
        isPaired,
        isLoading,
        signUp,
        signIn,
        signInWithGoogle,
        resetPassword,
        initPhoneRecaptcha,
        sendPhoneCode,
        verifyPhoneCode,
        loginGuest,
        logout,
        updateProfile,
        createSpace,
        joinSpace,
        unpairSpace,
        updatePresence
      }}
    >
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = (): AuthContextType => {
  const context = useContext(AuthContext)
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}
