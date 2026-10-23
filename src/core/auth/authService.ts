import { createClient } from '@supabase/supabase-js'
import { getSupabaseClient } from '../storage/supabase'
import { isFirebaseConfigured, getFirebaseAuth, getFirebaseDb } from '../storage/firebase'
import { createUserWithEmailAndPassword } from 'firebase/auth'
import { doc, setDoc } from 'firebase/firestore'
import {
  firebaseSignUp,
  firebaseSignIn,
  firebaseSignOut,
  firebaseUpdateProfile,
  firebaseCreateSpace,
  firebaseJoinSpace,
  firebaseUnpairSpace,
  firebaseFetchSpace,
  firebaseSignInWithGoogle,
  firebaseResetPassword,
  firebaseInitRecaptcha,
  firebaseSendPhoneCode,
  firebaseVerifyPhoneCode,
  firebaseLoginAsGuest
} from './firebaseAuthService'
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

export const loginAsGuest = (
  nickname = 'Maya'
): { user: UserProfile; space: SharedSpace } => {
  if (isFirebaseConfigured()) {
    return firebaseLoginAsGuest(nickname)
  }

  const guestUser: UserProfile = {
    id: `guest_${Date.now()}`,
    email: '',
    nickname,
    avatarUrl: '',
    bio: 'A quiet digital sanctuary for us.',
    presenceStatus: 'Thinking of you 🌿',
    createdAt: new Date().toISOString(),
    lastActiveAt: new Date().toISOString()
  }
  const guestSpace: SharedSpace = {
    id: `space_${Date.now()}`,
    spaceName: `${nickname}'s Space`,
    pairCode: generatePairCode(),
    creatorId: guestUser.id,
    members: { [guestUser.id]: guestUser },
    createdAt: new Date().toISOString()
  }
  guestUser.spaceId = guestSpace.id
  saveLocalSession(guestUser, guestSpace)

  // Asynchronously register in Supabase so Phone B can pair with this code
  try {
    const supabase = getSupabaseClient()
    supabase.from('spaces').upsert({
      id: guestSpace.id,
      space_name: guestSpace.spaceName,
      pair_code: guestSpace.pairCode,
      creator_id: guestUser.id
    }).then(null, () => {})

    supabase.from('app_content').upsert({
      id: guestSpace.id,
      content: guestSpace,
      updated_at: new Date().toISOString()
    }).then(null, () => {})

    supabase.from('app_content').upsert({
      id: `pair_${guestSpace.pairCode}`,
      content: { spaceId: guestSpace.id },
      updated_at: new Date().toISOString()
    }).then(null, () => {})
  } catch {}

  return { user: guestUser, space: guestSpace }
}

const getAdminSupabaseClient = () => {
  const secretKey =
    import.meta.env.VITE_SUPABASE_SECRET_KEY ||
    import.meta.env.SUPABASE_SECRET_KEY ||
    'sb_secret_UTcJ-2s9TUXxxsvymP6QEA_krmvDQsE'
  const url = import.meta.env.VITE_SUPABASE_URL || 'https://qzycnvpyjrphvxogndjd.supabase.co'
  return createClient(url, secretKey, {
    auth: { autoRefreshToken: false, persistSession: false }
  })
}

// 1. Permanent Cloud Sign Up (Auto-confirmed account)
export const cloudSignUp = async (
  email: string,
  password: string,
  nickname: string
): Promise<{ user: UserProfile; space: SharedSpace }> => {
  if (isFirebaseConfigured()) {
    return firebaseSignUp(email, password, nickname)
  }

  const cleanEmail = email.trim().toLowerCase()
  const cleanNickname = nickname.trim()

  if (!cleanEmail || !password || !cleanNickname) {
    throw new Error('Please enter your nickname, email, and password.')
  }

  if (password.length < 6) {
    throw new Error('Password must be at least 6 characters.')
  }

  const adminClient = getAdminSupabaseClient()
  const anonClient = getSupabaseClient()

  let authUser: any = null

  // 1. Create auto-confirmed user in Supabase Auth via Admin API
  const { data: createData, error: createError } = await adminClient.auth.admin.createUser({
    email: cleanEmail,
    password,
    email_confirm: true,
    user_metadata: {
      nickname: cleanNickname
    }
  })

  if (createError) {
    const errorMsg = (createError.message || '').toLowerCase()
    const isAlreadyRegistered =
      errorMsg.includes('already registered') ||
      errorMsg.includes('already been registered') ||
      errorMsg.includes('already exists')

    if (isAlreadyRegistered) {
      // Account exists already! Attempt auto-login with the provided credentials seamlessly
      const { data: signInData, error: signInError } = await anonClient.auth.signInWithPassword({
        email: cleanEmail,
        password
      })

      if (signInError || !signInData.user) {
        throw new Error('An account with this email already exists. Please switch to Log In with your password.')
      }

      authUser = signInData.user
    } else {
      // If admin createUser failed for another reason (e.g. rate limit/network), fallback to anonClient.signUp
      try {
        const { data: anonSignUpData, error: anonSignUpError } = await anonClient.auth.signUp({
          email: cleanEmail,
          password,
          options: {
            data: { nickname: cleanNickname }
          }
        })
        if (anonSignUpError) {
          throw new Error(createError.message || anonSignUpError.message)
        }
        authUser = anonSignUpData.user
      } catch {
        throw new Error(createError.message)
      }
    }
  } else {
    authUser = createData.user
  }

  if (!authUser) {
    throw new Error('Unable to create account. Please try again.')
  }

  // 2. Ensure session is active in anon client
  const { data: sessionData } = await anonClient.auth.getSession()
  if (!sessionData?.session) {
    const { error: signInError } = await anonClient.auth.signInWithPassword({
      email: cleanEmail,
      password
    })
    if (signInError) {
      console.warn('Session sign-in notice:', signInError)
    }
  }

  // 3. Build or fetch Permanent User Profile
  let userProfile: UserProfile | null = null
  try {
    const { data: profileDoc } = await anonClient
      .from('app_content')
      .select('content')
      .eq('id', `profile_${authUser.id}`)
      .single()

    if (profileDoc?.content) {
      userProfile = profileDoc.content as UserProfile
    }
  } catch {}

  if (!userProfile) {
    userProfile = {
      id: authUser.id,
      email: cleanEmail,
      nickname: cleanNickname || authUser.user_metadata?.nickname || 'Partner',
      avatarUrl: authUser.user_metadata?.avatarUrl || '',
      bio: 'A quiet digital sanctuary for us.',
      presenceStatus: 'Thinking of you 🌿',
      createdAt: authUser.created_at || new Date().toISOString(),
      lastActiveAt: new Date().toISOString()
    }
  }

  // 4. Create user's couple space if none exists
  let space: SharedSpace | null = null
  if (userProfile.spaceId) {
    space = await fetchLatestSpace(userProfile.spaceId)
  }
  if (!space) {
    space = await createCloudSpace(`${userProfile.nickname}'s Space`, userProfile)
    userProfile.spaceId = space.id
  }

  // 5. Store permanent profile in Supabase app_content (both admin and anon attempt)
  try {
    await adminClient.from('app_content').upsert({
      id: `profile_${userProfile.id}`,
      content: userProfile,
      updated_at: new Date().toISOString()
    })
  } catch {
    try {
      await anonClient.from('app_content').upsert({
        id: `profile_${userProfile.id}`,
        content: userProfile,
        updated_at: new Date().toISOString()
      })
    } catch {}
  }

  saveLocalSession(userProfile, space)
  return { user: userProfile, space }
}

// 2. Permanent Cloud Sign In
export const cloudSignIn = async (
  email: string,
  password: string
): Promise<{ user: UserProfile; space: SharedSpace | null }> => {
  const cleanEmail = email.trim().toLowerCase()

  if (isFirebaseConfigured()) {
    try {
      return await firebaseSignIn(cleanEmail, password)
    } catch (fbErr: any) {
      // If Firebase failed, check if account exists in Supabase
      try {
        const anonClient = getSupabaseClient()
        const { data: supaData, error: supaErr } = await anonClient.auth.signInWithPassword({
          email: cleanEmail,
          password
        })

        if (!supaErr && supaData?.user) {
          const auth = getFirebaseAuth()
          const db = getFirebaseDb()
          if (auth && db) {
            let migratedUser = null
            try {
              const cred = await createUserWithEmailAndPassword(auth, cleanEmail, password)
              migratedUser = cred.user
            } catch (createErr: any) {
              if (createErr.code === 'auth/email-already-in-use') {
                throw new Error('Incorrect password. If you forgot your password, tap "Forgot password?" to receive a reset link.')
              }
            }

            if (migratedUser) {
              const profile: UserProfile = {
                id: migratedUser.uid,
                email: cleanEmail,
                nickname: supaData.user.user_metadata?.nickname || cleanEmail.split('@')[0],
                avatarUrl: '',
                bio: 'A quiet digital sanctuary for us.',
                presenceStatus: 'Thinking of you 🌿',
                createdAt: new Date().toISOString(),
                lastActiveAt: new Date().toISOString()
              }
              const space = await firebaseCreateSpace(`${profile.nickname}'s Space`, profile)
              profile.spaceId = space.id
              await setDoc(doc(db, 'users', migratedUser.uid), profile, { merge: true })
              saveLocalSession(profile, space)
              return { user: profile, space }
            }
          }
        }
      } catch (legacyErr: any) {
        if (legacyErr.message?.includes('Incorrect password')) {
          throw legacyErr
        }
      }

      throw fbErr
    }
  }

  const anonClient = getSupabaseClient()
  const adminClient = getAdminSupabaseClient()

  const { data, error } = await anonClient.auth.signInWithPassword({
    email: cleanEmail,
    password
  })

  if (error || !data.user) {
    throw new Error(error?.message || 'Invalid email or password.')
  }

  const authUser = data.user

  // Fetch permanent profile from app_content
  let profile: UserProfile | null = null
  try {
    const { data: profileDoc } = await anonClient
      .from('app_content')
      .select('content')
      .eq('id', `profile_${authUser.id}`)
      .single()

    if (profileDoc?.content) {
      profile = profileDoc.content as UserProfile
    }
  } catch {}

  if (!profile) {
    profile = {
      id: authUser.id,
      email: authUser.email || cleanEmail,
      nickname: authUser.user_metadata?.nickname || cleanEmail.split('@')[0],
      avatarUrl: authUser.user_metadata?.avatarUrl || '',
      bio: 'A quiet digital sanctuary for us.',
      presenceStatus: 'Thinking of you 🌿',
      createdAt: authUser.created_at || new Date().toISOString(),
      lastActiveAt: new Date().toISOString()
    }

    try {
      await adminClient.from('app_content').upsert({
        id: `profile_${profile.id}`,
        content: profile,
        updated_at: new Date().toISOString()
      })
    } catch {
      try {
        await anonClient.from('app_content').upsert({
          id: `profile_${profile.id}`,
          content: profile,
          updated_at: new Date().toISOString()
        })
      } catch {}
    }
  }

  // Fetch user's shared space
  let userSpace: SharedSpace | null = null
  if (profile.spaceId) {
    userSpace = await fetchLatestSpace(profile.spaceId)
  }

  if (!userSpace) {
    try {
      const { data: spaceRows } = await anonClient
        .from('spaces')
        .select('*')
        .or(`creator_id.eq.${authUser.id},partner_id.eq.${authUser.id}`)
        .limit(1)

      if (spaceRows && spaceRows.length > 0) {
        userSpace = await fetchLatestSpace(spaceRows[0].id)
      }
    } catch {}
  }

  if (!userSpace) {
    userSpace = await createCloudSpace(`${profile.nickname}'s Space`, profile)
    profile.spaceId = userSpace.id
    try {
      await adminClient.from('app_content').upsert({
        id: `profile_${profile.id}`,
        content: profile,
        updated_at: new Date().toISOString()
      })
    } catch {}
  }

  saveLocalSession(profile, userSpace)
  return { user: profile, space: userSpace }
}

// 3. Cloud Sign Out
export const cloudSignOut = async (): Promise<void> => {
  if (isFirebaseConfigured()) {
    return firebaseSignOut()
  }
  const anonClient = getSupabaseClient()
  try {
    await anonClient.auth.signOut()
  } catch {}
  saveLocalSession(null, null)
}

// 3B. Google 1-Tap Sign In
export const cloudSignInWithGoogle = async (): Promise<{ user: UserProfile; space: SharedSpace | null }> => {
  if (isFirebaseConfigured()) {
    return firebaseSignInWithGoogle()
  }
  throw new Error('Google Sign-In is only supported when Firebase is configured.')
}

// 3C. Password Reset Link
export const cloudResetPassword = async (email: string): Promise<void> => {
  if (isFirebaseConfigured()) {
    return firebaseResetPassword(email)
  }
  const anonClient = getSupabaseClient()
  const { error } = await anonClient.auth.resetPasswordForEmail(email)
  if (error) throw new Error(error.message)
}

// 3D. Phone Number Verification (SMS OTP)
export const cloudInitRecaptcha = (containerId: string) => {
  return firebaseInitRecaptcha(containerId)
}

export const cloudSendPhoneCode = async (phoneNumber: string, verifier: any) => {
  return firebaseSendPhoneCode(phoneNumber, verifier)
}

export const cloudVerifyPhoneCode = async (
  confirmationResult: any,
  code: string,
  nickname?: string
): Promise<{ user: UserProfile; space: SharedSpace | null }> => {
  return firebaseVerifyPhoneCode(confirmationResult, code, nickname)
}

// 4. Permanent Profile Customization Update
export const cloudUpdateProfile = async (
  user: UserProfile,
  space: SharedSpace | null,
  updates: Partial<UserProfile>
): Promise<{ user: UserProfile; space: SharedSpace | null }> => {
  if (isFirebaseConfigured()) {
    return firebaseUpdateProfile(user, space, updates)
  }
  const anonClient = getSupabaseClient()

  const updatedProfile: UserProfile = {
    ...user,
    ...updates,
    lastActiveAt: new Date().toISOString()
  }

  // 1. Update app_content profile document
  await anonClient.from('app_content').upsert({
    id: `profile_${user.id}`,
    content: updatedProfile,
    updated_at: new Date().toISOString()
  })

  // 2. Update Supabase Auth user metadata
  try {
    await anonClient.auth.updateUser({
      data: {
        nickname: updatedProfile.nickname,
        avatarUrl: updatedProfile.avatarUrl,
        bio: updatedProfile.bio,
        presenceStatus: updatedProfile.presenceStatus
      }
    })
  } catch {}

  // 3. Update space members so partner sees changes in real time
  let updatedSpace = space
  if (space) {
    updatedSpace = {
      ...space,
      members: {
        ...space.members,
        [user.id]: updatedProfile
      }
    }

    try {
      await anonClient.from('app_content').upsert({
        id: space.id,
        content: updatedSpace,
        updated_at: new Date().toISOString()
      })
    } catch {}
  }

  // 4. Broadcast live update to partner
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

// Create a new shared space in Supabase `spaces` table
export const createCloudSpace = async (
  spaceName: string,
  user: UserProfile
): Promise<SharedSpace> => {
  if (isFirebaseConfigured()) {
    return firebaseCreateSpace(spaceName, user)
  }
  const supabase = getSupabaseClient()
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

  try {
    // 1. Insert into dedicated spaces table
    await supabase.from('spaces').upsert({
      id: spaceId,
      space_name: spaceName,
      pair_code: pairCode,
      creator_id: user.id
    })

    // 2. Keep document fallback in app_content
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
  } catch (err) {
    console.warn('Supabase space sync warning (saved locally):', err)
  }

  return newSpace
}

// Join an existing space using the pair code
export const joinCloudSpace = async (
  pairCode: string,
  user: UserProfile
): Promise<SharedSpace> => {
  if (isFirebaseConfigured()) {
    return firebaseJoinSpace(pairCode, user)
  }
  const supabase = getSupabaseClient()
  const cleanCode = pairCode.trim().toUpperCase()

  // 1. Check dedicated spaces table first
  const { data: spaceRow } = await supabase
    .from('spaces')
    .select('*')
    .eq('pair_code', cleanCode)
    .single()

  let spaceId = spaceRow?.id

  // Fallback to app_content lookup if needed
  if (!spaceId) {
    const { data: pairDoc } = await supabase
      .from('app_content')
      .select('content')
      .eq('id', `pair_${cleanCode}`)
      .single()
    spaceId = pairDoc?.content?.spaceId
  }

  if (!spaceId) {
    throw new Error('Invalid or expired pair code. Please double check with your partner.')
  }

  // 2. Fetch the space details
  let existingSpace = loadStoredSpace()
  const { data: spaceDoc } = await supabase
    .from('app_content')
    .select('content')
    .eq('id', spaceId)
    .single()

  if (spaceDoc?.content) {
    existingSpace = spaceDoc.content
  } else if (spaceRow) {
    existingSpace = {
      id: spaceRow.id,
      spaceName: spaceRow.space_name,
      pairCode: spaceRow.pair_code,
      creatorId: spaceRow.creator_id,
      members: {},
      createdAt: spaceRow.created_at
    }
  }

  if (!existingSpace) {
    throw new Error('Unable to retrieve space details. Please try again.')
  }

  existingSpace.partnerId = user.id
  existingSpace.members[user.id] = user

  // 3. Save updated space to spaces & app_content
  await supabase.from('spaces').update({ partner_id: user.id }).eq('id', spaceId)
  await supabase.from('app_content').upsert({
    id: spaceId,
    content: existingSpace,
    updated_at: new Date().toISOString()
  })

  // 4. Update user's profile with spaceId
  const updatedUser: UserProfile = { ...user, spaceId }
  await supabase.from('app_content').upsert({
    id: `profile_${user.id}`,
    content: updatedUser,
    updated_at: new Date().toISOString()
  })

  saveLocalSession(updatedUser, existingSpace)
  return existingSpace
}

export const unpairCloudSpace = async (
  user: UserProfile,
  space: SharedSpace | null
): Promise<SharedSpace> => {
  if (isFirebaseConfigured()) {
    return firebaseUnpairSpace(user, space)
  }
  const supabase = getSupabaseClient()
  if (space) {
    try {
      await supabase.from('spaces').update({ partner_id: null }).eq('id', space.id)
    } catch {}
  }
  const newSpace = await createCloudSpace(`${user.nickname}'s Space`, user)
  user.spaceId = newSpace.id
  saveLocalSession(user, newSpace)
  return newSpace
}

// Fetch latest space status from cloud
export const fetchLatestSpace = async (spaceId: string): Promise<SharedSpace | null> => {
  if (isFirebaseConfigured()) {
    return firebaseFetchSpace(spaceId)
  }
  try {
    const supabase = getSupabaseClient()
    const { data } = await supabase
      .from('app_content')
      .select('content')
      .eq('id', spaceId)
      .single()

    if (data?.content) {
      saveLocalSession(null, data.content)
      return data.content as SharedSpace
    }
  } catch (err) {
    console.warn('Error fetching latest space:', err)
  }
  return loadStoredSpace()
}
