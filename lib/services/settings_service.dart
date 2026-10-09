import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/stadium_themes.dart';

/// Persisted settings + stats for Cricket. Survives app restarts.
///
/// Stores: audio toggles, team names (2 slots), match setup (mode, overs,
/// difficulty), appearance (stadium, kits, ball, custom kit), Pro unlock
/// state, and lifetime stats.
class CricketSettings extends ChangeNotifier {
  static const _kMusic = 'cricket_music_on';
  static const _kSfx = 'cricket_sfx_on';
  static const _kVolume = 'cricket_volume';
  static const _kMode = 'cricket_mode'; // 0 = vs AI, 1 = 2-player
  static const _kOvers = 'cricket_overs'; // 2, 5 or 10
  static const _kDifficulty = 'cricket_bot_difficulty'; // 0 easy, 1 medium, 2 hard
  static const _kNames = 'cricket_player_names'; // legacy unordered StringSet key
  /// Order-safe team-name storage: a single JSON string. Android's
  /// SharedPreferences stores StringLists as an unordered StringSet, so a
  /// StringList key scrambles name order on every app restart. Never use a
  /// StringList for ordered data on Android.
  static const _kNamesJson = 'cricket_player_names_json';
  static const _kStadium = 'cricket_stadium_id';
  static const _kKits = 'cricket_kit_indices'; // JSON [a, b]
  static const _kBall = 'cricket_ball_style';
  static const _kWins = 'cricket_wins';
  static const _kGames = 'cricket_games_played';
  static const _kBest = 'cricket_best_score';
  static const _kSixes = 'cricket_sixes';
  static const _kIsPro = 'cricket_is_pro';
  static const _kCustomPrefix = 'cricket_custom_';

  static const defaultNames = ['Home XI', 'Away XI'];

  /// Encode the 2 team names as one JSON string (order-preserving).
  static String encodePlayerNames(List<String> names) => jsonEncode(names);

  static String _cleanName(int i, Object? v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? defaultNames[i] : s;
  }

  /// Decode persisted names; falls back to defaults on missing/corrupt data.
  static List<String> decodePlayerNames(String? raw) {
    if (raw == null) return List.of(defaultNames);
    try {
      final d = jsonDecode(raw);
      if (d is List && d.length == 2) {
        return [for (int i = 0; i < 2; i++) _cleanName(i, d[i])];
      }
    } catch (_) {}
    return List.of(defaultNames);
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  int mode = 0; // 0 = vs AI (seat 1 is bot), 1 = 2-player pass-and-play
  int overs = 5;
  int difficulty = 1; // medium default
  List<String> playerNames = List.of(defaultNames);
  String stadiumId = 'village';
  List<int> kitIndices = [0, 2]; // per-seat kit style
  int ballStyle = 0;
  int wins = 0;
  int gamesPlayed = 0;
  int bestScore = 0;
  int sixes = 0;
  bool isPro = false;

  /// Custom kit colors (ARGB ints): primary, secondary, ball, seam.
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'kitPrimary': 0xFF2E6B34,
    'kitSecondary': 0xFFF5F0E2,
    'ball': 0xFFA31621,
    'seam': 0xFFF5F0E2,
    'skyTop': 0xFF7FB8E6,
    'skyBottom': 0xFFD8ECFA,
    'grassLight': 0xFF5DA24A,
    'grassDark': 0xFF3E7A31,
    'pitch': 0xFFD9BE8C,
    'boundary': 0xFFF5F0E0,
    'accent': 0xFFB98A2F,
    'accentLight': 0xFFE9C878,
    'ink': 0xFF1E2A1A,
    'cream': 0xFFF8F4E6,
  };

  /// Builds the user-designed custom stadium from stored colors.
  StadiumThemeDef get customStadium {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return StadiumThemeDef(
      id: 'custom',
      name: 'My Ground',
      skyTop: c('skyTop'),
      skyBottom: c('skyBottom'),
      grassLight: c('grassLight'),
      grassDark: c('grassDark'),
      pitch: c('pitch'),
      boundary: c('boundary'),
      accent: c('accent'),
      accentLight: c('accentLight'),
      ink: c('ink'),
      cream: c('cream'),
    );
  }

  /// The user's custom kit (primary/secondary) as a KitDef.
  KitDef get customKit => KitDef(
        'My Kit',
        Color(customColors['kitPrimary'] ?? 0xFF2E6B34),
        Color(customColors['kitSecondary'] ?? 0xFFF5F0E2),
      );

  /// The user's custom ball as a BallDef.
  BallDef get customBall => BallDef(
        'My Ball',
        Color(customColors['ball'] ?? 0xFFA31621),
        Color(customColors['seam'] ?? 0xFFF5F0E2),
      );

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    mode = (p.getInt(_kMode) ?? 0).clamp(0, 1);
    overs = p.getInt(_kOvers) ?? 5;
    if (![2, 5, 10].contains(overs)) overs = 5;
    difficulty = (p.getInt(_kDifficulty) ?? 1).clamp(0, 2);
    // Team names: prefer the order-safe JSON key. Fall back to the legacy
    // StringList key once (one-time migration); it may already be scrambled
    // on Android, which is exactly the bug this replaces.
    final namesRaw = p.getString(_kNamesJson);
    if (namesRaw != null) {
      playerNames = decodePlayerNames(namesRaw);
    } else {
      final legacy = p.getStringList(_kNames);
      playerNames = (legacy != null && legacy.length == 2)
          ? [for (int i = 0; i < 2; i++) _cleanName(i, legacy[i])]
          : List.of(defaultNames);
    }
    stadiumId = p.getString(_kStadium) ?? 'village';
    kitIndices = _decodeKits(p.getString(_kKits));
    ballStyle = (p.getInt(_kBall) ?? 0).clamp(0, BallStyles.all.length - 1);
    wins = p.getInt(_kWins) ?? 0;
    gamesPlayed = p.getInt(_kGames) ?? 0;
    bestScore = p.getInt(_kBest) ?? 0;
    sixes = p.getInt(_kSixes) ?? 0;
    isPro = p.getBool(_kIsPro) ?? false;
    for (final k in _defaultCustomColors.keys) {
      customColors[k] = p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  static List<int> _decodeKits(String? raw) {
    if (raw == null) return [0, 2];
    try {
      final d = jsonDecode(raw);
      if (d is List && d.length == 2) {
        return [
          (d[0] as num).toInt().clamp(0, KitStyles.all.length - 1),
          (d[1] as num).toInt().clamp(0, KitStyles.all.length - 1),
        ];
      }
    } catch (_) {}
    return [0, 2];
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setInt(_kMode, mode);
    await p.setInt(_kOvers, overs);
    await p.setInt(_kDifficulty, difficulty);
    await p.setString(_kNamesJson, encodePlayerNames(playerNames));
    await p.remove(_kNames); // drop the legacy unordered key for good
    await p.setString(_kStadium, stadiumId);
    await p.setString(_kKits, jsonEncode(kitIndices));
    await p.setInt(_kBall, ballStyle);
    await p.setInt(_kWins, wins);
    await p.setInt(_kGames, gamesPlayed);
    await p.setInt(_kBest, bestScore);
    await p.setInt(_kSixes, sixes);
    await p.setBool(_kIsPro, isPro);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (stadiumId == 'custom' || StadiumThemes.isProTheme(stadiumId)) {
      stadiumId = 'village';
      changed = true;
    }
    for (int i = 0; i < 2; i++) {
      if (KitStyles.isPro(kitIndices[i])) {
        kitIndices[i] = 0;
        changed = true;
      }
    }
    if (BallStyles.isPro(ballStyle)) {
      ballStyle = 0;
      changed = true;
    }
    if (difficulty > 1) {
      difficulty = 1;
      changed = true;
    }
    if (overs == 10) {
      overs = 5;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return; // custom creator is a Pro feature
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setMode(int v) async {
    mode = v.clamp(0, 1);
    notifyListeners();
    await _save();
  }

  Future<void> setOvers(int v) async {
    if (![2, 5, 10].contains(v)) return;
    if (v == 10 && !isPro) return; // 10-over matches are Pro
    overs = v;
    notifyListeners();
    await _save();
  }

  Future<void> setDifficulty(int v) async {
    v = v.clamp(0, 2);
    if (v == 2 && !isPro) return; // Hard AI is Pro
    difficulty = v;
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerName(int index, String name) async {
    if (index < 0 || index > 1) return;
    final clean = name.trim();
    playerNames[index] = clean.isEmpty ? defaultNames[index] : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setStadium(String id) async {
    if (!isPro && (id == 'custom' || StadiumThemes.isProTheme(id))) return;
    stadiumId = id;
    notifyListeners();
    await _save();
  }

  /// [seat] 0/1, [kit] index into KitStyles.all or -1 for the custom kit.
  Future<void> setKit(int seat, int kit) async {
    if (seat < 0 || seat > 1) return;
    if (kit != -1) kit = kit.clamp(0, KitStyles.all.length - 1);
    if (!isPro && (kit == -1 || KitStyles.isPro(kit))) return;
    kitIndices[seat] = kit;
    notifyListeners();
    await _save();
  }

  /// [ball] index into BallStyles.all or -1 for the custom ball.
  Future<void> setBall(int ball) async {
    if (ball != -1) ball = ball.clamp(0, BallStyles.all.length - 1);
    if (!isPro && (ball == -1 || BallStyles.isPro(ball))) return;
    ballStyle = ball;
    notifyListeners();
    await _save();
  }

  KitDef kitFor(int seat) {
    final i = kitIndices[seat];
    if (i == -1) return customKit;
    return KitStyles.all[i.clamp(0, KitStyles.all.length - 1)];
  }

  BallDef get ballDef =>
      ballStyle == -1 ? customBall : BallStyles.all[ballStyle];

  Future<void> resetStats() async {
    wins = 0;
    gamesPlayed = 0;
    bestScore = 0;
    sixes = 0;
    notifyListeners();
    await _save();
  }

  /// Record a finished match.
  Future<void> recordGame(
      {required bool humanWon, required int humanBest, required int sixesHit}) async {
    gamesPlayed++;
    if (humanWon) wins++;
    if (humanBest > bestScore) bestScore = humanBest;
    sixes += sixesHit;
    notifyListeners();
    await _save();
  }
}
