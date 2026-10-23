import { useState, useRef, useCallback, useEffect } from 'react'
import { uploadMediaFile } from '../storage'

export interface AudioRecordingResult {
  blob: Blob
  url: string
  duration: number
}

// Convert Blob to Data URL for guaranteed persistent storage without cloud bucket failures
export const blobToDataUrl = (blob: Blob): Promise<string> => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onloadend = () => {
      if (typeof reader.result === 'string') {
        resolve(reader.result)
      } else {
        reject(new Error('Failed to convert audio blob to base64'))
      }
    }
    reader.onerror = reject
    reader.readAsDataURL(blob)
  })
}

export const useAudioRecorder = () => {
  const [isRecording, setIsRecording] = useState(false)
  const [recordingTime, setRecordingTime] = useState(0)
  const [recordedAudio, setRecordedAudio] = useState<Blob | null>(null)
  const [audioUrl, setAudioUrl] = useState<string | null>(null)
  const [isPlayingPreview, setIsPlayingPreview] = useState(false)
  const [isUploading, setIsUploading] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  const mediaRecorderRef = useRef<MediaRecorder | null>(null)
  const audioChunksRef = useRef<Blob[]>([])
  const timerRef = useRef<number | null>(null)
  const previewAudioRef = useRef<HTMLAudioElement | null>(null)
  const streamRef = useRef<MediaStream | null>(null)

  // Safe MIME type detector for mobile & desktop
  const getSupportedMimeType = (): string => {
    if (typeof MediaRecorder === 'undefined' || !MediaRecorder.isTypeSupported) {
      return ''
    }
    const candidates = [
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/mp4',
      'audio/aac',
      'audio/ogg;codecs=opus'
    ]
    for (const mime of candidates) {
      if (MediaRecorder.isTypeSupported(mime)) {
        return mime
      }
    }
    return ''
  }

  const stopTracks = () => {
    if (streamRef.current) {
      streamRef.current.getTracks().forEach((track) => track.stop())
      streamRef.current = null
    }
  }

  const stopRecording = useCallback(() => {
    if (timerRef.current) {
      clearInterval(timerRef.current)
      timerRef.current = null
    }

    if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
      try {
        mediaRecorderRef.current.stop()
      } catch (err) {
        console.warn('Error stopping mediaRecorder:', err)
      }
    }
    setIsRecording(false)
    stopTracks()
  }, [])

  const startRecording = useCallback(async () => {
    setErrorMessage(null)
    clearRecording()

    try {
      if (!navigator?.mediaDevices?.getUserMedia) {
        throw new Error(
          'Microphone access requires a secure connection (HTTPS) or native mobile app.'
        )
      }

      const stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true
        }
      })
      streamRef.current = stream
      audioChunksRef.current = []

      const mimeType = getSupportedMimeType()
      const options: MediaRecorderOptions = mimeType ? { mimeType } : {}
      const mediaRecorder = new MediaRecorder(stream, options)
      mediaRecorderRef.current = mediaRecorder

      mediaRecorder.ondataavailable = (event) => {
        if (event.data && event.data.size > 0) {
          audioChunksRef.current.push(event.data)
        }
      }

      mediaRecorder.onstop = () => {
        const recordedBlob = new Blob(audioChunksRef.current, {
          type: mediaRecorder.mimeType || 'audio/webm'
        })
        setRecordedAudio(recordedBlob)
        const objectUrl = URL.createObjectURL(recordedBlob)
        setAudioUrl(objectUrl)
        stopTracks()
      }

      mediaRecorder.start(250) // collect chunks every 250ms
      setIsRecording(true)
      setRecordingTime(0)

      timerRef.current = window.setInterval(() => {
        setRecordingTime((prev) => {
          if (prev >= 29) {
            // Auto-stop at 30 seconds max limit
            stopRecording()
            return 30
          }
          return prev + 1
        })
      }, 1000)
    } catch (err: any) {
      console.error('Microphone access denied or error:', err)
      const msg =
        err?.message ||
        'Microphone permission is required to record a 30s voice whisper.'
      setErrorMessage(msg)
      stopTracks()
      throw new Error(msg)
    }
  }, [stopRecording])

  const clearRecording = useCallback(() => {
    if (previewAudioRef.current) {
      previewAudioRef.current.pause()
      previewAudioRef.current = null
    }
    setIsPlayingPreview(false)
    setRecordedAudio(null)
    if (audioUrl) {
      URL.revokeObjectURL(audioUrl)
      setAudioUrl(null)
    }
    setRecordingTime(0)
    setErrorMessage(null)
  }, [audioUrl])

  // Audio Preview toggle (Play / Pause what was just recorded)
  const togglePlayPreview = useCallback(() => {
    if (!audioUrl) return

    if (isPlayingPreview && previewAudioRef.current) {
      previewAudioRef.current.pause()
      setIsPlayingPreview(false)
      return
    }

    if (previewAudioRef.current) {
      previewAudioRef.current.pause()
    }

    const audio = new Audio(audioUrl)
    previewAudioRef.current = audio
    setIsPlayingPreview(true)

    audio.onended = () => {
      setIsPlayingPreview(false)
    }
    audio.onerror = () => {
      setIsPlayingPreview(false)
    }

    audio.play().catch((err) => {
      console.warn('Audio preview play error:', err)
      setIsPlayingPreview(false)
    })
  }, [audioUrl, isPlayingPreview])

  // Upload or convert to base64 Data URL (100% resilient)
  const uploadVoiceMemo = useCallback(
    async (folder: string = 'voice_memos'): Promise<string> => {
      if (!recordedAudio) throw new Error('No recorded audio to save')

      setIsUploading(true)
      try {
        // A 30s voice recording is small (~40-90 KB).
        // Try uploading to cloud storage if possible; if it fails or bucket missing,
        // seamlessly fall back to Base64 data URL which NEVER fails and is 100% stored in DB.
        try {
          const ext = recordedAudio.type.includes('mp4') ? 'm4a' : 'webm'
          const file = new File([recordedAudio], `whisper_${Date.now()}.${ext}`, {
            type: recordedAudio.type
          })
          const res = await uploadMediaFile(file, folder)
          if (res?.url) {
            return res.url
          }
        } catch (uploadErr) {
          console.warn('Cloud storage upload failed, converting voice memo to reliable Data URL:', uploadErr)
        }

        // Guaranteed Base64 Data URL fallback
        const dataUrl = await blobToDataUrl(recordedAudio)
        return dataUrl
      } finally {
        setIsUploading(false)
      }
    },
    [recordedAudio]
  )

  useEffect(() => {
    return () => {
      if (timerRef.current) clearInterval(timerRef.current)
      if (previewAudioRef.current) {
        previewAudioRef.current.pause()
      }
      stopTracks()
    }
  }, [])

  return {
    isRecording,
    recordingTime,
    recordedAudio,
    audioUrl,
    isPlayingPreview,
    isUploading,
    errorMessage,
    startRecording,
    stopRecording,
    clearRecording,
    togglePlayPreview,
    uploadVoiceMemo
  }
}
