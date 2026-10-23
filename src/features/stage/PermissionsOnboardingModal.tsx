import React, { useState } from 'react'
import {
  Bell,
  Camera,
  Mic,
  MapPin,
  Image as ImageIcon,
  Check,
  ShieldCheck,
  Sparkles,
  ArrowRight,
  RefreshCw
} from 'lucide-react'
import {
  requestAllSanctuaryPermissions,
  markPermissionsOnboardingComplete
} from '@/core/permissions/permissionsService'

interface PermissionsModalProps {
  isOpen: boolean
  onComplete: () => void
}

export const PermissionsOnboardingModal: React.FC<PermissionsModalProps> = ({
  isOpen,
  onComplete
}) => {
  const [isRequesting, setIsRequesting] = useState(false)
  const [currentStep, setCurrentStep] = useState<string | null>(null)

  if (!isOpen) return null

  const handleGrantPermissions = async () => {
    setIsRequesting(true)
    try {
      await requestAllSanctuaryPermissions((step) => {
        setCurrentStep(step)
      })
    } catch (err) {
      console.warn('Permissions request notice:', err)
    } finally {
      markPermissionsOnboardingComplete()
      setIsRequesting(false)
      onComplete()
    }
  }

  const handleSkip = () => {
    markPermissionsOnboardingComplete()
    onComplete()
  }

  const PERMISSION_ITEMS = [
    {
      icon: Bell,
      color: 'bg-rose-50 text-rose-700 border-rose-200',
      title: 'Instant Lock-screen Alerts',
      desc: 'Get notified when your partner sends a love letter or updates their note.'
    },
    {
      icon: Camera,
      color: 'bg-amber-50 text-amber-700 border-amber-200',
      title: 'Camera & Candid Moments',
      desc: 'Snap instant candid selfies and memories directly inside your sanctuary.'
    },
    {
      icon: ImageIcon,
      color: 'bg-emerald-50 text-emerald-700 border-emerald-200',
      title: 'Photos & Vault Storage',
      desc: 'Tuck private couple photos and vacation memories safely into your Vault.'
    },
    {
      icon: Mic,
      color: 'bg-indigo-50 text-indigo-700 border-indigo-200',
      title: 'Voice Memos & Audio',
      desc: 'Send voice letters and listen to quiet audio snippets together.'
    },
    {
      icon: MapPin,
      color: 'bg-sky-50 text-sky-700 border-sky-200',
      title: 'Live Presence & Distance Tether',
      desc: 'Calculate real-time distance and local sunrises between you two.'
    }
  ]

  return (
    <div className="modal-backdrop show !z-[99999] bg-black/75 backdrop-blur-md">
      <div className="modal max-w-sm !rounded-3xl shadow-2xl border border-[var(--line)] bg-[var(--white)] text-[var(--ink)] my-auto overflow-hidden">
        <div className="modal-handle"></div>

        {/* Header Branding */}
        <div className="text-center pt-2 pb-3">
          <div className="w-12 h-12 rounded-2xl bg-[var(--paper)] text-[var(--app-accent)] flex items-center justify-center mx-auto mb-2 shadow-xs font-serif text-xl">
            ❦
          </div>
          <div className="text-[10px] tracking-widest uppercase font-semibold text-[var(--soft)]">
            ONE-TIME SETUP
          </div>
          <h2 className="text-xl font-serif font-bold text-[var(--ink)] mt-0.5">
            Welcome to Pages of Us
          </h2>
          <p className="text-[11px] text-[var(--soft)] mt-1 max-w-xs mx-auto leading-relaxed">
            To make your couple sanctuary seamless without asking every time, allow the permissions below once.
          </p>
        </div>

        {/* Permissions List */}
        <div className="space-y-2 py-2 max-h-[38vh] overflow-y-auto pr-1">
          {PERMISSION_ITEMS.map((item, idx) => {
            const Icon = item.icon
            return (
              <div
                key={idx}
                className="flex items-start gap-2.5 p-2 rounded-2xl bg-[var(--paper)] border border-[var(--line)]"
              >
                <div
                  className={`w-7 h-7 rounded-xl flex items-center justify-center shrink-0 border ${item.color}`}
                >
                  <Icon className="w-3.5 h-3.5" />
                </div>
                <div className="min-w-0 flex-1">
                  <div className="text-xs font-semibold text-[var(--ink)] leading-tight">
                    {item.title}
                  </div>
                  <div className="text-[10px] text-[var(--soft)] mt-0.5 leading-snug">
                    {item.desc}
                  </div>
                </div>
              </div>
            )
          })}
        </div>

        {/* Action Button */}
        <div className="pt-3 space-y-2">
          <button
            type="button"
            onClick={handleGrantPermissions}
            disabled={isRequesting}
            className="w-full py-2.5 px-4 rounded-xl bg-[var(--app-accent)] text-white text-xs font-medium cursor-pointer hover:opacity-90 transition shadow-xs flex items-center justify-center gap-1.5 disabled:opacity-50"
          >
            {isRequesting ? (
              <>
                <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                <span>
                  {currentStep === 'notifications'
                    ? 'Allowing Alerts...'
                    : currentStep === 'media'
                    ? 'Allowing Camera & Audio...'
                    : currentStep === 'location'
                    ? 'Allowing Tether...'
                    : 'Setting up permissions...'}
                </span>
              </>
            ) : (
              <>
                <span>Enable Sanctuary Access</span>
                <ArrowRight className="w-3.5 h-3.5" />
              </>
            )}
          </button>

          <button
            type="button"
            onClick={handleSkip}
            disabled={isRequesting}
            className="w-full py-1 text-center text-[11px] text-[var(--soft)] hover:text-[var(--ink)] transition cursor-pointer"
          >
            Maybe later · Continue to Sanctuary
          </button>
        </div>

        {/* Privacy Note */}
        <div className="pt-3 mt-3 border-t border-[var(--line)] flex items-center justify-center gap-1.5 text-[10px] text-[var(--soft)]">
          <ShieldCheck className="w-3.5 h-3.5 text-[var(--app-accent)]" />
          <span>Encrypted between only you two · Never sold or shared</span>
        </div>
      </div>
    </div>
  )
}
