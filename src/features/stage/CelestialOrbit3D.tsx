import React, { useEffect, useRef } from 'react'
import * as THREE from 'three'

interface CelestialOrbit3DProps {
  userInitial?: string
  partnerInitial?: string
  isPaired: boolean
  triggerPulse?: boolean
  onCanvasTap?: () => void
}

export const CelestialOrbit3D: React.FC<CelestialOrbit3DProps> = ({
  userInitial = 'A',
  partnerInitial = 'Z',
  isPaired,
  triggerPulse,
  onCanvasTap
}) => {
  const containerRef = useRef<HTMLDivElement>(null)
  const pulseTriggerRef = useRef(triggerPulse)
  pulseTriggerRef.current = triggerPulse

  useEffect(() => {
    const container = containerRef.current
    if (!container) return

    const width = container.clientWidth
    const height = container.clientHeight

    // 1. Scene, Camera, Renderer
    const scene = new THREE.Scene()
    const camera = new THREE.PerspectiveCamera(50, width / height, 0.1, 1000)
    camera.position.z = 24

    const renderer = new THREE.WebGLRenderer({
      alpha: true,
      antialias: true,
      powerPreference: 'high-performance'
    })
    renderer.setSize(width, height)
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
    container.appendChild(renderer.domElement)

    // 2. Cosmic Particle Field (Stardust)
    const particleCount = 450
    const particleGeometry = new THREE.BufferGeometry()
    const particlePositions = new Float32Array(particleCount * 3)
    const particleColors = new Float32Array(particleCount * 3)

    for (let i = 0; i < particleCount; i++) {
      const radius = 10 + Math.random() * 18
      const theta = Math.random() * Math.PI * 2
      const phi = Math.acos(2 * Math.random() - 1)

      particlePositions[i * 3] = radius * Math.sin(phi) * Math.cos(theta)
      particlePositions[i * 3 + 1] = radius * Math.sin(phi) * Math.sin(theta)
      particlePositions[i * 3 + 2] = radius * Math.cos(phi)

      // Gradient color (amber gold to soft rose violet)
      const isGold = Math.random() > 0.4
      particleColors[i * 3] = isGold ? 0.98 : 0.85
      particleColors[i * 3 + 1] = isGold ? 0.82 : 0.45
      particleColors[i * 3 + 2] = isGold ? 0.45 : 0.75
    }

    particleGeometry.setAttribute(
      'position',
      new THREE.BufferAttribute(particlePositions, 3)
    )
    particleGeometry.setAttribute(
      'color',
      new THREE.BufferAttribute(particleColors, 3)
    )

    const particleMaterial = new THREE.PointsMaterial({
      size: 0.28,
      vertexColors: true,
      transparent: true,
      opacity: 0.65,
      blending: THREE.AdditiveBlending
    })

    const particleSystem = new THREE.Points(particleGeometry, particleMaterial)
    scene.add(particleSystem)

    // 3. The Two Celestial Orbs (You & Partner)
    const orbGeometry = new THREE.SphereGeometry(1.3, 32, 32)

    // User Core (Warm Gold / Amber Glow)
    const userOrbMaterial = new THREE.MeshBasicMaterial({
      color: 0xf59e0b,
      wireframe: true
    })
    const userOrb = new THREE.Mesh(orbGeometry, userOrbMaterial)
    scene.add(userOrb)

    // Partner Core (Rose / Amethyst Glow)
    const partnerOrbMaterial = new THREE.MeshBasicMaterial({
      color: isPaired ? 0xec4899 : 0x71717a,
      wireframe: true
    })
    const partnerOrb = new THREE.Mesh(orbGeometry, partnerOrbMaterial)
    scene.add(partnerOrb)

    // Constellation Tether Line
    const tetherMaterial = new THREE.LineBasicMaterial({
      color: 0xffffff,
      transparent: true,
      opacity: isPaired ? 0.35 : 0.1
    })
    const tetherPoints = [new THREE.Vector3(), new THREE.Vector3()]
    const tetherGeometry = new THREE.BufferGeometry().setFromPoints(tetherPoints)
    const tetherLine = new THREE.Line(tetherGeometry, tetherMaterial)
    scene.add(tetherLine)

    // 4. Shockwave Pulse Ring (Expands when pulse triggered)
    const ringGeometry = new THREE.RingGeometry(0.1, 0.4, 64)
    const ringMaterial = new THREE.MeshBasicMaterial({
      color: 0xf59e0b,
      side: THREE.DoubleSide,
      transparent: true,
      opacity: 0
    })
    const pulseRing = new THREE.Mesh(ringGeometry, ringMaterial)
    scene.add(pulseRing)

    let pulseScale = 0
    let isPulseActive = false

    // 5. Interactive Touch / Mouse Drag Controls
    let isDragging = false
    let previousMousePosition = { x: 0, y: 0 }
    let targetRotationX = 0
    let targetRotationY = 0

    const onPointerDown = (e: MouseEvent | TouchEvent) => {
      isDragging = true
      const clientX = 'touches' in e ? e.touches[0].clientX : e.clientX
      const clientY = 'touches' in e ? e.touches[0].clientY : e.clientY
      previousMousePosition = { x: clientX, y: clientY }
    }

    const onPointerMove = (e: MouseEvent | TouchEvent) => {
      if (!isDragging) return
      const clientX = 'touches' in e ? e.touches[0].clientX : e.clientX
      const clientY = 'touches' in e ? e.touches[0].clientY : e.clientY

      const deltaX = clientX - previousMousePosition.x
      const deltaY = clientY - previousMousePosition.y

      targetRotationY += deltaX * 0.006
      targetRotationX += deltaY * 0.006

      previousMousePosition = { x: clientX, y: clientY }
    }

    const onPointerUp = () => {
      isDragging = false
    }

    container.addEventListener('mousedown', onPointerDown)
    window.addEventListener('mousemove', onPointerMove)
    window.addEventListener('mouseup', onPointerUp)

    container.addEventListener('touchstart', onPointerDown, { passive: true })
    window.addEventListener('touchmove', onPointerMove, { passive: true })
    window.addEventListener('touchend', onPointerUp)

    // 6. Animation Loop
    let animationFrameId: number
    let clock = new THREE.Clock()
    let lastPulseRefState = false

    const animate = () => {
      animationFrameId = requestAnimationFrame(animate)
      const elapsedTime = clock.getElapsedTime()

      // Smooth interactive rotation
      scene.rotation.y += (targetRotationY - scene.rotation.y) * 0.05
      scene.rotation.x += (targetRotationX - scene.rotation.x) * 0.05

      // Passive cosmic swirl
      particleSystem.rotation.y = elapsedTime * 0.03
      particleSystem.rotation.x = elapsedTime * 0.015

      // Celestial Orbit Math (Two bodies orbiting a common barycenter)
      const orbitSpeed = 0.7
      const orbitDistance = 5.5

      userOrb.position.x = Math.cos(elapsedTime * orbitSpeed) * orbitDistance
      userOrb.position.z = Math.sin(elapsedTime * orbitSpeed) * orbitDistance
      userOrb.position.y = Math.sin(elapsedTime * orbitSpeed * 1.5) * 1.2
      userOrb.rotation.y += 0.02
      userOrb.rotation.x += 0.01

      partnerOrb.position.x = -Math.cos(elapsedTime * orbitSpeed) * orbitDistance
      partnerOrb.position.z = -Math.sin(elapsedTime * orbitSpeed) * orbitDistance
      partnerOrb.position.y = -Math.sin(elapsedTime * orbitSpeed * 1.5) * 1.2
      partnerOrb.rotation.y -= 0.02
      partnerOrb.rotation.x -= 0.01

      // Update tether connection line
      const positions = tetherGeometry.attributes.position.array as Float32Array
      positions[0] = userOrb.position.x
      positions[1] = userOrb.position.y
      positions[2] = userOrb.position.z
      positions[3] = partnerOrb.position.x
      positions[4] = partnerOrb.position.y
      positions[5] = partnerOrb.position.z
      tetherGeometry.attributes.position.needsUpdate = true

      // Trigger Pulse Shockwave
      if (pulseTriggerRef.current && !lastPulseRefState) {
        isPulseActive = true
        pulseScale = 0.5
        ringMaterial.opacity = 0.9
      }
      lastPulseRefState = Boolean(pulseTriggerRef.current)

      if (isPulseActive) {
        pulseScale += 0.4
        pulseRing.scale.set(pulseScale, pulseScale, pulseScale)
        pulseRing.position.copy(userOrb.position)
        pulseRing.lookAt(camera.position)
        ringMaterial.opacity *= 0.92

        if (ringMaterial.opacity < 0.03) {
          isPulseActive = false
          ringMaterial.opacity = 0
        }
      }

      renderer.render(scene, camera)
    }

    animate()

    // 7. Responsive Resize Handler
    const handleResize = () => {
      if (!container) return
      const w = container.clientWidth
      const h = container.clientHeight
      camera.aspect = w / h
      camera.updateProjectionMatrix()
      renderer.setSize(w, h)
    }

    window.addEventListener('resize', handleResize)

    return () => {
      cancelAnimationFrame(animationFrameId)
      window.removeEventListener('resize', handleResize)
      container.removeEventListener('mousedown', onPointerDown)
      window.removeEventListener('mousemove', onPointerMove)
      window.removeEventListener('mouseup', onPointerUp)
      container.removeEventListener('touchstart', onPointerDown)
      window.removeEventListener('touchmove', onPointerMove)
      window.removeEventListener('touchend', onPointerUp)
      if (container.contains(renderer.domElement)) {
        container.removeChild(renderer.domElement)
      }
      renderer.dispose()
    }
  }, [isPaired])

  return (
    <div
      ref={containerRef}
      onClick={onCanvasTap}
      className="w-full h-56 relative rounded-3xl overflow-hidden cursor-grab active:cursor-grabbing select-none"
      style={{
        background: 'radial-gradient(circle at center, rgba(245,158,11,0.06) 0%, rgba(10,9,20,0.8) 70%, transparent 100%)'
      }}
    >
      {/* Interactive Overlay Hints */}
      <div className="absolute top-3 left-4 pointer-events-none">
        <span className="text-[10px] uppercase font-bold tracking-widest text-amber-400/80">
          3D Celestial Orbit
        </span>
        <p className="text-[11px] text-white/50">Drag to rotate cosmic space</p>
      </div>

      <div className="absolute bottom-3 right-4 pointer-events-none">
        <span className="text-[9px] font-mono text-white/40">
          {userInitial} ─── ✦ ─── {partnerInitial}
        </span>
      </div>
    </div>
  )
}
