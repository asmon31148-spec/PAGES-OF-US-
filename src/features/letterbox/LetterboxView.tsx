import React, { useState, useEffect, useCallback } from 'react'
import { useAuth } from '@/core/auth'
import { useTheme } from '@/core/theme'
import { useToast } from '@/core/toast'
import { getSupabaseClient, formatAuthor, getAuthorAttribution, generateEntityId, formatLocalDate, encodeEnvelopeMetadata, decodeEnvelopeMetadata } from '@/core/storage'
import { realtimeBridge } from '@/core/realtime'
import { dispatchPartnerInteraction } from '@/core/ai'
import { Plus, X, Send, Lock, Trash2 } from 'lucide-react'

export interface LetterItem {
  id: string
  title: string
  body: string
  author: string
  authorName: string
  isMine: boolean
  createdAt: string
  writtenDate: string
  sealType?: 'green' | 'terra' | 'slate' | 'rose'
  category?: string
  sealedUntilDate?: string // YYYY-MM-DD
  isRead: boolean
  voiceUrl?: string
}

export const LetterboxView: React.FC = () => {
  const { user, space, partner } = useAuth()
  const { theme, isDark, toggleDarkLight } = useTheme()
  const { showToast } = useToast()

  const [letters, setLetters] = useState<LetterItem[]>([])
  const [selectedLetter, setSelectedLetter] = useState<LetterItem | null>(null)

  // Write modal state
  const [isWriting, setIsWriting] = useState(false)
  const [newTitle, setNewTitle] = useState('')
  const [newBody, setNewBody] = useState('')
  const [newCategory, setNewCategory] = useState('For a quiet day')
  const [newSeal, setNewSeal] = useState<'green' | 'terra' | 'slate' | 'rose'>('green')
  const [sealedDate, setSealedDate] = useState('')
  const [isSending, setIsSending] = useState(false)

  const spaceId = space?.id || 'default_space'

  const fetchLetters = useCallback(async () => {
    try {
      const supabase = getSupabaseClient()
      const { data, error } = await supabase
        .from('letters')
        .select('*')
        .eq('space_id', spaceId)
        .order('created_at', { ascending: false })

      if (error) {
        console.warn('Error fetching letters from Supabase:', error.message)
        return
      }

      if (data && data.length > 0) {
        const mapped: LetterItem[] = data.map((row) => {
          const { authorName, isMine } = getAuthorAttribution(row.author, user, partner?.nickname)
          const { seal, category } = decodeEnvelopeMetadata(row.envelope_color)
          const writtenFormatted = formatLocalDate(row.created_at, { day: 'numeric', month: 'long', year: 'numeric' })
          return {
            id: row.id,
            title: row.title,
            body: row.body,
            author: row.author,
            authorName,
            isMine,
            writtenDate: `Written on ${writtenFormatted}`,
            createdAt: row.sealed_until
              ? `Sealed until ${formatLocalDate(row.sealed_until, { day: 'numeric', month: 'long', year: 'numeric' })}`
              : `Written on ${writtenFormatted}`,
            category,
            sealType: seal,
            sealedUntilDate: row.sealed_until || undefined,
            isRead: Boolean(row.is_read)
          }
        })
        setLetters(mapped)
      } else {
        setLetters([])
      }
    } catch (err) {
      console.warn('Error fetching letters:', err)
    }
  }, [spaceId, user, partner?.nickname])

  // Fetch real letters from Supabase & subscribe to real-time events
  useEffect(() => {
    fetchLetters()

    const supabase = getSupabaseClient()
    const channel = supabase
      .channel(`letters_feed_${spaceId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'letters',
          filter: `space_id=eq.${spaceId}`
        },
        () => {
          fetchLetters()
        }
      )
      .subscribe()

    // Realtime WebSocket bridge listener for instant partner sync
    const unsubBridge = realtimeBridge.subscribe((event) => {
      if (event.type === 'LETTER_SEALED') {
        fetchLetters()
      }
    })

    return () => {
      supabase.removeChannel(channel)
      unsubBridge()
    }
  }, [spaceId, fetchLetters])

  const handleOpenLetter = (letter: LetterItem) => {
    // Check if sealed until future date
    if (letter.sealedUntilDate) {
      const today = new Date().toISOString().split('T')[0]
      if (today < letter.sealedUntilDate) {
        showToast(`This letter is sealed until ${formatLocalDate(letter.sealedUntilDate, { day: 'numeric', month: 'long', year: 'numeric' })}.`)
        return
      }
    }
    setSelectedLetter(letter)
  }

  const handleDeleteLetter = async (id: string) => {
    if (!window.confirm('Delete this letter from your letterbox?')) return

    setLetters((prev) => prev.filter((l) => l.id !== id))
    if (selectedLetter?.id === id) {
      setSelectedLetter(null)
    }
    showToast('Letter deleted.')

    try {
      const supabase = getSupabaseClient()
      const { error } = await supabase.from('letters').delete().eq('id', id)
      if (error) {
        console.warn('Supabase letter deletion error:', error.message)
      }
    } catch (err) {
      console.warn('Error deleting letter from Supabase:', err)
    }
  }

  const handleSendLetter = async () => {
    if (!newTitle.trim() || !newBody.trim() || !user) {
      showToast('Please add a title and write your letter.')
      return
    }

    setIsSending(true)
    try {
      const supabase = getSupabaseClient()
      const newLetterId = generateEntityId('letter')
      const authorEncoded = formatAuthor(user)
      const envelopeMeta = encodeEnvelopeMetadata(newSeal, newCategory)
      const nowIso = new Date().toISOString()

      const newRow = {
        id: newLetterId,
        space_id: spaceId,
        title: newTitle.trim(),
        body: newBody.trim(),
        author: authorEncoded,
        envelope_color: envelopeMeta,
        sealed_until: sealedDate || null,
        created_at: nowIso,
        is_read: false
      }

      const { error } = await supabase.from('letters').insert(newRow)
      if (error) {
        console.error('Supabase letter insert error:', error)
        throw new Error(error.message || 'Failed to save letter to database')
      }

      // Optimistically update UI state so it appears immediately
      const writtenFormatted = formatLocalDate(nowIso, { day: 'numeric', month: 'long', year: 'numeric' })
      const optimisticLetter: LetterItem = {
        id: newLetterId,
        title: newTitle.trim(),
        body: newBody.trim(),
        author: authorEncoded,
        authorName: user.nickname || 'You',
        isMine: true,
        writtenDate: `Written on ${writtenFormatted}`,
        createdAt: sealedDate
          ? `Sealed until ${formatLocalDate(sealedDate, { day: 'numeric', month: 'long', year: 'numeric' })}`
          : `Written on ${writtenFormatted}`,
        category: newCategory,
        sealType: newSeal,
        sealedUntilDate: sealedDate || undefined,
        isRead: false
      }

      setLetters((prev) => [optimisticLetter, ...prev.filter((l) => l.id !== newLetterId)])

      // Broadcast event and dispatch contextual partner notification
      realtimeBridge.broadcast({
        type: 'LETTER_SEALED',
        senderId: user.id,
        senderNickname: user.nickname,
        timestamp: Date.now(),
        data: { letterId: newLetterId, title: newTitle.trim() }
      }).catch(() => {})

      dispatchPartnerInteraction(user, space, 'LETTER_SENT', {
        noteTitle: newTitle.trim()
      }).catch(() => {})

      showToast('Your letter has been sealed in the letterbox.')
      setIsWriting(false)
      setNewTitle('')
      setNewBody('')
      setSealedDate('')
    } catch (err: any) {
      console.error('Failed to send letter:', err)
      showToast(err.message || 'Error sealing letter. Please try again.')
    } finally {
      setIsSending(false)
    }
  }

  return (
    <div className="page active" id="letters">
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
            onClick={() => setIsWriting(true)}
          >
            ＋ &nbsp; Write
          </button>
        </div>
      </header>

      {/* 2. HEAD & TITLE */}
      <div className="screen-head">
        <span className="overline">Words, saved for later</span>
      </div>
      <h2 className="screen-title">Letterbox</h2>
      <p className="screen-subtitle">For the days and versions of you still ahead.</p>

      {/* 3. ENVELOPES LIST */}
      {letters.length === 0 ? (
        <div className="p-8 text-center border border-dashed border-[var(--line)] rounded-2xl bg-[var(--white)] my-6 space-y-3 shadow-xs">
          <div className="w-12 h-12 rounded-full bg-[var(--paper)] text-[var(--app-accent)] flex items-center justify-center mx-auto text-xl">
            ✉️
          </div>
          <h3 className="font-serif text-sm font-semibold text-[var(--ink)]">No letters written yet</h3>
          <p className="text-xs text-[var(--soft)] max-w-xs mx-auto leading-relaxed">
            Write a quiet letter or time capsule for your partner to read now or unlock in the future.
          </p>
          <button
            type="button"
            onClick={() => setIsWriting(true)}
            className="py-2 px-4 rounded-xl bg-[var(--app-accent)] text-[var(--app-accent-text)] text-xs font-medium hover:opacity-90 transition shadow-xs cursor-pointer"
          >
            ＋ Write Your First Letter
          </button>
        </div>
      ) : (
        <div className="letters-list">
          {letters.map((letter) => {
            const isLocked = Boolean(
              letter.sealedUntilDate &&
                new Date().toISOString().split('T')[0] < letter.sealedUntilDate
            )

            const sealClass =
              letter.sealType === 'terra'
                ? 'terra'
                : letter.sealType === 'slate'
                ? 'slate'
                : letter.sealType === 'rose'
                ? 'rose'
                : ''

            return (
              <article
                key={letter.id}
                className="envelope cursor-pointer"
                onClick={() => handleOpenLetter(letter)}
              >
                <div className="env-top">
                  <span className="env-label">{letter.category || 'For a quiet day'}</span>
                  <div className="flex items-center gap-1.5 z-10">
                    <span className="env-date">
                      {isLocked
                        ? `${formatLocalDate(letter.sealedUntilDate)} · 🔒`
                        : 'Open now'}
                    </span>
                    <button
                      type="button"
                      onClick={(e) => {
                        e.stopPropagation()
                        handleDeleteLetter(letter.id)
                      }}
                      className="text-[#888980] hover:text-red-600 p-0.5 cursor-pointer transition"
                      title="Delete letter"
                    >
                      <Trash2 className="w-3 h-3" />
                    </button>
                  </div>
                </div>
                <div className="env-title">{letter.title}</div>
                <div className="env-sub">
                  {isLocked
                    ? `Sealed until ${formatLocalDate(letter.sealedUntilDate)}`
                    : letter.isMine
                    ? 'Written by you'
                    : `A note from ${letter.authorName}`}
                </div>
                <div className={`seal ${sealClass}`}>✦</div>
              </article>
            )
          })}
        </div>
      )}

      <p className="letter-foot">
        Sealed letters open on the day you choose. They stay between the two of you.
      </p>

      {/* 4. LETTER READER MODAL */}
      {selectedLetter && (
        <div
          className="modal-backdrop show"
          onClick={(e) => {
            if (e.target === e.currentTarget) setSelectedLetter(null)
          }}
        >
          <div className="modal">
            <div className="modal-handle"></div>
            <button
              type="button"
              className="close"
              onClick={() => setSelectedLetter(null)}
            >
              ×
            </button>
            <div className="modal-date">
              <span className="font-semibold text-[var(--ink)]">
                {selectedLetter.isMine ? 'Written by you' : `From ${selectedLetter.authorName}`}
              </span>
              <span className="mx-1.5 text-[var(--soft)]">·</span>
              <span>{selectedLetter.writtenDate}</span>
              {selectedLetter.sealedUntilDate && (
                <div className="text-[11px] text-[var(--app-accent)] mt-1 flex items-center gap-1">
                  <Lock className="w-3 h-3 inline" />
                  <span>Sealed until {formatLocalDate(selectedLetter.sealedUntilDate, { day: 'numeric', month: 'long', year: 'numeric' })}</span>
                </div>
              )}
            </div>
            <h3 className="text-lg font-serif mt-2">{selectedLetter.title}</h3>
            <p className="whitespace-pre-line leading-relaxed text-sm text-[var(--ink)] mt-3">
              {selectedLetter.body}
            </p>

            {selectedLetter.voiceUrl && (
              <div className="modal-audio">
                ◉ &nbsp; {selectedLetter.isMine ? 'You' : selectedLetter.authorName} left an audio note &nbsp;{' '}
                <span
                  style={{ float: 'right', cursor: 'pointer' }}
                  onClick={() => {
                    const audio = new Audio(selectedLetter.voiceUrl)
                    audio.play().catch(() => showToast('Could not play audio.'))
                  }}
                >
                  Listen ▶
                </span>
              </div>
            )}

            <div className="flex items-center justify-between pt-3 mt-4 border-t border-[var(--line)]">
              <button
                type="button"
                onClick={() => handleDeleteLetter(selectedLetter.id)}
                className="text-[10px] text-rose-500 hover:text-rose-400 flex items-center gap-1 cursor-pointer py-1 px-1.5 rounded transition"
              >
                <Trash2 className="w-3 h-3" />
                <span>Delete letter</span>
              </button>
              <span className="text-[9px] text-[var(--soft)]">Shared between you two</span>
            </div>
          </div>
        </div>
      )}

      {/* 5. WRITE LETTER MODAL */}
      {isWriting && (
        <div
          className="modal-backdrop show"
          onClick={(e) => {
            if (e.target === e.currentTarget) setIsWriting(false)
          }}
        >
          <div className="modal">
            <div className="modal-handle"></div>
            <button
              type="button"
              className="close"
              onClick={() => setIsWriting(false)}
            >
              ×
            </button>
            <div className="modal-date">New Letter to {partner?.nickname || 'Your Partner'}</div>
            <h3 className="font-serif">Write something for later</h3>

            <div className="mt-4 space-y-3.5">
              <div>
                <label className="text-[11px] font-medium text-[var(--soft)] block mb-1">
                  Title
                </label>
                <input
                  type="text"
                  placeholder="e.g. When you miss home"
                  value={newTitle}
                  onChange={(e) => setNewTitle(e.target.value)}
                  className="w-full text-sm p-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] focus:outline-none focus:ring-1 focus:ring-[var(--app-accent)]"
                />
              </div>

              <div>
                <label className="text-[11px] font-medium text-[var(--soft)] block mb-1">
                  Envelope Prompt / Occasion
                </label>
                <select
                  value={newCategory}
                  onChange={(e) => setNewCategory(e.target.value)}
                  className="w-full text-xs p-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] focus:outline-none"
                >
                  <option value="For a quiet day">For a quiet day</option>
                  <option value="Open on our anniversary">Open on our anniversary</option>
                  <option value="When you need a reminder">When you need a reminder</option>
                  <option value="For when we fight">For when we fight</option>
                  <option value="Open when you miss me">Open when you miss me</option>
                  <option value="Just because">Just because</option>
                </select>
              </div>

              <div>
                <label className="text-[11px] font-medium text-[var(--soft)] block mb-1">
                  Your Letter
                </label>
                <textarea
                  rows={5}
                  placeholder="Write whatever is in your heart..."
                  value={newBody}
                  onChange={(e) => setNewBody(e.target.value)}
                  className="w-full text-sm p-2.5 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] focus:outline-none focus:ring-1 focus:ring-[var(--app-accent)] resize-none"
                />
              </div>

              <div>
                <label className="text-[11px] font-medium text-[var(--soft)] block mb-1">
                  Seal Color
                </label>
                <div className="flex gap-2">
                  {[
                    { id: 'green', label: 'Sage', bg: '#4d655a' },
                    { id: 'terra', label: 'Terracotta', bg: '#c46851' },
                    { id: 'slate', label: 'Charcoal', bg: '#334155' },
                    { id: 'rose', label: 'Dusty Rose', bg: '#be7b72' }
                  ].map((s) => (
                    <button
                      key={s.id}
                      type="button"
                      onClick={() => setNewSeal(s.id as any)}
                      className={`flex-1 py-1.5 px-2 rounded-lg text-[10px] font-medium border flex items-center justify-center gap-1.5 transition ${
                        newSeal === s.id
                          ? 'border-[var(--app-accent)] ring-1 ring-[var(--app-accent)] font-semibold'
                          : 'border-[var(--line)] opacity-70'
                      }`}
                    >
                      <span
                        className="w-2.5 h-2.5 rounded-full"
                        style={{ backgroundColor: s.bg }}
                      />
                      <span>{s.label}</span>
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <label className="text-[11px] font-medium text-[var(--soft)] block mb-1">
                  Seal Until Date (Optional)
                </label>
                <input
                  type="date"
                  min={new Date().toISOString().split('T')[0]}
                  value={sealedDate}
                  onChange={(e) => setSealedDate(e.target.value)}
                  className="w-full text-xs p-2 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] focus:outline-none"
                />
                <p className="text-[10px] text-[var(--soft)] mt-0.5">
                  Leave blank to allow your partner to open it immediately.
                </p>
              </div>

              <div className="pt-2">
                <button
                  type="button"
                  disabled={isSending}
                  onClick={handleSendLetter}
                  className="w-full py-2.5 rounded-xl bg-[var(--app-accent)] text-[var(--app-accent-text)] text-xs font-semibold hover:opacity-90 transition shadow-xs flex items-center justify-center gap-1.5 cursor-pointer disabled:opacity-50"
                >
                  <Send className="w-3.5 h-3.5" />
                  <span>{isSending ? 'Sealing letter...' : 'Seal in Letterbox'}</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
