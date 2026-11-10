import 'package:flutter/material.dart';
import 'models/app_theme_data.dart';
import 'models/theme_palette.dart';

/// Central hand-crafted registry of living couple themes
class ThemeRegistry {
  static const String defaultThemeId = 'sunset_chai';

  // 1. DEFAULT SANCTUARY (The Current Obsidian Midnight / Warm Cream Silk)
  static const AppThemeData defaultSanctuary = AppThemeData(
    id: 'default_sanctuary',
    name: 'Sanctuary Obsidian',
    description: 'Deep midnight obsidian with warm terracotta, rose-plum & golden amber blooms',
    emoji: '✨',
    lightPalette: ThemePalette(
      gradientColors: [
        Color(0xFFE07A5F), // Terracotta
        Color(0xFFD4A373), // Warm Sand
        Color(0xFF8B4789), // Soft Plum
      ],
      glassTint: Color(0xFFFFFFFF),
      glassOpacity: 0.88,
      primaryText: Color(0xFF1A1C22),
      secondaryText: Color(0xFF555D6E),
      accentColor: Color(0xFFE07A5F),
      iconColor: Color(0xFFE07A5F),
      dividerColor: Color(0x1F000000),
      canvasBackground: Color(0xFFECE7DE),
      cardBackground: Color(0xFFFFFFFF),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.60,
    ),
    darkPalette: ThemePalette(
      gradientColors: [
        Color(0xFFE07A5F), // Warm Terracotta
        Color(0xFF8B4789), // Ethereal Plum
        Color(0xFFE9C46A), // Amber
      ],
      glassTint: Color(0xFF141722),
      glassOpacity: 0.90,
      primaryText: Color(0xFFFBFBFC),
      secondaryText: Color(0xFFA5ACB8),
      accentColor: Color(0xFFE07A5F),
      iconColor: Color(0xFFE07A5F),
      dividerColor: Color(0x28FFFFFF),
      canvasBackground: Color(0xFF0C0E14),
      cardBackground: Color(0xFF141722),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.35,
    ),
  );

  // 2. SUNSET CHAI (Warm Terracotta, Cinnamon Chai, Golden Dusk)
  static const AppThemeData sunsetChai = AppThemeData(
    id: 'sunset_chai',
    name: 'Sunset Chai',
    description: 'Warm earthen cinnamon, spiced tea, and sun-drenched evening dusk',
    emoji: '☕',
    lightPalette: ThemePalette(
      gradientColors: [
        Color(0xFFE27D60), // Spiced Chai
        Color(0xFFE8A87C), // Apricot Clay
        Color(0xFFC38D9E), // Dusky Rose
      ],
      glassTint: Color(0xFFFFFFFF),
      glassOpacity: 0.90,
      primaryText: Color(0xFF1E1A17),
      secondaryText: Color(0xFF63564F),
      accentColor: Color(0xFFE07A5F),
      iconColor: Color(0xFFE07A5F),
      dividerColor: Color(0x228B4513),
      canvasBackground: Color(0xFFF5EFE6),
      cardBackground: Color(0xFFFFFFFF),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.65,
    ),
    darkPalette: ThemePalette(
      gradientColors: [
        Color(0xFFB85042), // Burnt Cinnamon
        Color(0xFFE7717D), // Soft Crimson
        Color(0xFFC2956E), // Golden Spice
      ],
      glassTint: Color(0xFF191316),
      glassOpacity: 0.90,
      primaryText: Color(0xFFFAF5F0),
      secondaryText: Color(0xFFB8A89C),
      accentColor: Color(0xFFE07A5F),
      iconColor: Color(0xFFE28468),
      dividerColor: Color(0x28FFFFFF),
      canvasBackground: Color(0xFF110D10),
      cardBackground: Color(0xFF1C1417),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.35,
    ),
  );

  // 3. MIDNIGHT RAIN (Deep Slate, Indigo, Electric Cyan)
  static const AppThemeData midnightRain = AppThemeData(
    id: 'midnight_rain',
    name: 'Midnight Rain',
    description: 'Quiet nighttime showers, neon puddles and electric blue moonlight',
    emoji: '🌧️',
    lightPalette: ThemePalette(
      gradientColors: [
        Color(0xFF38BDF8), // Sky Rain
        Color(0xFF818CF8), // Soft Indigo
        Color(0xFF2DD4BF), // Dew Teal
      ],
      glassTint: Color(0xFFFFFFFF),
      glassOpacity: 0.90,
      primaryText: Color(0xFF0F172A),
      secondaryText: Color(0xFF475569),
      accentColor: Color(0xFF0284C7),
      iconColor: Color(0xFF0284C7),
      dividerColor: Color(0x1F0F172A),
      canvasBackground: Color(0xFFE8EDF4),
      cardBackground: Color(0xFFFFFFFF),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.65,
    ),
    darkPalette: ThemePalette(
      gradientColors: [
        Color(0xFF0284C7), // Electric Cyan
        Color(0xFF4338CA), // Deep Indigo
        Color(0xFF0F766E), // Deep Marine
      ],
      glassTint: Color(0xFF0B132B),
      glassOpacity: 0.92,
      primaryText: Color(0xFFF8FAFC),
      secondaryText: Color(0xFF94A3B8),
      accentColor: Color(0xFF38BDF8),
      iconColor: Color(0xFF38BDF8),
      dividerColor: Color(0x28FFFFFF),
      canvasBackground: Color(0xFF070B14),
      cardBackground: Color(0xFF0F172A),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.38,
    ),
  );

  // 4. LAVENDER DREAM (Velvet Plum, Soft Lilac, Alabaster)
  static const AppThemeData lavenderDream = AppThemeData(
    id: 'lavender_dream',
    name: 'Lavender Dream',
    description: 'Soft purple haze, gentle twilight petals and dreamy velvet lavender',
    emoji: '💜',
    lightPalette: ThemePalette(
      gradientColors: [
        Color(0xFFC084FC), // Lavender
        Color(0xFFF472B6), // Soft Orchid
        Color(0xFFA78BFA), // Pale Violet
      ],
      glassTint: Color(0xFFFFFFFF),
      glassOpacity: 0.90,
      primaryText: Color(0xFF1E102E),
      secondaryText: Color(0xFF5B4A6F),
      accentColor: Color(0xFF9333EA),
      iconColor: Color(0xFF9333EA),
      dividerColor: Color(0x1F3B0764),
      canvasBackground: Color(0xFFF3EDF7),
      cardBackground: Color(0xFFFFFFFF),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.65,
    ),
    darkPalette: ThemePalette(
      gradientColors: [
        Color(0xFF7E22CE), // Velvet Plum
        Color(0xFFBE185D), // Midnight Berry
        Color(0xFF4C1D95), // Deep Amethyst
      ],
      glassTint: Color(0xFF140D1E),
      glassOpacity: 0.92,
      primaryText: Color(0xFFFAF5FF),
      secondaryText: Color(0xFFA899B8),
      accentColor: Color(0xFFC084FC),
      iconColor: Color(0xFFC084FC),
      dividerColor: Color(0x28FFFFFF),
      canvasBackground: Color(0xFF0C0714),
      cardBackground: Color(0xFF170F24),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.35,
    ),
  );

  // 5. SKY AND MINT (Airy Sky Blue, Crisp Seafoam Mint, Soft Cloud)
  static const AppThemeData skyAndMint = AppThemeData(
    id: 'sky_and_mint',
    name: 'Sky & Mint',
    description: 'Crisp morning air, cool sea breezes and fresh green mint leaves',
    emoji: '🌱',
    lightPalette: ThemePalette(
      gradientColors: [
        Color(0xFF38BDF8), // Clear Sky
        Color(0xFF34D399), // Fresh Mint
        Color(0xFF67E8F9), // Lagoon
      ],
      glassTint: Color(0xFFFFFFFF),
      glassOpacity: 0.90,
      primaryText: Color(0xFF0F241F),
      secondaryText: Color(0xFF436058),
      accentColor: Color(0xFF059669),
      iconColor: Color(0xFF059669),
      dividerColor: Color(0x1F064E3B),
      canvasBackground: Color(0xFFE8F4F0),
      cardBackground: Color(0xFFFFFFFF),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.65,
    ),
    darkPalette: ThemePalette(
      gradientColors: [
        Color(0xFF065F46), // Deep Forest Mint
        Color(0xFF0369A1), // Deep Ocean
        Color(0xFF047857), // Pine Glow
      ],
      glassTint: Color(0xFF0A1814),
      glassOpacity: 0.92,
      primaryText: Color(0xFFF0FDF4),
      secondaryText: Color(0xFF98B2A6),
      accentColor: Color(0xFF34D399),
      iconColor: Color(0xFF34D399),
      dividerColor: Color(0x28FFFFFF),
      canvasBackground: Color(0xFF06110D),
      cardBackground: Color(0xFF0E1F1A),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.35,
    ),
  );

  // 6. ROSE QUARTZ (Blush Pink, Champagne Glow, Ethereal Cream)
  static const AppThemeData roseQuartz = AppThemeData(
    id: 'rose_quartz',
    name: 'Rose Quartz',
    description: 'Delicate mineral crystal blush, warm champagne and tender romantic intimacy',
    emoji: '🌸',
    lightPalette: ThemePalette(
      gradientColors: [
        Color(0xFFFB7185), // Soft Rose
        Color(0xFFF472B6), // Blush
        Color(0xFFFBBF24), // Champagne Gold
      ],
      glassTint: Color(0xFFFFFFFF),
      glassOpacity: 0.90,
      primaryText: Color(0xFF281119),
      secondaryText: Color(0xFF6E4D5A),
      accentColor: Color(0xFFE11D48),
      iconColor: Color(0xFFE11D48),
      dividerColor: Color(0x22881337),
      canvasBackground: Color(0xFFFBF0F3),
      cardBackground: Color(0xFFFFFFFF),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.65,
    ),
    darkPalette: ThemePalette(
      gradientColors: [
        Color(0xFF9F1239), // Deep Velvet Rose
        Color(0xFF831843), // Rich Berry
        Color(0xFFB45309), // Warm Amber
      ],
      glassTint: Color(0xFF1E0E14),
      glassOpacity: 0.92,
      primaryText: Color(0xFFFFF1F2),
      secondaryText: Color(0xFFBFA0AA),
      accentColor: Color(0xFFFB7185),
      iconColor: Color(0xFFFB7185),
      dividerColor: Color(0x28FFFFFF),
      canvasBackground: Color(0xFF12070B),
      cardBackground: Color(0xFF1F0D15),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.35,
    ),
  );

  // 7. OCEAN GLOW (Deep Marine, Bioluminescent Teal, Cyan Pearl)
  static const AppThemeData oceanGlow = AppThemeData(
    id: 'ocean_glow',
    name: 'Ocean Glow',
    description: 'Bioluminescent deep seas, glowing coral reef reflections and tranquil waters',
    emoji: '🌊',
    lightPalette: ThemePalette(
      gradientColors: [
        Color(0xFF06B6D4), // Cyan
        Color(0xFF0EA5E9), // Marine
        Color(0xFF14B8A6), // Aqua
      ],
      glassTint: Color(0xFFFFFFFF),
      glassOpacity: 0.90,
      primaryText: Color(0xFF08252C),
      secondaryText: Color(0xFF385E67),
      accentColor: Color(0xFF0891B2),
      iconColor: Color(0xFF0891B2),
      dividerColor: Color(0x1F164E63),
      canvasBackground: Color(0xFFE6F3F5),
      cardBackground: Color(0xFFFFFFFF),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.65,
    ),
    darkPalette: ThemePalette(
      gradientColors: [
        Color(0xFF0E7490), // Glowing Cyan
        Color(0xFF155E75), // Deep Teal
        Color(0xFF1E3A8A), // Midnight Navy
      ],
      glassTint: Color(0xFF08171E),
      glassOpacity: 0.92,
      primaryText: Color(0xFFECFEFF),
      secondaryText: Color(0xFF8BB5BF),
      accentColor: Color(0xFF22D3EE),
      iconColor: Color(0xFF22D3EE),
      dividerColor: Color(0x28FFFFFF),
      canvasBackground: Color(0xFF051015),
      cardBackground: Color(0xFF0B1E28),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.38,
    ),
  );

  // 8. GOLDEN HOUR (Warm Honey Amber, Apricot Nectar, Sunset Gold)
  static const AppThemeData goldenHour = AppThemeData(
    id: 'golden_hour',
    name: 'Golden Hour',
    description: 'Sun-drenched late afternoons, rich wildflower honey and gleaming golden rays',
    emoji: '🌅',
    lightPalette: ThemePalette(
      gradientColors: [
        Color(0xFFF59E0B), // Golden Amber
        Color(0xFFFB923C), // Sun Apricot
        Color(0xFFFCD34D), // Sunburst
      ],
      glassTint: Color(0xFFFFFFFF),
      glassOpacity: 0.90,
      primaryText: Color(0xFF271705),
      secondaryText: Color(0xFF6A543C),
      accentColor: Color(0xFFD97706),
      iconColor: Color(0xFFD97706),
      dividerColor: Color(0x2278350F),
      canvasBackground: Color(0xFFFAF2E6),
      cardBackground: Color(0xFFFFFFFF),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.65,
    ),
    darkPalette: ThemePalette(
      gradientColors: [
        Color(0xFFB45309), // Rich Amber
        Color(0xFFC2410C), // Sunset Flame
        Color(0xFF78350F), // Bronze Glow
      ],
      glassTint: Color(0xFF1B1206),
      glassOpacity: 0.92,
      primaryText: Color(0xFFFFFBEB),
      secondaryText: Color(0xFFBEA88B),
      accentColor: Color(0xFFFBBF24),
      iconColor: Color(0xFFFBBF24),
      dividerColor: Color(0x28FFFFFF),
      canvasBackground: Color(0xFF110B03),
      cardBackground: Color(0xFF1D1408),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.38,
    ),
  );

  // 9. CHERRY BLOSSOM (Sakura Pink, Soft Strawberry, Cream Silk)
  static const AppThemeData cherryBlossom = AppThemeData(
    id: 'cherry_blossom',
    name: 'Cherry Blossom',
    description: 'Dancing spring petals, sweet strawberry cream and gentle Tokyo breezes',
    emoji: '🌸',
    lightPalette: ThemePalette(
      gradientColors: [
        Color(0xFFF472B6), // Sakura Blossom
        Color(0xFFFDA4AF), // Petal Pink
        Color(0xFFFBCFE8), // Cream Blush
      ],
      glassTint: Color(0xFFFFFFFF),
      glassOpacity: 0.90,
      primaryText: Color(0xFF2B101D),
      secondaryText: Color(0xFF704A5D),
      accentColor: Color(0xFFDB2777),
      iconColor: Color(0xFFDB2777),
      dividerColor: Color(0x1F831843),
      canvasBackground: Color(0xFFFDF2F7),
      cardBackground: Color(0xFFFFFFFF),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.65,
    ),
    darkPalette: ThemePalette(
      gradientColors: [
        Color(0xFF9D174D), // Deep Cherry
        Color(0xFF831843), // Velvet Blossom
        Color(0xFF701A75), // Evening Plum
      ],
      glassTint: Color(0xFF1B0B14),
      glassOpacity: 0.92,
      primaryText: Color(0xFFFDF2F8),
      secondaryText: Color(0xFFBFA0B0),
      accentColor: Color(0xFFF472B6),
      iconColor: Color(0xFFF472B6),
      dividerColor: Color(0x28FFFFFF),
      canvasBackground: Color(0xFF10060C),
      cardBackground: Color(0xFF1C0D17),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.35,
    ),
  );

  // 10. NORTHERN LIGHTS (Aurora Emerald, Deep Polar Night, Electric Violet)
  static const AppThemeData northernLights = AppThemeData(
    id: 'northern_lights',
    name: 'Northern Lights',
    description: 'Shimmering Arctic aurora, dancing emerald ribbons and celestial polar mystery',
    emoji: '🌌',
    lightPalette: ThemePalette(
      gradientColors: [
        Color(0xFF10B981), // Aurora Emerald
        Color(0xFF06B6D4), // Cyan Glow
        Color(0xFF8B5CF6), // Sky Violet
      ],
      glassTint: Color(0xFFFFFFFF),
      glassOpacity: 0.90,
      primaryText: Color(0xFF09231D),
      secondaryText: Color(0xFF3F6359),
      accentColor: Color(0xFF059669),
      iconColor: Color(0xFF059669),
      dividerColor: Color(0x1F064E3B),
      canvasBackground: Color(0xFFEAF5F2),
      cardBackground: Color(0xFFFFFFFF),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.65,
    ),
    darkPalette: ThemePalette(
      gradientColors: [
        Color(0xFF059669), // Glowing Aurora Green
        Color(0xFF0891B2), // Polar Cyan
        Color(0xFF6D28D9), // Midnight Violet
      ],
      glassTint: Color(0xFF071714),
      glassOpacity: 0.92,
      primaryText: Color(0xFFECFDF5),
      secondaryText: Color(0xFF8CBAB0),
      accentColor: Color(0xFF10B981),
      iconColor: Color(0xFF10B981),
      dividerColor: Color(0x28FFFFFF),
      canvasBackground: Color(0xFF050E0C),
      cardBackground: Color(0xFF0B1F1B),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.38,
    ),
  );

  // 11. PEACH FIZZ (Juicy Peach, Coral Fizz, Morning Sun)
  static const AppThemeData peachFizz = AppThemeData(
    id: 'peach_fizz',
    name: 'Peach Fizz',
    description: 'Sparkling peach bellinis, cheerful citrus sunrise and sweet summer mornings',
    emoji: '🍑',
    lightPalette: ThemePalette(
      gradientColors: [
        Color(0xFFFB923C), // Juicy Peach
        Color(0xFFF472B6), // Coral Pink
        Color(0xFFFBBF24), // Sun Fizz
      ],
      glassTint: Color(0xFFFFFFFF),
      glassOpacity: 0.90,
      primaryText: Color(0xFF28160B),
      secondaryText: Color(0xFF6B5140),
      accentColor: Color(0xFFEA580C),
      iconColor: Color(0xFFEA580C),
      dividerColor: Color(0x227C2D12),
      canvasBackground: Color(0xFFFAF3EC),
      cardBackground: Color(0xFFFFFFFF),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.65,
    ),
    darkPalette: ThemePalette(
      gradientColors: [
        Color(0xFFC2410C), // Deep Peach Ember
        Color(0xFF9F1239), // Velvet Coral
        Color(0xFFB45309), // Spiced Fizz
      ],
      glassTint: Color(0xFF1A1009),
      glassOpacity: 0.92,
      primaryText: Color(0xFFFFF7ED),
      secondaryText: Color(0xFFBEA595),
      accentColor: Color(0xFFFB923C),
      iconColor: Color(0xFFFB923C),
      dividerColor: Color(0x28FFFFFF),
      canvasBackground: Color(0xFF120A05),
      cardBackground: Color(0xFF20120B),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.38,
    ),
  );

  // 12. MOONLIT BLUE (Midnight Sapphire, Powder Blue, Silver Moonbeam)
  static const AppThemeData moonlitBlue = AppThemeData(
    id: 'moonlit_blue',
    name: 'Moonlit Blue',
    description: 'Silver moonlight on still lakes, sapphire shadows and deep peaceful serenity',
    emoji: '🌙',
    lightPalette: ThemePalette(
      gradientColors: [
        Color(0xFF60A5FA), // Powder Sky
        Color(0xFF818CF8), // Periwinkle
        Color(0xFF93C5FD), // Silver Mist
      ],
      glassTint: Color(0xFFFFFFFF),
      glassOpacity: 0.90,
      primaryText: Color(0xFF0F1A2C),
      secondaryText: Color(0xFF4A5C75),
      accentColor: Color(0xFF2563EB),
      iconColor: Color(0xFF2563EB),
      dividerColor: Color(0x1F1E3A8A),
      canvasBackground: Color(0xFFEBF1F9),
      cardBackground: Color(0xFFFFFFFF),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.65,
    ),
    darkPalette: ThemePalette(
      gradientColors: [
        Color(0xFF1E40AF), // Midnight Sapphire
        Color(0xFF312E81), // Night Indigo
        Color(0xFF0369A1), // Deep Cobalt
      ],
      glassTint: Color(0xFF0A1124),
      glassOpacity: 0.92,
      primaryText: Color(0xFFEFF6FF),
      secondaryText: Color(0xFF95A8C4),
      accentColor: Color(0xFF60A5FA),
      iconColor: Color(0xFF60A5FA),
      dividerColor: Color(0x28FFFFFF),
      canvasBackground: Color(0xFF070B17),
      cardBackground: Color(0xFF101932),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.38,
    ),
  );

  // 13. FOREST MIST (Dewy Pine, Sage Spruce, Morning Fog)
  static const AppThemeData forestMist = AppThemeData(
    id: 'forest_mist',
    name: 'Forest Mist',
    description: 'Ancient pine woods at dawn, soft rolling morning fog and deep herbal quietude',
    emoji: '🌲',
    lightPalette: ThemePalette(
      gradientColors: [
        Color(0xFF4ADE80), // Spring Pine
        Color(0xFF2DD4BF), // Dew Emerald
        Color(0xFFA3E635), // Soft Moss
      ],
      glassTint: Color(0xFFFFFFFF),
      glassOpacity: 0.90,
      primaryText: Color(0xFF132415),
      secondaryText: Color(0xFF475E4A),
      accentColor: Color(0xFF16A34A),
      iconColor: Color(0xFF16A34A),
      dividerColor: Color(0x1F14532D),
      canvasBackground: Color(0xFFEAF4EC),
      cardBackground: Color(0xFFFFFFFF),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.65,
    ),
    darkPalette: ThemePalette(
      gradientColors: [
        Color(0xFF15803D), // Deep Evergreen
        Color(0xFF14532D), // Pine Needle
        Color(0xFF065F46), // Woodland Shadow
      ],
      glassTint: Color(0xFF0C190F),
      glassOpacity: 0.92,
      primaryText: Color(0xFFF0FDF4),
      secondaryText: Color(0xFF97B29B),
      accentColor: Color(0xFF4ADE80),
      iconColor: Color(0xFF4ADE80),
      dividerColor: Color(0x28FFFFFF),
      canvasBackground: Color(0xFF08120A),
      cardBackground: Color(0xFF112316),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.35,
    ),
  );

  // 14. VELVET NOIR (Dark Romance: Crimson Obsidian & Midnight Devotion)
  static const AppThemeData velvetNoir = AppThemeData(
    id: 'velvet_noir',
    name: 'Velvet Noir',
    description: 'Deep obsidian night with blood-crimson velvet, dark rose, and devoted shadow glow',
    emoji: '🥀',
    lightPalette: ThemePalette(
      gradientColors: [
        Color(0xFF9F1239), // Crimson Rose
        Color(0xFF4C0519), // Deep Wine
        Color(0xFF881337), // Dark Velvet
      ],
      glassTint: Color(0xFFFAF2F4),
      glassOpacity: 0.90,
      primaryText: Color(0xFF1F0910),
      secondaryText: Color(0xFF6E3546),
      accentColor: Color(0xFFBE123C),
      iconColor: Color(0xFFBE123C),
      dividerColor: Color(0x1F881337),
      canvasBackground: Color(0xFFF5E9EC),
      cardBackground: Color(0xFFFFFFFF),
      specularBorderColor: Color(0xFFFFFFFF),
      specularBorderOpacity: 0.60,
    ),
    darkPalette: ThemePalette(
      gradientColors: [
        Color(0xFF881337), // Blood Crimson
        Color(0xFF3B0718), // Velvet Burgundy
        Color(0xFF14060D), // Midnight Shadow
      ],
      glassTint: Color(0xFF11070C),
      glassOpacity: 0.92,
      primaryText: Color(0xFFFDE8EE),
      secondaryText: Color(0xFFB88896),
      accentColor: Color(0xFFE11D48),
      iconColor: Color(0xFFF43F5E),
      dividerColor: Color(0x28F43F5E),
      canvasBackground: Color(0xFF070306),
      cardBackground: Color(0xFF14090F),
      specularBorderColor: Color(0xFFF43F5E),
      specularBorderOpacity: 0.32,
    ),
  );

  /// All 14 living couple themes in order
  static const List<AppThemeData> allThemes = [
    defaultSanctuary,
    sunsetChai,
    velvetNoir,
    midnightRain,
    lavenderDream,
    skyAndMint,
    roseQuartz,
    oceanGlow,
    goldenHour,
    cherryBlossom,
    northernLights,
    peachFizz,
    moonlitBlue,
    forestMist,
  ];

  /// Safe lookup by ID with fallback to Sunset Chai
  static AppThemeData getById(String? id) {
    if (id == null || id.isEmpty) return sunsetChai;
    return allThemes.firstWhere(
      (t) => t.id == id,
      orElse: () => sunsetChai,
    );
  }
}
