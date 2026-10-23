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
  ShieldCheck,
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

  const [mode, setMode] = useState<'login' | 'signup' | 'forgot'>('login')

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
          'Google Sign-In is active for web. On the Android app, please log in with Email & Password below!'
        )
      } else if (err.code === 'auth/popup-closed-by-user') {
        setErrorMessage('Google Sign-In was closed before completing.')
      } else {
        setErrorMessage(
          'Google popup is blocked in this view. Please log in directly with your Email and Password below!'
        )
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

  const isPasswordError =
    errorMessage &&
    (errorMessage.toLowerCase().includes('wrong password') ||
      errorMessage.toLowerCase().includes('incorrect password') ||
      errorMessage.toLowerCase().includes('invalid-credential'))

  return (
    <div className="fixed inset-0 z-[9999] bg-[var(--app-bg)] text-[var(--ink)] flex flex-col justify-between overflow-y-auto p-5 sm:p-8 transition-colors duration-200">
      <div className="w-full max-w-sm mx-auto flex-1 flex flex-col justify-between my-auto">
        {/* Top Navigation Bar */}
        <div className="flex items-center justify-between mb-4">
          {mode === 'forgot' ? (
            <button
              type="button"
              onClick={() => handleModeSwitch('login')}
              className="flex items-center gap-1.5 text-xs text-[var(--soft)] hover:text-[var(--ink)] transition cursor-pointer p-1"
            >
              <ArrowLeft className="w-4 h-4" />
              <span>Back to Log In</span>
            </button>
          ) : (
            <div className="text-[10px] tracking-widest uppercase font-semibold text-[var(--soft)]">
              PAGES OF US · PRIVATE COUPLE APP
            </div>
          )}

          {onClose && (
            <button
              type="button"
              onClick={onClose}
              className="p-1.5 rounded-full text-[var(--soft)] hover:text-[var(--ink)] hover:bg-[var(--paper)] transition cursor-pointer ml-auto"
              title="Close"
            >
              <X className="w-4 h-4" />
            </button>
          )}
        </div>

        {/* Card Body */}
        <div className="p-6 sm:p-7 rounded-3xl border border-[var(--line)] bg-[var(--white)] shadow-md space-y-4">
          {/* Brand Header */}
          <div className="text-center pb-1">
            <div className="w-12 h-12 rounded-2xl bg-[var(--paper)] text-[var(--app-accent)] flex items-center justify-center mx-auto mb-2.5 shadow-2xs text-2xl font-serif">
              ❦
            </div>
            <h2 className="text-2xl font-bold tracking-tight text-[var(--ink)]">
              {mode === 'login'
                ? 'Welcome Back'
                : mode === 'signup'
                ? 'Create Account'
                : 'Reset Password'}
            </h2>
            <p className="text-xs text-[var(--soft)] mt-1 max-w-xs mx-auto leading-relaxed">
              {mode === 'login'
                ? 'Log in to your private shared couple space.'
                : mode === 'signup'
                ? 'Create a permanent account to keep your memories safe.'
                : 'Enter your email and we will send you an official link to reset your password.'}
            </p>
          </div>

          {/* FORGOT PASSWORD MODE */}
          {mode === 'forgot' ? (
            <form onSubmit={handleForgotPasswordSubmit} className="space-y-3.5 pt-1">
              {/* Feedback messages */}
              {errorMessage && (
                <div className="p-3 rounded-xl bg-red-500/10 border border-red-500/20 text-red-600 dark:text-red-400 text-xs flex items-start gap-2 animate-in fade-in">
                  <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                  <span className="leading-snug">{errorMessage}</span>
                </div>
              )}

              {successNotice && (
                <div className="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-700 dark:text-emerald-300 text-xs flex items-start gap-2 animate-in fade-in">
                  <CheckCircle2 className="w-4 h-4 shrink-0 mt-0.5" />
                  <span className="leading-snug">{successNotice}</span>
                </div>
              )}

              <div>
                <label className="text-[11px] font-semibold text-[var(--soft)] block mb-1">
                  Your Registered Email
                </label>
                <div className="relative">
                  <input
                    type="email"
                    required
                    placeholder="name@example.com"
                    value={email}
                    onChange={(e) => {
                      setEmail(e.target.value)
                      if (errorMessage) setErrorMessage(null)
                    }}
                    className="w-full text-xs py-2.5 px-3 pl-9 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] focus:outline-none focus:border-[var(--app-accent)]"
                    autoFocus
                  />
                  <Mail className="w-4 h-4 text-[var(--soft)] absolute left-3 top-3" />
                </div>
              </div>

              <button
                type="submit"
                disabled={isSubmitting || isLoading}
                className="w-full mt-2 py-3 px-4 rounded-xl bg-[var(--app-accent)] text-white text-xs font-semibold cursor-pointer hover:opacity-90 active:scale-[0.99] transition shadow-xs flex items-center justify-center gap-2 disabled:opacity-50"
              >
                {isSubmitting || isLoading ? (
                  <>
                    <RefreshCw className="w-4 h-4 animate-spin" />
                    <span>Sending Reset Link...</span>
                  </>
                ) : (
                  <>
                    <span>Send Password Reset Link</span>
                    <ArrowRight className="w-4 h-4" />
                  </>
                )}
              </button>

              <div className="text-center pt-2">
                <button
                  type="button"
                  onClick={() => handleModeSwitch('login')}
                  className="text-xs text-[var(--app-accent)] hover:underline font-medium cursor-pointer"
                >
                  Remember your password? Log in →
                </button>
              </div>
            </form>
          ) : (
            /* LOGIN OR SIGNUP MODE */
            <div className="space-y-3.5">
              {/* 1-Tap Google Sign-In Button */}
              <div>
                <button
                  type="button"
                  onClick={handleGoogleSignIn}
                  disabled={isSubmitting || isLoading}
                  className="w-full py-2.5 px-4 rounded-xl bg-[var(--paper)] border border-[var(--line)] hover:opacity-90 text-[var(--ink)] text-xs font-medium transition shadow-xs flex items-center justify-center gap-2.5 cursor-pointer disabled:opacity-50"
                >
                  <svg className="w-4 h-4" viewBox="0 0 24 24">
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
                  <span>Continue with Google</span>
                </button>
              </div>

              {/* Divider */}
              <div className="relative my-2 text-center">
                <div className="absolute inset-0 flex items-center">
                  <div className="w-full border-t border-[var(--line)]" />
                </div>
                <span className="relative bg-[var(--white)] px-2 text-[10px] uppercase tracking-wider text-[var(--soft)] font-medium">
                  or with email & password
                </span>
              </div>

              {/* Toggle Mode: Log In vs Create Account */}
              <div className="flex p-1 rounded-xl bg-[var(--paper)] border border-[var(--line)]">
                <button
                  type="button"
                  onClick={() => handleModeSwitch('login')}
                  className={`flex-1 py-1.5 text-xs font-semibold rounded-lg transition cursor-pointer ${
                    mode === 'login'
                      ? 'bg-[var(--white)] text-[var(--ink)] shadow-xs'
                      : 'text-[var(--soft)] hover:text-[var(--ink)]'
                  }`}
                >
                  Log In
                </button>
                <button
                  type="button"
                  onClick={() => handleModeSwitch('signup')}
                  className={`flex-1 py-1.5 text-xs font-semibold rounded-lg transition cursor-pointer ${
                    mode === 'signup'
                      ? 'bg-[var(--white)] text-[var(--ink)] shadow-xs'
                      : 'text-[var(--soft)] hover:text-[var(--ink)]'
                  }`}
                >
                  Create Account
                </button>
              </div>

              {/* Feedback Alert */}
              {errorMessage && (
                <div className="p-3 rounded-xl bg-red-500/10 border border-red-500/20 text-red-600 dark:text-red-400 text-xs flex items-start gap-2 animate-in fade-in">
                  <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                  <div className="flex-1">
                    <span className="leading-snug">{errorMessage}</span>
                    {isPasswordError && (
                      <button
                        type="button"
                        onClick={() => handleModeSwitch('forgot')}
                        className="block mt-1 text-[11px] font-semibold underline text-red-700 dark:text-red-300 cursor-pointer"
                      >
                        Forgot your password? Reset it here →
                      </button>
                    )}
                  </div>
                </div>
              )}

              {successNotice && (
                <div className="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-700 dark:text-emerald-300 text-xs flex items-start gap-2 animate-in fade-in">
                  <CheckCircle2 className="w-4 h-4 shrink-0 mt-0.5" />
                  <span className="leading-snug">{successNotice}</span>
                </div>
              )}

              {/* Form Fields */}
              <form onSubmit={handleEmailSubmit} className="space-y-3">
                {/* Nickname for signup */}
                {mode === 'signup' && (
                  <div>
                    <label className="text-[11px] font-semibold text-[var(--soft)] block mb-1">
                      Your Name / Nickname
                    </label>
                    <div className="relative">
                      <input
                        type="text"
                        required
                        placeholder="e.g. Alex"
                        value={nickname}
                        onChange={(e) => {
                          setNickname(e.target.value)
                          if (errorMessage) setErrorMessage(null)
                        }}
                        className="w-full text-xs py-2 px-3 pl-8 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] focus:outline-none focus:border-[var(--app-accent)]"
                      />
                      <User className="w-3.5 h-3.5 text-[var(--soft)] absolute left-2.5 top-2.5" />
                    </div>
                  </div>
                )}

                {/* Email Field */}
                <div>
                  <label className="text-[11px] font-semibold text-[var(--soft)] block mb-1">
                    Email Address
                  </label>
                  <div className="relative">
                    <input
                      type="email"
                      required
                      placeholder="name@example.com"
                      value={email}
                      onChange={(e) => {
                        setEmail(e.target.value)
                        if (errorMessage) setErrorMessage(null)
                      }}
                      className="w-full text-xs py-2 px-3 pl-8 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] focus:outline-none focus:border-[var(--app-accent)]"
                    />
                    <Mail className="w-3.5 h-3.5 text-[var(--soft)] absolute left-2.5 top-2.5" />
                  </div>
                </div>

                {/* Password Field */}
                <div>
                  <div className="flex items-center justify-between mb-1">
                    <label className="text-[11px] font-semibold text-[var(--soft)]">
                      {mode === 'signup' ? 'Create Password' : 'Password'}
                    </label>
                    {mode === 'login' && (
                      <button
                        type="button"
                        onClick={() => handleModeSwitch('forgot')}
                        className="text-[10.5px] text-[var(--app-accent)] hover:underline cursor-pointer font-medium"
                      >
                        Forgot password?
                      </button>
                    )}
                  </div>
                  <div className="relative">
                    <input
                      type={showPassword ? 'text' : 'password'}
                      required
                      placeholder="At least 6 characters"
                      value={password}
                      onChange={(e) => {
                        setPassword(e.target.value)
                        if (errorMessage) setErrorMessage(null)
                      }}
                      className="w-full text-xs py-2 px-3 pl-8 pr-8 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] focus:outline-none focus:border-[var(--app-accent)]"
                    />
                    <Lock className="w-3.5 h-3.5 text-[var(--soft)] absolute left-2.5 top-2.5" />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute right-2.5 top-2.5 text-[var(--soft)] hover:text-[var(--app-accent)] cursor-pointer"
                    >
                      {showPassword ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
                    </button>
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={isSubmitting || isLoading}
                  className="w-full mt-3 py-2.5 px-4 rounded-xl bg-[var(--app-accent)] text-white text-xs font-semibold cursor-pointer hover:opacity-90 active:scale-[0.99] transition shadow-xs flex items-center justify-center gap-1.5 disabled:opacity-50"
                >
                  {isSubmitting || isLoading ? (
                    <>
                      <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                      <span>Connecting...</span>
                    </>
                  ) : (
                    <>
                      <span>{mode === 'login' ? 'Log In' : 'Create Account'}</span>
                      <ArrowRight className="w-3.5 h-3.5" />
                    </>
                  )}
                </button>
              </form>
            </div>
          )}

          {/* Trust Badges */}
          <div className="pt-3 border-t border-[var(--line)] space-y-1.5 text-[10px] text-[var(--soft)]">
            <div className="flex items-center gap-2">
              <ShieldCheck className="w-3.5 h-3.5 text-[var(--app-accent)] shrink-0" />
              <span>Encrypted cloud storage · Safe between you two</span>
            </div>
            <div className="flex items-center gap-2">
              <Sparkles className="w-3.5 h-3.5 text-[var(--terra)] shrink-0" />
              <span>Instant live sync across both phones</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
