import 'dart:convert';
import '../services/scoreboard_name_resolver.dart';

/// Represents the full state of a single match: players, scores, grid
/// dimensions, letter grid contents, locked cells, whose turn it is, and
/// exactly where the turn-lock state machine currently sits. Everything
/// here is serializable so a kill/resume restores the match mid-turn.
class GameState {
  String id;
  String player1Name;
  String player2Name;
  String player1Initials;
  String player2Initials;
  int rows;
  int cols;
  int score1;
  int score2;
  List<List<String>> grid;
  List<List<bool>> locked;
  DateTime lastSaved;

  /// Which player's turn is currently active: 1 or 2. Can change either
  /// automatically (after a score is applied) or manually (the player
  /// taps the other player's card to claim the turn).
  int currentTurn;

  /// Whether the Numeric Strip is currently armed/enabled for the active
  /// player. Set to true either by tapping Add(+)/Minus(-) on the active
  /// player's card, or automatically the moment a letter is placed. While
  /// true, the Alphabet Bank is disabled (but stays visible) so a second
  /// letter can't be placed before this turn's score is recorded.
  bool scoringArmed;

  /// The cell that received a letter this turn and is awaiting a score
  /// decision, so "Clear Selected" knows to unwind back to letter-placing
  /// mode. Null when scoring was armed manually (via +/-) without a
  /// letter having been placed first.
  int? pendingRow;
  int? pendingCol;

  /// Whether the armed numeric-strip tap will add (true) or subtract
  /// (false) from the active player's score. Auto-reset to true (add)
  /// whenever a fresh turn begins.
  bool isAddMode;

  GameState({
    required this.id,
    required this.player1Name,
    required this.player2Name,
    required this.player1Initials,
    required this.player2Initials,
    required this.rows,
    required this.cols,
    this.score1 = 0,
    this.score2 = 0,
    this.currentTurn = 1,
    this.scoringArmed = false,
    this.pendingRow,
    this.pendingCol,
    this.isAddMode = true,
    List<List<String>>? grid,
    List<List<bool>>? locked,
    DateTime? lastSaved,
  })  : grid = grid ?? List.generate(rows, (_) => List.generate(cols, (_) => '')),
        locked = locked ?? List.generate(rows, (_) => List.generate(cols, (_) => false)),
        lastSaved = lastSaved ?? DateTime.now();

  /// Max Word Length = max(Rows, Columns). Both dimensions are capped
  /// during setup (1 to 10), so this is always between 1 and 10.
  int get maxWordLength => rows > cols ? rows : cols;

  /// True once every cell on the board has a locked letter in it.
  bool get isBoardFull => locked.every((row) => row.every((cell) => cell));

  /// True once the board is full AND there's no outstanding score to
  /// record — i.e. the match is truly finished, not just mid-way through
  /// scoring the last letter placed.
  bool get isComplete => isBoardFull && !scoringArmed;

  /// Extracts the first letter of every whitespace-separated word in
  /// [name] and uppercases them, e.g. "Rajat Rai" -> "RR". Kept for any
  /// external callers/tests; new game creation uses
  /// [ScoreboardNameResolver] instead, which additionally understands
  /// emoji/symbol-only names and disambiguates collisions.
  static String computeInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    return parts.map((p) => p[0].toUpperCase()).join();
  }

  factory GameState.newGame({
    required String player1Name,
    required String player2Name,
    required int rows,
    required int cols,
  }) {
    final resolved = ScoreboardNameResolver.resolve(player1: player1Name, player2: player2Name);
    return GameState(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      player1Name: player1Name.trim(),
      player2Name: player2Name.trim(),
      player1Initials: resolved.player1Label,
      player2Initials: resolved.player2Label,
      rows: rows,
      cols: cols,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'player1Name': player1Name,
      'player2Name': player2Name,
      'player1Initials': player1Initials,
      'player2Initials': player2Initials,
      'rows': rows,
      'cols': cols,
      'score1': score1,
      'score2': score2,
      'currentTurn': currentTurn,
      'scoringArmed': scoringArmed,
      'pendingRow': pendingRow,
      'pendingCol': pendingCol,
      'isAddMode': isAddMode,
      'grid': grid,
      'locked': locked,
      'lastSaved': lastSaved.toIso8601String(),
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      id: json['id'] as String,
      player1Name: json['player1Name'] as String,
      player2Name: json['player2Name'] as String,
      player1Initials: json['player1Initials'] as String,
      player2Initials: json['player2Initials'] as String,
      rows: json['rows'] as int,
      cols: json['cols'] as int,
      score1: json['score1'] as int,
      score2: json['score2'] as int,
      // Fallbacks keep older saved games (from before these fields
      // existed) loadable without crashing.
      currentTurn: json['currentTurn'] as int? ?? 1,
      // 'scoringArmed' is the current field; fall back to the older
      // 'phase' string (from saves made before this field existed) so
      // old saved games still load without crashing.
      scoringArmed: json['scoringArmed'] as bool? ?? ((json['phase'] as String?) == 'scoring'),
      pendingRow: json['pendingRow'] as int?,
      pendingCol: json['pendingCol'] as int?,
      isAddMode: json['isAddMode'] as bool? ?? true,
      grid: (json['grid'] as List<dynamic>)
          .map<List<String>>(
              (row) => (row as List<dynamic>).map((e) => e.toString()).toList())
          .toList(),
      locked: (json['locked'] as List<dynamic>)
          .map<List<bool>>(
              (row) => (row as List<dynamic>).map((e) => e as bool).toList())
          .toList(),
      lastSaved: DateTime.parse(json['lastSaved'] as String),
    );
  }

  String encode() => jsonEncode(toJson());

  static GameState decode(String source) =>
      GameState.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
