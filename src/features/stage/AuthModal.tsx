import React, { useState } from 'react'
import { useAuth } from '@/core/auth'
import { useToast } from '@/core/toast'
import {
  Lock,
  Mail,
  User,
  Eye,
  EyeOff,
  Sparkles,
  ArrowRight,
  ArrowLeft,
  RefreshCw,
  AlertCircle,
  CheckCircle2,
  X
} from 'lucide-react'

interface AuthModalProps {
  isOpen: boolean
  onClose?: () => void
}

export const AuthModal: React.FC<AuthModalProps> = ({ isOpen, onClose }) => {
  const {
    signUp,
    signIn,
    signInWithGoogle,
    resetPassword,
    isLoading
  } = useAuth()
  const { showToast } = useToast()

  // Mode: 'login' | 'signup' | 'forgot'
  const [mode, setMode] = useState<'login' | 'signup' | 'forgot'>('login')
  const [isEmailSheetOpen, setIsEmailSheetOpen] = useState(false)

  // Form state
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [nickname, setNickname] = useState('')
  const [showPassword, setShowPassword] = useState(false)

  // Feedback state
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [successNotice, setSuccessNotice] = useState<string | null>(null)

  if (!isOpen) return null

  const handleModeSwitch = (newMode: 'login' | 'signup' | 'forgot') => {
    setMode(newMode)
    setErrorMessage(null)
    setSuccessNotice(null)
  }

  // 1. Google Sign In
  const handleGoogleSignIn = async () => {
    setErrorMessage(null)
    setSuccessNotice(null)
    setIsSubmitting(true)
    try {
      await signInWithGoogle()
      showToast('Signed in with Google! Welcome to Pages of Us 💕')
      onClose?.()
    } catch (err: any) {
      if (err.code === 'auth/unauthorized-domain' || err.message?.includes('unauthorized-domain')) {
        setErrorMessage(
          'Google Sign-In is active for web. On the Android app, please log in with Email & Password!'
        )
        setIsEmailSheetOpen(true)
      } else if (err.code === 'auth/popup-closed-by-user') {
        setErrorMessage('Google Sign-In was closed before completing.')
      } else {
        setErrorMessage(
          'Please continue with your Email and Password below!'
        )
        setIsEmailSheetOpen(true)
      }
    } finally {
      setIsSubmitting(false)
    }
  }

  // 2. Email & Password Submit
  const handleEmailSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setErrorMessage(null)
    setSuccessNotice(null)

    const cleanEmail = email.trim().toLowerCase()
    const cleanPassword = password.trim()
    const cleanNickname = nickname.trim()

    if (!cleanEmail || !cleanPassword) {
      setErrorMessage('Please enter both your email and password.')
      return
    }

    if (cleanPassword.length < 6) {
      setErrorMessage('Password must be at least 6 characters.')
      return
    }

    if (mode === 'signup' && !cleanNickname) {
      setErrorMessage('Please enter your nickname so your partner knows who you are.')
      return
    }

    setIsSubmitting(true)
    try {
      if (mode === 'signup') {
        await signUp(cleanEmail, cleanPassword, cleanNickname)
        showToast(`Welcome to Pages of Us, ${cleanNickname}! 💕`)
      } else {
        await signIn(cleanEmail, cleanPassword)
        showToast('Logged in successfully. Welcome back!')
      }
      onClose?.()
    } catch (err: any) {
      const msg = err.message || 'Authentication error. Please try again.'
      setErrorMessage(msg)
    } finally {
      setIsSubmitting(false)
    }
  }

  // 3. Forgot Password Link
  const handleForgotPasswordSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    const cleanEmail = email.trim().toLowerCase()
    if (!cleanEmail) {
      setErrorMessage('Please enter your registered email address.')
      return
    }

    setIsSubmitting(true)
    setErrorMessage(null)
    setSuccessNotice(null)
    try {
      await resetPassword(cleanEmail)
      setSuccessNotice(
        `We sent a secure password reset link to ${cleanEmail}. Please check your email inbox and spam folder.`
      )
      showToast('Password reset link sent to your email ✉️')
    } catch (err: any) {
      setErrorMessage(err.message || 'Failed to send reset link. Please check your email and try again.')
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className="fixed inset-0 z-[9999] bg-[#faf8f5] text-[#1f231e] flex flex-col justify-between overflow-hidden p-6 sm:p-10 select-none">
      {/* 1. TOP CUTE ANIMATED MASCOT (Breeze Style) */}
      <div className="w-full max-w-sm mx-auto flex-1 flex flex-col items-center justify-center pt-4">
        <div className="relative w-full max-w-[340px] h-56 flex items-center justify-center">
          <svg
            viewBox="0 0 360 220"
            className="w-full h-full overflow-visible drop-shadow-sm"
          >
            {/* Pastel Sun */}
            <circle cx="100" cy="140" r="75" fill="#fef08a" opacity="0.55" />

            {/* Pastel Rainbow Arc Behind Clouds */}
            <path
              d="M 180 220 A 110 110 0 0 1 360 220"
              fill="none"
              stroke="#f87171"
              strokeWidth="11"
              strokeLinecap="round"
              opacity="0.85"
            />
            <path
              d="M 194 220 A 96 96 0 0 1 346 220"
              fill="none"
              stroke="#fbbf24"
              strokeWidth="11"
              strokeLinecap="round"
              opacity="0.85"
            />
            <path
              d="M 208 220 A 82 82 0 0 1 332 220"
              fill="none"
              stroke="#34d399"
              strokeWidth="11"
              strokeLinecap="round"
              opacity="0.85"
            />
            <path
              d="M 222 220 A 68 68 0 0 1 318 220"
              fill="none"
              stroke="#60a5fa"
              strokeWidth="11"
              strokeLinecap="round"
              opacity="0.85"
            />

            {/* Cloud 1 (Center Top - Joyful bouncing) */}
            <g className="animate-cloud-slow">
              {/* Cloud Body */}
              <path
                d="M 140 85 C 130 85 120 72 130 60 C 135 48 155 45 165 52 C 175 40 195 40 205 52 C 215 45 235 48 240 60 C 250 72 240 85 230 85 Z"
                fill="#ffffff"
                filter="drop-shadow(0px 8px 16px rgba(0,0,0,0.06))"
              />
              {/* Cute Smiling Face */}
              <circle cx="178" cy="67" r="2.5" fill="#1f231e" />
              <circle cx="197" cy="67" r="2.5" fill="#1f231e" />
              {/* Blushing Cheeks */}
              <ellipse cx="172" cy="71" rx="4" ry="2.5" fill="#fca5a5" opacity="0.65" />
              <ellipse cx="203" cy="71" rx="4" ry="2.5" fill="#fca5a5" opacity="0.65" />
              {/* Mouth */}
              <path
                d="M 184 72 Q 187.5 76 191 72"
                stroke="#1f231e"
                strokeWidth="1.8"
                fill="none"
                strokeLinecap="round"
              />
            </g>

            {/* Cloud 2 (Left Foreground - Playful bounce) */}
            <g className="animate-cloud-delayed">
              <path
                d="M 50 160 C 35 160 25 145 35 130 C 45 115 70 110 82 120 C 95 105 125 105 135 120 C 150 110 175 118 180 135 C 190 150 180 160 165 160 Z"
                fill="#ffffff"
                filter="drop-shadow(0px 8px 20px rgba(0,0,0,0.07))"
              />
              {/* Happy squint eyes */}
              <path
                d="M 98 138 Q 102 133 106 138"
                stroke="#1f231e"
                strokeWidth="2"
                fill="none"
                strokeLinecap="round"
              />
              <path
                d="M 124 138 Q 128 133 132 138"
                stroke="#1f231e"
                strokeWidth="2"
                fill="none"
                strokeLinecap="round"
              />
              {/* Cheeks */}
              <ellipse cx="93" cy="143" rx="4.5" ry="3" fill="#fca5a5" opacity="0.75" />
              <ellipse cx="137" cy="143" rx="4.5" ry="3" fill="#fca5a5" opacity="0.75" />
              {/* Open Joyful Smile */}
              <path
                d="M 110 144 Q 115 152 120 144 Z"
                fill="#f43f5e"
              />
            </g>

            {/* Cloud 3 (Right Foreground - Peeking Cloud) */}
            <g className="animate-cloud-slow">
              <path
                d="M 215 170 C 200 170 190 155 200 140 C 210 125 235 120 248 130 C 260 115 290 115 300 130 C 315 120 340 128 345 145 C 355 160 345 170 330 170 Z"
                fill="#ffffff"
                filter="drop-shadow(0px 8px 20px rgba(0,0,0,0.07))"
              />
              {/* Eyes */}
              <circle cx="265" cy="146" r="2.8" fill="#1f231e" />
              <circle cx="290" cy="146" r="2.8" fill="#1f231e" />
              {/* Cheeks */}
              <ellipse cx="258" cy="151" rx="4.5" ry="3" fill="#fca5a5" opacity="0.7" />
              <ellipse cx="297" cy="151" rx="4.5" ry="3" fill="#fca5a5" opacity="0.7" />
              {/* Smile */}
              <path
                d="M 273 150 Q 277.5 156 282 150"
                stroke="#1f231e"
                strokeWidth="2"
                fill="none"
                strokeLinecap="round"
              />
            </g>
          </svg>
        </div>

        {/* 2. WELCOMING HEADLINE */}
        <div className="text-center mt-3 mb-6">
          <h1 className="text-2xl font-bold tracking-tight text-[#1f231e]">
            Welcome to Pages of Us
          </h1>
          <p className="text-xs text-[#73776e] mt-1 font-medium">
            Log in or create an account below to continue.
          </p>
        </div>

        {/* Error message notice if any */}
        {errorMessage && (
          <div className="w-full mb-4 p-3 rounded-2xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2">
            <AlertCircle className="w-4 h-4 shrink-0 text-rose-600" />
            <span>{errorMessage}</span>
          </div>
        )}

        {/* 3. TWO CLEAN BREEZE-STYLE ACTION PILLS */}
        <div className="w-full space-y-3.5">
          {/* Button 1: Continue with Email */}
          <button
            type="button"
            onClick={() => {
              setIsEmailSheetOpen(true)
              setErrorMessage(null)
            }}
            className="w-full h-13 rounded-full bg-[#ffffff] hover:bg-[#f5f3ee] text-[#1f231e] font-semibold text-sm border border-[#e5e1d8] shadow-sm flex items-center justify-center gap-2.5 transition active:scale-[0.98] cursor-pointer"
          >
            <Mail className="w-4 h-4 text-[#1f231e]" />
            <span>Continue with Email</span>
          </button>

          {/* Divider */}
          <div className="relative flex items-center justify-center my-2">
            <div className="w-full border-t border-[#dedad0]"></div>
            <span className="absolute bg-[#faf8f5] px-3 text-[11px] font-medium text-[#8f928a]">
              or
            </span>
          </div>

          {/* Button 2: Continue with Google */}
          <button
            type="button"
            onClick={handleGoogleSignIn}
            disabled={isSubmitting}
            className="w-full h-13 rounded-full bg-[#ffffff] hover:bg-[#f5f3ee] text-[#1f231e] font-semibold text-sm border border-[#e5e1d8] shadow-sm flex items-center justify-center gap-3 transition active:scale-[0.98] cursor-pointer disabled:opacity-50"
          >
            {isSubmitting ? (
              <RefreshCw className="w-4 h-4 animate-spin text-[#1f231e]" />
            ) : (
              <svg className="w-4 h-4 shrink-0" viewBox="0 0 24 24">
                <path
                  fill="#4285F4"
                  d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                />
                <path
                  fill="#34A853"
                  d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                />
                <path
                  fill="#FBBC05"
                  d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"
                />
                <path
                  fill="#EA4335"
                  d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"
                />
              </svg>
            )}
            <span>Continue with Google</span>
          </button>
        </div>
      </div>

      {/* 4. FOOTER LEGAL DISCLAIMER */}
      <div className="w-full text-center py-2">
        <p className="text-[11px] text-[#8f928a] leading-relaxed max-w-xs mx-auto">
          By creating your account, you agree to Pages of Us’s{' '}
          <span className="text-[#425b4d] font-medium underline underline-offset-2 cursor-pointer">
            Privacy Policy
          </span>{' '}
          and{' '}
          <span className="text-[#425b4d] font-medium underline underline-offset-2 cursor-pointer">
            Terms of Use
          </span>
        </p>
      </div>

      {/* 5. SLIDE-UP EMAIL & PASSWORD BOTTOM SHEET */}
      {isEmailSheetOpen && (
        <div
          className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/45 backdrop-blur-xs transition-opacity duration-300"
          onClick={() => setIsEmailSheetOpen(false)}
        >
          <div
            className="w-full max-w-sm bg-[#ffffff] text-[#1f231e] rounded-t-3xl sm:rounded-3xl border border-[#dedad0] shadow-2xl p-6 animate-in slide-in-from-bottom duration-300 max-h-[85vh] overflow-y-auto"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Top Close / Back Control */}
            <div className="flex items-center justify-between pb-3 border-b border-[#dedad0]">
              <div className="flex items-center gap-1.5 text-xs font-semibold text-[#1f231e]">
                {mode === 'forgot' ? (
                  <button
                    type="button"
                    onClick={() => handleModeSwitch('login')}
                    className="flex items-center gap-1 text-[#425b4d] hover:underline cursor-pointer"
                  >
                    <ArrowLeft className="w-3.5 h-3.5" />
                    <span>Back to Log In</span>
                  </button>
                ) : (
                  <span>{mode === 'login' ? 'Welcome Back' : 'Create an Account'}</span>
                )}
              </div>
              <button
                type="button"
                onClick={() => setIsEmailSheetOpen(false)}
                className="w-7 h-7 rounded-full bg-[#ece8de] flex items-center justify-center text-[#73776e] hover:text-[#1f231e] transition cursor-pointer"
              >
                <X className="w-3.5 h-3.5" />
              </button>
            </div>

            {/* Segmented Mode Toggle (Log In / Create Account) */}
            {mode !== 'forgot' && (
              <div className="grid grid-cols-2 p-1 rounded-2xl bg-[#ece8de] border border-[#dedad0] text-xs font-semibold my-4">
                <button
                  type="button"
                  onClick={() => handleModeSwitch('login')}
                  className={`py-2 rounded-xl transition cursor-pointer ${
                    mode === 'login'
                      ? 'bg-[#ffffff] text-[#1f231e] shadow-xs'
                      : 'text-[#73776e] hover:text-[#1f231e]'
                  }`}
                >
                  Log In
                </button>
                <button
                  type="button"
                  onClick={() => handleModeSwitch('signup')}
                  className={`py-2 rounded-xl transition cursor-pointer ${
                    mode === 'signup'
                      ? 'bg-[#ffffff] text-[#1f231e] shadow-xs'
                      : 'text-[#73776e] hover:text-[#1f231e]'
                  }`}
                >
                  Create Account
                </button>
              </div>
            )}

            {/* Error & Success Alerts */}
            {errorMessage && (
              <div className="mb-3.5 p-3 rounded-2xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2">
                <AlertCircle className="w-4 h-4 shrink-0 text-rose-600" />
                <span>{errorMessage}</span>
              </div>
            )}

            {successNotice && (
              <div className="mb-3.5 p-3 rounded-2xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs flex items-center gap-2">
                <CheckCircle2 className="w-4 h-4 shrink-0 text-emerald-600" />
                <span>{successNotice}</span>
              </div>
            )}

            {/* Form */}
            {mode === 'forgot' ? (
              <form onSubmit={handleForgotPasswordSubmit} className="space-y-4 my-2">
                <p className="text-xs text-[#73776e] leading-relaxed">
                  Enter your account email. We will send you an official password recovery link.
                </p>
                <div>
                  <label className="text-[10px] font-semibold text-[#73776e] uppercase tracking-wider block mb-1">
                    Email Address
                  </label>
                  <div className="relative">
                    <input
                      type="email"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      placeholder="youremail@example.com"
                      required
                      autoFocus
                      className="w-full text-xs py-2.5 px-3 pl-8 rounded-xl border border-[#dedad0] bg-[#faf8f5] text-[#1f231e] focus:outline-none focus:border-[#425b4d]"
                    />
                    <Mail className="w-3.5 h-3.5 text-[#73776e] absolute left-2.5 top-3" />
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="w-full py-3 rounded-2xl bg-[#425b4d] text-white font-semibold text-xs hover:opacity-90 transition cursor-pointer flex items-center justify-center gap-1.5 shadow-sm disabled:opacity-50"
                >
                  {isSubmitting ? (
                    <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                  ) : (
                    <Mail className="w-3.5 h-3.5" />
                  )}
                  <span>Send Reset Email</span>
                </button>
              </form>
            ) : (
              <form onSubmit={handleEmailSubmit} className="space-y-3.5 my-2">
                {/* Nickname (Sign Up only) */}
                {mode === 'signup' && (
                  <div>
                    <label className="text-[10px] font-semibold text-[#73776e] uppercase tracking-wider block mb-1">
                      Your Nickname
                    </label>
                    <div className="relative">
                      <input
                        type="text"
                        value={nickname}
                        onChange={(e) => setNickname(e.target.value)}
                        placeholder="How your partner calls you"
                        required
                        className="w-full text-xs py-2.5 px-3 pl-8 rounded-xl border border-[#dedad0] bg-[#faf8f5] text-[#1f231e] focus:outline-none focus:border-[#425b4d]"
                      />
                      <User className="w-3.5 h-3.5 text-[#73776e] absolute left-2.5 top-3" />
                    </div>
                  </div>
                )}

                {/* Email Address */}
                <div>
                  <label className="text-[10px] font-semibold text-[#73776e] uppercase tracking-wider block mb-1">
                    Email Address
                  </label>
                  <div className="relative">
                    <input
                      type="email"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      placeholder="youremail@example.com"
                      required
                      className="w-full text-xs py-2.5 px-3 pl-8 rounded-xl border border-[#dedad0] bg-[#faf8f5] text-[#1f231e] focus:outline-none focus:border-[#425b4d]"
                    />
                    <Mail className="w-3.5 h-3.5 text-[#73776e] absolute left-2.5 top-3" />
                  </div>
                </div>

                {/* Password */}
                <div>
                  <div className="flex items-center justify-between mb-1">
                    <label className="text-[10px] font-semibold text-[#73776e] uppercase tracking-wider block">
                      Password
                    </label>
                    {mode === 'login' && (
                      <button
                        type="button"
                        onClick={() => handleModeSwitch('forgot')}
                        className="text-[10.5px] text-[#425b4d] font-medium hover:underline cursor-pointer"
                      >
                        Forgot password?
                      </button>
                    )}
                  </div>
                  <div className="relative">
                    <input
                      type={showPassword ? 'text' : 'password'}
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      placeholder="At least 6 characters"
                      required
                      className="w-full text-xs py-2.5 px-3 pl-8 pr-9 rounded-xl border border-[#dedad0] bg-[#faf8f5] text-[#1f231e] focus:outline-none focus:border-[#425b4d]"
                    />
                    <Lock className="w-3.5 h-3.5 text-[#73776e] absolute left-2.5 top-3" />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute right-2.5 top-2.5 p-0.5 text-[#73776e] hover:text-[#1f231e] cursor-pointer"
                      tabIndex={-1}
                    >
                      {showPassword ? (
                        <EyeOff className="w-3.5 h-3.5" />
                      ) : (
                        <Eye className="w-3.5 h-3.5" />
                      )}
                    </button>
                  </div>
                </div>

                {/* Submit Action Button */}
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="w-full py-3 rounded-2xl bg-[#425b4d] text-white font-semibold text-xs hover:opacity-90 transition cursor-pointer flex items-center justify-center gap-1.5 shadow-sm disabled:opacity-50 mt-2"
                >
                  {isSubmitting ? (
                    <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                  ) : (
                    <ArrowRight className="w-3.5 h-3.5" />
                  )}
                  <span>
                    {mode === 'login' ? 'Log In to Our Space' : 'Create Account'}
                  </span>
                </button>
              </form>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
