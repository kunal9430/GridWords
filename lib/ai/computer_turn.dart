import 'dart:isolate';

import 'computer_player.dart';
import 'difficulty.dart';
import 'word_list.dart';

/// Plain-data request for one computer turn. Only strings/ints/lists so it
/// can be sent to a background isolate (`Isolate.run`).
class ComputerMoveRequest {
  final String wordsText;
  final List<List<String>> grid;
  final List<String> usedWords;
  final String difficultyName;
  final int seed;

  const ComputerMoveRequest({
    required this.wordsText,
    required this.grid,
    required this.usedWords,
    required this.difficultyName,
    required this.seed,
  });
}

/// Plain-data answer. [word] is null for a zero-point placement;
/// [wordCells] is a flat [row, col, row, col, ...] list in reading order.
class ComputerMoveResult {
  final int row;
  final int col;
  final String letter;
  final String? word;
  final List<int> wordCells;

  const ComputerMoveResult({
    required this.row,
    required this.col,
    required this.letter,
    required this.word,
    required this.wordCells,
  });

  int get score => word?.length ?? 0;
}

/// Top-level so `Isolate.run(() => computeComputerMove(req))` works.
/// Returns null when the grid is full.
ComputerMoveResult? computeComputerMove(ComputerMoveRequest req) {
  final words = WordList.fromText(req.wordsText);
  final move = ComputerPlayer(words).chooseMove(
    grid: req.grid,
    usedWords: req.usedWords,
    difficulty: AiDifficulty.fromName(req.difficultyName),
    seed: req.seed,
  );
  if (move == null) return null;
  final claim = move.claim;
  return ComputerMoveResult(
    row: move.row,
    col: move.col,
    letter: move.letter,
    word: claim?.word,
    wordCells: claim == null ? const [] : [for (final c in claim.cells) ...[c.row, c.col]],
  );
}

/// Runs [computeComputerMove] on a background isolate so the search never
/// blocks the UI. Deliberately a top-level function: the closure it passes
/// to `Isolate.run` captures ONLY [req]. (Creating that closure inside a
/// widget's State method would also capture `this`, which can't be sent
/// across isolates.)
Future<ComputerMoveResult?> computeComputerMoveInBackground(ComputerMoveRequest req) =>
    Isolate.run(() => computeComputerMove(req));
