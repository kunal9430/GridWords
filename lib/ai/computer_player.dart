import 'dart:math';

import 'difficulty.dart';
import 'move_generator.dart';
import 'word_list.dart';

class _Timeout implements Exception {
  const _Timeout();
}

/// Chooses the computer's move. Pure and synchronous - run it off the UI
/// thread (see `computer_turn.dart`) for the deeper levels.
class ComputerPlayer {
  final WordList words;
  const ComputerPlayer(this.words);

  /// Picks one move for the computer, or null if the grid has no vacant
  /// cell (nothing can be played). Always returns a LEGAL move: a vacant
  /// cell and a letter; its [Move.claim] (if any) is a dictionary word, not
  /// already in [usedWords], laid on a contiguous straight line through
  /// the new letter.
  ///
  /// [grid] is never modified (a private copy is searched).
  Move? chooseMove({
    required List<List<String>> grid,
    required Iterable<String> usedWords,
    required AiDifficulty difficulty,
    int seed = 0,
    Duration? timeBudget,
  }) {
    final work = [for (final row in grid) List<String>.from(row)];
    if (MoveGenerator.vacantCount(work) == 0) return null;
    final used = <String>{for (final w in usedWords) w.trim().toUpperCase()};
    final rng = Random(seed);

    if (difficulty.plies == 0) {
      return _chooseEasy(work, used, rng);
    }
    final search = _Search(work, used, words, difficulty, timeBudget ?? difficulty.timeBudget, rng);
    return search.choose();
  }

  /// Easy: no lookahead. Weighted-random among scoring moves (weight =
  /// points), falling back to a zero-point placement when nothing scores.
  Move? _chooseEasy(List<List<String>> grid, Set<String> used, Random rng) {
    final moves = MoveGenerator.scoringMoves(grid, words, used);
    if (moves.isEmpty) {
      final fillers = MoveGenerator.fillerMoves(grid, words, used, 6);
      return fillers.isEmpty ? null : fillers[rng.nextInt(fillers.length)];
    }
    moves.sort(Move.compareForSearch); // stable order => reproducible per seed
    final total = moves.fold<int>(0, (sum, m) => sum + m.score);
    var pick = rng.nextInt(total);
    for (final m in moves) {
      pick -= m.score;
      if (pick < 0) return m;
    }
    return moves.last;
  }
}

/// Selective alpha-beta search over score differential.
///
/// Value of a position for the player to move:
///   f = max over moves ( points(move) - f(position after move) )
/// i.e. negamax on "my points minus their points". Leaves (depth 0) are
/// valued 0, so the result is the best achievable points margin within the
/// horizon, which naturally accounts for both leaving the opponent easy
/// replies (so it avoids them) and occupying cells they wanted (blocking).
class _Search {
  static const int _inf = 1 << 20;

  final List<List<String>> grid;
  final Set<String> used;
  final WordList words;
  final AiDifficulty difficulty;
  final Duration limit;
  final Random rng;
  final Stopwatch clock = Stopwatch();
  bool _enforceDeadline = false;

  _Search(this.grid, this.used, this.words, this.difficulty, this.limit, this.rng);

  Move? choose() {
    final rootMoves = _candidates(0);
    if (rootMoves.isEmpty) return null;
    clock.start();

    List<Move> best = rootMoves.where((m) => m.score == rootMoves.first.score).toList();
    for (var depth = 1; depth <= difficulty.plies; depth++) {
      // Depth 1 always completes; deeper passes may be abandoned on time.
      _enforceDeadline = depth > 1;
      try {
        final ties = _searchRoot(rootMoves, depth, best);
        best = ties;
      } on _Timeout {
        break;
      }
    }
    return best[rng.nextInt(best.length)];
  }

  /// Returns every root move tied for the best value at [depth].
  List<Move> _searchRoot(List<Move> rootMoves, int depth, List<Move> previousBest) {
    // Search last iteration's winners first: better cut-offs.
    final ordered = <Move>[...previousBest, ...rootMoves.where((m) => !previousBest.contains(m))];
    var bestValue = -_inf;
    var ties = <Move>[];
    for (final m in ordered) {
      final added = _apply(m);
      int childValue;
      try {
        // Parent window is (bestValue - 1, +inf) so moves that merely TIE
        // the best are still searched exactly and can be reported as ties.
        childValue = _value(depth - 1, 1, -_inf, m.score - (bestValue - 1));
      } finally {
        _undo(m, added);
      }
      final v = m.score - childValue;
      if (v > bestValue) {
        bestValue = v;
        ties = [m];
      } else if (v == bestValue) {
        ties.add(m);
      }
    }
    return ties;
  }

  int _value(int depth, int ply, int alpha, int beta) {
    if (depth == 0) return 0;
    if (_enforceDeadline && clock.elapsed > limit) throw const _Timeout();
    final moves = _candidates(ply);
    if (moves.isEmpty) return 0; // board full: nothing more to gain
    var best = -_inf;
    for (final m in moves) {
      final added = _apply(m);
      int childValue;
      try {
        childValue = _value(depth - 1, ply + 1, m.score - beta, m.score - alpha);
      } finally {
        _undo(m, added);
      }
      final v = m.score - childValue;
      if (v > best) best = v;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break;
    }
    return best;
  }

  /// Candidates at [ply]: the best-scoring moves up to the beam width,
  /// plus a few zero-point placements (the only option when nothing
  /// scores, and sometimes the smartest one).
  List<Move> _candidates(int ply) {
    if (MoveGenerator.vacantCount(grid) == 0) return const [];
    final beam = difficulty.beamAt(ply);
    // Shuffle first so equal-scoring moves are truncated by the beam in a
    // seeded-random (not positional) order - otherwise an opening board,
    // where every cell scores the same, would always favour the top-left.
    final scoring = MoveGenerator.scoringMoves(grid, words, used)
      ..shuffle(rng)
      ..sort(Move.compareByScore);
    final out = scoring.length > beam ? scoring.sublist(0, beam) : scoring;
    final fillerSlots = scoring.isEmpty ? 4 : (ply == 0 ? 3 : 1);
    out.addAll(MoveGenerator.fillerMoves(grid, words, used, fillerSlots));
    return out;
  }

  bool _apply(Move m) {
    grid[m.row][m.col] = m.letter;
    final word = m.claim?.word;
    return word != null && used.add(word);
  }

  void _undo(Move m, bool addedWord) {
    grid[m.row][m.col] = '';
    if (addedWord) used.remove(m.claim!.word);
  }
}
