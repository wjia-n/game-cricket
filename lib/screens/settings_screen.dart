import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/county_pavilion.dart';
import '../theme/stadium_themes.dart';

/// Settings: music / SFX toggles, volume, and stats reset.
class SettingsScreen extends StatefulWidget {
  final CricketAudio audio;
  final CricketSettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  CricketSettings get _s => widget.settings;
  StadiumThemeDef get _t =>
      StadiumThemes.byId(_s.stadiumId, custom: _s.customStadium);

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return GroundBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.accentLight),
            onPressed: () {
              widget.audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Settings', style: Pavilion.display(22, theme: t)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _s,
            builder: (_, _) => ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              children: [
                ScoreboardCard(
                  theme: t,
                  title: 'Audio',
                  child: Column(
                    children: [
                      _ToggleRow(
                        theme: t,
                        label: '🎵 Music',
                        value: _s.musicOn,
                        onChanged: (v) {
                          _s.setMusic(v);
                          widget.audio.configure(
                            musicOn: v,
                            sfxOn: _s.sfxOn,
                            volume: _s.volume,
                          );
                          if (v) {
                            widget.audio.click();
                            widget.audio.startMenuMusic();
                          }
                        },
                      ),
                      _ToggleRow(
                        theme: t,
                        label: '🔊 Sound effects',
                        value: _s.sfxOn,
                        onChanged: (v) {
                          _s.setSfx(v);
                          widget.audio.configure(
                            musicOn: _s.musicOn,
                            sfxOn: v,
                            volume: _s.volume,
                          );
                          if (v) widget.audio.click();
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('🔈 Volume',
                              style: Pavilion.body(15, theme: t)),
                          Expanded(
                            child: Slider(
                              value: _s.volume,
                              activeColor: t.accent,
                              inactiveColor:
                                  t.accent.withValues(alpha: 0.3),
                              onChanged: (v) {
                                _s.setVolume(v);
                                widget.audio.configure(
                                  musicOn: _s.musicOn,
                                  sfxOn: _s.sfxOn,
                                  volume: v,
                                );
                              },
                              onChangeEnd: (_) => widget.audio.click(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ScoreboardCard(
                  theme: t,
                  title: 'Career',
                  child: Column(
                    children: [
                      _StatRow(
                          theme: t,
                          label: 'Matches played',
                          value: '${_s.gamesPlayed}'),
                      _StatRow(
                          theme: t, label: 'Wins', value: '${_s.wins}'),
                      _StatRow(
                          theme: t,
                          label: 'Best innings',
                          value: '${_s.bestScore}'),
                      _StatRow(
                          theme: t, label: 'Sixes smashed', value: '${_s.sixes}'),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () async {
                          widget.audio.click();
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: t.ink,
                              title: Text('Reset stats?',
                                  style: Pavilion.display(20, theme: t)),
                              content: Text(
                                  'Your wins, matches and records will be cleared.',
                                  style: Pavilion.body(14, theme: t)),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: Text('Cancel',
                                      style: Pavilion.label(14, theme: t)),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('Reset',
                                      style: TextStyle(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            _s.resetStats();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.6)),
                          ),
                          child: const Text('Reset career stats',
                              style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text('Cricket v2.0  •  Made with ♥ by WAJIHA',
                      style: Pavilion.label(11, theme: t)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final StadiumThemeDef theme;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow(
      {required this.theme,
      required this.label,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: Pavilion.body(15, theme: theme))),
        Switch(
          value: value,
          activeColor: theme.accentLight,
          activeTrackColor: theme.accent.withValues(alpha: 0.5),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final StadiumThemeDef theme;
  final String label;
  final String value;
  const _StatRow(
      {required this.theme, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Pavilion.body(14, theme: theme))),
          Text(value, style: Pavilion.display(16, theme: theme)),
        ],
      ),
    );
  }
}
