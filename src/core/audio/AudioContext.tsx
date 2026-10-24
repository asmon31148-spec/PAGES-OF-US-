import React, { createContext, useContext, useEffect, useState } from 'react'
import { audioManager } from './AudioManager'
import { Track, AmbientSound } from './types'

interface AudioContextType {
  currentTrack: Track | null
  isPlaying: boolean
  volume: number
  progress: number
  duration: number
  isMuted: boolean
  playlist: Track[]
  ambientSounds: AmbientSound[]
  playTrack: (track: Track) => void
  togglePlay: () => void
  nextTrack: () => void
  prevTrack: () => void
  seek: (seconds: number) => void
  setVolume: (volume: number) => void
  toggleMute: () => void
  toggleAmbient: (soundId: string) => void
  setAmbientVolume: (soundId: string, volume: number) => void
  setPlaylist: (tracks: Track[]) => void
  duckForMedia: () => void
  restoreFromMedia: () => void
}

const AudioContext = createContext<AudioContextType | null>(null)

export const AudioProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [, setTick] = useState(0)

  useEffect(() => {
    const unsubscribe = audioManager.subscribe(() => {
      setTick((t) => t + 1)
    })
    return () => unsubscribe()
  }, [])

  return (
    <AudioContext.Provider
      value={{
        currentTrack: audioManager.currentTrack,
        isPlaying: audioManager.isPlaying,
        volume: audioManager.volume,
        progress: audioManager.progress,
        duration: audioManager.duration,
        isMuted: audioManager.isMuted,
        playlist: audioManager.playlist,
        ambientSounds: audioManager.ambientSounds,
        playTrack: (t) => audioManager.playTrack(t),
        togglePlay: () => audioManager.togglePlay(),
        nextTrack: () => audioManager.nextTrack(),
        prevTrack: () => audioManager.prevTrack(),
        seek: (s) => audioManager.seek(s),
        setVolume: (v) => audioManager.setVolume(v),
        toggleMute: () => audioManager.toggleMute(),
        toggleAmbient: (id) => audioManager.toggleAmbient(id),
        setAmbientVolume: (id, v) => audioManager.setAmbientVolume(id, v),
        setPlaylist: (tracks) => audioManager.setPlaylist(tracks),
        duckForMedia: () => audioManager.duckForMedia(),
        restoreFromMedia: () => audioManager.restoreFromMedia()
      }}
    >
      {children}
    </AudioContext.Provider>
  )
}

export const useAudio = () => {
  const context = useContext(AudioContext)
  if (!context) {
    throw new Error('useAudio must be used within an AudioProvider')
  }
  return context
}
