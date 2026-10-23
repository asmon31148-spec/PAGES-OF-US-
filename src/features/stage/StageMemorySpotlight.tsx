import React, { useState, useEffect, useCallback } from 'react'
import { useAuth } from '@/core/auth'
import { useTheme } from '@/core/theme'
import { getSupabaseClient, formatLocalDate, getAuthorAttribution } from '@/core/storage'
import { realtimeBridge } from '@/core/realtime'
import { Image as ImageIcon, Sparkles, ArrowRight } from 'lucide-react'

interface SpotlightItem {
  id: string
  title: string
  caption: string
  mediaUrl: string
  author: string
  createdAt: string
}

interface StageMemorySpotlightProps {
  onGoToMemories: () => void
}

export const StageMemorySpotlight: React.FC<StageMemorySpotlightProps> = ({
  onGoToMemories
}) => {
  const { user, space, partner } = useAuth()
  const { theme } = useTheme()
  const [latestMemories, setLatestMemories] = useState<SpotlightItem[]>([])

  const spaceId = space?.id || 'default_space'

  const fetchLatest = useCallback(async () => {
    try {
      const supabase = getSupabaseClient()
      const { data } = await supabase
        .from('memories')
        .select('*')
        .eq('space_id', spaceId)
        .order('created_at', { ascending: false })
        .limit(3)

      if (data && data.length > 0) {
        const mapped: SpotlightItem[] = data.map((d) => {
          const { authorName, isMine } = getAuthorAttribution(d.author, user, partner?.nickname)
          return {
            id: d.id,
            title: d.title,
            caption: d.caption,
            mediaUrl: d.media_url,
            author: isMine ? 'You' : authorName,
            createdAt: formatLocalDate(d.created_at, {
              month: 'short',
              day: 'numeric'
            })
          }
        })
        setLatestMemories(mapped)
      } else {
        setLatestMemories([])
      }
    } catch (err) {
      console.warn('Error fetching spotlight memories:', err)
    }
  }, [spaceId, user, partner?.nickname])

  useEffect(() => {
    fetchLatest()

    const supabase = getSupabaseClient()
    const channel = supabase
      .channel(`spotlight_memories_${spaceId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'memories',
          filter: `space_id=eq.${spaceId}`
        },
        () => {
          fetchLatest()
        }
      )
      .subscribe()

    const unsubBridge = realtimeBridge.subscribe((event) => {
      if (event.type === 'MEMORY_ADDED') {
        fetchLatest()
      }
    })

    return () => {
      supabase.removeChannel(channel)
      unsubBridge()
    }
  }, [spaceId, fetchLatest])

  if (latestMemories.length === 0) return null

  const featured = latestMemories[0]

  return (
    <div
      onClick={onGoToMemories}
      className="p-4 rounded-3xl border space-y-3 cursor-pointer transition-all hover:scale-[1.01] active:scale-[0.99] group shadow-sm"
      style={{
        backgroundColor: theme.bgSecondary,
        borderColor: theme.surfaceBorder
      }}
    >
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-1.5">
          <Sparkles className="w-3.5 h-3.5" style={{ color: theme.accent }} />
          <span className="text-[11px] font-bold uppercase tracking-wider" style={{ color: theme.accent }}>
            Memory Spotlight
          </span>
        </div>
        <div className="flex items-center gap-1 text-[11px] font-medium opacity-60 group-hover:opacity-100 transition" style={{ color: theme.textSecondary }}>
          <span>View all</span>
          <ArrowRight className="w-3 h-3" />
        </div>
      </div>

      <div className="relative aspect-[16/9] rounded-2xl overflow-hidden bg-neutral-900">
        <img
          src={featured.mediaUrl}
          alt={featured.title}
          className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent flex flex-col justify-end p-3 text-white">
          <p className="text-xs font-bold truncate">{featured.title || 'Captured Moment'}</p>
          {featured.caption && (
            <p className="text-[10px] text-white/80 line-clamp-1 mt-0.5">{featured.caption}</p>
          )}
          <span className="text-[9px] text-white/60 mt-1">
            {featured.createdAt} • by {featured.author}
          </span>
        </div>
      </div>
    </div>
  )
}
