import React, { useState, useEffect } from 'react'
import { useAuth } from '@/core/auth'
import { useTheme } from '@/core/theme'
import { getSupabaseClient } from '@/core/storage/supabase'
import { getFirebaseDb } from '@/core/storage/firebase'
import { doc, setDoc, onSnapshot } from 'firebase/firestore'
import { realtimeBridge } from '@/core/realtime'
import { dispatchPartnerInteraction } from '@/core/ai'
import { Plus, Radio, X, Check, Sparkles } from 'lucide-react'

interface InstagramNotesProps {
  onSendPulse: () => void
  isPulsing: boolean
}

export interface SharedNotesState {
  [userId: string]: {
    text: string
    updatedAt: string
    author: string
  }
}

export const InstagramNotes: React.FC<InstagramNotesProps> = ({
  onSendPulse,
  isPulsing
}) => {
  const { user, space, partner, isPaired } = useAuth()
  const { theme } = useTheme()

  const spaceId = space?.id || 'default_space'
  const notesDocId = `notes_${spaceId}`

  const [notes, setNotes] = useState<SharedNotesState>({})
  const [isEditingMyNote, setIsEditingMyNote] = useState(false)
  const [noteInput, setNoteInput] = useState('')
  const [isSaving, setIsSaving] = useState(false)

  // Fetch real notes from Supabase & Firestore, subscribe to Realtime
  useEffect(() => {
    const supabase = getSupabaseClient()
    const db = getFirebaseDb()

    const fetchNotes = async () => {
      try {
        const { data } = await supabase
          .from('app_content')
          .select('content')
          .eq('id', notesDocId)
          .maybeSingle()

        if (data?.content) {
          setNotes(data.content as SharedNotesState)
        }
      } catch (err) {
        console.warn('Error fetching notes:', err)
      }
    }

    fetchNotes()

    const channel = supabase
      .channel(`notes_chan_${spaceId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'app_content',
          filter: `id=eq.${notesDocId}`
        },
        (payload: any) => {
          if (payload.new?.content) {
            setNotes(payload.new.content as SharedNotesState)
          }
        }
      )
      .subscribe()

    // Firestore listener for cross-platform peer synchronization
    let unsubFirestore: (() => void) | undefined
    if (db && spaceId) {
      try {
        unsubFirestore = onSnapshot(doc(db, 'spaces', spaceId, 'features', 'notes'), (snapshot) => {
          if (snapshot.exists()) {
            const data = snapshot.data()
            if (data?.notes) {
              setNotes(data.notes as SharedNotesState)
            }
          }
        }, (err) => {
          console.warn('Firestore notes snapshot error:', err)
        })
      } catch (err) {
        console.warn('Failed to listen to Firestore notes:', err)
      }
    }

    // Peer broadcast listener
    const unsubBroadcast = realtimeBridge.subscribe((event) => {
      if (event.type === 'PINNED_NOTE_CHANGED' && event.data?.notes) {
        setNotes(event.data.notes as SharedNotesState)
      }
    })

    return () => {
      supabase.removeChannel(channel)
      if (unsubFirestore) unsubFirestore()
      unsubBroadcast()
    }
  }, [spaceId, notesDocId])

  const myNote = user?.id ? notes[user.id]?.text : ''
  const partnerNote = partner?.id ? notes[partner.id]?.text : ''

  const handleSaveNote = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!user || !noteInput.trim()) return

    setIsSaving(true)
    const updated: SharedNotesState = {
      ...notes,
      [user.id]: {
        text: noteInput.trim().slice(0, 60), // Instagram 60-char limit for clean bubbles
        updatedAt: new Date().toISOString(),
        author: user.nickname
      }
    }

    setNotes(updated)
    setIsEditingMyNote(false)

    try {
      const supabase = getSupabaseClient()
      await supabase.from('app_content').upsert({
        id: notesDocId,
        content: updated,
        updated_at: new Date().toISOString()
      })

      // Sync to Firebase Firestore
      const db = getFirebaseDb()
      if (db && spaceId) {
        try {
          await setDoc(doc(db, 'spaces', spaceId, 'features', 'notes'), { notes: updated }, { merge: true })
        } catch {}
      }

      // Instant peer broadcast
      await realtimeBridge.broadcast({
        type: 'PINNED_NOTE_CHANGED',
        senderId: user.id,
        senderNickname: user.nickname,
        timestamp: Date.now(),
        data: { notes: updated }
      }).catch(() => {})

      dispatchPartnerInteraction(user, space, 'THOUGHT_POSTED', {
        thought: noteInput.trim().slice(0, 60)
      }).catch(() => {})
    } catch (err) {
      console.warn('Error saving note:', err)
    } finally {
      setIsSaving(false)
    }
  }

  return (
    <div className="relative py-2">
      {/* Both Avatars with Floating Instagram Notes */}
      <div className="flex items-center justify-around px-2">
        {/* User 1: You */}
        <div className="flex flex-col items-center relative group">
          {/* Floating Instagram Note Bubble */}
          <button
            onClick={() => {
              setNoteInput(myNote || '')
              setIsEditingMyNote(true)
            }}
            className="mb-2 max-w-[140px] px-3 py-1.5 rounded-2xl bg-white/10 backdrop-blur-md border border-white/15 shadow-lg text-left transition hover:scale-105 active:scale-95 cursor-pointer relative"
          >
            {myNote ? (
              <p className="text-[11px] font-medium text-white truncate leading-tight">
                {myNote}
              </p>
            ) : (
              <p className="text-[10px] text-white/50 flex items-center gap-1 font-medium">
                <Plus className="w-3 h-3 text-amber-400" />
                <span>Share a note...</span>
              </p>
            )}
            {/* Bubble Tail */}
            <div className="absolute -bottom-1 left-1/2 -translate-x-1/2 w-2 h-2 rotate-45 bg-white/10 border-r border-b border-white/15" />
          </button>

          {/* Instagram Story Gradient Ring Avatar */}
          <div className="p-[2.5px] rounded-full bg-gradient-to-tr from-amber-500 via-rose-500 to-purple-600 shadow-md">
            <div
              className="w-14 h-14 rounded-full flex items-center justify-center font-bold text-sm shadow-inner"
              style={{ backgroundColor: '#121215', color: '#ffffff' }}
            >
              {user ? user.nickname.slice(0, 2).toUpperCase() : 'ME'}
            </div>
          </div>
          <span className="text-xs font-semibold mt-1.5 text-white/90">
            {user?.nickname || 'You'}
          </span>
        </div>

        {/* Center: Tether Pulse Shockwave Button */}
        <div className="flex flex-col items-center gap-1">
          <button
            onClick={onSendPulse}
            disabled={isPulsing}
            className={`w-11 h-11 rounded-full flex items-center justify-center shadow-lg transition active:scale-90 ${
              isPulsing ? 'animate-pulse ring-4 ring-amber-400/40' : ''
            }`}
            style={{
              background: 'linear-gradient(135deg, #f59e0b 0%, #ec4899 100%)',
              color: '#ffffff'
            }}
            title="Send real-time gentle pulse & shockwave"
          >
            <Radio className="w-5 h-5 fill-current" />
          </button>
          <span className="text-[9px] font-mono uppercase tracking-wider text-amber-400/90 font-bold">
            {isPulsing ? 'Pulsing...' : 'Tether'}
          </span>
        </div>

        {/* User 2: Partner */}
        <div className="flex flex-col items-center relative">
          {/* Partner's Floating Note Bubble */}
          <div className="mb-2 max-w-[140px] px-3 py-1.5 rounded-2xl bg-white/10 backdrop-blur-md border border-white/15 shadow-lg relative">
            {partnerNote ? (
              <p className="text-[11px] font-medium text-white truncate leading-tight">
                {partnerNote}
              </p>
            ) : (
              <p className="text-[10px] text-white/40 italic">
                {isPaired ? 'Quiet right now' : 'Invite partner'}
              </p>
            )}
            {/* Bubble Tail */}
            <div className="absolute -bottom-1 left-1/2 -translate-x-1/2 w-2 h-2 rotate-45 bg-white/10 border-r border-b border-white/15" />
          </div>

          {/* Partner Avatar with Gradient Ring */}
          <div
            className={`p-[2.5px] rounded-full shadow-md ${
              isPaired
                ? 'bg-gradient-to-tr from-purple-500 via-pink-500 to-amber-500'
                : 'border border-dashed border-white/30'
            }`}
          >
            <div
              className="w-14 h-14 rounded-full flex items-center justify-center font-bold text-sm shadow-inner"
              style={{
                backgroundColor: isPaired ? '#121215' : 'rgba(255,255,255,0.03)',
                color: isPaired ? '#ffffff' : '#71717a'
              }}
            >
              {partner ? partner.nickname.slice(0, 2).toUpperCase() : '?'}
            </div>
          </div>
          <span className="text-xs font-semibold mt-1.5 text-white/80">
            {partner ? partner.nickname : 'Partner'}
          </span>
        </div>
      </div>

      {/* Edit Note Modal / Drawer */}
      {isEditingMyNote && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-md animate-in fade-in">
          <div
            className="w-full max-w-sm rounded-3xl p-6 shadow-2xl relative border"
            style={{
              backgroundColor: '#16141f',
              borderColor: 'rgba(255,255,255,0.12)',
              color: '#ffffff'
            }}
          >
            <button
              onClick={() => setIsEditingMyNote(false)}
              className="absolute top-4 right-4 p-2 rounded-full opacity-60 hover:opacity-100 transition"
            >
              <X className="w-4 h-4" />
            </button>

            <form onSubmit={handleSaveNote} className="space-y-4">
              <div>
                <span className="text-[10px] uppercase font-bold tracking-wider text-amber-400">
                  Instagram Note
                </span>
                <h3 className="text-base font-bold">Share what's on your mind</h3>
                <p className="text-xs text-neutral-400 mt-0.5">
                  Floats above your avatar in real time for your partner.
                </p>
              </div>

              <div className="relative">
                <input
                  type="text"
                  maxLength={60}
                  placeholder="e.g. Listening to rain 🌧️, Can't sleep..."
                  value={noteInput}
                  onChange={(e) => setNoteInput(e.target.value)}
                  className="w-full px-4 py-3 rounded-2xl text-xs border border-white/15 bg-white/5 outline-none text-white focus:border-amber-400"
                  autoFocus
                  required
                />
                <span className="absolute right-3 top-3 text-[10px] text-white/40 font-mono">
                  {60 - noteInput.length}
                </span>
              </div>

              <div className="flex gap-2 pt-1">
                <button
                  type="button"
                  onClick={() => setIsEditingMyNote(false)}
                  className="w-1/2 py-2.5 rounded-xl text-xs font-medium border border-white/10 text-white/70"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSaving || !noteInput.trim()}
                  className="w-1/2 py-2.5 rounded-xl text-xs font-bold transition active:scale-95 shadow-md flex items-center justify-center gap-1.5"
                  style={{
                    background: 'linear-gradient(135deg, #f59e0b 0%, #ec4899 100%)',
                    color: '#ffffff'
                  }}
                >
                  <Check className="w-3.5 h-3.5" />
                  Share Note
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
