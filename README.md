# Cricket — Slog-Overs Arcade

A complete, original arcade cricket game by **WAJIHA** (`com.gameswajiha.cricket`).

Two sides, slog-overs cricket: tap **BOWL**, then **SLOG** when the timing
needle hits the green. Perfect timing = fours and sixes. Sloppy timing =
bowled, caught, LBW or run out. Chase the target in the second innings.

## Features

- **Engine-owned ball-by-ball state machine + watchdog** — stuck states
  impossible by construction (`lib/engine/cricket_engine.dart`).
- **Visible AI** — Easy/Medium/Hard AI batters visibly swing mid-delivery
  with ball-by-ball narration; AI bowlers shave timing quality and speed up
  the needle. Nothing is ever silently auto-played.
- **Modes** — vs AI (3 difficulties), 2-player pass-and-play, 2/5/10-over
  matches (10 overs = Pro).
- **Audio** — cached synthesized clips (no asset files), menu + gameplay
  music, bat crack, appeal whistle, stumps, crowd. Busy-guard serialization,
  pause/resume on lifecycle, pre-warmed on splash.
- **Renameable teams** — persisted as one order-preserving JSON string
  (`cricket_player_names_json`); saved on every keystroke, committed on
  focus loss.
- **Customization** — 12 stadium grounds + custom ground creator, 8 team
  kits + creator, 6 ball leathers + creator (Pro unlocks the rest).
- **Pro + tip jar** — real `in_app_purchase` (`cricketpro`, `cricketcoffee`,
  `cricketchocolate`), Free-vs-Pro comparison, graceful pre-launch state.
- **Share + review** — `share_plus` with the real Play URL, `in_app_review`.
- **Splash** — WAJIHA company moment → game splash (logo + animated loading
  line + Credits: WAJIHA).

## Rules

See [RULES.md](RULES.md) — the authoritative source of truth for gameplay.

## Build

CI (`.github/workflows/build.yml`, manual trigger) runs `flutter analyze`,
builds signed APK + AAB, and attaches them to tag releases.
