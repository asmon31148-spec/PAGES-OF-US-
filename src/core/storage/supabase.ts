import { createClient, SupabaseClient } from '@supabase/supabase-js'

export const DEFAULT_SUPABASE_URL =
  import.meta.env.VITE_SUPABASE_URL || 'https://qzycnvpyjrphvxogndjd.supabase.co'

export const DEFAULT_SUPABASE_ANON_KEY =
  import.meta.env.VITE_SUPABASE_ANON_KEY || 'sb_publishable_H5qrH4beZA17m8FoHyy-DA_yCLlyH5H'

export const MEDIA_BUCKET_NAME = 'pages-media'

let supabaseInstance: SupabaseClient | null = null

export const getSupabaseClient = (
  customUrl?: string,
  customKey?: string
): SupabaseClient => {
  const url = customUrl || DEFAULT_SUPABASE_URL
  const key = customKey || DEFAULT_SUPABASE_ANON_KEY

  if (!supabaseInstance) {
    supabaseInstance = createClient(url, key, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true
      },
      realtime: {
        params: {
          eventsPerSecond: 10
        }
      }
    })
  }

  return supabaseInstance
}
