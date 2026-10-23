export interface CloudinaryUploadOptions {
  cloudName?: string
  uploadPreset?: string
  folder?: string
  onProgress?: (percent: number) => void
}

export interface CloudinaryUploadResult {
  url: string
  secureUrl: string
  publicId: string
  format: string
  resourceType: string
  bytes: number
  width?: number
  height?: number
  thumbnailUrl?: string
}

export const CLOUDINARY_CLOUD_NAME =
  import.meta.env.VITE_CLOUDINARY_CLOUD_NAME || 'i8bn5qmo'

export const CLOUDINARY_UPLOAD_PRESET =
  import.meta.env.VITE_CLOUDINARY_UPLOAD_PRESET || 'pages_of_us_preset'

export const isCloudinaryConfigured = (): boolean => {
  return Boolean(CLOUDINARY_CLOUD_NAME && CLOUDINARY_UPLOAD_PRESET)
}

export const uploadToCloudinary = async (
  file: File | Blob,
  options: CloudinaryUploadOptions = {}
): Promise<CloudinaryUploadResult> => {
  const cloudName = options.cloudName || CLOUDINARY_CLOUD_NAME
  const uploadPreset = options.uploadPreset || CLOUDINARY_UPLOAD_PRESET
  const folder = options.folder || 'pages_of_us'

  if (!cloudName || !uploadPreset) {
    throw new Error('Cloudinary credentials (Cloud Name & Upload Preset) are not configured.')
  }

  const endpoint = `https://api.cloudinary.com/v1_1/${cloudName}/auto/upload`

  const formData = new FormData()
  formData.append('file', file)
  formData.append('upload_preset', uploadPreset)
  formData.append('folder', folder)

  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest()
    xhr.open('POST', endpoint, true)
    xhr.timeout = 180000 // 3 minutes timeout for video/audio

    if (xhr.upload && options.onProgress) {
      xhr.upload.onprogress = (e) => {
        if (e.lengthComputable) {
          const progress = Math.round((e.loaded / e.total) * 100)
          options.onProgress?.(progress)
        }
      }
    }

    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        try {
          const res = JSON.parse(xhr.responseText)

          // Build smart optimized delivery URLs
          const secureUrl = res.secure_url
          // Auto-format, auto-quality transformation
          const optimizedUrl = secureUrl.replace(
            '/upload/',
            '/upload/f_auto,q_auto/'
          )
          // Thumbnail URL for instant previews
          const thumbnailUrl = secureUrl.replace(
            '/upload/',
            '/upload/c_thumb,w_300,g_face,f_auto,q_auto/'
          )

          resolve({
            url: optimizedUrl,
            secureUrl,
            publicId: res.public_id,
            format: res.format,
            resourceType: res.resource_type,
            bytes: res.bytes,
            width: res.width,
            height: res.height,
            thumbnailUrl
          })
        } catch (err) {
          reject(new Error('Failed to parse Cloudinary response'))
        }
      } else {
        reject(
          new Error(
            `Cloudinary upload error (${xhr.status}): ${xhr.responseText}`
          )
        )
      }
    }

    xhr.onerror = () => reject(new Error('Network error during Cloudinary upload'))
    xhr.ontimeout = () => reject(new Error('Upload timed out. Check your connection.'))

    xhr.send(formData)
  })
}
