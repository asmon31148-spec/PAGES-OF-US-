import { getSupabaseClient, MEDIA_BUCKET_NAME } from './supabase'
import { isCloudinaryConfigured, uploadToCloudinary } from './cloudinary'

export interface UploadProgressCallback {
  (percentage: number): void
}

export interface UploadResult {
  url: string
  fileName: string
  size: number
  contentType: string
  provider: 'cloudinary' | 'supabase'
  thumbnailUrl?: string
}

// Compress images client-side before cloud upload to guarantee fast uploads on mobile
export const compressImage = (
  file: File,
  maxWidth: number = 1600,
  quality: number = 0.85
): Promise<Blob> => {
  return new Promise((resolve, reject) => {
    if (!file.type.startsWith('image/') || file.type === 'image/gif') {
      return resolve(file)
    }

    const reader = new FileReader()
    reader.onload = (e) => {
      const img = new Image()
      img.onload = () => {
        let width = img.width
        let height = img.height

        if (width > maxWidth) {
          height = Math.round((height * maxWidth) / width)
          width = maxWidth
        }

        const canvas = document.createElement('canvas')
        canvas.width = width
        canvas.height = height
        const ctx = canvas.getContext('2d')
        if (!ctx) {
          return resolve(file)
        }

        ctx.drawImage(img, 0, 0, width, height)
        canvas.toBlob(
          (blob) => {
            if (blob) {
              resolve(blob)
            } else {
              resolve(file)
            }
          },
          'image/jpeg',
          quality
        )
      }
      img.onerror = () => resolve(file)
      img.src = e.target?.result as string
    }
    reader.onerror = (err) => reject(err)
    reader.readAsDataURL(file)
  })
}

// Resilient unified media uploader: Prefers Cloudinary if configured, falls back to Supabase
export const uploadMediaFile = async (
  file: File,
  folder: string = 'memories',
  onProgress?: UploadProgressCallback
): Promise<UploadResult> => {
  const isImage = file.type.startsWith('image/')
  let uploadPayload: Blob | File = file

  if (isImage) {
    onProgress?.(10)
    uploadPayload = await compressImage(file)
    onProgress?.(25)
  }

  // 1. If Cloudinary is configured, upload directly to Cloudinary CDN
  if (isCloudinaryConfigured()) {
    try {
      const cRes = await uploadToCloudinary(uploadPayload, {
        folder,
        onProgress: (pct) => {
          // Remap 0-100 to 25-100 range
          onProgress?.(25 + Math.round((pct * 75) / 100))
        }
      })
      return {
        url: cRes.url,
        fileName: file.name,
        size: cRes.bytes,
        contentType: file.type,
        provider: 'cloudinary',
        thumbnailUrl: cRes.thumbnailUrl
      }
    } catch (cErr) {
      console.warn('Cloudinary upload error, falling back to Supabase Storage:', cErr)
    }
  }

  // 2. Fallback to Supabase Storage
  const supabase = getSupabaseClient()
  const ext = file.name.split('.').pop() || (isImage ? 'jpg' : 'bin')
  const uniqueName = `${folder}/${Date.now()}_${Math.random().toString(36).substring(2, 9)}.${ext}`

  return new Promise((resolve, reject) => {
    const supabaseUrl = (supabase as any).supabaseUrl || 'https://qzycnvpyjrphvxogndjd.supabase.co'
    const supabaseKey = (supabase as any).supabaseKey || 'sb_publishable_H5qrH4beZA17m8FoHyy-DA_yCLlyH5H'
    const endpoint = `${supabaseUrl}/storage/v1/object/${MEDIA_BUCKET_NAME}/${uniqueName}`

    const xhr = new XMLHttpRequest()
    xhr.open('POST', endpoint, true)
    xhr.timeout = 120000

    xhr.setRequestHeader('apikey', supabaseKey)
    xhr.setRequestHeader('Authorization', `Bearer ${supabaseKey}`)
    xhr.setRequestHeader('Content-Type', file.type || 'application/octet-stream')
    xhr.setRequestHeader('x-upsert', 'true')

    if (xhr.upload && onProgress) {
      xhr.upload.onprogress = (e) => {
        if (e.lengthComputable) {
          const progress = 25 + Math.round((e.loaded / e.total) * 75)
          onProgress(progress)
        }
      }
    }

    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        const publicUrl = `${supabaseUrl}/storage/v1/object/public/${MEDIA_BUCKET_NAME}/${uniqueName}`
        onProgress?.(100)
        resolve({
          url: publicUrl,
          fileName: file.name,
          size: uploadPayload.size,
          contentType: file.type,
          provider: 'supabase'
        })
      } else {
        reject(new Error(`Storage error (${xhr.status}): ${xhr.responseText}`))
      }
    }

    xhr.onerror = () => reject(new Error('Network connection error during upload.'))
    xhr.ontimeout = () => reject(new Error('Media upload timed out. Check your connection.'))

    xhr.send(uploadPayload)
  })
}
