export interface Track {
  id: string
  title: string
  artist: string
  audioUrl: string
  coverUrl?: string
  duration?: number // in seconds
  addedBy?: string
}

export interface AmbientSound {
  id: string
  name: string
  icon: string
  url: string
  volume: number // 0 to 1
  isPlaying: boolean
}

export interface AudioState {
  currentTrack: Track | null
  isPlaying: boolean
  volume: number // 0 to 100
  progress: number // current time in seconds
  duration: number // total duration in seconds
  isMuted: boolean
  playlist: Track[]
  ambientSounds: AmbientSound[]
}
