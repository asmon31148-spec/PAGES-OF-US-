import {
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  signOut,
  updateProfile as updateAuthProfile,
  onAuthStateChanged,
  GoogleAuthProvider,
  signInWithPopup,
  signInWithCredential,
  sendPasswordResetEmail,
  User as FirebaseUser
} from 'firebase/auth'
import { Capacitor } from '@capacitor/core'
import { FirebaseAuthentication } from '@capacitor-firebase/authentication'
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  collection,
  query,
  where,
  getDocs,
  onSnapshot
} from 'firebase/firestore'
import { getFirebaseAuth, getFirebaseDb, isFirebaseConfigured } from '../storage/firebase'
import { getSupabaseClient } from '../storage/supabase'
import { UserProfile, SharedSpace } from './types'
import { realtimeBridge } from '../realtime'

const LOCAL_USER_KEY = 'pages_of_us_local_user'
const LOCAL_SPACE_KEY = 'pages_of_us_local_space'

export const generatePairCode = (): string => {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
  let code = ''
  for (let i = 0; i < 4; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length))
  }
  return `PAGE-${code}`
}

export const loadStoredUser = (): UserProfile | null => {
  try {
    const raw = localStorage.getItem(LOCAL_USER_KEY)
    if (raw) return JSON.parse(raw)
  } catch {}
  return null
}

export const loadStoredSpace = (): SharedSpace | null => {
  try {
    const raw = localStorage.getItem(LOCAL_SPACE_KEY)
    if (raw) return JSON.parse(raw)
  } catch {}
  return null
}

export const saveLocalSession = (user?: UserProfile | null, space?: SharedSpace | null) => {
  try {
    // Explicit full sign-out
    if (user === null && space === null) {
      localStorage.removeItem(LOCAL_USER_KEY)
      localStorage.removeItem(LOCAL_SPACE_KEY)
      return
    }

    if (user) {
      localStorage.setItem(LOCAL_USER_KEY, JSON.stringify(user))
    }

    if (space) {
      localStorage.setItem(LOCAL_SPACE_KEY, JSON.stringify(space))
    }
  } catch {}
}

// 1. Permanent Cloud Sign Up (Firebase Auth + Firestore)
export const firebaseSignUp = async (
  email: string,
  password: string,
  nickname: string
): Promise<{ user: UserProfile; space: SharedSpace }> => {
  const cleanEmail = email.trim().toLowerCase()
  const cleanNickname = nickname.trim()

  if (!cleanEmail || !password || !cleanNickname) {
    throw new Error('Please enter your nickname, email, and password.')
  }

  if (password.length < 6) {
    throw new Error('Password must be at least 6 characters.')
  }

  const auth = getFirebaseAuth()
  const db = getFirebaseDb()

  if (!auth || !db) {
    throw new Error('Firebase is not yet configured. Please verify your keys in .env.local.')
  }

  let firebaseUser: FirebaseUser | null = null

  try {
    const cred = await createUserWithEmailAndPassword(auth, cleanEmail, password)
    firebaseUser = cred.user
    await updateAuthProfile(firebaseUser, { displayName: cleanNickname })
  } catch (err: any) {
    if (err.code === 'auth/email-already-in-use') {
      // User already exists! Seamlessly attempt login with the provided password
      try {
        const cred = await signInWithEmailAndPassword(auth, cleanEmail, password)
        firebaseUser = cred.user
      } catch (signInErr: any) {
        throw new Error('An account with this email already exists. Please switch to Log In with your password.')
      }
    } else {
      throw new Error(err.message || 'Unable to create account.')
    }
  }

  if (!firebaseUser) {
    throw new Error('Unable to complete account registration.')
  }

  // Check or build UserProfile in Firestore
  let userProfile: UserProfile | null = null
  const userDocRef = doc(db, 'users', firebaseUser.uid)

  try {
    const snap = await getDoc(userDocRef)
    if (snap.exists()) {
      userProfile = snap.data() as UserProfile
    }
  } catch {}

  if (!userProfile) {
    userProfile = {
      id: firebaseUser.uid,
      email: cleanEmail,
      nickname: cleanNickname,
      avatarUrl: '',
      bio: 'A quiet digital sanctuary for us.',
      presenceStatus: 'Thinking of you 🌿',
      createdAt: new Date().toISOString(),
      lastActiveAt: new Date().toISOString()
    }
  }

  // Create or retrieve space
  let space: SharedSpace | null = null
  if (userProfile.spaceId) {
    space = await firebaseFetchSpace(userProfile.spaceId)
  }
  if (!space) {
    space = await firebaseCreateSpace(`${userProfile.nickname}'s Space`, userProfile)
    userProfile.spaceId = space.id
  }

  // Save profile to Firestore with offline support
  await setDoc(userDocRef, userProfile, { merge: true })
  saveLocalSession(userProfile, space)

  return { user: userProfile, space }
}

// 2. Permanent Cloud Sign In (Firebase Auth + Firestore)
export const firebaseSignIn = async (
  email: string,
  password: string
): Promise<{ user: UserProfile; space: SharedSpace | null }> => {
  const cleanEmail = email.trim().toLowerCase()
  const auth = getFirebaseAuth()
  const db = getFirebaseDb()

  if (!auth || !db) {
    throw new Error('Firebase is not yet configured.')
  }

  let cred: any
  try {
    cred = await signInWithEmailAndPassword(auth, cleanEmail, password)
  } catch (err: any) {
    if (err.code === 'auth/user-not-found' || err.code === 'auth/wrong-password' || err.code === 'auth/invalid-credential') {
      throw new Error('Invalid email or password.')
    }
    throw new Error(err.message || 'Error signing in.')
  }

  const firebaseUser = cred.user
  const userDocRef = doc(db, 'users', firebaseUser.uid)

  let profile: UserProfile | null = null
  try {
    const snap = await getDoc(userDocRef)
    if (snap.exists()) {
      profile = snap.data() as UserProfile
    }
  } catch {}

  if (!profile) {
    profile = {
      id: firebaseUser.uid,
      email: firebaseUser.email || cleanEmail,
      nickname: firebaseUser.displayName || cleanEmail.split('@')[0],
      avatarUrl: firebaseUser.photoURL || '',
      bio: 'A quiet digital sanctuary for us.',
      presenceStatus: 'Thinking of you 🌿',
      createdAt: new Date().toISOString(),
      lastActiveAt: new Date().toISOString()
    }
    await setDoc(userDocRef, profile, { merge: true })
  }

  let userSpace: SharedSpace | null = null
  if (profile.spaceId) {
    userSpace = await firebaseFetchSpace(profile.spaceId)
  }

  if (!userSpace) {
    userSpace = await firebaseCreateSpace(`${profile.nickname}'s Space`, profile)
    profile.spaceId = userSpace.id
    await setDoc(userDocRef, { spaceId: userSpace.id }, { merge: true })
  }

  saveLocalSession(profile, userSpace)
  return { user: profile, space: userSpace }
}

// 2B. Google 1-Tap Sign In
export const firebaseSignInWithGoogle = async (): Promise<{ user: UserProfile; space: SharedSpace | null }> => {
  const auth = getFirebaseAuth()
  const db = getFirebaseDb()
  if (!auth || !db) throw new Error('Firebase is not yet configured.')

  let cred: any
  try {
    if (Capacitor.isNativePlatform()) {
      // Native Android Google One Tap / Credential Manager bottom sheet (stays inside app)
      const result = await FirebaseAuthentication.signInWithGoogle()
      if (result.credential?.idToken) {
        const googleCred = GoogleAuthProvider.credential(result.credential.idToken)
        cred = await signInWithCredential(auth, googleCred)
      } else if (auth.currentUser) {
        cred = { user: auth.currentUser }
      } else if (result.user) {
        cred = { user: result.user }
      } else {
        throw new Error('No user returned from Google Sign-In.')
      }
    } else {
      // Web browser popup fallback
      const provider = new GoogleAuthProvider()
      provider.setCustomParameters({ prompt: 'select_account' })
      cred = await signInWithPopup(auth, provider)
    }
  } catch (err: any) {
    if (
      err.code === 'auth/popup-closed-by-user' ||
      err.message?.includes('canceled') ||
      err.message?.includes('cancelled') ||
      err.message?.includes('16')
    ) {
      throw new Error('Google Sign-In was closed.')
    }
    if (err.code === 'auth/popup-blocked') {
      throw new Error('Google Sign-In popup was blocked by your browser. Please allow popups or try email login.')
    }
    throw new Error(err.message || 'Google Sign-In failed.')
  }

  const firebaseUser = cred.user
  const cleanEmail = (firebaseUser.email || '').toLowerCase()
  const cleanNickname = firebaseUser.displayName || cleanEmail.split('@')[0] || 'Partner'
  const userDocRef = doc(db, 'users', firebaseUser.uid)

  let profile: UserProfile | null = null
  try {
    const snap = await getDoc(userDocRef)
    if (snap.exists()) {
      profile = snap.data() as UserProfile
    }
  } catch {}

  if (!profile) {
    profile = {
      id: firebaseUser.uid,
      email: cleanEmail,
      nickname: cleanNickname,
      avatarUrl: firebaseUser.photoURL || '',
      bio: 'A quiet digital sanctuary for us.',
      presenceStatus: 'Thinking of you 🌿',
      createdAt: new Date().toISOString(),
      lastActiveAt: new Date().toISOString()
    }
    await setDoc(userDocRef, profile, { merge: true })
  }

  let userSpace: SharedSpace | null = null
  if (profile.spaceId) {
    userSpace = await firebaseFetchSpace(profile.spaceId)
  }

  if (!userSpace) {
    userSpace = await firebaseCreateSpace(`${profile.nickname}'s Space`, profile)
    profile.spaceId = userSpace.id
    await setDoc(userDocRef, { spaceId: userSpace.id }, { merge: true })
  }

  saveLocalSession(profile, userSpace)
  return { user: profile, space: userSpace }
}

// 2C. Password Reset Link (Sends directly to user's email)
export const firebaseResetPassword = async (email: string): Promise<void> => {
  const cleanEmail = email.trim().toLowerCase()
  if (!cleanEmail) {
    throw new Error('Please enter your email address to receive a password reset link.')
  }
  const auth = getFirebaseAuth()
  if (!auth) throw new Error('Firebase is not configured.')

  try {
    await sendPasswordResetEmail(auth, cleanEmail)
  } catch (err: any) {
    if (err.code === 'auth/user-not-found') {
      throw new Error('No registered account found with this email. Please sign up first.')
    }
    if (err.code === 'auth/invalid-email') {
      throw new Error('Please enter a valid email address.')
    }
    throw new Error(err.message || 'Unable to send password reset email.')
  }
}

// 3. Sign Out
export const firebaseSignOut = async (): Promise<void> => {
  const auth = getFirebaseAuth()
  if (auth) {
    try {
      await signOut(auth)
    } catch {}
  }
  saveLocalSession(null, null)
}

// 4. Update Profile (Firestore + Auth)
export const firebaseUpdateProfile = async (
  user: UserProfile,
  space: SharedSpace | null,
  updates: Partial<UserProfile>
): Promise<{ user: UserProfile; space: SharedSpace | null }> => {
  const db = getFirebaseDb()
  const auth = getFirebaseAuth()

  const updatedProfile: UserProfile = {
    ...user,
    ...updates,
    lastActiveAt: new Date().toISOString()
  }

  if (db) {
    await setDoc(doc(db, 'users', user.id), updatedProfile, { merge: true })
  }

  if (auth?.currentUser) {
    try {
      await updateAuthProfile(auth.currentUser, {
        displayName: updatedProfile.nickname,
        photoURL: updatedProfile.avatarUrl
      })
    } catch {}
  }

  // Update space members in Firestore
  let updatedSpace = space
  if (space && db) {
    updatedSpace = {
      ...space,
      members: {
        ...space.members,
        [user.id]: updatedProfile
      }
    }
    await setDoc(doc(db, 'spaces', space.id), updatedSpace, { merge: true })
  }

  // Broadcast to partner in real-time
  try {
    await realtimeBridge.broadcast({
      type: 'PROFILE_UPDATE',
      senderId: user.id,
      senderNickname: updatedProfile.nickname,
      timestamp: Date.now(),
      data: updatedProfile
    })
  } catch {}

  saveLocalSession(updatedProfile, updatedSpace)
  return { user: updatedProfile, space: updatedSpace }
}

// 5. Create Space in Firestore
export const firebaseCreateSpace = async (
  spaceName: string,
  user: UserProfile
): Promise<SharedSpace> => {
  const db = getFirebaseDb()
  const spaceId = `space_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`
  const pairCode = generatePairCode()

  const newSpace: SharedSpace = {
    id: spaceId,
    spaceName,
    pairCode,
    creatorId: user.id,
    members: {
      [user.id]: user
    },
    createdAt: new Date().toISOString()
  }

  saveLocalSession(user, newSpace)

  if (db) {
    try {
      await setDoc(doc(db, 'spaces', spaceId), newSpace)
      await setDoc(doc(db, 'pair_codes', pairCode), { spaceId })
    } catch (err) {
      console.warn('Firestore space write notice (cached locally):', err)
    }
  }

  // Also sync to Supabase spaces and app_content as cloud bridge fallback
  try {
    const supabase = getSupabaseClient()
    await supabase.from('spaces').upsert({
      id: spaceId,
      space_name: spaceName,
      pair_code: pairCode,
      creator_id: user.id
    })
    await supabase.from('app_content').upsert({
      id: spaceId,
      content: newSpace,
      updated_at: new Date().toISOString()
    })
    await supabase.from('app_content').upsert({
      id: `pair_${pairCode}`,
      content: { spaceId },
      updated_at: new Date().toISOString()
    })
  } catch {}

  return newSpace
}

// 6. Join Space in Firestore
export const firebaseJoinSpace = async (
  pairCode: string,
  user: UserProfile
): Promise<SharedSpace> => {
  const db = getFirebaseDb()
  if (!db) throw new Error('Database unavailable')

  const cleanCode = pairCode.trim().toUpperCase()
  const codeSnap = await getDoc(doc(db, 'pair_codes', cleanCode))

  if (!codeSnap.exists()) {
    throw new Error('Invalid or expired pair code. Please double check with your partner.')
  }

  const spaceId = codeSnap.data().spaceId
  const spaceSnap = await getDoc(doc(db, 'spaces', spaceId))

  if (!spaceSnap.exists()) {
    throw new Error('Space not found.')
  }

  const existingSpace = spaceSnap.data() as SharedSpace
  existingSpace.partnerId = user.id
  existingSpace.members[user.id] = user

  await setDoc(doc(db, 'spaces', spaceId), existingSpace, { merge: true })
  await setDoc(doc(db, 'users', user.id), { spaceId }, { merge: true })

  // Also sync to Supabase fallback and broadcast in real-time
  try {
    const supabase = getSupabaseClient()
    await supabase.from('spaces').upsert({
      id: spaceId,
      partner_id: user.id
    })
    await supabase.from('app_content').upsert({
      id: spaceId,
      content: existingSpace,
      updated_at: new Date().toISOString()
    })
  } catch {}

  try {
    await realtimeBridge.broadcast({
      type: 'PROFILE_UPDATE',
      senderId: user.id,
      senderNickname: user.nickname,
      timestamp: Date.now(),
      data: user
    })
  } catch {}

  const updatedUser = { ...user, spaceId }
  saveLocalSession(updatedUser, existingSpace)

  return existingSpace
}

// 7. Unpair from Space (Keeps user logged in, resets to fresh space)
export const firebaseUnpairSpace = async (
  user: UserProfile,
  space: SharedSpace | null
): Promise<SharedSpace> => {
  const db = getFirebaseDb()
  if (space && db) {
    try {
      await updateDoc(doc(db, 'spaces', space.id), { partnerId: null })
    } catch {}
  }

  const newSpace = await firebaseCreateSpace(`${user.nickname}'s Space`, user)
  if (db) {
    try {
      await updateDoc(doc(db, 'users', user.id), { spaceId: newSpace.id })
    } catch {}
  }

  user.spaceId = newSpace.id
  saveLocalSession(user, newSpace)
  return newSpace
}

// 8. Fetch Space from Firestore
export const firebaseFetchSpace = async (spaceId: string): Promise<SharedSpace | null> => {
  const db = getFirebaseDb()
  if (db) {
    try {
      const snap = await getDoc(doc(db, 'spaces', spaceId))
      if (snap.exists()) {
        const spaceData = snap.data() as SharedSpace
        saveLocalSession(null, spaceData)
        return spaceData
      }
    } catch {}
  }
  return loadStoredSpace()
}
