import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const CricketApp());

class CricketApp extends StatelessWidget {
  const CricketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.elegantSerif,
      title: 'Cricket',
      tagline: 'Smash sixes and bowl yorkers in quick cricket clashes',
      emoji: '🏏',
      slug: 'cricket',
      howToPlay:
          '• Each side bats 5 overs (30 balls). Most runs wins.\n• Tap BOWL, then SLOG when the needle hits the green zone!\n• Perfect timing = fours and sixes. Sloppy timing = bowled!\n• The second innings is a chase — beat the target to win.',
      playerOptions: const [1, 2],
      supportsBots: true,
      gameBuilder: (ctx, players, cb) => CricketScreen(players: players, callbacks: cb),
    );
  }
}
