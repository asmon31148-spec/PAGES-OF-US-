const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

// 1. Create directory if not exists
const ensureDir = (dir) => {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
};

// SVG 1: Full App Icon (1024x1024) - Beautiful Sanctuary Journal & Heart Crest
const fullIconSvg = `
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <defs>
    <!-- Background Velvet Sanctuary Gradient -->
    <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#2a3d34"/>
      <stop offset="45%" stop-color="#202f28"/>
      <stop offset="100%" stop-color="#141c18"/>
    </linearGradient>

    <!-- Warm Atmospheric Aura Sphere -->
    <radialGradient id="auraGlow" cx="50%" cy="45%" r="55%">
      <stop offset="0%" stop-color="#e07a5f" stop-opacity="0.38"/>
      <stop offset="35%" stop-color="#f4a261" stop-opacity="0.2"/>
      <stop offset="70%" stop-color="#8a9b85" stop-opacity="0.12"/>
      <stop offset="100%" stop-color="#141c18" stop-opacity="0"/>
    </radialGradient>

    <!-- Soft Gold Gradient for Page Ribbons & Accents -->
    <linearGradient id="goldGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#fff3d1"/>
      <stop offset="50%" stop-color="#e9c46a"/>
      <stop offset="100%" stop-color="#d4a373"/>
    </linearGradient>

    <!-- Terracotta Rose Gradient for Left/Right Accent Pages -->
    <linearGradient id="roseGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#f28482"/>
      <stop offset="50%" stop-color="#e07a5f"/>
      <stop offset="100%" stop-color="#b77e6b"/>
    </linearGradient>

    <!-- Sanctuary Sage Gradient for Facing Page -->
    <linearGradient id="sageGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#c1d3be"/>
      <stop offset="50%" stop-color="#8a9b85"/>
      <stop offset="100%" stop-color="#4d655a"/>
    </linearGradient>

    <!-- Paper Texture Sheen -->
    <linearGradient id="paperLinen" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#ffffff"/>
      <stop offset="100%" stop-color="#f4f1ea"/>
    </linearGradient>

    <!-- Drop Shadow Filters -->
    <filter id="shadowLg" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="18" stdDeviation="22" flood-color="#070c09" flood-opacity="0.6"/>
    </filter>
    <filter id="shadowSm" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="6" stdDeviation="10" flood-color="#000000" flood-opacity="0.45"/>
    </filter>
    <filter id="glowLight" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="14" result="blur"/>
      <feComposite in="SourceGraphic" in2="blur" operator="over"/>
    </filter>
  </defs>

  <!-- 1. Background Rounded Canvas -->
  <rect width="1024" height="1024" rx="230" fill="url(#bgGrad)"/>
  <rect width="1024" height="1024" rx="230" fill="url(#auraGlow)"/>

  <!-- Subtle Outer Keyline Ring -->
  <rect x="24" y="24" width="976" height="976" rx="214" fill="none" stroke="url(#goldGrad)" stroke-width="2.5" stroke-opacity="0.25"/>

  <!-- 2. Sacred Starburst Stars in Background (Constellation of Us) -->
  <g opacity="0.4" fill="#fff3d1">
    <circle cx="280" cy="240" r="4"/>
    <circle cx="740" cy="260" r="3.5"/>
    <circle cx="210" cy="620" r="3"/>
    <circle cx="820" cy="580" r="4"/>
  </g>

  <!-- Top Center Sanctuary Star ✦ -->
  <g transform="translate(512, 220) scale(1.1)" filter="url(#glowLight)">
    <!-- 4-point North Star -->
    <path d="M 0,-42 Q 0,0 42,0 Q 0,0 0,42 Q 0,0 -42,0 Q 0,0 0,-42 Z" fill="url(#goldGrad)"/>
    <circle cx="0" cy="0" r="7" fill="#ffffff"/>
  </g>

  <!-- 3. MAIN OPEN JOURNAL EMBLEM (Forms an elegant heart at the top) -->
  <g filter="url(#shadowLg)" transform="translate(512, 545)">
    <!-- Back Cover Shadow & Edge (Open Leather Journal) -->
    <path d="M -300,160 Q -160,205 0,165 Q 160,205 300,160 L 320,-80 Q 170,-30 0,-70 Q -170,-30 -320,-80 Z"
          fill="#1b2620" opacity="0.75"/>

    <!-- Left Book Leaf (Sage Tone with Soft Linen) -->
    <path d="M -16,-62 C -95,-135 -245,-125 -295,-60 C -305,25 -285,115 -275,145 C -205,185 -95,145 -16,132 Z"
          fill="url(#paperLinen)" filter="url(#shadowSm)"/>
    
    <!-- Left Inner Depth Contour Layer -->
    <path d="M -20,-50 C -90,-115 -225,-105 -270,-50 C -278,25 -260,95 -250,128 C -185,165 -90,132 -20,122 Z"
          fill="url(#sageGrad)" opacity="0.18"/>

    <!-- Left Turning Page Ribbon (Heart-arc curve) -->
    <path d="M -16,-58 C -75,-125 -190,-120 -245,-65 C -255,10 -240,80 -230,118 C -170,150 -85,125 -16,115 Z"
          fill="url(#paperLinen)" opacity="0.95"/>

    <!-- Right Book Leaf (Rose Warmth Tone) -->
    <path d="M 16,-62 C 95,-135 245,-125 295,-60 C 305,25 285,115 275,145 C 205,185 95,145 16,132 Z"
          fill="url(#paperLinen)" filter="url(#shadowSm)"/>

    <!-- Right Inner Depth Contour Layer -->
    <path d="M 20,-50 C 90,-115 225,-105 270,-50 C 278,25 260,95 250,128 C 185,165 90,132 20,122 Z"
          fill="url(#roseGrad)" opacity="0.22"/>

    <!-- Right Turning Page Ribbon -->
    <path d="M 16,-58 C 75,-125 190,-120 245,-65 C 255,10 240,80 230,118 C 170,150 85,125 16,115 Z"
          fill="url(#paperLinen)" opacity="0.95"/>

    <!-- Spine Binding Ridge (Gilded Sanctuary Spine) -->
    <path d="M -16,-62 Q 0,-70 16,-62 L 16,132 Q 0,140 -16,132 Z"
          fill="url(#goldGrad)"/>

    <!-- Gilded Book Bookmark Ribbon Dropping Down -->
    <path d="M -8,135 Q 0,140 8,135 L 12,210 L 0,195 L -12,210 Z"
          fill="url(#roseGrad)" filter="url(#shadowSm)"/>

    <!-- Delicate Music Note / Whisper Feather on Left Page -->
    <g transform="translate(-130, 15) scale(0.85)" opacity="0.65">
      <path d="M 18,-25 L 38,-30 L 38,-8 L 18,-3 Z" fill="url(#sageGrad)"/>
      <ellipse cx="14" cy="5" rx="14" ry="10" transform="rotate(-20 14 5)" fill="url(#sageGrad)"/>
      <ellipse cx="34" cy="0" rx="14" ry="10" transform="rotate(-20 34 0)" fill="url(#sageGrad)"/>
    </g>

    <!-- Delicate Connected Heart on Right Page -->
    <g transform="translate(130, 20) scale(0.85)" opacity="0.75" filter="url(#glowLight)">
      <path d="M 0,-15 C -18,-35 -40,-12 -28,14 C -18,28 0,42 0,42 C 0,42 18,28 28,14 C 40,-12 18,-35 0,-15 Z"
            fill="url(#roseGrad)"/>
    </g>

    <!-- Center Tether Star Glow -->
    <circle cx="0" cy="25" r="9" fill="url(#goldGrad)" filter="url(#glowLight)"/>
    <circle cx="0" cy="25" r="4" fill="#ffffff"/>
  </g>

  <!-- 4. Subtle Bottom Script Tag: "PAGES OF US" -->
  <text x="512" y="870" 
        font-family="'Playfair Display', 'DM Serif Display', Georgia, serif" 
        font-size="44" 
        font-weight="600" 
        letter-spacing="12" 
        text-anchor="middle" 
        fill="#f4f1ea" 
        opacity="0.88">
    PAGES OF US
  </text>
  <text x="512" y="910" 
        font-family="'DM Sans', -apple-system, sans-serif" 
        font-size="20" 
        font-weight="500" 
        letter-spacing="6" 
        text-anchor="middle" 
        fill="#e07a5f" 
        opacity="0.85">
    SANCTUARY FOR TWO
  </text>
</svg>
`;

// SVG 2: Android Adaptive Icon Foreground (Centered strictly within safe 66% zone)
const adaptiveForegroundSvg = `
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <defs>
    <linearGradient id="afGold" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#fff3d1"/>
      <stop offset="50%" stop-color="#e9c46a"/>
      <stop offset="100%" stop-color="#d4a373"/>
    </linearGradient>

    <linearGradient id="afRose" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#f28482"/>
      <stop offset="50%" stop-color="#e07a5f"/>
      <stop offset="100%" stop-color="#b77e6b"/>
    </linearGradient>

    <linearGradient id="afSage" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#c1d3be"/>
      <stop offset="50%" stop-color="#8a9b85"/>
      <stop offset="100%" stop-color="#4d655a"/>
    </linearGradient>

    <linearGradient id="afPaper" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#ffffff"/>
      <stop offset="100%" stop-color="#f4f1ea"/>
    </linearGradient>

    <filter id="afShadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="16" stdDeviation="20" flood-color="#050a07" flood-opacity="0.55"/>
    </filter>
    <filter id="afGlow" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="12" result="blur"/>
      <feComposite in="SourceGraphic" in2="blur" operator="over"/>
    </filter>
  </defs>

  <!-- Scale slightly and place right in the central safe circle (diameter ~660px) -->
  <g transform="translate(512, 510) scale(0.92)">
    <!-- Top Sanctuary Star ✦ -->
    <g transform="translate(0, -250) scale(1.05)" filter="url(#afGlow)">
      <path d="M 0,-40 Q 0,0 40,0 Q 0,0 0,40 Q 0,0 -40,0 Q 0,0 0,-40 Z" fill="url(#afGold)"/>
      <circle cx="0" cy="0" r="7" fill="#ffffff"/>
    </g>

    <!-- Main Open Heart Book -->
    <g filter="url(#afShadow)">
      <!-- Back Cover Shadow -->
      <path d="M -260,140 Q -140,180 0,145 Q 140,180 260,140 L 275,-70 Q 150,-25 0,-60 Q -150,-25 -275,-70 Z"
            fill="#141c17" opacity="0.7"/>

      <!-- Left Page -->
      <path d="M -14,-54 C -82,-118 -215,-110 -258,-52 C -267,22 -250,100 -240,126 C -180,162 -82,126 -14,115 Z"
            fill="url(#afPaper)"/>
      <path d="M -18,-44 C -78,-100 -195,-92 -235,-44 C -242,22 -226,82 -218,110 C -162,144 -78,115 -18,106 Z"
            fill="url(#afSage)" opacity="0.22"/>

      <!-- Right Page -->
      <path d="M 14,-54 C 82,-118 215,-110 258,-52 C 267,22 250,100 240,126 C 180,162 82,126 14,115 Z"
            fill="url(#afPaper)"/>
      <path d="M 18,-44 C 78,-100 195,-92 235,-44 C 242,22 226,82 218,110 C 162,144 78,115 18,106 Z"
            fill="url(#afRose)" opacity="0.25"/>

      <!-- Spine -->
      <path d="M -14,-54 Q 0,-61 14,-54 L 14,115 Q 0,122 -14,115 Z"
            fill="url(#afGold)"/>

      <!-- Bookmark Ribbon -->
      <path d="M -7,118 Q 0,123 7,118 L 10,185 L 0,172 L -10,185 Z"
            fill="url(#afRose)"/>

      <!-- Right Heart Emblem -->
      <g transform="translate(110, 16) scale(0.72)" filter="url(#afGlow)">
        <path d="M 0,-15 C -18,-35 -40,-12 -28,14 C -18,28 0,42 0,42 C 0,42 18,28 28,14 C 40,-12 18,-35 0,-15 Z"
              fill="url(#afRose)"/>
      </g>

      <!-- Center Tether Star Glow -->
      <circle cx="0" cy="22" r="8" fill="url(#afGold)" filter="url(#afGlow)"/>
      <circle cx="0" cy="22" r="3.5" fill="#ffffff"/>
    </g>

    <!-- Elegant Monogram "P & U" at Bottom -->
    <text x="0" y="270" 
          font-family="'Playfair Display', Georgia, serif" 
          font-size="34" 
          font-weight="600" 
          letter-spacing="9" 
          text-anchor="middle" 
          fill="#f4f1ea" 
          opacity="0.95">
      PAGES OF US
    </text>
  </g>
</svg>
`;

// SVG 3: Android Adaptive Icon Background (1024x1024)
const adaptiveBackgroundSvg = `
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <defs>
    <linearGradient id="abBg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#2a3d34"/>
      <stop offset="45%" stop-color="#202f28"/>
      <stop offset="100%" stop-color="#141c18"/>
    </linearGradient>
    <radialGradient id="abAura" cx="50%" cy="50%" r="55%">
      <stop offset="0%" stop-color="#e07a5f" stop-opacity="0.32"/>
      <stop offset="40%" stop-color="#8a9b85" stop-opacity="0.16"/>
      <stop offset="100%" stop-color="#141c18" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#abBg)"/>
  <rect width="1024" height="1024" fill="url(#abAura)"/>
  <!-- Gentle Constellation dots -->
  <circle cx="300" cy="320" r="4" fill="#ffffff" opacity="0.3"/>
  <circle cx="720" cy="300" r="3" fill="#ffffff" opacity="0.25"/>
  <circle cx="280" cy="700" r="3.5" fill="#ffffff" opacity="0.2"/>
  <circle cx="750" cy="680" r="4" fill="#ffffff" opacity="0.3"/>
</svg>
`;

// SVG 4: Circular Mask for Round Icon
const roundIconSvg = fullIconSvg.replace('<rect width="1024" height="1024" rx="230"', '<circle cx="512" cy="512" r="512"');

async function generateAll() {
  console.log('Generating master PNG assets...');

  // 1. Assets folder for Capacitor
  ensureDir('assets');
  await sharp(Buffer.from(fullIconSvg)).resize(1024, 1024).png().toFile('assets/icon.png');
  await sharp(Buffer.from(fullIconSvg)).resize(1024, 1024).png().toFile('assets/icon-only.png');
  await sharp(Buffer.from(adaptiveForegroundSvg)).resize(1024, 1024).png().toFile('assets/icon-foreground.png');
  await sharp(Buffer.from(adaptiveBackgroundSvg)).resize(1024, 1024).png().toFile('assets/icon-background.png');
  await sharp(Buffer.from(fullIconSvg)).resize(2732, 2732, { fit: 'contain', background: '#1c2822' }).png().toFile('assets/splash.png');

  // 2. Public web assets
  await sharp(Buffer.from(fullIconSvg)).resize(512, 512).png().toFile('public/favicon.png');
  await sharp(Buffer.from(fullIconSvg)).resize(192, 192).png().toFile('public/icon-192.png');
  await sharp(Buffer.from(fullIconSvg)).resize(512, 512).png().toFile('public/icon-512.png');
  fs.writeFileSync('public/favicon.svg', fullIconSvg);

  // 3. Android Mipmap Densities
  const mipmaps = [
    { dir: 'mipmap-mdpi', iconSize: 48, fgSize: 108 },
    { dir: 'mipmap-hdpi', iconSize: 72, fgSize: 162 },
    { dir: 'mipmap-xhdpi', iconSize: 96, fgSize: 216 },
    { dir: 'mipmap-xxhdpi', iconSize: 144, fgSize: 324 },
    { dir: 'mipmap-xxxhdpi', iconSize: 192, fgSize: 432 },
  ];

  const resBase = path.join('android', 'app', 'src', 'main', 'res');

  for (const m of mipmaps) {
    const targetDir = path.join(resBase, m.dir);
    ensureDir(targetDir);

    // Standard Icon (Squircle/Rounded)
    await sharp(Buffer.from(fullIconSvg))
      .resize(m.iconSize, m.iconSize)
      .png()
      .toFile(path.join(targetDir, 'ic_launcher.png'));

    // Round Icon (Circular)
    await sharp(Buffer.from(roundIconSvg))
      .resize(m.iconSize, m.iconSize)
      .png()
      .toFile(path.join(targetDir, 'ic_launcher_round.png'));

    // Adaptive Foreground Icon (Safe 108dp canvas)
    await sharp(Buffer.from(adaptiveForegroundSvg))
      .resize(m.fgSize, m.fgSize)
      .png()
      .toFile(path.join(targetDir, 'ic_launcher_foreground.png'));

    console.log(`Generated icons for ${m.dir} (${m.iconSize}x${m.iconSize}, FG: ${m.fgSize}x${m.fgSize})`);
  }

  // 4. Update ic_launcher_background.xml
  const bgXmlPath = path.join(resBase, 'values', 'ic_launcher_background.xml');
  const bgXmlContent = `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#202f28</color>
</resources>
`;
  fs.writeFileSync(bgXmlPath, bgXmlContent, 'utf-8');
  console.log('Updated ic_launcher_background.xml to sanctuary sage #202f28');

  console.log('All icons generated successfully!');
}

generateAll().catch(err => {
  console.error('Error generating icons:', err);
  process.exit(1);
});
