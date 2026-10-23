import React, { createContext, useContext, useState, useRef, useCallback } from 'react'

interface ToastContextType {
  showToast: (message: string) => void
}

const ToastContext = createContext<ToastContextType>({
  showToast: () => {}
})

export const useToast = () => useContext(ToastContext)

export const ToastProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [toastMessage, setToastMessage] = useState<string>('')
  const [isVisible, setIsVisible] = useState(false)
  const timerRef = useRef<any>(null)

  const showToast = useCallback((message: string) => {
    if (timerRef.current) {
      clearTimeout(timerRef.current)
    }
    setToastMessage(message)
    setIsVisible(true)
    timerRef.current = setTimeout(() => {
      setIsVisible(false)
    }, 2200)
  }, [])

  return (
    <ToastContext.Provider value={{ showToast }}>
      {children}
      <div
        className={`toast ${isVisible ? 'show' : ''}`}
        role="alert"
        style={{ zIndex: 100000 }}
      >
        {toastMessage}
      </div>
    </ToastContext.Provider>
  )
}
