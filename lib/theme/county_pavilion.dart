import 'package:flutter/material.dart';
import 'stadium_themes.dart';

/// County Pavilion — the design system for Cricket.
/// Warm summer-afternoon materials: grass, straw, leather, willow, brass.
/// No neon, no cyberpunk, no generic Material look.
class Pavilion {
  static const shadow = Color(0xFF101408);

  static TextStyle display(double size,
          {Color? color, StadiumThemeDef? theme}) =>
      TextStyle(
        fontFamily: 'serif',
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? theme?.accentLight ?? const Color(0xFFE9C878),
        letterSpacing: 1.1,
        shadows: const [
          Shadow(color: shadow, offset: Offset(0, 2), blurRadius: 4),
        ],
      );

  static TextStyle body(double size, {Color? color, StadiumThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? theme?.cream ?? const Color(0xFFF8F4E6),
        height: 1.35,
      );

  static TextStyle label(double size, {Color? color, StadiumThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? theme?.accentLight ?? const Color(0xFFE9C878),
        letterSpacing: 0.8,
      );

  static ThemeData theme([StadiumThemeDef? t]) {
    t ??= StadiumThemes.byId('village');
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: t.ink,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: t.accent,
        onPrimary: t.ink,
        secondary: t.accentLight,
        onSecondary: t.ink,
        surface: t.ink,
        onSurface: t.cream,
        error: const Color(0xFFC0392B),
        onError: t.cream,
      ),
      textTheme: TextTheme(
        displayLarge: display(34, theme: t),
        displayMedium: display(26, theme: t),
        titleLarge: display(22, theme: t),
        bodyLarge: body(16, theme: t),
        bodyMedium: body(14, theme: t),
        labelLarge: label(14, theme: t),
      ),
      dialogTheme: DialogThemeData(backgroundColor: t.ink),
    );
  }
}

/// Sky-to-grass stadium backdrop, theme-aware, with soft mowing stripes.
class GroundBackdrop extends StatelessWidget {
  final Widget child;
  final StadiumThemeDef? theme;
  const GroundBackdrop({super.key, required this.child, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? StadiumThemes.byId('village');
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.skyTop, t.skyBottom, t.grassLight, t.grassDark],
          stops: const [0.0, 0.32, 0.36, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _MowingStripes(t.grassLight, t.grassDark),
        child: child,
      ),
    );
  }
}

class _MowingStripes extends CustomPainter {
  final Color light;
  final Color dark;
  _MowingStripes(this.light, this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle alternating grass stripes on the lower (field) half.
    final top = size.height * 0.36;
    const stripes = 7;
    final paint = Paint();
    for (int i = 0; i < stripes; i++) {
      paint.color = (i.isEven ? light : dark).withValues(alpha: 0.16);
      canvas.drawRect(
        Rect.fromLTWH(0, top + (size.height - top) * i / stripes,
            size.width, (size.height - top) / stripes),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MowingStripes old) =>
      old.light != light || old.dark != dark;
}

/// Chunky leather-and-willow button.
class PavilionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final StadiumThemeDef? theme;
  final double width;
  final double fontSize;
  const PavilionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.theme,
    this.width = 260,
    this.fontSize = 19,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme ?? StadiumThemes.byId('village');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.accentLight, t.accent],
          ),
          border: Border.all(color: t.cream.withValues(alpha: 0.65), width: 2),
          boxShadow: const [
            BoxShadow(
                color: shadow, offset: Offset(0, 5), blurRadius: 10),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Pavilion.label(fontSize, theme: t, color: t.ink),
        ),
      ),
    );
  }
}

/// White picket-fence scoreboard card used across menu + game.
class ScoreboardCard extends StatelessWidget {
  final StadiumThemeDef theme;
  final String title;
  final Widget child;
  const ScoreboardCard(
      {super.key, required this.theme, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.ink.withValues(alpha: 0.88),
        border: Border.all(color: theme.accent, width: 2),
        boxShadow: const [
          BoxShadow(color: shadow, offset: Offset(0, 5), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Text(title, style: Pavilion.display(20, theme: theme)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
