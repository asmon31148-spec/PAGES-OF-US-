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
  RefreshCw,
  AlertCircle,
  Phone,
  KeyRound,
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
    initPhoneRecaptcha,
    sendPhoneCode,
    verifyPhoneCode,
    loginGuest,
    isLoading
  } = useAuth()
  const { showToast } = useToast()

  const [mode, setMode] = useState<'login' | 'signup'>('login')
  const [authMethod, setAuthMethod] = useState<'email' | 'phone'>('email')

  // Email form state
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [nickname, setNickname] = useState('')
  const [showPassword, setShowPassword] = useState(false)

  // Phone form state
  const [phoneNumber, setPhoneNumber] = useState('')
  const [verificationCode, setVerificationCode] = useState('')
  const [confirmationResult, setConfirmationResult] = useState<any>(null)
  const [isCodeSent, setIsCodeSent] = useState(false)

  // Feedback state
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [successNotice, setSuccessNotice] = useState<string | null>(null)

  if (!isOpen) return null

  const handleModeSwitch = (newMode: 'login' | 'signup') => {
    setMode(newMode)
    setErrorMessage(null)
    setSuccessNotice(null)
  }

  // 1. Google 1-Tap Sign In
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
          'Your mobile IP (192.168.0.202) is not authorized for Google Sign-In in Firebase Console yet. In Firebase Console → Authentication → Settings → Authorized Domains, add 192.168.0.202. Alternatively, log in instantly below with Email & Password!'
        )
      } else if (err.code === 'auth/popup-closed-by-user') {
        setErrorMessage('Google Sign-In was closed before completing.')
      } else {
        setErrorMessage(err.message || 'Google Sign-In failed.')
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
  const handleForgotPassword = async () => {
    const cleanEmail = email.trim().toLowerCase()
    if (!cleanEmail) {
      setErrorMessage('Please enter your email above first so we can send your reset link.')
      return
    }

    setIsSubmitting(true)
    setErrorMessage(null)
    try {
      await resetPassword(cleanEmail)
      setSuccessNotice(`Password reset link sent to ${cleanEmail}. Please check your inbox and spam folder.`)
      showToast('Password reset link sent to your email ✉️')
    } catch (err: any) {
      setErrorMessage(err.message || 'Failed to send reset link.')
    } finally {
      setIsSubmitting(false)
    }
  }

  // 4. Send Phone Code (SMS)
  const handleSendPhoneCode = async (e: React.FormEvent) => {
    e.preventDefault()
    setErrorMessage(null)
    setSuccessNotice(null)

    const cleanPhone = phoneNumber.trim()
    if (!cleanPhone || cleanPhone.length < 8) {
      setErrorMessage('Please enter a valid phone number with country code (e.g. +1 555 123 4567).')
      return
    }

    setIsSubmitting(true)
    try {
      const verifier = initPhoneRecaptcha('recaptcha-container')
      if (!verifier) {
        throw new Error('Could not initialize reCAPTCHA verifier. Please check your network.')
      }
      const confirmation = await sendPhoneCode(cleanPhone, verifier)
      setConfirmationResult(confirmation)
      setIsCodeSent(true)
      setSuccessNotice(`Verification code sent to ${cleanPhone}. Please enter it below.`)
      showToast('SMS verification code sent! 📱')
    } catch (err: any) {
      if (err.code === 'auth/operation-not-allowed' || err.message?.includes('operation-not-allowed')) {
        setErrorMessage(
          'Phone SMS requires enabling India (+91) in Firebase Console (Authentication → Settings → SMS Region Policy). In the meantime, please log in with Email & Password or Google Sign-In above!'
        )
      } else {
        setErrorMessage(err.message || 'Error sending SMS code. Please try Google or Email login.')
      }
    } finally {
      setIsSubmitting(false)
    }
  }

  // 5. Verify Phone Code
  const handleVerifyPhoneCode = async (e: React.FormEvent) => {
    e.preventDefault()
    setErrorMessage(null)

    const cleanCode = verificationCode.trim()
    if (!cleanCode || cleanCode.length < 6) {
      setErrorMessage('Please enter the 6-digit code received via SMS.')
      return
    }

    if (!confirmationResult) {
      setErrorMessage('Verification session expired. Please request a new code.')
      return
    }

    setIsSubmitting(true)
    try {
      await verifyPhoneCode(confirmationResult, cleanCode, nickname.trim() || 'Partner')
      showToast('Phone verified! Welcome to Pages of Us 💕')
      onClose?.()
    } catch (err: any) {
      setErrorMessage(err.message || 'Invalid verification code. Please check and try again.')
    } finally {
      setIsSubmitting(false)
    }
  }

  const isAlreadyRegistered =
    errorMessage &&
    (errorMessage.toLowerCase().includes('already registered') ||
      errorMessage.toLowerCase().includes('already exists') ||
      errorMessage.toLowerCase().includes('already in use'))

  const isInvalidCredential =
    errorMessage &&
    (errorMessage.toLowerCase().includes('invalid email or password') ||
      errorMessage.toLowerCase().includes('incorrect password') ||
      errorMessage.toLowerCase().includes('invalid-credential'))

  return (
    <div className="modal-backdrop show !z-[9999] bg-black/75 backdrop-blur-md">
      <div className="modal max-w-sm !rounded-3xl shadow-2xl border border-[var(--line)] bg-[var(--white)] text-[var(--ink)] my-auto relative max-h-[92vh] overflow-y-auto">
        {onClose && (
          <button
            type="button"
            onClick={onClose}
            className="absolute top-4 right-4 p-1.5 rounded-full text-[var(--soft)] hover:text-[var(--ink)] hover:bg-[var(--paper)] transition cursor-pointer"
            title="Close"
          >
            <X className="w-4 h-4" />
          </button>
        )}

        <div className="modal-handle"></div>

        {/* Brand Header */}
        <div className="text-center pt-1 pb-2">
          <div className="w-12 h-12 rounded-2xl bg-[var(--paper)] text-[var(--app-accent)] flex items-center justify-center mx-auto mb-2 shadow-xs font-serif text-xl">
            ❦
          </div>
          <div className="text-[10px] tracking-widest uppercase font-semibold text-[var(--soft)]">
            A PLACE FOR TWO
          </div>
          <h2 className="text-xl font-serif font-bold text-[var(--ink)] mt-0.5">
            Pages of Us
          </h2>
          <p className="text-[11px] text-[var(--soft)] mt-0.5 max-w-xs mx-auto">
            {mode === 'login'
              ? 'Sign in to access your shared memories and stage.'
              : 'Create an account to keep your couple memories permanently.'}
          </p>
        </div>

        {/* 1-Tap Google Sign-In Button */}
        <div className="my-2">
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
        <div className="relative my-3 text-center">
          <div className="absolute inset-0 flex items-center">
            <div className="w-full border-t border-[var(--line)]" />
          </div>
          <span className="relative bg-[var(--white)] px-2 text-[10px] uppercase tracking-wider text-[var(--soft)]">
            or with email / phone
          </span>
        </div>

        {/* Method Switcher: Email vs Phone */}
        <div className="flex items-center justify-center gap-1.5 mb-2.5">
          <button
            type="button"
            onClick={() => {
              setAuthMethod('email')
              setErrorMessage(null)
              setSuccessNotice(null)
            }}
            className={`px-3 py-1 rounded-lg text-xs font-medium transition cursor-pointer ${
              authMethod === 'email'
                ? 'bg-[var(--app-accent)] text-white shadow-2xs'
                : 'text-[var(--soft)] hover:text-[var(--ink)] hover:bg-[var(--paper)]'
            }`}
          >
            ✉️ Email & Password
          </button>
          <button
            type="button"
            onClick={() => {
              setAuthMethod('phone')
              setErrorMessage(null)
              setSuccessNotice(null)
            }}
            className={`px-3 py-1 rounded-lg text-xs font-medium transition cursor-pointer ${
              authMethod === 'phone'
                ? 'bg-[var(--app-accent)] text-white shadow-2xs'
                : 'text-[var(--soft)] hover:text-[var(--ink)] hover:bg-[var(--paper)]'
            }`}
          >
            📱 Phone (SMS)
          </button>
        </div>

        {/* Toggle Mode: Log In vs Sign Up */}
        <div className="flex p-1 rounded-xl bg-[var(--paper)] border border-[var(--line)] mb-3">
          <button
            type="button"
            onClick={() => handleModeSwitch('login')}
            className={`flex-1 py-1.5 text-xs font-medium rounded-lg transition cursor-pointer ${
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
            className={`flex-1 py-1.5 text-xs font-medium rounded-lg transition cursor-pointer ${
              mode === 'signup'
                ? 'bg-[var(--white)] text-[var(--ink)] shadow-xs'
                : 'text-[var(--soft)] hover:text-[var(--ink)]'
            }`}
          >
            Sign Up
          </button>
        </div>

        {/* Success Notice Banner */}
        {successNotice && (
          <div className="mb-3 p-2.5 rounded-2xl bg-emerald-500/10 border border-emerald-500/30 text-emerald-900 text-[11px] flex items-start gap-2 animate-in fade-in">
            <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0 mt-0.5" />
            <span className="flex-1 leading-tight">{successNotice}</span>
          </div>
        )}

        {/* Error Banner with Smart Helpful Actions */}
        {errorMessage && (
          <div className="mb-3 animate-in fade-in duration-200">
            {errorMessage.toLowerCase().includes('authorized domains') ? (
              <div className="p-3 rounded-2xl bg-amber-500/10 border border-amber-500/30 text-amber-900 text-xs flex flex-col gap-2">
                <div className="flex items-start gap-2">
                  <AlertCircle className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
                  <span className="font-medium text-[11px] leading-tight">
                    {errorMessage}
                  </span>
                </div>
                <button
                  type="button"
                  onClick={() => {
                    setAuthMethod('email')
                    setErrorMessage(null)
                  }}
                  className="py-1.5 px-3 bg-[#4d655a] hover:bg-[#3d5047] text-white rounded-xl text-[11px] font-medium transition cursor-pointer text-center shadow-xs"
                >
                  Use Email & Password Instead →
                </button>
              </div>
            ) : errorMessage.toLowerCase().includes('sms region') ? (
              <div className="p-3 rounded-2xl bg-amber-500/10 border border-amber-500/30 text-amber-900 text-xs flex flex-col gap-2">
                <div className="flex items-start gap-2">
                  <AlertCircle className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
                  <span className="font-medium text-[11px] leading-tight">
                    {errorMessage}
                  </span>
                </div>
                <button
                  type="button"
                  onClick={() => {
                    setAuthMethod('email')
                    setErrorMessage(null)
                  }}
                  className="py-1.5 px-3 bg-[#4d655a] hover:bg-[#3d5047] text-white rounded-xl text-[11px] font-medium transition cursor-pointer text-center shadow-xs"
                >
                  Use Email & Password Instead →
                </button>
              </div>
            ) : isAlreadyRegistered ? (
              <div className="p-3 rounded-2xl bg-amber-500/10 border border-amber-500/30 text-amber-900 text-xs flex flex-col gap-1.5">
                <div className="flex items-start gap-2">
                  <AlertCircle className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
                  <span className="font-medium text-[11px] leading-tight">
                    This email is already registered in your sanctuary.
                  </span>
                </div>
                <button
                  type="button"
                  onClick={() => handleModeSwitch('login')}
                  className="mt-1 py-1.5 px-3 bg-amber-600 hover:bg-amber-700 text-white rounded-xl text-[11px] font-medium transition flex items-center justify-center gap-1.5 cursor-pointer shadow-xs"
                >
                  <span>Switch to Log In</span>
                  <ArrowRight className="w-3.5 h-3.5" />
                </button>
              </div>
            ) : isInvalidCredential ? (
              <div className="p-3 rounded-2xl bg-rose-500/10 border border-rose-500/25 text-rose-900 text-xs flex flex-col gap-2">
                <div className="flex items-start gap-2">
                  <AlertCircle className="w-4 h-4 text-rose-600 shrink-0 mt-0.5" />
                  <span className="leading-tight text-[11px]">
                    Invalid email or password. If you signed up with Google, use Google Sign-In.
                  </span>
                </div>
                <div className="flex items-center gap-2 pt-1 border-t border-rose-200">
                  <button
                    type="button"
                    onClick={handleForgotPassword}
                    className="flex-1 py-1 px-2 text-[10px] bg-rose-600 hover:bg-rose-700 text-white rounded-lg transition font-medium text-center cursor-pointer"
                  >
                    Send Password Reset Link
                  </button>
                  <button
                    type="button"
                    onClick={handleGoogleSignIn}
                    className="flex-1 py-1 px-2 text-[10px] bg-[var(--white)] border border-rose-300 dark:border-rose-900 text-rose-600 dark:text-rose-300 rounded-lg transition font-medium text-center cursor-pointer"
                  >
                    Try Google Sign-In
                  </button>
                </div>
              </div>
            ) : (
              <div className="p-2.5 rounded-2xl bg-rose-500/10 border border-rose-500/25 text-rose-800 text-[11px] flex items-center gap-2">
                <AlertCircle className="w-4 h-4 text-rose-600 shrink-0" />
                <span className="flex-1 leading-tight">{errorMessage}</span>
              </div>
            )}
          </div>
        )}

        {/* METHOD A: Email Form */}
        {authMethod === 'email' ? (
          <form onSubmit={handleEmailSubmit} className="space-y-3">
            {mode === 'signup' && (
              <div>
                <label className="text-[10px] font-semibold text-[var(--soft)] uppercase tracking-wider block mb-1">
                  Your Nickname
                </label>
                <div className="relative">
                  <input
                    type="text"
                    required
                    placeholder="e.g. Maya, Zoobi..."
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

            <div>
              <label className="text-[10px] font-semibold text-[var(--soft)] uppercase tracking-wider block mb-1">
                Email Address
              </label>
              <div className="relative">
                <input
                  type="email"
                  required
                  placeholder="you@email.com"
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

            <div>
              <div className="flex items-center justify-between mb-1">
                <label className="text-[10px] font-semibold text-[var(--soft)] uppercase tracking-wider">
                  Password
                </label>
                {mode === 'login' && (
                  <button
                    type="button"
                    onClick={handleForgotPassword}
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
              className="w-full mt-3 py-2.5 px-4 rounded-xl bg-[var(--app-accent)] text-white text-xs font-medium cursor-pointer hover:opacity-90 transition shadow-xs flex items-center justify-center gap-1.5 disabled:opacity-50"
            >
              {isSubmitting || isLoading ? (
                <>
                  <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                  <span>Connecting...</span>
                </>
              ) : (
                <>
                  <span>{mode === 'login' ? 'Log In to Sanctuary' : 'Create Account'}</span>
                  <ArrowRight className="w-3.5 h-3.5" />
                </>
              )}
            </button>
          </form>
        ) : (
          /* METHOD B: Phone Form (SMS OTP) */
          <div className="space-y-3">
            <div id="recaptcha-container"></div>

            {!isCodeSent ? (
              <form onSubmit={handleSendPhoneCode} className="space-y-3">
                <div>
                  <label className="text-[10px] font-semibold text-[var(--soft)] uppercase tracking-wider block mb-1">
                    Phone Number (with Country Code)
                  </label>
                  <div className="relative">
                    <input
                      type="tel"
                      required
                      placeholder="+1 (555) 123-4567"
                      value={phoneNumber}
                      onChange={(e) => setPhoneNumber(e.target.value)}
                      className="w-full text-xs py-2 px-3 pl-8 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] focus:outline-none focus:border-[var(--app-accent)]"
                    />
                    <Phone className="w-3.5 h-3.5 text-[var(--soft)] absolute left-2.5 top-2.5" />
                  </div>
                  <span className="text-[9.5px] text-[var(--soft)] mt-1 block">
                    Include your country code (e.g. +91, +1, +44).
                  </span>
                </div>

                <button
                  type="submit"
                  disabled={isSubmitting || isLoading}
                  className="w-full mt-2 py-2.5 px-4 rounded-xl bg-[var(--app-accent)] text-white text-xs font-medium cursor-pointer hover:opacity-90 transition shadow-xs flex items-center justify-center gap-1.5 disabled:opacity-50"
                >
                  {isSubmitting || isLoading ? (
                    <>
                      <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                      <span>Sending SMS code...</span>
                    </>
                  ) : (
                    <>
                      <span>Send 6-Digit SMS Code</span>
                      <ArrowRight className="w-3.5 h-3.5" />
                    </>
                  )}
                </button>
              </form>
            ) : (
              <form onSubmit={handleVerifyPhoneCode} className="space-y-3">
                {mode === 'signup' && (
                  <div>
                    <label className="text-[10px] font-semibold text-[var(--soft)] uppercase tracking-wider block mb-1">
                      Your Nickname
                    </label>
                    <div className="relative">
                      <input
                        type="text"
                        placeholder="e.g. Maya, Zoobi..."
                        value={nickname}
                        onChange={(e) => setNickname(e.target.value)}
                        className="w-full text-xs py-2 px-3 pl-8 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] focus:outline-none focus:border-[var(--app-accent)]"
                      />
                      <User className="w-3.5 h-3.5 text-[var(--soft)] absolute left-2.5 top-2.5" />
                    </div>
                  </div>
                )}

                <div>
                  <label className="text-[10px] font-semibold text-[var(--soft)] uppercase tracking-wider block mb-1">
                    6-Digit SMS Verification Code
                  </label>
                  <div className="relative">
                    <input
                      type="text"
                      maxLength={6}
                      required
                      placeholder="123456"
                      value={verificationCode}
                      onChange={(e) => setVerificationCode(e.target.value)}
                      className="w-full text-center tracking-widest font-mono text-base py-2 px-3 rounded-xl border border-[var(--line)] bg-[var(--paper)] text-[var(--ink)] focus:outline-none focus:border-[var(--app-accent)]"
                      autoFocus
                    />
                    <KeyRound className="w-3.5 h-3.5 text-[var(--soft)] absolute left-2.5 top-3" />
                  </div>
                </div>

                <div className="flex gap-2">
                  <button
                    type="button"
                    onClick={() => {
                      setIsCodeSent(false)
                      setVerificationCode('')
                    }}
                    className="py-2.5 px-3 rounded-xl border border-[var(--line)] text-xs text-[var(--soft)] hover:bg-[var(--paper)] transition cursor-pointer"
                  >
                    Change Phone
                  </button>
                  <button
                    type="submit"
                    disabled={isSubmitting || isLoading}
                    className="flex-1 py-2.5 px-4 rounded-xl bg-[var(--app-accent)] text-white text-xs font-medium cursor-pointer hover:opacity-90 transition shadow-xs flex items-center justify-center gap-1.5 disabled:opacity-50"
                  >
                    {isSubmitting || isLoading ? (
                      <>
                        <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                        <span>Verifying...</span>
                      </>
                    ) : (
                      <>
                        <span>Verify & Enter</span>
                        <ArrowRight className="w-3.5 h-3.5" />
                      </>
                    )}
                  </button>
                </div>
              </form>
            )}
          </div>
        )}

        {/* Offline / Guest Escape Hatch */}
        <div className="pt-3 text-center">
          <button
            type="button"
            onClick={() => {
              loginGuest(nickname.trim() || 'Maya')
              showToast('Entered Sanctuary in Offline / Guest Mode 🌿')
              onClose?.()
            }}
            className="text-[11px] text-[var(--soft)] hover:text-[var(--ink)] underline underline-offset-4 transition cursor-pointer"
          >
            Skip for now · Enter sanctuary as guest →
          </button>
        </div>

        {/* Commercial Trust Badges */}
        <div className="pt-2.5 mt-2.5 border-t border-[var(--line)] space-y-1 text-[10px] text-[var(--soft)]">
          <div className="flex items-center gap-2">
            <ShieldCheck className="w-3.5 h-3.5 text-[var(--app-accent)] shrink-0" />
            <span>Encrypted cloud storage · Safe between you two</span>
          </div>
          <div className="flex items-center gap-2">
            <Sparkles className="w-3.5 h-3.5 text-[var(--terra)] shrink-0" />
            <span>Permanent cross-device sync like Instagram</span>
          </div>
        </div>
      </div>
    </div>
  )
}
