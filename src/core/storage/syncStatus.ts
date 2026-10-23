import { useState, useEffect } from 'react'

export type SyncState = 'synced' | 'syncing' | 'offline' | 'error'

export interface SyncStatusInfo {
  status: SyncState
  pendingCount: number
  lastSyncedAt: Date | null
  errorMessage: string | null
}

let currentSyncStatus: SyncStatusInfo = {
  status: navigator.onLine ? 'synced' : 'offline',
  pendingCount: 0,
  lastSyncedAt: new Date(),
  errorMessage: null
}

const listeners = new Set<(status: SyncStatusInfo) => void>()

export const updateSyncStatus = (updates: Partial<SyncStatusInfo>) => {
  currentSyncStatus = { ...currentSyncStatus, ...updates }
  listeners.forEach((listener) => listener(currentSyncStatus))
}

export const useSyncStatus = () => {
  const [status, setStatus] = useState<SyncStatusInfo>(currentSyncStatus)

  useEffect(() => {
    const handleOnline = () => {
      updateSyncStatus({ status: 'synced', errorMessage: null })
    }
    const handleOffline = () => {
      updateSyncStatus({ status: 'offline' })
    }

    window.addEventListener('online', handleOnline)
    window.addEventListener('offline', handleOffline)

    listeners.add(setStatus)
    return () => {
      window.removeEventListener('online', handleOnline)
      window.removeEventListener('offline', handleOffline)
      listeners.delete(setStatus)
    }
  }, [])

  return status
}
