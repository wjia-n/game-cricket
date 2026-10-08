import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Slog-overs cricket: 5 overs a side, timing-based batting.
class CricketScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const CricketScreen({super.key, required this.players, required this.callbacks});

  @override
  State<CricketScreen> createState() => _CricketScreenState();
}

class _CricketScreenState extends State<CricketScreen> {
  static const ballsPerInnings = 30;
  static const maxWkts = 5;

  final _rand = Random();
  int innings = 0; // 0 or 1
  int balls = 0;
  int wkts = 0;
  int target = 0;
  List<String> overDots = [];
  String phase = 'ready'; // ready | swing | result
  String commentary = 'Tap BOWL to start the over!';
  String resultPop = '';
  bool over = false;

  // timing needle
  Ticker? _ticker;
  double _needle = 0.0;
  double _dir = 1.0;
  double _lastT = 0;

  bool get battingHuman => !widget.players[innings].isBot;
  String get oversStr => '${balls ~/ 6}.${balls % 6}';

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  // ---------- timing meter ----------
  void _startSwing() {
    _needle = 0.0;
    _dir = 1.0;
    _lastT = 0;
    _ticker?.dispose();
    _ticker = Ticker((d) {
      final t = d.inMicroseconds / 1e6;
      final dt = _lastT == 0 ? 0.016 : min(0.05, t - _lastT);
      _lastT = t;
      if (!mounted || phase != 'swing') return;
      setState(() {
        _needle += _dir * dt * 1.6;
        if (_needle >= 1) {
          _needle = 1;
          _dir = -1;
        } else if (_needle <= 0) {
          _needle = 0;
          _dir = 1;
        }
      });
    })
      ..start();
    setState(() => phase = 'swing');
  }

  String _pick(List<String> t) => t[_rand.nextInt(t.length)];

  void _humanBowl() {
    Sfx.click();
    setState(() {
      commentary = 'Ball incoming… SLOG when the needle hits green!';
      resultPop = '';
    });
    _startSwing();
  }

  void _slog() {
    if (phase != 'swing') return;
    _ticker?.stop();
    final d = (_needle - 0.5).abs();
    String outcome;
    if (d < 0.07) {
      outcome = _pick(['6', '6', '4', '4', '4', '2', '1']);
      Sfx.move();
    } else if (d < 0.18) {
      outcome = _pick(['4', '2', '2', '1', '1', '3', '0']);
      Sfx.tap();
    } else if (d < 0.32) {
      outcome = _pick(['1', '0', '0', '2', 'W', 'W']);
      Sfx.tap();
    } else {
      outcome = _pick(['0', '0', 'W', 'W']);
      Sfx.lose();
    }
    _applyBall(outcome);
  }

  Future<void> _botBowl() async {
    setState(() {
      phase = 'result';
      commentary = '${widget.players[innings].name} faces…';
    });
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted || over) return;
    final outcome = _pick(['0', '0', '1', '1', '1', '2', '2', '4', '6', 'W', '1', '2', '0', '4']);
    Sfx.tap();
    _applyBall(outcome);
  }

  // ---------- ball resolution ----------
  void _applyBall(String outcome) {
    final wicket = outcome == 'W';
    final runs = wicket ? 0 : int.parse(outcome);
    final p = widget.players[innings];
    setState(() {
      phase = 'result';
      balls++;
      if (wicket) {
        wkts++;
        overDots.add('W');
      } else {
        p.score += runs;
        overDots.add(outcome);
      }
      if (overDots.length > 6) overDots.removeAt(0);
      resultPop = _popFor(outcome, wicket);
      commentary = _commentaryFor(outcome, wicket, p.name);
    });
    widget.callbacks.refreshHud();
    Future.delayed(const Duration(milliseconds: 1400), _nextBall);
  }

  String _popFor(String o, bool w) {
    if (w) return 'BOWLED! 🎯';
    return switch (o) {
      '6' => 'SIX! 🚀',
      '4' => 'FOUR! 💥',
      '3' => '+3 runs 🏃',
      '2' => '+2 runs',
      '1' => '1 run',
      _ => 'Dot ball.',
    };
  }

  String _commentaryFor(String o, bool w, String name) {
    if (w) {
      return _pick([
        '$name is BOWLED! The stumps go flying! 🎯',
        'CAUGHT! $name skies it and the fielder takes it! 🧤',
        'GONE! $name misses a straight one! 💥',
      ]);
    }
    return switch (o) {
      '6' => _pick(['$name launches it into the stands! SIX! 🚀', 'HUGE! That\'s out of the ground! 6️⃣']),
      '4' => _pick(['Cracked through the covers! FOUR! 💥', 'Timed beautifully — races to the rope! 4️⃣']),
      '0' => _pick(['Beaten! Dot ball. 😅', 'Good ball, no run.']),
      _ => '$name picks up $o run${o == '1' ? '' : 's'}.',
    };
  }

  void _nextBall() {
    if (!mounted || over) return;
    final p = widget.players[innings];
    final chasing = innings == 1;
    // chase complete?
    if (chasing && p.score >= target) return _endMatch();
    // innings complete?
    if (balls >= ballsPerInnings || wkts >= maxWkts) {
      if (innings == 0) {
        _startSecondInnings();
      } else {
        _endMatch();
      }
      return;
    }
    setState(() {
      phase = 'ready';
      resultPop = '';
      commentary = battingHuman ? 'Tap BOWL for the next ball!' : '${p.name} is ready…';
    });
    if (!battingHuman) _botBowl();
  }

  void _startSecondInnings() {
    target = widget.players[0].score + 1;
    setState(() {
      innings = 1;
      balls = 0;
      wkts = 0;
      overDots = [];
      phase = 'ready';
      resultPop = '';
      commentary = 'Innings break! ${widget.players[1].name} needs $target to win. 🎯';
    });
    widget.callbacks.setActivePlayer(1);
    widget.callbacks.refreshHud();
    if (!battingHuman) _botBowl();
  }

  void _endMatch() {
    if (over) return;
    over = true;
    _ticker?.stop();
    final a = widget.players[0];
    final b = widget.players[1];
    if (a.score == b.score) {
      Sfx.win();
      widget.callbacks.finish(headline: 'It\'s a TIE! ${a.score} all! 🤝', subline: 'What a thriller!');
      return;
    }
    final winner = a.score > b.score ? a : b;
    final loser = winner == a ? b : a;
    if (winner.isBot) {
      Sfx.lose();
    } else {
      Sfx.win();
    }
    widget.callbacks.finish(
      winner: winner,
      headline: '${winner.name} wins by ${winner.score - loser.score} runs! 🏆',
      subline: '${a.name} ${a.score}  •  ${b.name} ${b.score}',
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.of(context).theme;
    final batter = widget.players[innings];
    final other = widget.players[1 - innings];
    return Column(
      children: [
        ScoreChips(players: widget.players, activeIndex: innings),
        const SizedBox(height: 8),
        _scoreboard(theme, batter, other),
        const SizedBox(height: 8),
        Expanded(child: _field(theme)),
        const SizedBox(height: 8),
        if (battingHuman && phase == 'ready')
          WajihaButton(label: 'Bowl ball', emoji: '🎾', primary: true, onTap: _humanBowl),
        if (battingHuman && phase == 'swing') ...[
          _meter(theme),
          const SizedBox(height: 8),
          WajihaButton(label: 'SLOG IT!', emoji: '🏏', primary: true, onTap: _slog),
        ],
        if (!battingHuman || phase == 'result') _statusLine(theme),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _scoreboard(GameTheme t, Player batter, Player other) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: t.surface, borderRadius: t.radius),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _scoreCell(t, batter, true),
          Text(innings == 0 ? '1st inns' : 'need $target', style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
          _scoreCell(t, other, false),
        ],
      ),
    );
  }

  Widget _scoreCell(GameTheme t, Player p, bool batting) => Column(
        children: [
          Text('${p.emoji} ${p.name}', style: TextStyle(color: t.text, fontWeight: FontWeight.w800, fontSize: 13)),
          Text(batting ? '${p.score}/$wkts  ($oversStr ov)' : '${p.score}${innings == 1 ? '/–' : ''}',
              style: TextStyle(color: t.primary, fontWeight: FontWeight.w900, fontSize: 18)),
        ],
      );

  Widget _field(GameTheme t) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: t.radius,
        gradient: LinearGradient(colors: [const Color(0xFF2E7D32), const Color(0xFF1B5E20)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 70,
              height: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFD7CCC8), borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const Positioned(top: 16, left: 0, right: 0, child: Center(child: Text('🎳', style: TextStyle(fontSize: 34)))),
          const Positioned(bottom: 16, left: 0, right: 0, child: Center(child: Text('🏏', style: TextStyle(fontSize: 40)))),
          if (resultPop.isNotEmpty)
            Center(
              child: TweenAnimationBuilder<double>(
                key: ValueKey(resultPop),
                tween: Tween(begin: 0.5, end: 1.0),
                duration: const Duration(milliseconds: 350),
                curve: Curves.elasticOut,
                builder: (_, v, _) => Transform.scale(
                  scale: v,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16)),
                    child: Text(resultPop, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: overDots
                  .map((d) => Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: d == 'W'
                              ? Colors.redAccent
                              : d == '6'
                                  ? Colors.amber
                                  : Colors.white70,
                        ),
                        child: Text(d, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black87)),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _meter(GameTheme t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text('Tap SLOG in the green!', style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Container(
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              gradient: const LinearGradient(colors: [Colors.redAccent, Colors.amber, Colors.greenAccent, Colors.amber, Colors.redAccent]),
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment(-1 + _needle * 2, 0),
                  child: Container(width: 8, height: 44, color: Colors.white, margin: const EdgeInsets.only(top: -5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusLine(GameTheme t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(commentary, style: TextStyle(color: t.text, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
    );
  }
}
