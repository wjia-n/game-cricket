import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/cricket_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/county_pavilion.dart';
import '../theme/stadium_themes.dart';
import 'custom_kit_screen.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

/// Main menu — County Pavilion edition.
/// Logo, PLAY, mode setup (vs AI / 2-player, overs, difficulty), stadium
/// picker, kit & ball picker, team renaming, tip jar, settings.
class MenuScreen extends StatefulWidget {
  final CricketAudio audio;
  final CricketSettings settings;

  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final StoreService _store = StoreService();

  CricketSettings get _s => widget.settings;
  StadiumThemeDef get _t =>
      StadiumThemes.byId(_s.stadiumId, custom: _s.customStadium);

  @override
  void initState() {
    super.initState();
    widget.audio.startMenuMusic();
    _store.init().then((_) {
      if (mounted) setState(() {});
    });
    _store.lastThanks.addListener(_onThanks);
    _store.proPurchased.addListener(_onPro);
  }

  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Pavilion.body(15, theme: _t)),
        backgroundColor: _t.ink,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _store.lastThanks.value = null;
  }

  void _onPro() {
    if (_store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      _store.proPurchased.value = false;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _store.lastThanks.removeListener(_onThanks);
    _store.proPurchased.removeListener(_onPro);
    _store.dispose();
    super.dispose();
  }

  /// Real in-app review flow: the Play in-app review sheet when available,
  /// otherwise fall back to opening the store listing. No fake dialogs.
  Future<void> _requestReview() async {
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await review.openStoreListing(appStoreId: null);
      }
    } catch (_) {
      // Review UI unavailable on this device/build: stay silent, no fake UI.
    }
  }

  void _play() {
    widget.audio.gameStart();
    final kits = [_s.kitFor(0), _s.kitFor(1)];
    final players = [
      CricketPlayer(
          name: _s.playerNames[0], color: kits[0].primary, isBot: false),
      CricketPlayer(
          name: _s.playerNames[1],
          color: kits[1].primary,
          isBot: _s.mode == 0),
    ];
    final engine = CricketEngine(
      players: players,
      botDifficulty: BotDifficulty.values[_s.difficulty],
      overs: _s.overs,
    );
    // App-scoped music: keep playing across screens. GameScreen switches
    // to the game track on entry; we switch back to menu music on return.
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => GameScreen(
        engine: engine,
        audio: widget.audio,
        settings: _s,
      ),
    ))
        .then((_) {
      if (mounted) widget.audio.startMenuMusic();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return GroundBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Logo plaque.
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: t.accent, width: 3),
                      boxShadow: const [
                        BoxShadow(
                          color: Pavilion.shadow,
                          offset: Offset(0, 8),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/cricket_logo.png',
                        fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 14),
                  Text('Cricket', style: Pavilion.display(46, theme: t)),
                  Text(
                    'SLOG-OVERS ARCADE',
                    style: Pavilion.label(12, theme: t),
                  ),
                  const SizedBox(height: 22),
                  PavilionButton(
                      label: '▶  Play', onTap: _play, theme: t, width: 260),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProScreen(
                          audio: widget.audio,
                          settings: _s,
                          store: _store,
                        ),
                      ));
                    },
                    child: Container(
                      width: 260,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(colors: [
                          t.accent.withValues(alpha: 0.9),
                          t.accent,
                        ]),
                        border: Border.all(
                            color: t.accentLight, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Pavilion.shadow,
                            offset: Offset(0, 4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _s.isPro ? '✦  PRO ACTIVE' : '✦  Get PRO',
                        style: Pavilion.label(17,
                            theme: t, color: t.ink),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _ModeCard(theme: t),
                  const SizedBox(height: 14),
                  _GroundCard(theme: t),
                  const SizedBox(height: 14),
                  _KitCard(theme: t),
                  const SizedBox(height: 14),
                  _NamesCard(theme: t),
                  const SizedBox(height: 14),
                  _SupportCard(theme: t, store: _store),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MenuIcon(
                        theme: t,
                        icon: Icons.share,
                        label: 'Share',
                        onTap: () async {
                          widget.audio.click();
                          await SharePlus.instance.share(
                            ShareParams(
                              text:
                                  'Play Cricket with me! https://play.google.com/store/apps/details?id=com.gameswajiha.cricket',
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 22),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.star_rate,
                        label: 'Rate',
                        onTap: () async {
                          widget.audio.click();
                          await _requestReview();
                        },
                      ),
                      const SizedBox(width: 22),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.settings,
                        label: 'Settings',
                        onTap: () async {
                          widget.audio.click();
                          await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              audio: widget.audio,
                              settings: _s,
                            ),
                          ));
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(width: 26),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.help_outline,
                        label: 'How to Play',
                        onTap: () {
                          widget.audio.click();
                          _showHowTo(context, t);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_s.gamesPlayed > 0)
                    Text(
                      'Wins: ${_s.wins}   •   Matches: ${_s.gamesPlayed}   •   Best: ${_s.bestScore}   •   Sixes: ${_s.sixes}',
                      style: Pavilion.label(12, theme: t),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/wajiha_logo.png',
                          width: 22, height: 22, fit: BoxFit.contain),
                      const SizedBox(width: 8),
                      Text('Credits: WAJIHA',
                          style: Pavilion.label(12, theme: t)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHowTo(BuildContext context, StadiumThemeDef t) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: t.ink,
            border: Border.all(color: t.accent, width: 3),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('How to Play', style: Pavilion.display(24, theme: t)),
                const SizedBox(height: 12),
                for (final line in [
                  '• Each side bats its overs (2, 5 or 10). Most runs wins.',
                  '• Tap BOWL, then SLOG when the needle hits the green!',
                  '• Perfect timing = fours and sixes. Sloppy timing = out!',
                  '• No shot at all is almost always a dot or a wicket.',
                  '• The second innings is a chase — beat the target to win.',
                  '• Lose all your wickets and the innings is over.',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(line, style: Pavilion.body(14, theme: t)),
                  ),
                const SizedBox(height: 16),
                Center(
                  child: PavilionButton(
                    label: 'Got it!',
                    width: 180,
                    fontSize: 16,
                    theme: t,
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _MenuIcon extends StatelessWidget {
  final StadiumThemeDef theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuIcon(
      {required this.theme,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.ink.withValues(alpha: 0.9),
              border: Border.all(color: theme.accent, width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: Pavilion.shadow,
                  offset: Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: theme.accentLight, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: Pavilion.label(12, theme: theme)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Mode setup: vs AI / 2-player, overs, bot difficulty.
class _ModeCard extends StatelessWidget {
  final StadiumThemeDef theme;
  const _ModeCard({required this.theme});

  static const difficulties = ['Easy', 'Medium', 'Hard'];

  Future<void> _goPro(BuildContext context, _MenuScreenState screen) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProScreen(
        audio: screen.widget.audio,
        settings: screen._s,
        store: screen._store,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    final audio = screen.widget.audio;
    return ScoreboardCard(
      theme: theme,
      title: 'Match Setup',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Chip(
                theme: theme,
                label: '🤖 vs AI',
                selected: s.mode == 0,
                onTap: () {
                  audio.click();
                  s.setMode(0);
                },
              ),
              _Chip(
                theme: theme,
                label: '👥 2 Players',
                selected: s.mode == 1,
                onTap: () {
                  audio.click();
                  s.setMode(1);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Overs:', style: Pavilion.body(15, theme: theme)),
              const SizedBox(width: 10),
              for (final o in [2, 5, 10])
                _Chip(
                  theme: theme,
                  label: '${o == 10 && !s.isPro ? '🔒 ' : ''}$o',
                  selected: s.overs == o,
                  onTap: () {
                    audio.click();
                    if (o == 10 && !s.isPro) {
                      _goPro(context, screen);
                      return;
                    }
                    s.setOvers(o);
                  },
                ),
            ],
          ),
          if (s.mode == 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('AI level:', style: Pavilion.body(15, theme: theme)),
                const SizedBox(width: 10),
                for (int d = 0; d < 3; d++)
                  _Chip(
                    theme: theme,
                    label:
                        '${d == 2 && !s.isPro ? '🔒 ' : ''}${difficulties[d]}',
                    selected: s.difficulty == d,
                    onTap: () {
                      audio.click();
                      if (d == 2 && !s.isPro) {
                        _goPro(context, screen);
                        return;
                      }
                      s.setDifficulty(d);
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Stadium picker: 12 grounds + custom creator, with PRO locks.
class _GroundCard extends StatelessWidget {
  final StadiumThemeDef theme;
  const _GroundCard({required this.theme});

  Future<void> _goPro(BuildContext context, _MenuScreenState screen) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProScreen(
        audio: screen.widget.audio,
        settings: screen._s,
        store: screen._store,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    final audio = screen.widget.audio;
    final isPro = s.isPro;
    return ScoreboardCard(
      theme: theme,
      title: 'Stadium',
      child: Column(
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final st in StadiumThemes.all)
                _StadiumTile(
                  theme: theme,
                  st: st,
                  selected: s.stadiumId == st.id,
                  locked:
                      StadiumThemes.isProTheme(st.id) && !isPro,
                  onTap: () {
                    audio.click();
                    if (StadiumThemes.isProTheme(st.id) && !isPro) {
                      _goPro(context, screen);
                      return;
                    }
                    s.setStadium(st.id);
                  },
                ),
              _StadiumTile(
                theme: theme,
                st: s.customStadium,
                selected: s.stadiumId == 'custom',
                locked: !isPro,
                custom: true,
                onTap: () {
                  audio.click();
                  if (!isPro) {
                    _goPro(context, screen);
                    return;
                  }
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CustomKitScreen(
                      audio: audio,
                      settings: s,
                    ),
                  ));
                },
              ),
            ],
          ),
          if (!isPro)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '🔒 ${StadiumThemes.all.length - StadiumThemes.freeThemeIds.length} more grounds in PRO',
                style: Pavilion.label(12, theme: theme),
              ),
            ),
        ],
      ),
    );
  }
}

class _StadiumTile extends StatelessWidget {
  final StadiumThemeDef theme;
  final StadiumThemeDef st;
  final bool selected;
  final bool locked;
  final bool custom;
  final VoidCallback onTap;
  const _StadiumTile({
    required this.theme,
    required this.st,
    required this.selected,
    required this.locked,
    required this.onTap,
    this.custom = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 104,
            padding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [st.skyBottom, st.grassLight],
              ),
              border: Border.all(
                color: selected
                    ? st.accentLight
                    : st.accent.withValues(alpha: 0.35),
                width: selected ? 3 : 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: st.pitch,
                    border: Border.all(
                        color: st.accentLight.withValues(alpha: 0.7)),
                  ),
                  child: Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFA31621),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  custom ? '🎨 My Ground' : st.name,
                  style: Pavilion.label(10, theme: st),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (locked)
            Container(
              width: 104,
              height: 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.black.withValues(alpha: 0.55),
              ),
              child: Icon(Icons.lock,
                  color: theme.accentLight, size: 22),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Kit (per team) + ball picker.
class _KitCard extends StatelessWidget {
  final StadiumThemeDef theme;
  const _KitCard({required this.theme});

  Future<void> _goPro(BuildContext context, _MenuScreenState screen) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProScreen(
        audio: screen.widget.audio,
        settings: screen._s,
        store: screen._store,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    final audio = screen.widget.audio;
    final isPro = s.isPro;
    return ScoreboardCard(
      theme: theme,
      title: 'Kits & Ball',
      child: Column(
        children: [
          for (int seat = 0; seat < 2; seat++) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${s.playerNames[seat]} kit:',
                style: Pavilion.body(14, theme: theme),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (int i = 0; i < KitStyles.all.length; i++)
                  _KitSwatch(
                    theme: theme,
                    kit: KitStyles.all[i],
                    selected: s.kitIndices[seat] == i,
                    locked: KitStyles.isPro(i) && !isPro,
                    onTap: () {
                      audio.click();
                      if (KitStyles.isPro(i) && !isPro) {
                        _goPro(context, screen);
                        return;
                      }
                      s.setKit(seat, i);
                    },
                  ),
                _KitSwatch(
                  theme: theme,
                  kit: s.customKit,
                  custom: true,
                  selected: s.kitIndices[seat] == -1,
                  locked: !isPro,
                  onTap: () {
                    audio.click();
                    if (!isPro) {
                      _goPro(context, screen);
                      return;
                    }
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CustomKitScreen(
                        audio: audio,
                        settings: s,
                      ),
                    ));
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Ball:', style: Pavilion.body(14, theme: theme)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (int i = 0; i < BallStyles.all.length; i++)
                _BallSwatch(
                  theme: theme,
                  ball: BallStyles.all[i],
                  selected: s.ballStyle == i,
                  locked: BallStyles.isPro(i) && !isPro,
                  onTap: () {
                    audio.click();
                    if (BallStyles.isPro(i) && !isPro) {
                      _goPro(context, screen);
                      return;
                    }
                    s.setBall(i);
                  },
                ),
              _BallSwatch(
                theme: theme,
                ball: s.customBall,
                custom: true,
                selected: s.ballStyle == -1,
                locked: !isPro,
                onTap: () {
                  audio.click();
                  if (!isPro) {
                    _goPro(context, screen);
                    return;
                  }
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CustomKitScreen(
                      audio: audio,
                      settings: s,
                    ),
                  ));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KitSwatch extends StatelessWidget {
  final StadiumThemeDef theme;
  final KitDef kit;
  final bool selected;
  final bool locked;
  final bool custom;
  final VoidCallback onTap;
  const _KitSwatch({
    required this.theme,
    required this.kit,
    required this.selected,
    required this.locked,
    required this.onTap,
    this.custom = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 52,
            height: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? theme.accentLight
                    : theme.accent.withValues(alpha: 0.35),
                width: selected ? 3 : 1.5,
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8)),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [kit.primary, kit.secondary],
                      ),
                    ),
                    child: custom
                        ? const Center(
                            child: Text('🎨', style: TextStyle(fontSize: 16)))
                        : null,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(8)),
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                    child: Text(
                      custom ? 'Mine' : kit.name.split(' ').first,
                      style: Pavilion.label(8, theme: theme),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (locked)
            Container(
              width: 52,
              height: 62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.black.withValues(alpha: 0.55),
              ),
              child: Icon(Icons.lock, color: theme.accentLight, size: 18),
            ),
        ],
      ),
    );
  }
}

class _BallSwatch extends StatelessWidget {
  final StadiumThemeDef theme;
  final BallDef ball;
  final bool selected;
  final bool locked;
  final bool custom;
  final VoidCallback onTap;
  const _BallSwatch({
    required this.theme,
    required this.ball,
    required this.selected,
    required this.locked,
    required this.onTap,
    this.custom = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.35, -0.35),
                    radius: 1.1,
                    colors: [
                      Color.lerp(ball.leather, Colors.white, 0.35)!,
                      ball.leather,
                      Color.lerp(ball.leather, Colors.black, 0.35)!,
                    ],
                  ),
                  border: Border.all(
                    color: selected
                        ? theme.accentLight
                        : theme.accent.withValues(alpha: 0.35),
                    width: selected ? 3 : 1.5,
                  ),
                ),
                child: Center(
                  child: custom
                      ? const Text('🎨', style: TextStyle(fontSize: 15))
                      : Container(
                          width: 26,
                          height: 5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2.5),
                            color: ball.seam,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 56,
                child: Text(
                  custom ? 'My Ball' : ball.name,
                  style: Pavilion.label(8, theme: theme),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (locked)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.55),
              ),
              child: Icon(Icons.lock, color: theme.accentLight, size: 18),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Rename the two teams.
class _NamesCard extends StatelessWidget {
  final StadiumThemeDef theme;
  const _NamesCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    return ScoreboardCard(
      theme: theme,
      title: 'Team Names',
      child: Column(
        children: [
          for (int i = 0; i < 2; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [
                        s.kitFor(i).primary,
                        s.kitFor(i).secondary,
                      ]),
                      border:
                          Border.all(color: theme.accentLight, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NameField(
                      theme: theme,
                      index: i,
                      initial: s.playerNames[i],
                      onDone: (v) => s.setPlayerName(i, v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    s.mode == 0 && i == 1 ? '🤖 AI' : '🧑 Human',
                    style: Pavilion.label(11, theme: theme),
                  ),
                ],
              ),
            ),
          Text(
            'Names show on the scoreboard, commentary and the winner podium.',
            style: Pavilion.body(12,
                theme: theme, color: theme.cream.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NameField extends StatefulWidget {
  final StadiumThemeDef theme;
  final int index;
  final String initial;
  final ValueChanged<String> onDone;
  const _NameField(
      {required this.theme,
      required this.index,
      required this.initial,
      required this.onDone});

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _c;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
    // Commit on focus loss: if the keyboard is dismissed (or the user taps
    // elsewhere) without "done", the latest text still persists.
    _focus = FocusNode()..addListener(_onFocus);
  }

  void _onFocus() {
    if (!_focus.hasFocus) {
      widget.onDone(_c.text);
    }
  }

  @override
  void didUpdateWidget(covariant _NameField old) {
    super.didUpdateWidget(old);
    if (old.initial != widget.initial && _c.text != widget.initial) {
      _c.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.black.withValues(alpha: 0.3),
        border:
            Border.all(color: widget.theme.accent.withValues(alpha: 0.5)),
      ),
      child: TextField(
        controller: _c,
        focusNode: _focus,
        style: Pavilion.body(15, theme: widget.theme),
        maxLength: 14,
        decoration: InputDecoration(
          counterText: '',
          border: InputBorder.none,
          hintText: 'Team ${widget.index + 1}',
          hintStyle: Pavilion.body(14,
              theme: widget.theme,
              color: widget.theme.cream.withValues(alpha: 0.4)),
        ),
        // Save on EVERY keystroke (not just keyboard-done); the FocusNode
        // listener above commits on focus loss. Names can never be lost.
        onChanged: widget.onDone,
        onSubmitted: widget.onDone,
        onEditingComplete: () => widget.onDone(_c.text),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Tip jar (IAP).
class _SupportCard extends StatelessWidget {
  final StadiumThemeDef theme;
  final StoreService store;
  const _SupportCard({required this.theme, required this.store});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final audio = screen.widget.audio;
    return ScoreboardCard(
      theme: theme,
      title: 'Support Wajiha',
      child: Column(
        children: [
          Text(
            'Cricket is 100% free. If it made you smile, a small tip keeps the pavilion open!',
            style: Pavilion.body(14, theme: theme),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Builder(builder: (_) {
            final tips = [
              store.coffeeProduct,
              store.chocolateProduct,
            ].whereType<ProductDetails>().toList();
            if (!store.storeReady) {
              return Text(
                store.error ?? 'Loading…',
                style: Pavilion.body(13,
                    theme: theme,
                    color: theme.cream.withValues(alpha: 0.6)),
                textAlign: TextAlign.center,
              );
            }
            if (tips.isEmpty) {
              return Text('Tips coming soon.',
                  style: Pavilion.body(13,
                      theme: theme,
                      color: theme.cream.withValues(alpha: 0.6)));
            }
            return Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final p in tips)
                  _Chip(
                    theme: theme,
                    label: p.id == StoreService.chocolateId
                        ? '🍫 ${p.price}'
                        : '☕ ${p.price}',
                    selected: false,
                    onTap: () {
                      audio.click();
                      store.buyTip(p);
                    },
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _Chip extends StatelessWidget {
  final StadiumThemeDef theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.theme,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
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
        child: Text(
          label,
          style: Pavilion.label(13,
              theme: theme, color: selected ? theme.ink : theme.cream),
        ),
      ),
    );
  }
}
