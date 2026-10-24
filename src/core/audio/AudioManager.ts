import { Howl, Howler } from 'howler'
import { Track, AmbientSound } from './types'

type AudioEventListener = () => void

const VOLUME_STORAGE_KEY = 'pages_of_us_audio_volume'

class GlobalAudioManager {
  private currentHowl: Howl | null = null
  private ambientHowls: Map<string, Howl> = new Map()
  private listeners: Set<AudioEventListener> = new Set()

  public currentTrack: Track | null = null
  public playlist: Track[] = [
    {
      id: 'default_piano_sanctuary',
      title: 'Piano Sanctuary',
      artist: 'Pages of Us',
      audioUrl: 'https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3?filename=lofi-study-112191.mp3',
      duration: 147,
      addedBy: 'Sanctuary'
    },
    {
      id: 'default_lofi_evening',
      title: 'Midnight Reverie',
      artist: 'Acoustic Calm',
      audioUrl: 'https://cdn.pixabay.com/download/audio/2022/01/18/audio_d0a13f69d2.mp3?filename=relaxed-vlog-night-street-131746.mp3',
      duration: 132,
      addedBy: 'Sanctuary'
    }
  ]
  public isPlaying: boolean = false
  public volume: number = 90 // 0 to 100 (crisp, loud default)
  public progress: number = 0
  public duration: number = 0
  public isMuted: boolean = false

  public ambientSounds: AmbientSound[] = [
    {
      id: 'rain',
      name: 'Gentle Rain',
      icon: 'CloudRain',
      url: '/audio/rain.mp3',
      volume: 0.85,
      isPlaying: false
    },
    {
      id: 'fireplace',
      name: 'Warm Fireplace',
      icon: 'Flame',
      url: '/audio/fireplace.mp3',
      volume: 0.85,
      isPlaying: false
    },
    {
      id: 'night',
      name: 'Midnight Breeze',
      icon: 'Moon',
      url: '/audio/breeze.mp3',
      volume: 0.85,
      isPlaying: false
    }
  ]

  private progressInterval: number | null = null
  private wasPlayingBeforeDuck: boolean = false
  private activeAmbientBeforeDuck: string[] = []

  constructor() {
    try {
      const savedVolume = localStorage.getItem(VOLUME_STORAGE_KEY)
      if (savedVolume !== null) {
        this.volume = parseInt(savedVolume, 10)
      }
    } catch {}

    Howler.volume(this.volume / 100)
  }

  public subscribe(listener: AudioEventListener): () => void {
    this.listeners.add(listener)
    return () => this.listeners.delete(listener)
  }

  private notify() {
    this.listeners.forEach((listener) => listener())
  }

  public setPlaylist(tracks: Track[]) {
    this.playlist = tracks
    if (!this.currentTrack && tracks.length > 0) {
      this.currentTrack = tracks[0]
    }
    this.notify()
  }

  public playTrack(track: Track) {
    if (this.currentTrack?.id === track.id && this.currentHowl) {
      if (!this.isPlaying) {
        this.currentHowl.play()
        this.isPlaying = true
        this.startProgressTracking()
        this.notify()
      }
      return
    }

    // Stop current track cleanly
    if (this.currentHowl) {
      this.currentHowl.stop()
      this.currentHowl.unload()
      this.currentHowl = null
    }

    this.currentTrack = track
    this.isPlaying = true
    this.progress = 0
    this.duration = track.duration || 0

    if (!track.audioUrl) {
      this.isPlaying = false
      this.notify()
      return
    }

    this.currentHowl = new Howl({
      src: [track.audioUrl],
      html5: true, // html5 audio prevents memory buildup on mobile & allows long streams
      volume: this.isMuted ? 0 : this.volume / 100,
      onplay: () => {
        this.isPlaying = true
        this.duration = this.currentHowl?.duration() || track.duration || 0
        this.startProgressTracking()
        this.notify()
      },
      onpause: () => {
        this.isPlaying = false
        this.stopProgressTracking()
        this.notify()
      },
      onend: () => {
        this.nextTrack()
      },
      onloaderror: (_id, err) => {
        console.warn('Audio load error:', err)
        this.isPlaying = false
        this.stopProgressTracking()
        this.notify()
      },
      onplayerror: (_id, err) => {
        console.warn('Audio play error, retrying unlock:', err)
        this.currentHowl?.once('unlock', () => {
          this.currentHowl?.play()
        })
      }
    })

    this.currentHowl.play()
    this.notify()
  }

  public togglePlay() {
    if (!this.currentTrack) {
      if (this.playlist.length > 0) {
        this.playTrack(this.playlist[0])
      }
      return
    }

    if (this.isPlaying && this.currentHowl) {
      this.currentHowl.pause()
      this.isPlaying = false
      this.stopProgressTracking()
    } else if (this.currentHowl) {
      this.currentHowl.play()
      this.isPlaying = true
      this.startProgressTracking()
    } else {
      this.playTrack(this.currentTrack)
    }
    this.notify()
  }

  public nextTrack() {
    if (this.playlist.length === 0) return
    const currentIndex = this.playlist.findIndex((t) => t.id === this.currentTrack?.id)
    const nextIndex = (currentIndex + 1) % this.playlist.length
    this.playTrack(this.playlist[nextIndex])
  }

  public prevTrack() {
    if (this.playlist.length === 0) return
    const currentIndex = this.playlist.findIndex((t) => t.id === this.currentTrack?.id)
    const prevIndex = (currentIndex - 1 + this.playlist.length) % this.playlist.length
    this.playTrack(this.playlist[prevIndex])
  }

  public seek(seconds: number) {
    if (this.currentHowl) {
      this.currentHowl.seek(seconds)
      this.progress = seconds
      this.notify()
    }
  }

  public setVolume(vol: number) {
    this.volume = Math.max(0, Math.min(100, vol))
    const normalized = this.volume / 100
    if (this.currentHowl && !this.isMuted) {
      this.currentHowl.volume(normalized)
    }
    try {
      localStorage.setItem(VOLUME_STORAGE_KEY, this.volume.toString())
    } catch {}
    this.notify()
  }

  public toggleMute() {
    this.isMuted = !this.isMuted
    if (this.currentHowl) {
      this.currentHowl.volume(this.isMuted ? 0 : this.volume / 100)
    }
    this.ambientHowls.forEach((howl, soundId) => {
      const sound = this.ambientSounds.find((s) => s.id === soundId)
      howl.volume(this.isMuted ? 0 : (sound?.volume ?? 0.95))
    })
    this.notify()
  }

  // Ambient Layer Controls
  public toggleAmbient(soundId: string) {
    const sound = this.ambientSounds.find((s) => s.id === soundId)
    if (!sound) return

    sound.isPlaying = !sound.isPlaying

    let howl = this.ambientHowls.get(soundId)
    if (sound.isPlaying) {
      if (!howl) {
        howl = new Howl({
          src: [sound.url],
          html5: true,
          loop: true,
          volume: this.isMuted ? 0 : sound.volume,
          onloaderror: (_id, err) => {
            console.warn(`Ambient sound '${soundId}' load error:`, err)
            sound.isPlaying = false
            this.notify()
          },
          onplayerror: (_id, err) => {
            console.warn(`Ambient sound '${soundId}' play error, unlocking:`, err)
            howl?.once('unlock', () => {
              howl?.play()
            })
          }
        })
        this.ambientHowls.set(soundId, howl)
      } else {
        howl.volume(this.isMuted ? 0 : sound.volume)
      }
      howl.play()
    } else {
      if (howl) {
        howl.pause()
      }
    }
    this.notify()
  }

  public setAmbientVolume(soundId: string, volume: number) {
    const sound = this.ambientSounds.find((s) => s.id === soundId)
    if (!sound) return
    sound.volume = Math.max(0, Math.min(1, volume))
    const howl = this.ambientHowls.get(soundId)
    if (howl && !this.isMuted) {
      howl.volume(sound.volume)
    }
    this.notify()
  }

  // Audio Ducking for Voice Whispers, Video Playback & Modals
  public duckForMedia() {
    if (this.isPlaying && this.currentHowl) {
      this.wasPlayingBeforeDuck = true
      this.currentHowl.pause()
      this.isPlaying = false
      this.stopProgressTracking()
    }
    // Duck active ambient layers
    this.activeAmbientBeforeDuck = []
    this.ambientSounds.forEach((s) => {
      if (s.isPlaying) {
        this.activeAmbientBeforeDuck.push(s.id)
        const howl = this.ambientHowls.get(s.id)
        if (howl) howl.pause()
        s.isPlaying = false
      }
    })
    this.notify()
  }

  public restoreFromMedia() {
    if (this.wasPlayingBeforeDuck && this.currentHowl) {
      this.currentHowl.play()
      this.isPlaying = true
      this.startProgressTracking()
      this.wasPlayingBeforeDuck = false
    }
    // Restore active ambient layers
    if (this.activeAmbientBeforeDuck.length > 0) {
      this.activeAmbientBeforeDuck.forEach((id) => {
        const sound = this.ambientSounds.find((s) => s.id === id)
        const howl = this.ambientHowls.get(id)
        if (sound && howl) {
          sound.isPlaying = true
          howl.play()
        }
      })
      this.activeAmbientBeforeDuck = []
    }
    this.notify()
  }

  private startProgressTracking() {
    this.stopProgressTracking()
    this.progressInterval = window.setInterval(() => {
      if (this.currentHowl && this.isPlaying) {
        const seek = this.currentHowl.seek()
        if (typeof seek === 'number') {
          this.progress = seek
          this.notify()
        }
      }
    }, 1000)
  }

  private stopProgressTracking() {
    if (this.progressInterval) {
      clearInterval(this.progressInterval)
      this.progressInterval = null
    }
  }
}

export const audioManager = new GlobalAudioManager()
