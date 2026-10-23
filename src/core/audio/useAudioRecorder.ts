import { useState, useRef, useCallback } from 'react'
import { uploadMediaFile } from '../storage'

export interface AudioRecordingResult {
  blob: Blob
  url: string
  duration: number
}

export const useAudioRecorder = () => {
  const [isRecording, setIsRecording] = useState(false)
  const [recordingTime, setRecordingTime] = useState(0)
  const [recordedAudio, setRecordedAudio] = useState<Blob | null>(null)
  const [audioUrl, setAudioUrl] = useState<string | null>(null)
  const [isUploading, setIsUploading] = useState(false)

  const mediaRecorderRef = useRef<MediaRecorder | null>(null)
  const audioChunksRef = useRef<Blob[]>([])
  const timerRef = useRef<number | null>(null)

  const startRecording = useCallback(async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      audioChunksRef.current = []

      const mediaRecorder = new MediaRecorder(stream, {
        mimeType: MediaRecorder.isTypeSupported('audio/webm')
          ? 'audio/webm'
          : 'audio/mp4'
      })

      mediaRecorderRef.current = mediaRecorder

      mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          audioChunksRef.current.push(event.data)
        }
      }

      mediaRecorder.onstop = () => {
        const audioBlob = new Blob(audioChunksRef.current, {
          type: mediaRecorder.mimeType
        })
        setRecordedAudio(audioBlob)
        setAudioUrl(URL.createObjectURL(audioBlob))

        // Stop all audio tracks to release microphone
        stream.getTracks().forEach((track) => track.stop())
      }

      mediaRecorder.start(250) // collect chunks every 250ms
      setIsRecording(true)
      setRecordingTime(0)

      timerRef.current = window.setInterval(() => {
        setRecordingTime((prev) => prev + 1)
      }, 1000)
    } catch (err) {
      console.error('Microphone access denied or error:', err)
      throw new Error('Microphone permission required to record voice memo.')
    }
  }, [])

  const stopRecording = useCallback(() => {
    if (mediaRecorderRef.current && isRecording) {
      mediaRecorderRef.current.stop()
      setIsRecording(false)
      if (timerRef.current) {
        clearInterval(timerRef.current)
        timerRef.current = null
      }
    }
  }, [isRecording])

  const clearRecording = useCallback(() => {
    setRecordedAudio(null)
    if (audioUrl) {
      URL.revokeObjectURL(audioUrl)
      setAudioUrl(null)
    }
    setRecordingTime(0)
  }, [audioUrl])

  const uploadVoiceMemo = useCallback(
    async (folder: string = 'voice_memos'): Promise<string> => {
      if (!recordedAudio) throw new Error('No recorded audio to upload')

      setIsUploading(true)
      try {
        const file = new File(
          [recordedAudio],
          `voice_${Date.now()}.${recordedAudio.type.includes('mp4') ? 'm4a' : 'webm'}`,
          { type: recordedAudio.type }
        )

        const res = await uploadMediaFile(file, folder)
        return res.url
      } finally {
        setIsUploading(false)
      }
    },
    [recordedAudio]
  )

  return {
    isRecording,
    recordingTime,
    recordedAudio,
    audioUrl,
    isUploading,
    startRecording,
    stopRecording,
    clearRecording,
    uploadVoiceMemo
  }
}
