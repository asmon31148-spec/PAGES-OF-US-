import React, { useState, useEffect, useCallback } from 'react'
import { useAuth } from '@/core/auth'
import { useTheme } from '@/core/theme'
import { useToast } from '@/core/toast'
import { getSupabaseClient, formatLocalDate } from '@/core/storage'
import { getFirebaseDb } from '@/core/storage/firebase'
import { doc, setDoc } from 'firebase/firestore'
import { realtimeBridge } from '@/core/realtime'
import confetti from 'canvas-confetti'
import {
  Pin,
  Edit3,
  Trash2,
  Plus,
  Heart,
  Clock,
  Sparkles
} from 'lucide-react'

export interface PinnedNoteEntry {
  note: string
  updatedBy: string
  updatedAt: string
}

export interface PinnedNotesContent {
  notes: Record<string, PinnedNoteEntry>
}

export const StagePinnedCorkboard: React.FC = () => {
  const { user, space, partner } = useAuth()
  const { theme } = useTheme()
  const { showToast } = useToast()

  const spaceId = space?.id || 'default_space'
  const pinnedDocId = `pinned_note_${spaceId}`

  const [notesData, setNotesData] = useState<Record<string, PinnedNoteEntry>>({})
  const [isEditingMyNote, setIsEditingMyNote] = useState(false)
  const [tempNoteInput, setTempNoteInput] = useState('')

  // Fetch pinned notes from Supabase
  const fetchPinnedNotes = useCallback(async () => {
    try {
      const supabase = getSupabaseClient()
      const { data, error } = await supabase
        .from('app_content')
        .select('content')
        .eq('id', pinnedDocId)
        .maybeSingle()

      if (error) {
        console.warn('Error fetching pinned notes:', error.message)
        return
      }

      if (data?.content) {
        const raw = data.content
        let normalizedNotes: Record<string, PinnedNoteEntry> = {}

        if (raw.notes && typeof raw.notes === 'object') {
          normalizedNotes = raw.notes
        } else if (raw.note && typeof raw.note === 'string') {
          // Backward compatibility for legacy single-note schema
          const authorId = raw.updatedById || user?.id || 'partner_legacy'
          normalizedNotes[authorId] = {
            note: raw.note,
            updatedBy: raw.updatedBy || 'Partner',
            updatedAt: raw.updatedAt || new Date().toISOString()
          }
        }
        setNotesData(normalizedNotes)
      } else {
        setNotesData({})
      }
    } catch (err) {
      console.warn('Error in fetchPinnedNotes:', err)
    }
  }, [pinnedDocId, user?.id])

  useEffect(() => {
    fetchPinnedNotes()

    const supabase = getSupabaseClient()
    const channel = supabase
      .channel(`pinned_chan_${spaceId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'app_content',
          filter: `id=eq.${pinnedDocId}`
        },
        () => {
          fetchPinnedNotes()
        }
      )
      .subscribe()

    // Realtime bridge listener
    const unsubBridge = realtimeBridge.subscribe((event) => {
      if (event.type === 'PINNED_NOTE_CHANGED') {
        fetchPinnedNotes()
        if (event.senderId !== user?.id && event.data?.message) {
          showToast(event.data.message)
        }
      }
    })

    return () => {
      supabase.removeChannel(channel)
      unsubBridge()
    }
  }, [spaceId, pinnedDocId, fetchPinnedNotes, user?.id, showToast])

  // Save current user's note
  const handleSaveMyNote = async () => {
    if (!tempNoteInput.trim() || !user) return

    const nowIso = new Date().toISOString()
    const updatedNotes: Record<string, PinnedNoteEntry> = {
      ...notesData,
      [user.id]: {
        note: tempNoteInput.trim(),
        updatedBy: user.nickname || 'You',
        updatedAt: nowIso
      }
    }

    setNotesData(updatedNotes)
    setIsEditingMyNote(false)
    confetti({ particleCount: 25, spread: 50, origin: { y: 0.6 } })
    showToast('Your pinned note has been saved to the board!')

    try {
      const supabase = getSupabaseClient()
      await supabase.from('app_content').upsert({
        id: pinnedDocId,
        content: {
          notes: updatedNotes,
          // Legacy top-level fields for backwards safety
          note: tempNoteInput.trim(),
          updatedBy: user.nickname || 'You',
          updatedById: user.id,
          updatedAt: nowIso
        },
        updated_at: nowIso
      })

      const db = getFirebaseDb()
      if (db && spaceId) {
        try {
          await setDoc(doc(db, 'spaces', spaceId, 'features', 'pinned_note'), {
            notes: updatedNotes,
            updatedAt: nowIso
          }, { merge: true })
        } catch {}
      }

      await realtimeBridge.broadcast({
        type: 'PINNED_NOTE_CHANGED',
        senderId: user.id,
        senderNickname: user.nickname,
        timestamp: Date.now(),
        data: {
          notes: updatedNotes,
          message: `${user.nickname} posted a new pinned note 📌`
        }
      })
    } catch (err) {
      console.warn('Error saving pinned note:', err)
    }
  }

  // Clear current user's note
  const handleClearMyNote = async () => {
    if (!user) return
    if (!window.confirm('Clear your pinned note from the board?')) return

    const updatedNotes = { ...notesData }
    delete updatedNotes[user.id]

    setNotesData(updatedNotes)
    setIsEditingMyNote(false)
    setTempNoteInput('')
    showToast('Your pinned note was cleared.')

    try {
      const supabase = getSupabaseClient()
      const nowIso = new Date().toISOString()
      await supabase.from('app_content').upsert({
        id: pinnedDocId,
        content: {
          notes: updatedNotes,
          note: '',
          updatedBy: '',
          updatedAt: nowIso
        },
        updated_at: nowIso
      })

      const db = getFirebaseDb()
      if (db && spaceId) {
        try {
          await setDoc(doc(db, 'spaces', spaceId, 'features', 'pinned_note'), {
            notes: updatedNotes,
            updatedAt: nowIso
          }, { merge: true })
        } catch {}
      }

      await realtimeBridge.broadcast({
        type: 'PINNED_NOTE_CHANGED',
        senderId: user.id,
        senderNickname: user.nickname,
        timestamp: Date.now(),
        data: { notes: updatedNotes }
      })
    } catch (err) {
      console.warn('Error clearing pinned note:', err)
    }
  }

  // Extract notes
  const myNoteEntry = user?.id ? notesData[user.id] : undefined
  const partnerNoteEntry = partner?.id
    ? notesData[partner.id]
    : Object.entries(notesData).find(([k]) => k !== user?.id)?.[1]

  return (
    <div className="w-full rounded-2xl sm:rounded-3xl p-4 sm:p-5 border border-[var(--line)] bg-[var(--white)] shadow-xs transition-all my-4 space-y-3.5">
      {/* 1. Header Row */}
      <div className="flex items-center justify-between border-b border-[var(--line)]/60 pb-3">
        <div className="flex items-center gap-2">
          <span className="w-7 h-7 rounded-full bg-[#425b4d]/10 text-[#425b4d] flex items-center justify-center shrink-0">
            <Pin className="w-3.5 h-3.5" />
          </span>
          <div>
            <span className="text-[10px] uppercase font-mono tracking-wider font-semibold text-[var(--ink)]">
              Pinned Notes
            </span>
            <p className="text-[10px] text-[var(--soft)] mt-0.5">
              Sticky reminder board for both of you
            </p>
          </div>
        </div>

        {/* Quick Add / Edit Button */}
        <button
          type="button"
          onClick={() => {
            setTempNoteInput(myNoteEntry?.note || '')
            setIsEditingMyNote(true)
          }}
          className="flex items-center gap-1 px-2.5 py-1 rounded-full bg-[var(--paper)] hover:bg-[var(--line)]/60 text-[10.5px] font-medium text-[var(--ink)] border border-[var(--line)] active:scale-95 transition cursor-pointer"
        >
          {myNoteEntry ? (
            <>
              <Edit3 className="w-3 h-3 text-[var(--app-accent)]" />
              <span>Edit My Pin</span>
            </>
          ) : (
            <>
              <Plus className="w-3 h-3 text-[var(--app-accent)]" />
              <span>Pin Note ＋</span>
            </>
          )}
        </button>
      </div>

      {/* 2. Dual Sticky Notes Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-1">
        {/* Your Sticky Note */}
        <div className="relative p-4 rounded-2xl border border-[var(--line)] bg-[var(--paper)]/75 dark:bg-white/[0.03] flex flex-col justify-between min-h-[120px] transition shadow-xs">
          {/* Note Top Bar */}
          <div className="flex items-center justify-between gap-1 mb-2 border-b border-[var(--line)]/60 pb-2">
            <div className="flex items-center gap-2 min-w-0">
              <span className="w-2 h-2 rounded-full bg-[#425b4d] shrink-0" />
              <span className="text-xs font-semibold text-[var(--ink)] truncate">From You</span>
              <span className="px-1.5 py-0.5 rounded-full bg-[#425b4d]/10 text-[#425b4d] font-mono text-[9px] font-semibold uppercase tracking-wider shrink-0">
                You
              </span>
              {myNoteEntry?.updatedAt && (
                <span className="text-[10px] text-[var(--soft)] font-mono truncate hidden sm:inline">
                  • {formatLocalDate(myNoteEntry.updatedAt, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })}
                </span>
              )}
            </div>

            {myNoteEntry && (
              <div className="flex items-center gap-1 shrink-0">
                <button
                  type="button"
                  onClick={() => {
                    setTempNoteInput(myNoteEntry.note)
                    setIsEditingMyNote(true)
                  }}
                  className="p-1.5 rounded-md hover:bg-black/5 dark:hover:bg-white/10 text-[var(--soft)] hover:text-[var(--ink)] transition cursor-pointer"
                  title="Edit your pinned note"
                >
                  <Edit3 className="w-3.5 h-3.5" />
                </button>
                <button
                  type="button"
                  onClick={handleClearMyNote}
                  className="p-1.5 rounded-md hover:bg-red-500/10 text-[var(--soft)] hover:text-red-500 transition cursor-pointer"
                  title="Clear your pinned note"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                </button>
              </div>
            )}
          </div>

          {/* Note Content */}
          {myNoteEntry ? (
            <div className="p-3 rounded-xl bg-white/95 dark:bg-black/20 border border-[var(--line)] shadow-2xs my-1">
              <p className="font-serif italic text-xs sm:text-[13px] text-[var(--ink)] leading-relaxed select-text">
                “{myNoteEntry.note}”
              </p>
            </div>
          ) : (
            <button
              type="button"
              onClick={() => {
                setTempNoteInput('')
                setIsEditingMyNote(true)
              }}
              className="w-full py-3 px-3 rounded-xl border border-dashed border-[#425b4d]/35 hover:border-[#425b4d] bg-[#425b4d]/[0.03] hover:bg-[#425b4d]/[0.08] transition-all flex items-center justify-center gap-2 group active:scale-[0.98] cursor-pointer my-1"
            >
              <Edit3 className="w-3.5 h-3.5 text-[#425b4d] group-hover:scale-110 transition-transform" />
              <span className="text-xs font-medium text-[var(--ink)]">
                Write a reminder or sweet note
              </span>
            </button>
          )}

          <div className="flex items-center justify-between text-[10px] text-[var(--soft)] pt-1.5">
            <span>Only you can edit this pin</span>
            <span className="font-mono text-[9.5px] text-[#425b4d] font-medium">✦ Active Board</span>
          </div>
        </div>

        {/* Partner's Sticky Note */}
        <div className="relative p-4 rounded-2xl border border-[var(--line)] bg-[var(--paper)]/75 dark:bg-white/[0.03] flex flex-col justify-between min-h-[120px] transition shadow-xs">
          {/* Partner Top Bar */}
          <div className="flex items-center justify-between gap-1 mb-2 border-b border-[var(--line)]/60 pb-2">
            <div className="flex items-center gap-2 min-w-0">
              <span className="w-2 h-2 rounded-full bg-[#c97a63] shrink-0" />
              <span className="text-xs font-semibold text-[var(--ink)] truncate">
                From {partner?.nickname || 'Partner'}
              </span>
              <span className="px-1.5 py-0.5 rounded-full bg-[#c97a63]/10 text-[#c97a63] font-mono text-[9px] font-semibold uppercase tracking-wider shrink-0">
                Partner
              </span>
              {partnerNoteEntry?.updatedAt && (
                <span className="text-[10px] text-[var(--soft)] font-mono truncate hidden sm:inline">
                  • {formatLocalDate(partnerNoteEntry.updatedAt, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })}
                </span>
              )}
            </div>

            {partnerNoteEntry && (
              <button
                type="button"
                onClick={() => {
                  confetti({ particleCount: 20, spread: 45, origin: { y: 0.65 } })
                  showToast(`Acknowledged ${partner?.nickname || 'partner'}'s note 💕`)
                }}
                className="p-1.5 rounded-md hover:bg-rose-500/10 text-[var(--soft)] hover:text-rose-500 transition cursor-pointer"
                title="Send heart reaction"
              >
                <Heart className="w-3.5 h-3.5 fill-rose-500 text-rose-500" />
              </button>
            )}
          </div>

          {/* Partner Note Content */}
          {partnerNoteEntry ? (
            <div className="p-3 rounded-xl bg-white/95 dark:bg-black/20 border border-[var(--line)] shadow-2xs my-1">
              <p className="font-serif italic text-xs sm:text-[13px] text-[var(--ink)] leading-relaxed select-text">
                “{partnerNoteEntry.note}”
              </p>
            </div>
          ) : (
            <div className="w-full py-3 px-3 rounded-xl border border-dashed border-[var(--line)]/60 bg-transparent text-center my-1 flex items-center justify-center">
              <p className="text-xs text-[var(--soft)] font-medium italic">
                Waiting for {partner?.nickname || 'partner'} to pin a note...
              </p>
            </div>
          )}

          <div className="flex items-center justify-between text-[10px] text-[var(--soft)] pt-1.5">
            <span>Posted by {partnerNoteEntry?.updatedBy || partner?.nickname || 'Partner'}</span>
            <span className="font-mono text-[9.5px] text-[#c97a63] font-medium">✦ Partner's Pin</span>
          </div>
        </div>
      </div>

      {/* MODAL: Edit Pinned Note */}
      {isEditingMyNote && (
        <div
          className="modal-backdrop"
          onClick={(e) => {
            if (e.target === e.currentTarget) setIsEditingMyNote(false)
          }}
        >
          <div className="modal">
            <div className="modal-handle" />
            <button
              type="button"
              className="close"
              onClick={() => setIsEditingMyNote(false)}
            >
              ×
            </button>
            <div className="modal-date">PINNED REMINDER</div>
            <h3>Pin a Note for Today</h3>
            <p style={{ fontStyle: 'normal', fontSize: '11px', color: '#777a76', marginBottom: '12px' }}>
              Leave a quiet reminder, meds check, sweet note, or inside joke for your partner.
            </p>
            <textarea
              rows={3}
              value={tempNoteInput}
              onChange={(e) => setTempNoteInput(e.target.value)}
              placeholder="e.g. Don't forget your umbrella today! Or stay hydrated 💧"
              className="w-full p-3 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] text-xs font-serif italic outline-none resize-none leading-relaxed mb-4"
              autoFocus
            />
            <div className="flex gap-2">
              {myNoteEntry && (
                <button
                  type="button"
                  onClick={handleClearMyNote}
                  className="py-2.5 px-4 rounded-xl border border-red-300 dark:border-red-900 text-red-600 dark:text-red-400 text-xs font-medium cursor-pointer hover:bg-red-500/10 transition"
                >
                  Clear Note
                </button>
              )}
              <button
                type="button"
                onClick={() => setIsEditingMyNote(false)}
                className="py-2.5 px-4 rounded-xl border border-[var(--line)] text-xs text-[var(--soft)] hover:bg-[var(--line)]/30 transition cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleSaveMyNote}
                className="flex-1 py-2.5 rounded-xl bg-[var(--app-accent)] text-white text-xs font-medium cursor-pointer hover:opacity-90"
              >
                Save to Board
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
