import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/county_pavilion.dart';
import '../theme/stadium_themes.dart';
import 'menu_screen.dart';

/// Launch splash flow (single sequence, two moments):
/// 1. Company moment — the official WAJIHA logo fades in (~1.1s).
/// 2. Game splash — logo + name + animated loading line + "Credits: WAJIHA".
///
/// Audio clips are pre-warmed during the company moment so menu music
/// starts reliably on game-splash entry.
class SplashScreen extends StatefulWidget {
  final CricketAudio audio;
  final CricketSettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;
  bool _companyMoment = true;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _run();
  }

  Future<void> _run() async {
    // Pre-warm audio while the company moment shows.
    widget.audio.prewarm();
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() => _companyMoment = false);
    widget.audio.startMenuMusic();
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = StadiumThemes.byId(
      widget.settings.stadiumId,
      custom: widget.settings.customStadium,
    );
    return Scaffold(
      backgroundColor: theme.ink,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _companyMoment
            ? _CompanyMoment(theme: theme, key: const ValueKey('company'))
            : _GameSplash(
                theme: theme,
                loader: _loader,
                key: const ValueKey('game'),
              ),
      ),
    );
  }
}

/// Company moment: the official WAJIHA logo, faded in gently.
class _CompanyMoment extends StatelessWidget {
  final StadiumThemeDef theme;
  const _CompanyMoment({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.ink,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          builder: (_, v, child) => Opacity(opacity: v, child: child),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/wajiha_logo.png',
                width: 128,
                height: 128,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 14),
              Text('WAJIHA', style: Pavilion.display(30, theme: theme)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Game splash: logo + name, animated loading line, "Credits: WAJIHA".
class _GameSplash extends StatelessWidget {
  final StadiumThemeDef theme;
  final AnimationController loader;
  const _GameSplash({super.key, required this.theme, required this.loader});

  @override
  Widget build(BuildContext context) {
    return GroundBackdrop(
      theme: theme,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: theme.accent, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Pavilion.shadow,
                    offset: Offset(0, 10),
                    blurRadius: 24,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/cricket_logo.png', fit: BoxFit.cover),
            ),
            const SizedBox(height: 22),
            Text('Cricket', style: Pavilion.display(52, theme: theme)),
            const SizedBox(height: 6),
            Text(
              'SLOG-OVERS ARCADE',
              style: Pavilion.label(13, theme: theme),
            ),
            const SizedBox(height: 30),
            // Animated loading line.
            SizedBox(
              width: 220,
              child: AnimatedBuilder(
                animation: loader,
                builder: (_, _) => Column(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.black.withValues(alpha: 0.45),
                        border: Border.all(
                            color: theme.accent.withValues(alpha: 0.5)),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: loader.value.clamp(0.02, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            gradient: LinearGradient(
                              colors: [
                                theme.accentLight,
                                theme.accent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      loader.value < 1 ? 'Rolling the pitch…' : 'Ready!',
                      style: Pavilion.body(13,
                          theme: theme,
                          color: theme.cream.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 44),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/wajiha_logo.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                Text(
                  'Credits: WAJIHA',
                  style: Pavilion.label(14, theme: theme),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
