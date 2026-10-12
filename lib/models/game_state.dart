import 'dart:convert';
import '../ai/computer_turn.dart';
import '../ai/difficulty.dart';
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

  /// Words already captured this match via "Capture Word" (uppercase,
  /// in the order they were saved). Shared across both players — once a
  /// word is captured, neither player can capture it again this match.
  List<String> usedWords;

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

  /// True for a "Play Against Computer" match. Player 1 is always the
  /// human and Player 2 the computer. False (the default) leaves the
  /// original two-human behaviour completely untouched.
  bool vsComputer;

  /// [AiDifficulty.name] of the computer opponent; only meaningful when
  /// [vsComputer] is true.
  String difficulty;

  /// True when the computer plays the opening move of a computer match
  /// (and of every restart of it). Only meaningful when [vsComputer].
  bool computerStarts;

  /// The computer's most recent move, kept only so the board can
  /// highlight it until the human completes their next turn: the cell it
  /// filled, the word it claimed (null for a 0-point placement) and that
  /// word's cells as a flat [row, col, row, col, ...] list.
  int? aiMoveRow;
  int? aiMoveCol;
  String? aiWord;
  List<int> aiWordCells;

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
    this.vsComputer = false,
    this.difficulty = 'medium',
    this.computerStarts = false,
    this.aiMoveRow,
    this.aiMoveCol,
    this.aiWord,
    List<int>? aiWordCells,
    List<List<String>>? grid,
    List<List<bool>>? locked,
    DateTime? lastSaved,
    List<String>? usedWords,
  })  : grid = grid ?? List.generate(rows, (_) => List.generate(cols, (_) => '')),
        locked = locked ?? List.generate(rows, (_) => List.generate(cols, (_) => false)),
        lastSaved = lastSaved ?? DateTime.now(),
        usedWords = usedWords ?? [],
        aiWordCells = aiWordCells ?? [];

  /// Max Word Length = max(Rows, Columns). Both dimensions are capped
  /// during setup (1 to 10), so this is always between 1 and 10.
  int get maxWordLength => rows > cols ? rows : cols;

  /// True once every cell on the board has a locked letter in it.
  bool get isBoardFull => locked.every((row) => row.every((cell) => cell));

  /// True once the board is full AND there's no outstanding score to
  /// record — i.e. the match is truly finished, not just mid-way through
  /// scoring the last letter placed.
  bool get isComplete => isBoardFull && !scoringArmed;

  /// Normalizes a captured word the same way every time (trim + uppercase)
  /// so "cat", "Cat", and " CAT " are all treated as the same word.
  static String normalizeWord(String word) => word.trim().toUpperCase();

  /// True if [word] (any casing/whitespace) has already been captured
  /// this match.
  bool isWordUsed(String word) => usedWords.contains(normalizeWord(word));

  /// Records [word] as captured this match. Does nothing if it's already
  /// present (callers should check [isWordUsed] first to warn the player).
  void addUsedWord(String word) {
    final normalized = normalizeWord(word);
    if (!usedWords.contains(normalized)) {
      usedWords.add(normalized);
    }
  }

  AiDifficulty get aiDifficulty => AiDifficulty.fromName(difficulty);

  /// True when the computer is due to move: a computer match, Player 2's
  /// turn, a vacant cell still exists, and no score is outstanding. It is
  /// false once the match is over, so the computer can never play after
  /// the game ends or out of turn.
  bool get isComputerTurn => vsComputer && currentTurn == 2 && !isBoardFull && !scoringArmed;

  /// Records the active player's score for this turn and hands the turn to
  /// the other player. This is the ONE place a turn's score is applied -
  /// the human's number-strip tap and the computer's move both go through
  /// it, so the two can never score differently.
  void applyTurnScore(int delta) {
    final scorer = currentTurn;
    if (scorer == 1) {
      score1 += delta;
      // The human has moved again: the computer's last move is no longer
      // "the latest" so its highlight goes away.
      clearAiHighlight();
    } else {
      score2 += delta;
    }
    pendingRow = null;
    pendingCol = null;
    currentTurn = scorer == 1 ? 2 : 1;
    scoringArmed = false;
    isAddMode = true;
  }

  void clearAiHighlight() {
    aiMoveRow = null;
    aiMoveCol = null;
    aiWord = null;
    aiWordCells = [];
  }

  /// Applies the computer's chosen move: one letter into one vacant cell,
  /// its claimed word (if any) added to the used-words list, its points
  /// added to Player 2 exactly once, and the turn passed back to the
  /// human. Returns false - changing nothing - if it isn't the computer's
  /// turn, the cell is off-board or already occupied, or the claimed word
  /// doesn't actually lie on the board through the new letter.
  bool applyComputerMove(ComputerMoveResult move) {
    if (!isComputerTurn) return false;
    final r = move.row;
    final c = move.col;
    if (r < 0 || r >= rows || c < 0 || c >= cols) return false;
    if (grid[r][c].isNotEmpty || locked[r][c]) return false;
    final word = move.word;
    if (word != null) {
      if (isWordUsed(word)) return false;
      if (!_claimMatchesBoard(move)) return false;
    }

    grid[r][c] = move.letter;
    locked[r][c] = true;
    if (word != null) addUsedWord(word);
    pendingRow = r;
    pendingCol = c;
    scoringArmed = true;
    isAddMode = true;
    applyTurnScore(word?.length ?? 0); // scores Player 2, passes turn to 1

    aiMoveRow = r;
    aiMoveCol = c;
    aiWord = word;
    aiWordCells = word == null ? [] : List<int>.from(move.wordCells);
    return true;
  }

  /// Sanity check that the claimed word is really spelled by contiguous
  /// board cells (after the new letter) in a straight line through (row,col).
  bool _claimMatchesBoard(ComputerMoveResult move) {
    final word = move.word!;
    final cells = move.wordCells;
    if (cells.length != word.length * 2) return false;
    var includesNew = false;
    int? stepR;
    int? stepC;
    for (var i = 0; i < word.length; i++) {
      final cr = cells[i * 2];
      final cc = cells[i * 2 + 1];
      if (cr < 0 || cr >= rows || cc < 0 || cc >= cols) return false;
      final letter = (cr == move.row && cc == move.col) ? move.letter : grid[cr][cc];
      if (letter != word[i]) return false;
      if (cr == move.row && cc == move.col) includesNew = true;
      if (i > 0) {
        final sr = cr - cells[(i - 1) * 2];
        final sc = cc - cells[(i - 1) * 2 + 1];
        if (sr.abs() > 1 || sc.abs() > 1 || (sr == 0 && sc == 0)) return false;
        if (stepR == null) {
          stepR = sr;
          stepC = sc;
        } else if (sr != stepR || sc != stepC) {
          return false; // not a single straight line
        }
      }
    }
    return includesNew;
  }

  /// Wipes the match back to an empty board: letters, scores, used words,
  /// any outstanding score, and the computer's highlight. In a computer
  /// match the opening turn goes back to whoever opens that match (the
  /// original two-human behaviour leaves whoever's turn it was untouched).
  void resetMatch() {
    grid = List.generate(rows, (_) => List.generate(cols, (_) => ''));
    locked = List.generate(rows, (_) => List.generate(cols, (_) => false));
    score1 = 0;
    score2 = 0;
    scoringArmed = false;
    pendingRow = null;
    pendingCol = null;
    isAddMode = true;
    usedWords.clear();
    clearAiHighlight();
    if (vsComputer) currentTurn = computerStarts ? 2 : 1;
  }

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

  /// A "Play Against Computer" match: the human is Player 1, the computer
  /// Player 2. The human moves first unless [computerStarts] is true.
  factory GameState.newComputerGame({
    required String humanName,
    required int rows,
    required int cols,
    required AiDifficulty difficulty,
    bool computerStarts = false,
  }) {
    const computerName = 'Computer';
    final resolved = ScoreboardNameResolver.resolve(player1: humanName, player2: computerName);
    return GameState(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      player1Name: humanName.trim(),
      player2Name: computerName,
      player1Initials: resolved.player1Label,
      player2Initials: '🤖 CPU',
      rows: rows,
      cols: cols,
      vsComputer: true,
      difficulty: difficulty.name,
      computerStarts: computerStarts,
      currentTurn: computerStarts ? 2 : 1,
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
      'usedWords': usedWords,
      'vsComputer': vsComputer,
      'difficulty': difficulty,
      'computerStarts': computerStarts,
      'aiMoveRow': aiMoveRow,
      'aiMoveCol': aiMoveCol,
      'aiWord': aiWord,
      'aiWordCells': aiWordCells,
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
      // Older saves (from before this feature existed) simply won't have
      // this key — default to an empty list so they still load fine.
      usedWords: (json['usedWords'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      // Saves from before the computer opponent existed lack these keys
      // and load as ordinary two-human matches.
      vsComputer: json['vsComputer'] as bool? ?? false,
      difficulty: json['difficulty'] as String? ?? 'medium',
      computerStarts: json['computerStarts'] as bool? ?? false,
      aiMoveRow: json['aiMoveRow'] as int?,
      aiMoveCol: json['aiMoveCol'] as int?,
      aiWord: json['aiWord'] as String?,
      aiWordCells: (json['aiWordCells'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
    );
  }

  String encode() => jsonEncode(toJson());

  static GameState decode(String source) =>
      GameState.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
