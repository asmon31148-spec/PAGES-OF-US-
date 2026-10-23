import { initializeApp, getApps, getApp, FirebaseApp } from 'firebase/app'
import { getAuth, Auth } from 'firebase/auth'
import {
  initializeFirestore,
  getFirestore,
  Firestore,
  persistentLocalCache,
  persistentMultipleTabManager
} from 'firebase/firestore'
import { getStorage, FirebaseStorage } from 'firebase/storage'

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY || '',
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN || '',
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID || '',
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET || '',
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID || '',
  appId: import.meta.env.VITE_FIREBASE_APP_ID || ''
}

export const isFirebaseConfigured = (): boolean => {
  return Boolean(firebaseConfig.apiKey && firebaseConfig.projectId)
}

let app: FirebaseApp | null = null
let authInstance: Auth | null = null
let dbInstance: Firestore | null = null
let storageInstance: FirebaseStorage | null = null

export const getFirebaseApp = (): FirebaseApp | null => {
  if (!isFirebaseConfigured()) return null
  if (!app) {
    app = getApps().length > 0 ? getApp() : initializeApp(firebaseConfig)
  }
  return app
}

// Eagerly initialize default app on module load if configured
try {
  getFirebaseApp()
} catch {}

export const getFirebaseAuth = (): Auth | null => {
  const firebaseApp = getFirebaseApp()
  if (!firebaseApp) return null
  if (!authInstance) {
    authInstance = getAuth(firebaseApp)
  }
  return authInstance
}

export const getFirebaseDb = (): Firestore | null => {
  const firebaseApp = getFirebaseApp()
  if (!firebaseApp) return null
  if (!dbInstance) {
    try {
      dbInstance = initializeFirestore(firebaseApp, {
        localCache: persistentLocalCache({
          tabManager: persistentMultipleTabManager()
        })
      })
    } catch {
      dbInstance = getFirestore(firebaseApp)
    }
  }
  return dbInstance
}

export const getFirebaseStorage = (): FirebaseStorage | null => {
  const firebaseApp = getFirebaseApp()
  if (!firebaseApp) return null
  if (!storageInstance) {
    storageInstance = getStorage(firebaseApp)
  }
  return storageInstance
}
