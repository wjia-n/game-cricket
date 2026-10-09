import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:in_app_review/in_app_review.dart';
import '../engine/cricket_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/county_pavilion.dart';
import '../theme/stadium_themes.dart';

/// Match screen: scoreboard, animated pitch, timing meter, per-side strips,
/// commentary, pause. The engine owns all phases; this screen only renders.
class GameScreen extends StatefulWidget {
  final CricketEngine engine;
  final CricketAudio audio;
  final CricketSettings settings;
  const GameScreen(
      {super.key,
      required this.engine,
      required this.audio,
      required this.settings});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  CricketEngine get _e => widget.engine;
  CricketSettings get _s => widget.settings;
  bool _paused = false;
  bool _reviewAsked = false;

  StadiumThemeDef get _t =>
      StadiumThemes.byId(_s.stadiumId, custom: _s.customStadium);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _e.onEvent = _onEngineEvent;
    widget.audio.startGameMusic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _e.onEvent = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
      if (!_e.over) {
        setState(() => _paused = true);
        _e.setPaused(true);
      }
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
      if (_paused && !_e.over) {
        setState(() => _paused = false);
        _e.setPaused(false);
      }
    }
  }

  void _onEngineEvent(CricketEvent event) {
    final a = widget.audio;
    switch (event) {
      case CricketEvent.deliveryStart:
        break;
      case CricketEvent.swing:
        a.ballThump();
        break;
      case CricketEvent.ballHit:
        // The outcome is already decided when this fires.
        if (_e.lastOutcome == 'W') {
          if (_e.lastWicketKind == 'bowled') {
            a.stumps();
          } else {
            a.appeal();
          }
        } else {
          a.batCrack();
        }
        break;
      case CricketEvent.six:
      case CricketEvent.four:
      case CricketEvent.wicket:
      case CricketEvent.bowled:
        a.crowdCheer();
        break;
      case CricketEvent.runs:
        break;
      case CricketEvent.inningsBreak:
        a.crowdCheer();
        break;
      case CricketEvent.humanWon:
        a.win();
        a.crowdCheer();
        _finishMatch(humanWon: true);
        break;
      case CricketEvent.botWon:
        a.lose();
        a.crowdGroan();
        _finishMatch(humanWon: false);
        break;
      case CricketEvent.tie:
        a.crowdCheer();
        _finishMatch(humanWon: true);
        break;
      case CricketEvent.invalid:
        a.invalid();
        break;
    }
  }

  Future<void> _finishMatch({required bool humanWon}) async {
    // Record stats once.
    await _s.recordGame(
      humanWon: humanWon,
      humanBest: _s.mode == 0
          ? _e.scores[0]
          : (_e.winner == null ? _e.scores[0] : _e.scores[_e.winner!]),
      sixesHit: _e.sixesHit,
    );
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(
        theme: _t,
        engine: _e,
        audio: widget.audio,
        onRematch: () {
          Navigator.of(context).pop();
          _e.restart();
        },
        onMenu: () => Navigator.of(context).pop(),
      ),
    );
    // Sensible review moment: a human win, asked at most once per match.
    // Graceful when not from Play / unavailable.
    if (humanWon && !_reviewAsked) {
      _reviewAsked = true;
      try {
        final review = InAppReview.instance;
        if (await review.isAvailable()) {
          await review.requestReview();
        }
      } catch (_) {}
    }
  }

  void _togglePause() {
    widget.audio.click();
    setState(() {
      _paused = !_paused;
      _e.setPaused(_paused);
      if (_paused) {
        widget.audio.onAppPaused();
      } else {
        widget.audio.onAppResumed();
      }
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
            listenable: _e,
            builder: (_, _) => Stack(
              children: [
                Column(
                  children: [
                    _TopBar(theme: t, paused: _paused, onPause: _togglePause),
                    const SizedBox(height: 6),
                    _Scoreboard(theme: t, engine: _e),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14),
                        child: _PitchView(
                          theme: t,
                          engine: _e,
                          settings: _s,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _SideStrips(theme: t, engine: _e),
                    const SizedBox(height: 6),
                    _BottomControls(
                      theme: t,
                      engine: _e,
                      audio: widget.audio,
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
                if (_e.resultPop.isNotEmpty &&
                    (_e.phase == Phase.result || _e.phase == Phase.over))
                  _ResultPop(theme: t, text: _e.resultPop),
                if (_paused && !_e.over)
                  _PauseOverlay(
                    theme: t,
                    onResume: _togglePause,
                    onRestart: () {
                      widget.audio.click();
                      setState(() => _paused = false);
                      _e.restart();
                    },
                    onQuit: () {
                      widget.audio.click();
                      Navigator.of(context).pop();
                    },
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
class _TopBar extends StatelessWidget {
  final StadiumThemeDef theme;
  final bool paused;
  final VoidCallback onPause;
  const _TopBar(
      {required this.theme, required this.paused, required this.onPause});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Text('🏏 Cricket', style: Pavilion.display(20, theme: theme)),
          const Spacer(),
          GestureDetector(
            onTap: onPause,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.ink.withValues(alpha: 0.85),
                border: Border.all(color: theme.accent, width: 2),
              ),
              child: Icon(paused ? Icons.play_arrow : Icons.pause,
                  color: theme.accentLight),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _Scoreboard extends StatelessWidget {
  final StadiumThemeDef theme;
  final CricketEngine engine;
  const _Scoreboard({required this.theme, required this.engine});

  @override
  Widget build(BuildContext context) {
    final e = engine;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.ink.withValues(alpha: 0.88),
        border: Border.all(color: theme.accent, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _scoreCell(e.players[0].name, e.scores[0],
              e.batter == 0 && !e.over, e, 0),
          Column(
            children: [
              Text(
                e.chasing
                    ? 'need ${e.target}'
                    : e.innings == 0
                        ? '1st inns'
                        : 'target ${e.target}',
                style: Pavilion.label(12, theme: theme),
              ),
              Text('${e.oversStr} ov',
                  style: Pavilion.body(12,
                      theme: theme,
                      color: theme.cream.withValues(alpha: 0.7))),
            ],
          ),
          _scoreCell(e.players[1].name, e.scores[1],
              e.batter == 1 && !e.over, e, 1),
        ],
      ),
    );
  }

  Widget _scoreCell(
      String name, int score, bool batting, CricketEngine e, int seat) {
    final showWkts = e.batter == seat;
    return Column(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            '${e.players[seat].isBot ? '🤖' : '🧑'} $name',
            style: Pavilion.body(12, theme: theme),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          showWkts ? '$score/${e.wickets}' : '$score',
          style: Pavilion.display(22, theme: theme,
              color: batting ? theme.accentLight : theme.cream),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
/// Per-side strips: batting and bowling teams, active side highlighted.
class _SideStrips extends StatelessWidget {
  final StadiumThemeDef theme;
  final CricketEngine engine;
  const _SideStrips({required this.theme, required this.engine});

  @override
  Widget build(BuildContext context) {
    final e = engine;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
              child: _strip(e.batter, 'BATTING', true)),
          const SizedBox(width: 8),
          Expanded(
              child: _strip(e.bowler, 'BOWLING', false)),
        ],
      ),
    );
  }

  Widget _strip(int seat, String role, bool batting) {
    final e = engine;
    final p = e.players[seat];
    final active = !e.over &&
        ((batting && e.phase != Phase.over) || (!batting));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: theme.ink.withValues(alpha: active ? 0.92 : 0.6),
        border: Border.all(
          color: batting ? theme.accentLight : theme.accent.withValues(alpha: 0.5),
          width: batting ? 2.5 : 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.color,
              border: Border.all(color: theme.accentLight, width: 1.5),
            ),
            child: Center(
              child: Text(p.isBot ? '🤖' : '🧑',
                  style: const TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    style: Pavilion.label(12, theme: theme),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(role,
                    style: Pavilion.body(10,
                        theme: theme,
                        color: theme.cream.withValues(alpha: 0.6))),
              ],
            ),
          ),
          if (batting && e.phase == Phase.delivery)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// BOWL / SLOG buttons, timing meter, commentary, over dots.
class _BottomControls extends StatelessWidget {
  final StadiumThemeDef theme;
  final CricketEngine engine;
  final CricketAudio audio;
  const _BottomControls(
      {required this.theme, required this.engine, required this.audio});

  @override
  Widget build(BuildContext context) {
    final e = engine;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Over dots.
          if (e.overDots.isNotEmpty)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: [
                for (final d in e.overDots)
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: d == 'W'
                          ? const Color(0xFFC0392B)
                          : d == '6'
                              ? theme.accentLight
                              : d == '4'
                                  ? theme.accent
                                  : Colors.white70,
                    ),
                    child: Text(d,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: Colors.black87)),
                  ),
              ],
            ),
          if (e.overDots.isNotEmpty) const SizedBox(height: 6),
          // Commentary.
          SizedBox(
            height: 40,
            child: Center(
              child: Text(
                e.commentary,
                style: Pavilion.body(14, theme: theme),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (e.awaitingHumanInput)
            PavilionButton(
                label: '🎾  BOWL', onTap: e.startBall, theme: theme, width: 240),
          if (e.phase == Phase.delivery && e.battingHuman) ...[
            _TimingMeter(theme: theme, engine: e),
            const SizedBox(height: 8),
            PavilionButton(
              label: e.swungThisBall ? '…swung!' : '🏏  SLOG IT!',
              onTap: e.swungThisBall ? () {} : e.swing,
              theme: theme,
              width: 240,
            ),
          ],
          if (!e.battingHuman && !e.over && e.phase != Phase.over)
            Text('🤖 ${e.battingSide.name} is batting…',
                style: Pavilion.label(13, theme: theme)),
          if (e.phase == Phase.inningsBreak)
            Text('☕ Innings break…',
                style: Pavilion.display(20, theme: theme)),
        ],
      ),
    );
  }
}

/// Timing meter: needle sweeps while the ball is delivered. Engine-owned
/// timing; the UI only renders the needle from the engine timestamp.
class _TimingMeter extends StatefulWidget {
  final StadiumThemeDef theme;
  final CricketEngine engine;
  const _TimingMeter({required this.theme, required this.engine});

  @override
  State<_TimingMeter> createState() => _TimingMeterState();
}

class _TimingMeterState extends State<_TimingMeter> {
  Ticker? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker((_) {
      if (mounted) setState(() {});
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.engine;
    final needle = e.phase == Phase.delivery
        ? e.needleAt(e.deliveryElapsedMs())
        : 0.5;
    return Column(
      children: [
        Text('Tap SLOG in the green!',
            style: Pavilion.body(12, theme: widget.theme)),
        const SizedBox(height: 6),
        Container(
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: const LinearGradient(colors: [
              Color(0xFFC0392B),
              Color(0xFFE0B44E),
              Color(0xFF4E9A42),
              Color(0xFFE0B44E),
              Color(0xFFC0392B),
            ]),
            border: Border.all(
                color: widget.theme.accentLight.withValues(alpha: 0.6),
                width: 2),
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment(-1 + needle * 2, 0),
                child: Container(
                  width: 7,
                  height: 40,
                  color: Colors.white,
                  margin: const EdgeInsets.only(top: -5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
/// The pitch: sky, grass, straw strip, stumps, players, animated ball.
/// Owns a Ticker so ball/needle motion is smooth; engine owns the state.
class _PitchView extends StatefulWidget {
  final StadiumThemeDef theme;
  final CricketEngine engine;
  final CricketSettings settings;
  const _PitchView(
      {required this.theme, required this.engine, required this.settings});

  @override
  State<_PitchView> createState() => _PitchViewState();
}

class _PitchViewState extends State<_PitchView> {
  Ticker? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker((_) {
      if (mounted) setState(() {});
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.theme.accent, width: 2),
        boxShadow: const [
          BoxShadow(color: Pavilion.shadow, offset: Offset(0, 4), blurRadius: 10),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: _PitchPainter(
          theme: widget.theme,
          engine: widget.engine,
          kitA: widget.settings.kitFor(0),
          kitB: widget.settings.kitFor(1),
          ball: widget.settings.ballDef,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  final StadiumThemeDef theme;
  final CricketEngine engine;
  final KitDef kitA;
  final KitDef kitB;
  final BallDef ball;

  _PitchPainter({
    required this.theme,
    required this.engine,
    required this.kitA,
    required this.kitB,
    required this.ball,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final e = engine;
    // Grass.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = theme.grassDark,
    );
    // Straw pitch strip (vertical center).
    final stripW = size.width * 0.30;
    final stripX = (size.width - stripW) / 2;
    canvas.drawRect(
      Rect.fromLTWH(stripX, size.height * 0.06, stripW, size.height * 0.88),
      Paint()..color = theme.pitch,
    );
    // Crease lines.
    final crease = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 2;
    for (final y in [0.10, 0.86]) {
      canvas.drawLine(
        Offset(stripX - 8, size.height * y),
        Offset(stripX + stripW + 8, size.height * y),
        crease,
      );
    }

    final bx = size.width / 2; // batter x
    final batterY = size.height * 0.80;
    final bowlerY = size.height * 0.14;

    // Stumps behind the batter (3 stumps).
    final stumpsBroken =
        e.lastOutcome == 'W' && e.lastWicketKind == 'bowled' &&
            (e.phase == Phase.ballFlight ||
                e.phase == Phase.result ||
                e.phase == Phase.over);
    _drawStumps(canvas, Offset(bx, batterY + 26), broken: stumpsBroken);

    // Players: bowler (top), batter (bottom) in kit colors.
    final bowlerKit = e.bowler == 0 ? kitA : kitB;
    final batterKit = e.batter == 0 ? kitA : kitB;
    _drawPlayer(canvas, Offset(bx, bowlerY), bowlerKit, bowling: true);
    // Batter swing pose: human swung, or AI mid-swing.
    final swung = e.battingSide.isBot
        ? (e.phase == Phase.delivery &&
            e.deliveryElapsedMs() >= e.aiSwingAtMs)
        : e.swungThisBall;
    _drawPlayer(canvas, Offset(bx, batterY), batterKit,
        bowling: false, swung: swung);

    // A couple of fielders.
    _drawFielder(canvas, Offset(size.width * 0.16, size.height * 0.42),
        batterKit);
    _drawFielder(canvas, Offset(size.width * 0.84, size.height * 0.42),
        batterKit);
    if (e.flight != null && e.flight!.kind == 4) {
      // Catcher under the caught ball.
      _drawFielder(canvas, Offset(size.width * 0.68, size.height * 0.22),
          bowlerKit,
          catching: true);
    }

    // Ball.
    final bp = _ballPos(size, bx, batterY, bowlerY);
    if (bp != null) {
      final r = 9.0;
      canvas.drawCircle(
        bp,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.35),
            radius: 1.1,
            colors: [
              Color.lerp(ball.leather, Colors.white, 0.4)!,
              ball.leather,
              Color.lerp(ball.leather, Colors.black, 0.4)!,
            ],
          ).createShader(Rect.fromCircle(center: bp, radius: r)),
      );
      // Seam.
      canvas.drawLine(
        bp + const Offset(-5, 0),
        bp + const Offset(5, 0),
        Paint()
          ..color = ball.seam
          ..strokeWidth = 2,
      );
    }
  }

  Offset? _ballPos(Size size, double bx, double batterY, double bowlerY) {
    final e = engine;
    final f = e.flight;
    if (f == null) return null;
    final elapsed =
        DateTime.now().difference(f.startedAt).inMilliseconds;
    final p = (elapsed / f.flightMs).clamp(0.0, 1.0);
    final start = Offset(bx, bowlerY + 20);
    final hit = Offset(bx, batterY - 10);

    Offset lerp(Offset a, Offset b, double t) =>
        Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);

    Offset quad(Offset a, Offset c, Offset b, double t) {
      final u = 1 - t;
      return Offset(
        u * u * a.dx + 2 * u * t * c.dx + t * t * b.dx,
        u * u * a.dy + 2 * u * t * c.dy + t * t * b.dy,
      );
    }

    switch (f.kind) {
      case 0: // delivery: bowler -> batter with a bounce
        if (p < 0.55) {
          final q = p / 0.55;
          return quad(start, Offset(bx, (start.dy + hit.dy) / 2 - 30), hit, q);
        }
        final q = (p - 0.55) / 0.45;
        return lerp(Offset(bx, (start.dy + hit.dy) / 2), hit, q);
      case 1: // SIX: high over long-on
        return quad(hit, Offset(bx + 40, -size.height * 0.25),
            Offset(bx + 30, -20), p);
      case 2: // FOUR: races to the cover boundary
        return quad(hit, Offset(size.width * 0.75, size.height * 0.45),
            Offset(size.width * 0.97, size.height * 0.38), p);
      case 3: // BOWLED: into the stumps
        return lerp(hit, Offset(bx, batterY + 22), p);
      case 4: // CAUGHT: skied to the fielder
        return quad(hit, Offset(size.width * 0.6, size.height * 0.02),
            Offset(size.width * 0.68, size.height * 0.20), p);
      case 6: // LBW: into the pads
        return lerp(hit, Offset(bx, batterY + 6), p);
      default: // 5: along the ground to a fielder
        return quad(hit, Offset(size.width * 0.7, size.height * 0.6),
            Offset(size.width * 0.84, size.height * 0.42), p);
    }
  }

  void _drawStumps(Canvas canvas, Offset base, {required bool broken}) {
    final paint = Paint()..color = const Color(0xFFF2E7C8);
    for (int i = -1; i <= 1; i++) {
      final dx = i * 7.0;
      if (broken && i != 0) {
        // Flying stump.
        canvas.save();
        canvas.translate(base.dx + dx * 2.2, base.dy - 14 - i.abs() * 6);
        canvas.rotate(i * 0.5);
        canvas.drawRect(
            Rect.fromLTWH(-2.5, -14, 5, 28), paint);
        canvas.restore();
      } else {
        canvas.drawRect(
          Rect.fromLTWH(base.dx + dx - 2.5, base.dy - 28, 5, 28),
          paint,
        );
      }
    }
    if (!broken) {
      // Bails.
      canvas.drawRect(Rect.fromLTWH(base.dx - 9, base.dy - 32, 18, 4), paint);
    }
  }

  void _drawPlayer(Canvas canvas, Offset c, KitDef kit,
      {required bool bowling, bool swung = false}) {
    // Head.
    canvas.drawCircle(
        c + const Offset(0, -26), 9, Paint()..color = const Color(0xFFE8B88A));
    // Body in kit colors.
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        colors: [kit.primary, kit.secondary],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: c, radius: 16));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(c.dx - 11, c.dy - 18, 22, 30),
          const Radius.circular(8)),
      bodyPaint,
    );
    if (bowling) {
      // Bowling arm raised with ball.
      canvas.drawLine(
        c + const Offset(8, -12),
        c + const Offset(18, -30),
        Paint()
          ..color = kit.primary
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(c + const Offset(18, -32), 5,
          Paint()..color = const Color(0xFFA31621));
    } else {
      // Bat: angled, swings across when swung.
      final ang = swung ? -1.1 : -0.35;
      canvas.save();
      canvas.translate(c.dx + 10, c.dy - 6);
      canvas.rotate(ang);
      // Handle + blade.
      canvas.drawRect(
          const Rect.fromLTWH(-3, -34, 6, 16),
          Paint()..color = const Color(0xFF6B4A2A));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-8, -18, 16, 34), const Radius.circular(4)),
        Paint()..color = const Color(0xFFD9B87C),
      );
      canvas.restore();
    }
  }

  void _drawFielder(Canvas canvas, Offset c, KitDef kit,
      {bool catching = false}) {
    canvas.drawCircle(
        c + const Offset(0, -20), 7, Paint()..color = const Color(0xFFE8B88A));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(c.dx - 9, c.dy - 14, 18, 24),
          const Radius.circular(7)),
      Paint()..color = kit.primary.withValues(alpha: 0.9),
    );
    if (catching) {
      canvas.drawLine(
        c + const Offset(-6, -8),
        c + const Offset(-6, -26),
        Paint()
          ..color = kit.primary
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        c + const Offset(6, -8),
        c + const Offset(6, -26),
        Paint()
          ..color = kit.primary
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PitchPainter old) => true;
}

// ---------------------------------------------------------------------------
class _ResultPop extends StatelessWidget {
  final StadiumThemeDef theme;
  final String text;
  const _ResultPop({required this.theme, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(text),
        tween: Tween(begin: 0.5, end: 1.0),
        duration: const Duration(milliseconds: 350),
        curve: Curves.elasticOut,
        builder: (_, v, _) => Transform.scale(
          scale: v,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.accentLight, width: 2),
            ),
            child: Text(text,
                style: Pavilion.display(32, theme: theme)),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _PauseOverlay extends StatelessWidget {
  final StadiumThemeDef theme;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;
  const _PauseOverlay({
    required this.theme,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: theme.ink,
            border: Border.all(color: theme.accent, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Paused', style: Pavilion.display(26, theme: theme)),
              const SizedBox(height: 18),
              PavilionButton(
                  label: 'Resume', onTap: onResume, theme: theme, width: 200),
              const SizedBox(height: 10),
              PavilionButton(
                  label: 'Restart', onTap: onRestart, theme: theme, width: 200),
              const SizedBox(height: 10),
              PavilionButton(
                  label: 'Quit Match', onTap: onQuit, theme: theme, width: 200),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _ResultDialog extends StatelessWidget {
  final StadiumThemeDef theme;
  final CricketEngine engine;
  final CricketAudio audio;
  final VoidCallback onRematch;
  final VoidCallback onMenu;
  const _ResultDialog({
    required this.theme,
    required this.engine,
    required this.audio,
    required this.onRematch,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final e = engine;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: theme.ink,
          border: Border.all(color: theme.accent, width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏆', style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 8),
            Text(
              e.tie
                  ? "It's a tie!"
                  : '${e.players[e.winner!].name} win${e.players[e.winner!].isBot ? 's' : ''}!',
              style: Pavilion.display(26, theme: theme),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              '${e.players[0].name} ${e.scores[0]}  •  ${e.players[1].name} ${e.scores[1]}',
              style: Pavilion.body(15, theme: theme),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            PavilionButton(
              label: '🔁  Rematch',
              width: 220,
              theme: theme,
              onTap: () {
                audio.gameStart();
                onRematch();
              },
            ),
            const SizedBox(height: 10),
            PavilionButton(
              label: '🏠  Menu',
              width: 220,
              theme: theme,
              onTap: () {
                audio.click();
                onMenu();
              },
            ),
          ],
        ),
      ),
    );
  }
}
