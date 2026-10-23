import React, { useState, useEffect, useCallback } from 'react'
import { useAuth } from '@/core/auth'
import { useTheme } from '@/core/theme'
import { useToast } from '@/core/toast'
import { getSupabaseClient, getAuthorAttribution, formatAuthor, generateEntityId, formatLocalDate } from '@/core/storage'
import { realtimeBridge } from '@/core/realtime'
import { dispatchPartnerInteraction } from '@/core/ai'
import { Plus, X, Trash2, Calendar } from 'lucide-react'

export interface MilestoneItem {
  id: string
  title: string
  date: string
  rawDate: string
  story: string
  addedBy: string
  isMine: boolean
}

export const TimelineView: React.FC = () => {
  const { user, space, partner } = useAuth()
  const { theme, isDark, toggleDarkLight } = useTheme()
  const { showToast } = useToast()

  const [milestones, setMilestones] = useState<MilestoneItem[]>([])
  const [isAdding, setIsAdding] = useState(false)
  const [title, setTitle] = useState('')
  const [date, setDate] = useState('')
  const [story, setStory] = useState('')
  const [isSaving, setIsSaving] = useState(false)

  const spaceId = space?.id || 'default_space'

  // Dynamic Year Grouping for Milestones
  const groupedMilestones = React.useMemo(() => {
    const groups: Record<number, MilestoneItem[]> = {}
    milestones.forEach((item) => {
      let year = new Date().getFullYear()
      if (item.rawDate) {
        const parsed = new Date(item.rawDate).getFullYear()
        if (!isNaN(parsed) && parsed > 1900) {
          year = parsed
        }
      }
      if (!groups[year]) groups[year] = []
      groups[year].push(item)
    })
    return Object.entries(groups)
      .map(([y, list]) => ({ year: Number(y), items: list }))
      .sort((a, b) => b.year - a.year)
  }, [milestones])

  // Fetch real milestones from Supabase
  const fetchMilestones = useCallback(async () => {
    try {
      const supabase = getSupabaseClient()
      const { data, error } = await supabase
        .from('milestones')
        .select('*')
        .eq('space_id', spaceId)
        .order('event_date', { ascending: false })

      if (error) {
        console.warn('Error fetching milestones from Supabase:', error.message)
        return
      }

      if (data && data.length > 0) {
        const mapped: MilestoneItem[] = data.map((row) => {
          const { authorName, isMine } = getAuthorAttribution(row.author, user, partner?.nickname)
          return {
            id: row.id,
            title: row.title,
            date: formatLocalDate(row.event_date, {
              day: 'numeric',
              month: 'short'
            }).toUpperCase(),
            rawDate: row.event_date,
            story: row.story || '',
            addedBy: isMine ? 'You' : authorName,
            isMine
          }
        })
        setMilestones(mapped)
      } else {
        setMilestones([])
      }
    } catch (err) {
      console.warn('Error fetching milestones:', err)
    }
  }, [spaceId, user, partner?.nickname])

  useEffect(() => {
    fetchMilestones()

    const supabase = getSupabaseClient()
    const channel = supabase
      .channel(`milestones_feed_${spaceId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'milestones',
          filter: `space_id=eq.${spaceId}`
        },
        () => {
          fetchMilestones()
        }
      )
      .subscribe()

    // Realtime WebSocket bridge listener for instant partner sync
    const unsubBridge = realtimeBridge.subscribe((event) => {
      if (event.type === 'MILESTONE_ADDED') {
        fetchMilestones()
      }
    })

    return () => {
      supabase.removeChannel(channel)
      unsubBridge()
    }
  }, [spaceId, fetchMilestones])

  const handleSaveMilestone = async () => {
    if (!title.trim() || !user) {
      showToast('Please provide a milestone title.')
      return
    }

    setIsSaving(true)
    try {
      const supabase = getSupabaseClient()
      const newMilestoneId = generateEntityId('milestone')
      const authorEncoded = formatAuthor(user)
      const nowIso = new Date().toISOString()
      const eventDateVal = date || nowIso.split('T')[0]

      const newRow = {
        id: newMilestoneId,
        space_id: spaceId,
        title: title.trim(),
        event_date: eventDateVal,
        story: story.trim(),
        author: authorEncoded,
        created_at: nowIso
      }

      const { error } = await supabase.from('milestones').insert(newRow)
      if (error) {
        console.error('Supabase milestone insert error:', error)
        throw new Error(error.message || 'Failed to save milestone to database')
      }

      // Optimistically add to UI state
      const optimisticItem: MilestoneItem = {
        id: newMilestoneId,
        title: title.trim(),
        date: formatLocalDate(eventDateVal, { day: 'numeric', month: 'short' }).toUpperCase(),
        rawDate: eventDateVal,
        story: story.trim(),
        addedBy: 'You',
        isMine: true
      }
      setMilestones((prev) => [optimisticItem, ...prev.filter((m) => m.id !== newMilestoneId)])

      // Broadcast and trigger partner notification
      realtimeBridge.broadcast({
        type: 'MILESTONE_ADDED',
        senderId: user.id,
        senderNickname: user.nickname,
        timestamp: Date.now(),
        data: { milestoneId: newMilestoneId, title: title.trim() }
      }).catch(() => {})

      dispatchPartnerInteraction(user, space, 'MILESTONE_ADDED', {
        noteTitle: title.trim()
      }).catch(() => {})

      showToast('Milestone added to your shared journey.')
      setIsAdding(false)
      setTitle('')
      setDate('')
      setStory('')
    } catch (err: any) {
      console.error('Failed to add milestone:', err)
      showToast(err.message || 'Error saving milestone. Please try again.')
    } finally {
      setIsSaving(false)
    }
  }

  const handleDeleteMilestone = async (id: string) => {
    if (!window.confirm('Delete this milestone from your journey?')) return

    setMilestones((prev) => prev.filter((m) => m.id !== id))
    showToast('Milestone deleted.')

    try {
      const supabase = getSupabaseClient()
      const { error } = await supabase.from('milestones').delete().eq('id', id)
      if (error) {
        console.warn('Supabase milestone delete error:', error.message)
      }
    } catch (err) {
      console.warn('Error deleting milestone:', err)
    }
  }

  return (
    <div className="page active" id="timeline">
      {/* 1. TOPBAR */}
      <header className="topbar">
        <div className="wordmark">Pages of Us</div>
        <div className="flex items-center gap-2">
          <button
            type="button"
            className="music-pill flex items-center justify-center w-8 h-8 !p-0"
            onClick={toggleDarkLight}
            title={isDark ? 'Switch to Light Sanctuary (☀️)' : 'Switch to Dark Sanctuary (🌙)'}
          >
            {isDark ? '☀️' : '🌙'}
          </button>
          <button
            type="button"
            className="music-pill"
            onClick={() => setIsAdding(true)}
          >
            ＋ &nbsp; Milestone
          </button>
        </div>
      </header>

      {/* 2. HEADER */}
      <div className="screen-head">
        <span className="overline">Our shared timeline</span>
      </div>
      <h2 className="screen-title">Our Journey</h2>
      <p className="screen-subtitle">The days and milestones we kept along the way.</p>

      {/* 3. TIMELINE ITEMS */}
      {milestones.length === 0 ? (
        <div className="p-8 text-center border border-dashed border-[var(--line)] rounded-2xl bg-[var(--white)] my-6 space-y-3 shadow-xs">
          <div className="w-12 h-12 rounded-full bg-[var(--paper)] text-[var(--app-accent)] flex items-center justify-center mx-auto text-xl">
            🌱
          </div>
          <h3 className="font-serif text-sm font-semibold text-[var(--ink)]">No milestones recorded yet</h3>
          <p className="text-xs text-[var(--soft)] max-w-xs mx-auto leading-relaxed">
            Record anniversaries, first trips, and the small days that mattered to both of you.
          </p>
          <button
            type="button"
            onClick={() => setIsAdding(true)}
            className="py-2 px-4 rounded-xl bg-[var(--app-accent)] text-[var(--app-accent-text)] text-xs font-medium hover:opacity-90 transition shadow-xs cursor-pointer"
          >
            ＋ Add First Milestone
          </button>
        </div>
      ) : (
        <div className="space-y-6 mt-4">
          {groupedMilestones.map(({ year, items }) => (
            <div key={year} className="timeline-panel">
              <div className="timeline-year">{year} · THE DAYS YOU KEPT</div>
              {items.map((item) => (
                <div key={item.id} className="timeline-item">
                  <span className="timeline-date">{item.date}</span>
                  <div className="timeline-card flex items-center justify-between">
                    <div>
                      <b>{item.title}</b>
                      <span>{item.story ? `${item.story} · Kept by ${item.addedBy}` : `Kept by ${item.addedBy}`}</span>
                    </div>
                    <button
                      type="button"
                      onClick={() => handleDeleteMilestone(item.id)}
                      className="text-[#888a82] hover:text-red-600 p-1 cursor-pointer transition ml-2"
                      title="Delete milestone"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          ))}
        </div>
      )}

      {/* 4. ADD MILESTONE MODAL */}
      {isAdding && (
        <div
          className="modal-backdrop show"
          onClick={(e) => {
            if (e.target === e.currentTarget) setIsAdding(false)
          }}
        >
          <div className="modal">
            <div className="modal-handle"></div>
            <button
              type="button"
              className="close"
              onClick={() => setIsAdding(false)}
            >
              ×
            </button>
            <div className="modal-date">Add to Shared Timeline</div>
            <h3 className="font-serif">Record a milestone</h3>

            <div className="mt-4 space-y-3.5">
              <div>
                <label className="text-[11px] font-medium text-[var(--soft)] block mb-1">
                  Milestone Title
                </label>
                <input
                  type="text"
                  placeholder="e.g. Moved into our first flat"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  className="w-full text-sm p-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] focus:outline-none focus:ring-1 focus:ring-[var(--app-accent)]"
                />
              </div>

              <div>
                <label className="text-[11px] font-medium text-[var(--soft)] block mb-1">
                  Date
                </label>
                <input
                  type="date"
                  value={date}
                  onChange={(e) => setDate(e.target.value)}
                  className="w-full text-xs p-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] focus:outline-none"
                />
              </div>

              <div>
                <label className="text-[11px] font-medium text-[var(--soft)] block mb-1">
                  The Story (Optional)
                </label>
                <textarea
                  rows={3}
                  placeholder="What made this day memorable..."
                  value={story}
                  onChange={(e) => setStory(e.target.value)}
                  className="w-full text-sm p-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] focus:outline-none focus:ring-1 focus:ring-[var(--app-accent)] resize-none"
                />
              </div>

              <div className="pt-2">
                <button
                  type="button"
                  disabled={isSaving}
                  onClick={handleSaveMilestone}
                  className="w-full py-2.5 rounded-xl bg-[var(--app-accent)] text-[var(--app-accent-text)] text-xs font-semibold hover:opacity-90 transition shadow-xs flex items-center justify-center gap-1.5 cursor-pointer disabled:opacity-50"
                >
                  <Calendar className="w-3.5 h-3.5" />
                  <span>{isSaving ? 'Saving milestone...' : 'Save Milestone'}</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
