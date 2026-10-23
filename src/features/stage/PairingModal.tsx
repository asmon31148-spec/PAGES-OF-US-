import React, { useState } from 'react'
import { useAuth } from '@/core/auth'
import { Copy, Check, Sparkles, X, Link2, Unlink } from 'lucide-react'

interface PairingModalProps {
  isOpen: boolean
  onClose: () => void
}

export const PairingModal: React.FC<PairingModalProps> = ({ isOpen, onClose }) => {
  const { user, space, partner, isPaired, joinSpace, unpairSpace } = useAuth()
  const [partnerCode, setPartnerCode] = useState('')
  const [copied, setCopied] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)

  if (!isOpen) return null

  // Live space pair code
  const currentPairCode = space?.pairCode || 'Generating code...'

  const handleCopy = () => {
    if (!space?.pairCode) return
    navigator.clipboard.writeText(currentPairCode)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  const handleJoin = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!partnerCode.trim()) return
    setError(null)
    setIsSubmitting(true)
    try {
      await joinSpace(partnerCode.trim())
      setPartnerCode('')
      onClose()
    } catch (err: any) {
      setError(err.message || 'Invalid pair code. Please double-check with your partner.')
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div
      className="fixed inset-0 z-[1000] flex items-end sm:items-center justify-center p-0 sm:p-4 bg-black/60 backdrop-blur-sm animate-in fade-in"
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose()
      }}
    >
      <div className="w-full max-w-sm rounded-t-3xl sm:rounded-3xl p-6 shadow-2xl relative border border-[var(--line)] bg-[var(--white)] text-[var(--ink)] max-h-[90dvh] overflow-y-auto">
        <button
          onClick={onClose}
          className="absolute top-4 right-4 p-2 rounded-full text-[var(--soft)] hover:text-[var(--ink)] transition cursor-pointer"
        >
          <X className="w-4 h-4" />
        </button>

        <div className="space-y-4">
          {/* Header */}
          <div className="text-center space-y-1">
            <div className="w-10 h-10 rounded-2xl mx-auto flex items-center justify-center mb-1.5 bg-[var(--paper)] text-[var(--app-accent)]">
              <Sparkles className="w-5 h-5 text-[var(--terra)]" />
            </div>
            <h2 className="text-base font-serif font-semibold text-[var(--ink)]">
              Two-Device Connection
            </h2>
            <p className="text-[11px] text-[var(--soft)] leading-relaxed">
              Connect both phones to share this private world in real time.
            </p>
          </div>

          {/* Connection Status Box */}
          <div className="p-3.5 rounded-2xl border border-[var(--line)] bg-[var(--paper)] space-y-2.5">
            <div className="flex items-center justify-between text-[11px]">
              <span className="text-[var(--soft)]">Status</span>
              <span
                className={`font-semibold flex items-center gap-1.5 ${
                  isPaired ? 'text-emerald-500' : 'text-amber-500'
                }`}
              >
                <span
                  className={`w-2 h-2 rounded-full ${
                    isPaired ? 'bg-emerald-500' : 'bg-amber-400 animate-pulse'
                  }`}
                />
                {isPaired && partner ? `Connected with ${partner.nickname}` : 'Waiting for Partner'}
              </span>
            </div>

            {/* Visual Avatar Bridge */}
            <div className="flex items-center justify-center gap-4 py-1">
              <div className="flex flex-col items-center gap-1">
                <div className="w-11 h-11 rounded-full border-2 border-[var(--app-accent)] bg-[var(--paper)] text-[var(--app-accent)] flex items-center justify-center font-bold text-xs">
                  {user?.nickname.slice(0, 2).toUpperCase() || 'YOU'}
                </div>
                <span className="text-[10px] font-medium text-[var(--ink)]">{user?.nickname || 'You'}</span>
              </div>

              <div className="flex flex-col items-center">
                <span className="text-xs text-[var(--soft)]">──── ✦ ────</span>
                <span className="text-[9px] text-[var(--soft)]">
                  {isPaired ? 'Private Tether' : 'Unlinked'}
                </span>
              </div>

              <div className="flex flex-col items-center gap-1">
                <div
                  className={`w-11 h-11 rounded-full border-2 flex items-center justify-center text-xs font-bold ${
                    isPaired
                      ? 'border-[var(--app-accent)] bg-[var(--paper)] text-[var(--app-accent)]'
                      : 'border-dashed border-[var(--line)] bg-transparent text-[var(--soft)]'
                  }`}
                >
                  {partner ? partner.nickname.slice(0, 2).toUpperCase() : '?'}
                </div>
                <span className="text-[10px] font-medium text-[var(--soft)]">
                  {partner ? partner.nickname : 'Partner'}
                </span>
              </div>
            </div>
          </div>

          {/* SECTION 1: YOUR PERSONAL INVITE CODE */}
          <div className="space-y-1.5 pt-1">
            <label className="text-[10px] font-semibold tracking-wider uppercase text-[var(--soft)] block">
              1. Your Personal Invite Code
            </label>
            <div className="flex items-center justify-between p-3 rounded-2xl border border-[var(--line)] bg-[var(--paper)] shadow-xs">
              <div className="space-y-0.5">
                <span className="font-mono text-base font-bold tracking-widest text-[var(--app-accent)]">
                  {currentPairCode}
                </span>
                <span className="block text-[9px] text-[var(--soft)]">
                  Share this code with your partner
                </span>
              </div>

              <button
                type="button"
                onClick={handleCopy}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-medium transition cursor-pointer active:scale-95 ${
                  copied
                    ? 'bg-emerald-600 text-white'
                    : 'bg-[var(--app-accent)] text-white hover:opacity-90'
                }`}
              >
                {copied ? <Check className="w-3.5 h-3.5" /> : <Copy className="w-3.5 h-3.5" />}
                <span>{copied ? 'Copied!' : 'Copy Code'}</span>
              </button>
            </div>
          </div>

          {/* DIVIDER */}
          <div className="relative flex py-1 items-center">
            <div className="flex-grow border-t border-[var(--line)]"></div>
            <span className="flex-shrink mx-3 text-[10px] uppercase font-semibold text-[var(--soft)] tracking-wider">
              OR
            </span>
            <div className="flex-grow border-t border-[var(--line)]"></div>
          </div>

          {/* SECTION 2: ENTER PARTNER'S CODE */}
          <form onSubmit={handleJoin} className="space-y-2">
            <label className="text-[10px] font-semibold tracking-wider uppercase text-[var(--soft)] block">
              2. Have your partner's code?
            </label>

            <div className="flex gap-2">
              <input
                type="text"
                placeholder="e.g. PAGE-7821"
                value={partnerCode}
                onChange={(e) => setPartnerCode(e.target.value.toUpperCase())}
                className="flex-1 px-3 py-2.5 rounded-xl font-mono text-center text-sm font-semibold tracking-wider border border-[var(--line)] bg-[var(--paper)] outline-none text-[var(--ink)] focus:border-[var(--app-accent)]"
              />
              <button
                type="submit"
                disabled={isSubmitting || !partnerCode.trim()}
                className="px-4 py-2.5 rounded-xl bg-[var(--app-accent)] text-white text-xs font-bold cursor-pointer hover:opacity-90 transition disabled:opacity-50 active:scale-95 flex items-center gap-1 shrink-0"
              >
                <Link2 className="w-3.5 h-3.5" />
                <span>{isSubmitting ? 'Linking...' : 'Connect'}</span>
              </button>
            </div>

            {error && (
              <p className="text-[10px] text-red-500 font-medium text-center pt-1">{error}</p>
            )}
          </form>

          {/* Unlink / Leave Space Option */}
          {isPaired && (
            <div className="pt-2 border-t border-[var(--line)] text-center">
              <button
                type="button"
                onClick={async () => {
                  if (window.confirm('Disconnect from this partner space? You will stay logged in to your account with a fresh private space.')) {
                    await unpairSpace()
                    onClose()
                  }
                }}
                className="text-[10px] text-rose-500 hover:text-rose-400 cursor-pointer inline-flex items-center gap-1 py-1"
              >
                <Unlink className="w-3 h-3" />
                <span>Disconnect Partner</span>
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
