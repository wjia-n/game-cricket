import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Slog-overs cricket engine (RULES.md is the source of truth).
//
// Ball-by-ball turn phases owned entirely by the engine. The UI only renders.
// Every ball is fully visible: animated delivery, visible swing, ball flight,
// commentary narration — never silently auto-played.
// ---------------------------------------------------------------------------

/// 0 = easy, 1 = medium, 2 = hard (RULES.md §11).
enum BotDifficulty { easy, medium, hard }

/// Ball-by-ball phases owned entirely by the engine. The UI only renders.
enum Phase { preBall, delivery, ballFlight, result, inningsBreak, over }

class CricketPlayer {
  String name;
  final Color color;
  final bool isBot;

  CricketPlayer({required this.name, required this.color, required this.isBot});
}

/// A ball in flight (visual). The logical outcome is decided at delivery end;
/// the UI animates from [flightStartedAt] over [flightMs].
class BallFlight {
  final int kind;
  // 0 = delivery (bowler -> batter), 1 = six, 2 = four, 3 = bowled (stumps),
  // 4 = caught (arc to fielder), 5 = along the ground (dot / 1 / 2 / 3),
  // 6 = lbw (into the pads)
  DateTime startedAt;
  final int flightMs;

  BallFlight({required this.kind, required this.flightMs})
      : startedAt = DateTime.now();
}

class CricketEngine extends ChangeNotifier {
  final List<CricketPlayer> players; // exactly 2 seats
  final BotDifficulty botDifficulty;
  final int overs;
  late final int maxWickets;
  late final int ballsPerInnings;

  int innings = 0; // 0 or 1
  int balls = 0;
  int wickets = 0;
  final List<int> scores = [0, 0];
  int target = 0;
  List<String> overDots = []; // this over's balls: '0'..'6' / 'W'
  String commentary = '';
  String resultPop = '';
  String lastOutcome = ''; // '0','1','2','3','4','6','W'
  String lastWicketKind = ''; // bowled | caught | lbw | run out
  int sixesHit = 0;

  Phase phase = Phase.preBall;
  bool over = false;
  int? winner; // 0, 1, or null for tie
  bool tie = false;

  // Delivery / timing state (engine-owned; UI renders from timestamps).
  DateTime? deliveryStartedAt;
  int deliveryMs = 1150;
  double needleSpeed = 1.0; // multiplier: AI bowling difficulty
  double _humanQuality = -1; // -1 = no swing yet this ball
  double _aiQuality = 0;
  int _aiSwingAtMs = 700; // when the AI visibly swings (animation)
  BallFlight? flight;

  final _rand = Random();
  Timer? _timer; // single phase-transition timer
  Timer? _watchdog; // stuck-state recovery
  bool _disposed = false;
  bool paused = false;
  DateTime? _pausedAt;

  static const resultMs = 1500;
  static const inningsBreakMs = 2600;

  /// Test hook: when set, the next ball's quality is fixed. Consumed once.
  @visibleForTesting
  double? forcedQuality;

  CricketEngine({
    required this.players,
    this.botDifficulty = BotDifficulty.medium,
    this.overs = 5,
  })  : assert(players.length == 2),
        ballsPerInnings = overs * 6 {
    maxWickets = switch (overs) {
      2 => 3,
      10 => 10,
      _ => 5,
    };
    commentary = '${players[0].name} to bat. Tap BOWL to start!';
    _watchdog = Timer.periodic(const Duration(seconds: 3), (_) => _recover());
    _afterPhase();
  }

  // ------------------------------------------------------------- derived
  int get batter => innings; // seat batting this innings
  int get bowler => 1 - innings;
  CricketPlayer get battingSide => players[batter];
  CricketPlayer get bowlingSide => players[bowler];
  bool get battingHuman => !battingSide.isBot;
  bool get awaitingHumanInput =>
      phase == Phase.preBall && battingHuman && !over;
  bool get awaitingHumanSwing =>
      phase == Phase.delivery && battingHuman && _humanQuality < 0 && !over;
  String get oversStr => '${balls ~/ 6}.${balls % 6}';
  bool get chasing => innings == 1;
  bool get swungThisBall => _humanQuality >= 0;
  int get aiSwingAtMs => _aiSwingAtMs;
  double get aiQuality => _aiQuality;

  /// Needle position 0..1 at [elapsedMs] into the delivery (triangle wave).
  double needleAt(int elapsedMs) {
    final period = deliveryMs / needleSpeed;
    if (period <= 0) return 0.5;
    final t = (elapsedMs % (2 * period)) / (2 * period);
    return t < 0.5 ? t * 2 : 2 - t * 2;
  }

  /// Timing quality 0..1 from a swing at [elapsedMs]: 1 = dead center.
  double qualityAt(int elapsedMs) {
    final d = (needleAt(elapsedMs) - 0.5).abs() * 2;
    return (1 - d).clamp(0.0, 1.0);
  }

  int deliveryElapsedMs() {
    final s = deliveryStartedAt;
    if (s == null) return 0;
    return DateTime.now().difference(s).inMilliseconds;
  }

  // ------------------------------------------------------------- lifecycle
  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  void _arm(Duration d, void Function() fn) {
    if (_disposed || paused) return;
    _timer?.cancel();
    _timer = Timer(d, () {
      _timer = null;
      if (!_disposed && !paused) fn();
    });
  }

  /// Pause: freeze the phase timer and shift phase timestamps on resume so
  /// animations continue exactly where they froze.
  void setPaused(bool v) {
    if (paused == v || _disposed) return;
    paused = v;
    if (v) {
      _timer?.cancel();
      _timer = null;
      _pausedAt = DateTime.now();
    } else {
      final p = _pausedAt;
      if (p != null) {
        final shift = DateTime.now().difference(p);
        if (deliveryStartedAt != null) {
          deliveryStartedAt = deliveryStartedAt!.add(shift);
        }
        final f = flight;
        if (f != null) {
          // Shift every live animation timestamp so visuals resume exactly
          // where they froze.
          f.startedAt = f.startedAt.add(shift);
        }
        _pausedAt = null;
      }
      _recover();
    }
    notifyListeners();
  }

  /// Watchdog: if the single phase timer ever dies without progress, recover.
  /// Stuck states are impossible by construction. Respects [paused].
  void _recover() {
    if (_disposed || over || paused || _timer != null) return;
    switch (phase) {
      case Phase.preBall:
        if (!battingHuman) _aiStartBall();
      case Phase.delivery:
        _endDelivery(); // delivery with no timer: resolve immediately
      case Phase.ballFlight:
        _showResult();
      case Phase.result:
        _nextBall();
      case Phase.inningsBreak:
        _startSecondInnings();
      case Phase.over:
        break;
    }
  }

  /// Called whenever we enter preBall: AI batters start their own ball.
  void _afterPhase() {
    if (over || phase != Phase.preBall) return;
    if (!battingHuman) {
      _arm(const Duration(milliseconds: 900), _aiStartBall);
    }
  }

  // ------------------------------------------------------------- ball flow
  /// Human batter taps BOWL. Strict: only in preBall, only the human batter.
  void startBall() {
    if (!awaitingHumanInput) {
      onEvent?.call(CricketEvent.invalid);
      return;
    }
    _beginDelivery();
  }

  void _aiStartBall() {
    if (over || phase != Phase.preBall || battingHuman) return;
    commentary = '${bowlingSide.name} runs in to ${battingSide.name}…';
    notifyListeners();
    _arm(const Duration(milliseconds: 700), _beginDelivery);
  }

  void _beginDelivery() {
    if (over || phase != Phase.preBall) return;
    phase = Phase.delivery;
    deliveryStartedAt = DateTime.now();
    _humanQuality = -1;
    flight = BallFlight(kind: 0, flightMs: deliveryMs);
    // AI bowling difficulty: harder = faster, twitchier needle.
    needleSpeed = switch (botDifficulty) {
      BotDifficulty.easy => 0.9,
      BotDifficulty.medium => 1.15,
      BotDifficulty.hard => 1.4,
    };
    if (battingSide.isBot) {
      // AI commits its swing quality now; the swing animates visibly mid-ball.
      _aiQuality = switch (botDifficulty) {
        BotDifficulty.easy => 0.05 + _rand.nextDouble() * 0.75,
        BotDifficulty.medium => 0.3 + _rand.nextDouble() * 0.65,
        BotDifficulty.hard => 0.55 + _rand.nextDouble() * 0.45,
      };
      _aiSwingAtMs =
          (deliveryMs * (0.45 + _rand.nextDouble() * 0.4)).round();
      commentary = '${battingSide.name} watches it…';
    } else {
      commentary = 'SLOG when the needle hits green!';
    }
    onEvent?.call(CricketEvent.deliveryStart);
    notifyListeners();
    _arm(Duration(milliseconds: deliveryMs), _endDelivery);
  }

  /// Human batter taps SLOG mid-delivery. Captures timing quality once.
  void swing() {
    if (!awaitingHumanSwing) return;
    _humanQuality = qualityAt(deliveryElapsedMs());
    onEvent?.call(CricketEvent.swing);
    notifyListeners();
  }

  /// Engine-owned delivery settle — the UI never calls this. No desync possible.
  void _endDelivery() {
    if (over || phase != Phase.delivery) return;
    final q = forcedQuality ?? _ballQuality();
    forcedQuality = null;
    final outcome = _sampleOutcome(q);
    lastOutcome = outcome.$1;
    lastWicketKind = outcome.$2;
    final kind = switch (lastOutcome) {
      '6' => 1,
      '4' => 2,
      'W' => lastWicketKind == 'bowled'
          ? 3
          : lastWicketKind == 'caught'
              ? 4
              : 6,
      _ => 5,
    };
    final flightMs = switch (kind) {
      1 => 1000,
      2 => 850,
      3 => 600,
      4 => 900,
      6 => 600,
      _ => 700,
    };
    flight = BallFlight(kind: kind, flightMs: flightMs);
    phase = Phase.ballFlight;
    if (lastOutcome == '6' || lastOutcome == '4') {
      commentary = _boundaryLine(lastOutcome == '6');
    } else if (lastOutcome == 'W') {
      commentary = _wicketLine();
    }
    onEvent?.call(CricketEvent.ballHit);
    notifyListeners();
    _arm(Duration(milliseconds: flightMs), _showResult);
  }

  /// Effective batting quality for this ball.
  double _ballQuality() {
    double q;
    if (battingSide.isBot) {
      q = _aiQuality;
    } else if (_humanQuality >= 0) {
      q = _humanQuality;
    } else {
      q = 0; // no shot offered
    }
    // Bowling difficulty shaves quality (only matters vs the human batter;
    // AI-vs-AI uses the same physics for fairness).
    final shave = switch (botDifficulty) {
      BotDifficulty.easy => 0.10,
      BotDifficulty.medium => 0.22,
      BotDifficulty.hard => 0.36,
    };
    return (q - shave * _rand.nextDouble() * 0.5).clamp(0.0, 1.0);
  }

  /// (outcome, wicketKind) from effective quality q (RULES.md §8).
  (String, String) _sampleOutcome(double q) {
    final r = _rand.nextDouble();
    if (q >= 0.93) {
      if (r < 0.45) return ('6', '');
      if (r < 0.80) return ('4', '');
      return ('2', '');
    }
    if (q >= 0.78) {
      if (r < 0.33) return ('4', '');
      if (r < 0.52) return ('2', '');
      if (r < 0.72) return ('1', '');
      if (r < 0.82) return ('3', '');
      if (r < 0.90) return ('6', '');
      return ('0', '');
    }
    if (q >= 0.58) {
      if (r < 0.30) return ('1', '');
      if (r < 0.55) return ('2', '');
      if (r < 0.68) return ('0', '');
      if (r < 0.78) return ('4', '');
      if (r < 0.86) return ('3', '');
      return ('1', '');
    }
    if (q >= 0.38) {
      if (r < 0.34) return ('0', '');
      if (r < 0.60) return ('1', '');
      if (r < 0.72) return ('W', _wicketKind());
      if (r < 0.85) return ('2', '');
      return ('0', '');
    }
    if (r < 0.30) return ('W', _wicketKind());
    if (r < 0.55) return ('0', '');
    if (r < 0.70) return ('W', _wicketKind());
    if (r < 0.85) return ('1', '');
    return ('0', '');
  }

  String _wicketKind() {
    final r = _rand.nextDouble();
    if (r < 0.45) return 'bowled';
    if (r < 0.75) return 'caught';
    if (r < 0.90) return 'lbw';
    return 'run out';
  }

  void _showResult() {
    if (over || phase != Phase.ballFlight) return;
    phase = Phase.result;
    balls++;
    final wicket = lastOutcome == 'W';
    final runs = wicket ? 0 : int.parse(lastOutcome);
    if (wicket) {
      wickets++;
      overDots.add('W');
    } else {
      scores[batter] += runs;
      overDots.add(lastOutcome);
      if (lastOutcome == '6') sixesHit++;
    }
    if (overDots.length > 6) overDots.removeAt(0);
    resultPop = _popFor();
    if (!wicket && lastOutcome != '6' && lastOutcome != '4') {
      commentary = _runsLine(runs);
    }
    if (wicket) {
      onEvent?.call(lastWicketKind == 'bowled'
          ? CricketEvent.bowled
          : CricketEvent.wicket);
    } else if (lastOutcome == '6') {
      onEvent?.call(CricketEvent.six);
    } else if (lastOutcome == '4') {
      onEvent?.call(CricketEvent.four);
    } else {
      onEvent?.call(CricketEvent.runs);
    }
    notifyListeners();
    _arm(const Duration(milliseconds: resultMs), _nextBall);
  }

  void _nextBall() {
    if (over) return;
    // Chase complete?
    if (chasing && scores[1] >= target) return _finish();
    // Innings complete?
    if (balls >= ballsPerInnings || wickets >= maxWickets) {
      if (innings == 0) {
        phase = Phase.inningsBreak;
        target = scores[0] + 1;
        commentary =
            'Innings break! ${players[1].name} need $target to win.';
        resultPop = '';
        onEvent?.call(CricketEvent.inningsBreak);
        notifyListeners();
        _arm(const Duration(milliseconds: inningsBreakMs), _startSecondInnings);
        return;
      }
      return _finish();
    }
    phase = Phase.preBall;
    resultPop = '';
    flight = null;
    commentary = battingHuman
        ? 'Tap BOWL for the next ball!'
        : '${battingSide.name} takes guard…';
    notifyListeners();
    _afterPhase();
  }

  void _startSecondInnings() {
    if (over) return;
    innings = 1;
    balls = 0;
    wickets = 0;
    overDots = [];
    phase = Phase.preBall;
    resultPop = '';
    flight = null;
    commentary =
        '${players[1].name} need $target. ${battingHuman ? 'Tap BOWL!' : '${battingSide.name} walks out…'}';
    notifyListeners();
    _afterPhase();
  }

  void _finish() {
    if (over) return;
    over = true;
    phase = Phase.over;
    flight = null;
    final a = scores[0];
    final b = scores[1];
    if (a == b) {
      tie = true;
      winner = null;
      commentary = 'Scores level — it\'s a TIE! What a thriller!';
      resultPop = 'TIE!';
      onEvent?.call(CricketEvent.tie);
    } else {
      winner = a > b ? 0 : 1;
      final w = players[winner!];
      final margin = chasing && winner == 1
          ? '${maxWickets - wickets} wicket${maxWickets - wickets == 1 ? '' : 's'}'
          : '${(a - b).abs()} run${(a - b).abs() == 1 ? '' : 's'}';
      commentary = '${w.name} win by $margin!';
      resultPop = '${w.name} WIN!';
      onEvent?.call(w.isBot ? CricketEvent.botWon : CricketEvent.humanWon);
    }
    notifyListeners();
  }

  void restart() {
    _timer?.cancel();
    paused = false;
    _pausedAt = null;
    innings = 0;
    balls = 0;
    wickets = 0;
    scores[0] = 0;
    scores[1] = 0;
    target = 0;
    overDots = [];
    commentary = '${players[0].name} to bat. Tap BOWL to start!';
    resultPop = '';
    lastOutcome = '';
    lastWicketKind = '';
    sixesHit = 0;
    phase = Phase.preBall;
    over = false;
    winner = null;
    tie = false;
    deliveryStartedAt = null;
    _humanQuality = -1;
    flight = null;
    notifyListeners();
    _afterPhase();
  }

  // ------------------------------------------------------------- commentary
  String _pick(List<String> t) => t[_rand.nextInt(t.length)];

  String _boundaryLine(bool six) {
    final n = battingSide.name;
    if (six) {
      return _pick([
        '$n launches it into the stands! SIX!',
        'HUGE! That\'s out of the ground! Six runs!',
        'Maximum! $n goes all the way!',
      ]);
    }
    return _pick([
      'Cracked through the covers! FOUR!',
      'Timed beautifully — races to the rope! Four!',
      '$n finds the gap! Four runs!',
    ]);
  }

  String _wicketLine() {
    final n = battingSide.name;
    return switch (lastWicketKind) {
      'bowled' => _pick([
          '$n is BOWLED! The stumps go flying!',
          'GONE! $n misses a straight one — timber!',
        ]),
      'caught' => _pick([
          'CAUGHT! $n skies it and the fielder takes it!',
          'In the air… and taken! $n has to go!',
        ]),
      'lbw' => _pick([
          'Huge appeal… GIVEN! $n is out LBW!',
          'Trapped in front! $n goes LBW!',
        ]),
      _ => _pick([
          'Direct hit! $n is RUN OUT!',
          'Terrible mix-up — $n is run out!',
        ]),
    };
  }

  String _runsLine(int runs) {
    final n = battingSide.name;
    return switch (runs) {
      0 => _pick(['Beaten! Dot ball.', 'Good ball, no run.', 'No shot offered — dot.']),
      3 => '$n picks up 3 runs.',
      2 => '$n picks up 2 runs.',
      _ => '$n picks up a single.',
    };
  }

  String _popFor() {
    if (lastOutcome == 'W') {
      return switch (lastWicketKind) {
        'bowled' => 'BOWLED!',
        'caught' => 'CAUGHT!',
        'lbw' => 'LBW!',
        _ => 'RUN OUT!',
      };
    }
    return switch (lastOutcome) {
      '6' => 'SIX!',
      '4' => 'FOUR!',
      '3' => '+3',
      '2' => '+2',
      '1' => '+1',
      _ => 'DOT',
    };
  }

  /// UI hook for sounds / haptics. Set by the screen.
  void Function(CricketEvent event)? onEvent;
}

enum CricketEvent {
  deliveryStart,
  swing,
  ballHit,
  runs,
  four,
  six,
  wicket,
  bowled,
  inningsBreak,
  humanWon,
  botWon,
  tie,
  invalid,
}
