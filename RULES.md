# Cricket — Slog Overs: Official Rules

Arcade slog-overs cricket: two sides, one batter per side per innings, every
ball a timing duel. This document is the authoritative source of truth. If the
implementation conflicts with it, fix the implementation.

## 1. Objective

Outscore the opposition across two innings. Side A bats first and sets a
score; Side B chases (target = Side A's score + 1). The side with more runs
at the end wins. Equal scores = tie.

## 2. Setup

- Two seats (teams), each with a renameable team name and a kit style.
- Mode: **vs AI** (seat 2 is a bot) or **2-player pass-and-play** (both human).
- Match length: **2 overs** (12 balls, 3 wickets), **5 overs** (30 balls,
  5 wickets) or **10 overs** (60 balls, 10 wickets).
- AI difficulty: Easy / Medium / Hard.
- Seat 1 bats the first innings; seat 2 bats the second (the chase).

## 3. Turn order

- Play is ball-by-ball. The batting side faces one ball at a time.
- Before each ball (phase `preBall`): the human batter taps **BOWL** to start
  the delivery; an AI batter starts its own ball automatically after a short
  narrated pause (fully visible — never skipped silently).
- During the delivery (phase `delivery`, ~1.15s): the human batter may tap
  **SLOG** exactly once to swing. The swing moment is captured; there is no
  re-swing.
- Then the ball flight animates, the result is applied with commentary, and
  the next ball begins.

## 4. Legal moves

- Tap **BOWL** only while `phase == preBall` and you are the human batter.
- Tap **SLOG** only while `phase == delivery` and you are the human batter
  and have not swung yet this ball.
- Timing quality is 1.0 at the exact center of the green zone, falling to 0
  at the edges.

## 5. Illegal moves

- Tapping BOWL or SLOG in any other phase is ignored (with an "invalid"
  sound) — it can never corrupt state.
- Tapping SLOG twice in one ball: the second tap is ignored; the first
  swing stands.

## 6. Captures

Not applicable (no pieces). Dismissals are §8 wickets.

## 7. Special rules

- **No shot offered:** if the human batter never taps SLOG during the
  delivery, timing quality is 0 (a certain near-miss — likely dot or wicket).
- **AI visibility:** the AI batter visibly swings mid-delivery (its swing
  moment is animated) and every ball carries narration
  ("X runs in to Y…", "Y watches it…").
- **No extras:** there are no wides or no-balls in slog-overs mode; every
  delivery is a legal ball and counts toward the over.
- **One batter per innings (arcade rule):** each side fields a single batter
  for the whole innings. Losing all allotted wickets ends the innings
  ("all out") but the same batter simply walks back out — arcade style.

## 8. Scoring

Each ball resolves to exactly one outcome, sampled from the effective
timing quality `q` (0..1, after the bowler's difficulty shave):

| q range       | Likely outcomes                                  |
|---------------|--------------------------------------------------|
| ≥ 0.93        | 6 (45%), 4 (35%), 2 (20%)                        |
| 0.78 – 0.93   | 4, 2, 1, 3, occasional 6                        |
| 0.58 – 0.78   | 1, 2, dot, occasional 4                          |
| 0.38 – 0.58   | dot, 1, wicket (12%), 2                          |
| < 0.38        | wicket (30%), dot, wicket (15%), 1               |

- Runs 0/1/2/3/4/6 add to the batting side's score.
- **W** = wicket: the batting side loses one wicket. Kind is sampled:
  bowled 45%, caught 30%, lbw 15%, run out 10%.
- The current over's balls are shown as dots (`1 4 6 W …`).

## 9. Winning conditions

- After both innings: higher score wins.
- Second innings: the chase ends the moment the batting side reaches the
  target — they win immediately by "N wickets" (wickets remaining).
- First-innings side wins by runs (difference).

## 10. Draw conditions

- Equal scores after both innings = **tie**. There is no super over in
  slog-overs mode.

## 11. AI strategy

- **AI batting:** commits a swing quality at delivery start, sampled by
  difficulty — Easy 0.05–0.80, Medium 0.30–0.95, Hard 0.55–1.00. The swing
  animates visibly at a random point mid-delivery.
- **AI bowling:** applies a quality shave to the batter's timing —
  Easy 0.10, Medium 0.22, Hard 0.36 (scaled by a random 0–0.5 factor) —
  and speeds up the timing needle (Easy 0.9×, Medium 1.15×, Hard 1.4×).

## 12. Edge cases

- **Innings ends exactly on the last ball:** the innings-break (or match
  end) triggers normally; no extra ball.
- **Target reached mid-over:** the match ends immediately; remaining balls
  are not played.
- **All out on the final ball of the innings:** innings ends; no extra ball.
- **Pause / backgrounding:** the single phase timer freezes and all
  animation timestamps shift by the paused duration on resume — the ball
  continues exactly where it froze. A watchdog re-arms any phase found
  without a live timer.
- **Restart mid-match:** full state reset; the opening ball is re-granted.

## 13. Test cases

1. Human taps BOWL in `preBall` → phase becomes `delivery`, ball animates.
2. Human taps SLOG at needle center → quality ≈ 1.0 → boundary likely.
3. Human never taps SLOG → quality 0 → dot or wicket, never a crash.
4. AI batter's ball: narration shows, swing animates, outcome resolves.
5. Wicket on last allowed wicket → innings ends ("all out").
6. Chase: batting side reaches target mid-over → match ends immediately.
7. Equal scores → tie declared, no winner.
8. Pause during delivery → resume continues the same ball.
9. Restart → scores/balls/wickets reset, first ball re-granted.
10. Tapping BOWL/SLOG out of phase → ignored, state unchanged.
