import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/county_pavilion.dart';
import '../theme/stadium_themes.dart';

/// PRO: design your own ground, team kit and ball.
/// Every choice persists and previews live.
class CustomKitScreen extends StatefulWidget {
  final CricketAudio audio;
  final CricketSettings settings;
  const CustomKitScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomKitScreen> createState() => _CustomKitScreenState();
}

class _CustomKitScreenState extends State<CustomKitScreen> {
  CricketSettings get _s => widget.settings;

  static const _fields = [
    ('Ground', ['skyTop', 'skyBottom', 'grassLight', 'grassDark', 'pitch', 'boundary']),
    ('UI Accent', ['accent', 'accentLight', 'ink', 'cream']),
    ('Team Kit', ['kitPrimary', 'kitSecondary']),
    ('Ball', ['ball', 'seam']),
  ];

  static const _fieldNames = {
    'skyTop': 'Sky top',
    'skyBottom': 'Sky horizon',
    'grassLight': 'Grass light',
    'grassDark': 'Grass dark',
    'pitch': 'Pitch strip',
    'boundary': 'Boundary',
    'accent': 'Accent',
    'accentLight': 'Accent light',
    'ink': 'Panels',
    'cream': 'Text',
    'kitPrimary': 'Shirt',
    'kitSecondary': 'Trim',
    'ball': 'Leather',
    'seam': 'Seam',
  };

  /// Earthy, pitch-appropriate palette (no neon).
  static const _palette = [
    0xFF1E2A1A, 0xFF2E3B22, 0xFF3E7A31, 0xFF5DA24A, 0xFF7A9A4A,
    0xFFD9BE8C, 0xFFE2C491, 0xFFF5F0E2, 0xFFD8ECFA, 0xFF7FB8E6,
    0xFF2E6EA8, 0xFF1B2A4A, 0xFF141C38, 0xFFB98A2F, 0xFFE9C878,
    0xFFC96A2E, 0xFF8A3B2E, 0xFFA31621, 0xFF7A1F2B, 0xFFC94F7C,
    0xFF5E2E8A, 0xFF1F7A6E, 0xFF3FA08F, 0xFF2A2E34, 0xFF6B4A2A,
  ];

  String _selectedField = 'grassLight';

  @override
  Widget build(BuildContext context) {
    final t = StadiumThemes.byId(_s.stadiumId, custom: _s.customStadium);
    return ListenableBuilder(
      listenable: _s,
      builder: (_, _) {
        final preview =
            StadiumThemes.byId('custom', custom: _s.customStadium);
        return GroundBackdrop(
          theme: preview,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: preview.accentLight),
                onPressed: () {
                  widget.audio.click();
                  Navigator.of(context).pop();
                },
              ),
              title:
                  Text('My Creation', style: Pavilion.display(22, theme: preview)),
              centerTitle: true,
              actions: [
                TextButton(
                  onPressed: () {
                    widget.audio.click();
                    _s.resetCustomColors();
                  },
                  child: Text('Reset',
                      style: Pavilion.label(14, theme: preview)),
                ),
              ],
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                child: Column(
                  children: [
                    // Live preview strip.
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            preview.skyTop,
                            preview.skyBottom,
                            preview.grassLight,
                            preview.grassDark,
                          ],
                          stops: const [0.0, 0.4, 0.45, 1.0],
                        ),
                        border: Border.all(
                            color: preview.accent, width: 2),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _previewKit(preview),
                            const SizedBox(width: 16),
                            _previewBall(),
                            const SizedBox(width: 16),
                            Text('My Ground',
                                style: Pavilion.display(20, theme: preview)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final group in _fields) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(group.$1,
                            style: Pavilion.label(14, theme: t)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final f in group.$2)
                            _FieldChip(
                              theme: t,
                              label: _fieldNames[f]!,
                              color: Color(_s.customColors[f]!),
                              selected: _selectedField == f,
                              onTap: () {
                                widget.audio.click();
                                setState(() => _selectedField = f);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          'Pick a color for ${_fieldNames[_selectedField]}:',
                          style: Pavilion.body(14, theme: t)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final c in _palette)
                          GestureDetector(
                            onTap: () {
                              widget.audio.click();
                              _s.setCustomColor(_selectedField, c);
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(c),
                                border: Border.all(
                                  color: _s.customColors[_selectedField] == c
                                      ? t.accentLight
                                      : Colors.black.withValues(alpha: 0.3),
                                  width: _s.customColors[_selectedField] == c
                                      ? 3.5
                                      : 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    PavilionButton(
                      label: 'Use My Creation',
                      theme: t,
                      width: 260,
                      onTap: () {
                        widget.audio.gameStart();
                        _s.setStadium('custom');
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _previewKit(StadiumThemeDef preview) {
    return Container(
      width: 44,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(colors: [
          _s.customKit.primary,
          _s.customKit.secondary,
        ]),
        border: Border.all(color: preview.accentLight, width: 2),
      ),
    );
  }

  Widget _previewBall() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          Color.lerp(_s.customBall.leather, Colors.white, 0.35)!,
          _s.customBall.leather,
          Color.lerp(_s.customBall.leather, Colors.black, 0.35)!,
        ]),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Center(
        child: Container(
          width: 24,
          height: 5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2.5),
            color: _s.customBall.seam,
          ),
        ),
      ),
    );
  }
}

class _FieldChip extends StatelessWidget {
  final StadiumThemeDef theme;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _FieldChip({
    required this.theme,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? theme.accent.withValues(alpha: 0.85)
              : Colors.black.withValues(alpha: 0.3),
          border: Border.all(
            color: selected
                ? theme.accentLight
                : theme.accent.withValues(alpha: 0.5),
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(color: Colors.white54),
              ),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: Pavilion.label(12,
                    theme: theme,
                    color: selected ? theme.ink : theme.cream)),
          ],
        ),
      ),
    );
  }
}
