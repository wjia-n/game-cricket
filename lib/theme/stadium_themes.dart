import 'package:flutter/material.dart';

/// Stadium, kit and ball catalogs for Cricket.
///
/// Art direction: "County Pavilion" — a real cricket ground on a summer
/// afternoon. Real grass, a straw pitch strip, leather ball, willow bat,
/// warm sunlight. No neon, no cyberpunk, no AI-dashboard looks. The variety
/// comes from different grounds (day / sunset / night / desert / coast),
/// team kit colors and ball leathers.
class StadiumThemeDef {
  final String id;
  final String name;
  final Color skyTop;
  final Color skyBottom;
  final Color grassLight;
  final Color grassDark;
  final Color pitch; // the straw strip
  final Color boundary; // rope / boards color
  final Color accent; // UI accent (brass-like, never neon)
  final Color accentLight;
  final Color ink; // dark UI panels
  final Color cream; // light text

  const StadiumThemeDef({
    required this.id,
    required this.name,
    required this.skyTop,
    required this.skyBottom,
    required this.grassLight,
    required this.grassDark,
    required this.pitch,
    required this.boundary,
    required this.accent,
    required this.accentLight,
    required this.ink,
    required this.cream,
  });
}

class StadiumThemes {
  /// First 4 are the FREE starter grounds. The rest are PRO.
  static const List<String> freeThemeIds = [
    'village',
    'meadows',
    'savanna',
    'classic',
  ];

  static const List<StadiumThemeDef> all = [
    StadiumThemeDef(
      id: 'village',
      name: 'Village Green',
      skyTop: Color(0xFF7FB8E6),
      skyBottom: Color(0xFFD8ECFA),
      grassLight: Color(0xFF5DA24A),
      grassDark: Color(0xFF3E7A31),
      pitch: Color(0xFFD9BE8C),
      boundary: Color(0xFFF5F0E0),
      accent: Color(0xFFB98A2F),
      accentLight: Color(0xFFE9C878),
      ink: Color(0xFF1E2A1A),
      cream: Color(0xFFF8F4E6),
    ),
    StadiumThemeDef(
      id: 'meadows',
      name: 'Golden Meadows',
      skyTop: Color(0xFF6AA9DE),
      skyBottom: Color(0xFFF2E3B8),
      grassLight: Color(0xFF6FAE4E),
      grassDark: Color(0xFF487F33),
      pitch: Color(0xFFE2C491),
      boundary: Color(0xFFC94F38),
      accent: Color(0xFFC9973B),
      accentLight: Color(0xFFF2D48A),
      ink: Color(0xFF232A18),
      cream: Color(0xFFFBF6E8),
    ),
    StadiumThemeDef(
      id: 'savanna',
      name: 'Sunset Savanna',
      skyTop: Color(0xFF3E5A8A),
      skyBottom: Color(0xFFE8935A),
      grassLight: Color(0xFF7A9A44),
      grassDark: Color(0xFF556E2E),
      pitch: Color(0xFFD4AC76),
      boundary: Color(0xFF8A3B2E),
      accent: Color(0xFFD99A4E),
      accentLight: Color(0xFFF5C98A),
      ink: Color(0xFF241C14),
      cream: Color(0xFFFAF0DC),
    ),
    StadiumThemeDef(
      id: 'classic',
      name: 'Emerald Classic',
      skyTop: Color(0xFF8FC3EE),
      skyBottom: Color(0xFFE4F2FD),
      grassLight: Color(0xFF4E9A42),
      grassDark: Color(0xFF35702C),
      pitch: Color(0xFFD2B47E),
      boundary: Color(0xFF1F4E79),
      accent: Color(0xFFA8842F),
      accentLight: Color(0xFFE3BE6E),
      ink: Color(0xFF18251A),
      cream: Color(0xFFF6F1E2),
    ),
    StadiumThemeDef(
      id: 'monsoon',
      name: 'Monsoon Park',
      skyTop: Color(0xFF5A6E84),
      skyBottom: Color(0xFFB9C9D6),
      grassLight: Color(0xFF3F8A4C),
      grassDark: Color(0xFF2A6234),
      pitch: Color(0xFFC4A06E),
      boundary: Color(0xFF2E5E8A),
      accent: Color(0xFF7FA8C9),
      accentLight: Color(0xFFBFD9EE),
      ink: Color(0xFF1A2228),
      cream: Color(0xFFF0F4F6),
    ),
    StadiumThemeDef(
      id: 'desert',
      name: 'Desert Mirage',
      skyTop: Color(0xFF4E9AD1),
      skyBottom: Color(0xFFF6D9A0),
      grassLight: Color(0xFF8AA653),
      grassDark: Color(0xFF647A3A),
      pitch: Color(0xFFE6C88F),
      boundary: Color(0xFFB4762A),
      accent: Color(0xFFC98F3D),
      accentLight: Color(0xFFF0C27E),
      ink: Color(0xFF2A2114),
      cream: Color(0xFFFBF3DF),
    ),
    StadiumThemeDef(
      id: 'harbor',
      name: 'Harbor Nights',
      skyTop: Color(0xFF141C38),
      skyBottom: Color(0xFF3A4E7A),
      grassLight: Color(0xFF3E7A44),
      grassDark: Color(0xFF2A552E),
      pitch: Color(0xFFD8BE90),
      boundary: Color(0xFFF2E7C8),
      accent: Color(0xFFD8B25C),
      accentLight: Color(0xFFF2DDA0),
      ink: Color(0xFF10141F),
      cream: Color(0xFFF4EDD8),
    ),
    StadiumThemeDef(
      id: 'alpine',
      name: 'Alpine Field',
      skyTop: Color(0xFF5E9BD8),
      skyBottom: Color(0xFFE8F3FC),
      grassLight: Color(0xFF5C9A52),
      grassDark: Color(0xFF3E6E38),
      pitch: Color(0xFFD9BE8C),
      boundary: Color(0xFF7A1F2B),
      accent: Color(0xFFB03A48),
      accentLight: Color(0xFFE08A94),
      ink: Color(0xFF1A2420),
      cream: Color(0xFFF6F1E4),
    ),
    StadiumThemeDef(
      id: 'cove',
      name: 'Tropical Cove',
      skyTop: Color(0xFF4FB3D9),
      skyBottom: Color(0xFFD8F2EC),
      grassLight: Color(0xFF55A24E),
      grassDark: Color(0xFF3A7434),
      pitch: Color(0xFFE0C184),
      boundary: Color(0xFF1F7A6E),
      accent: Color(0xFF3FA08F),
      accentLight: Color(0xFF8FD8C8),
      ink: Color(0xFF14231F),
      cream: Color(0xFFF2F7EE),
    ),
    StadiumThemeDef(
      id: 'autumn',
      name: 'Autumn Oval',
      skyTop: Color(0xFF7A8FC4),
      skyBottom: Color(0xFFF2C99A),
      grassLight: Color(0xFF7A9A4A),
      grassDark: Color(0xFF5A7232),
      pitch: Color(0xFFCFA878),
      boundary: Color(0xFF8A4A2E),
      accent: Color(0xFFC07A3D),
      accentLight: Color(0xFFE8AE7A),
      ink: Color(0xFF251D14),
      cream: Color(0xFFFAF2E2),
    ),
    StadiumThemeDef(
      id: 'pavilion',
      name: 'Royal Pavilion',
      skyTop: Color(0xFF2E3A5E),
      skyBottom: Color(0xFF8A9AC4),
      grassLight: Color(0xFF467A42),
      grassDark: Color(0xFF30562E),
      pitch: Color(0xFFDCC08E),
      boundary: Color(0xFFC9A227),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFEFD08A),
      ink: Color(0xFF141A24),
      cream: Color(0xFFF8F2DF),
    ),
    StadiumThemeDef(
      id: 'floodlit',
      name: 'Floodlit Arena',
      skyTop: Color(0xFF0E1424),
      skyBottom: Color(0xFF2A3A5E),
      grassLight: Color(0xFF3E7A44),
      grassDark: Color(0xFF2A552E),
      pitch: Color(0xFFD4B67E),
      boundary: Color(0xFFF5F0E0),
      accent: Color(0xFFE0B44E),
      accentLight: Color(0xFFF6DC9A),
      ink: Color(0xFF0C1018),
      cream: Color(0xFFF6EFDC),
    ),
  ];

  static StadiumThemeDef byId(String id, {StadiumThemeDef? custom}) {
    if (id == 'custom' && custom != null) return custom;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }

  static bool isProTheme(String id) => !freeThemeIds.contains(id);
}

// ---------------------------------------------------------------------------
/// Team kit styles (two-tone shirts). First 3 free, rest PRO.
class KitDef {
  final String name;
  final Color primary;
  final Color secondary;
  const KitDef(this.name, this.primary, this.secondary);
}

class KitStyles {
  static const List<String> names = [
    'Classic Whites',
    'County Green',
    'Sky Blue',
    'Maroon XI',
    'Royal Purple',
    'Sunset Orange',
    'Teal Titans',
    'Charcoal',
  ];

  static const List<KitDef> all = [
    KitDef('Classic Whites', Color(0xFFF5F0E2), Color(0xFFB98A2F)),
    KitDef('County Green', Color(0xFF2E6B34), Color(0xFFF5F0E2)),
    KitDef('Sky Blue', Color(0xFF2E6EA8), Color(0xFFF5F0E2)),
    KitDef('Maroon XI', Color(0xFF7A1F2B), Color(0xFFE9C878)),
    KitDef('Royal Purple', Color(0xFF5E2E8A), Color(0xFFE9C878)),
    KitDef('Sunset Orange', Color(0xFFC96A2E), Color(0xFF1E2A1A)),
    KitDef('Teal Titans', Color(0xFF1F7A6E), Color(0xFFF5F0E2)),
    KitDef('Charcoal', Color(0xFF2A2E34), Color(0xFFE0B44E)),
  ];

  /// Free kits: the first 3.
  static bool isPro(int i) => i >= 3;
}

// ---------------------------------------------------------------------------
/// Ball leather styles. First 2 free, rest PRO.
class BallDef {
  final String name;
  final Color leather;
  final Color seam;
  const BallDef(this.name, this.leather, this.seam);
}

class BallStyles {
  static const List<BallDef> all = [
    BallDef('Test Red', Color(0xFFA31621), Color(0xFFF5F0E2)),
    BallDef('ODI White', Color(0xFFF2EEE2), Color(0xFFA31621)),
    BallDef('T20 Pink', Color(0xFFC94F7C), Color(0xFFF5F0E2)),
    BallDef('Tennis Yellow', Color(0xFFD9C53B), Color(0xFF7A1F2B)),
    BallDef('County Blue', Color(0xFF1D4E9E), Color(0xFFF5F0E2)),
    BallDef('Vintage Tan', Color(0xFFB4762A), Color(0xFF3B2416)),
  ];

  /// Free balls: the first 2.
  static bool isPro(int i) => i >= 2;
}
