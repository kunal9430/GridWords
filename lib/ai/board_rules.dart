import 'word_list.dart';

/// A grid coordinate.
class Cell {
  final int row;
  final int col;
  const Cell(this.row, this.col);

  @override
  bool operator ==(Object other) => other is Cell && other.row == row && other.col == col;

  @override
  int get hashCode => row * 1000 + col;

  @override
  String toString() => '($row,$col)';
}

/// One scorable word found on the board: its text (in reading order) and
/// the cells it occupies (also in reading order).
class WordHit {
  final String word;
  final List<Cell> cells;
  const WordHit(this.word, this.cells);

  /// A word scores its length.
  int get score => word.length;

  @override
  String toString() => '$word@${cells.join('')}';
}

/// The geometry + word rules of Grid Words, independent of any UI.
///
/// Rules implemented here (the app has no automatic word detection for
/// human players, so these are the documented rules the computer plays by):
///  * a word is a run of CONTIGUOUS filled cells on one straight line:
///    horizontal, vertical or either diagonal - no skipping empty cells;
///  * it may be read in either direction along that line;
///  * it must include the cell that was just filled this turn;
///  * a word already scored this match ([usedWords]) can't score again;
///  * a word scores its length.
class BoardRules {
  BoardRules._();

  /// The four line axes (row step, column step). Each is read both ways.
  static const List<List<int>> axes = [
    [0, 1], // horizontal
    [1, 0], // vertical
    [1, 1], // diagonal \
    [1, -1], // diagonal /
  ];

  static bool _inBounds(List<List<String>> grid, int r, int c) =>
      r >= 0 && r < grid.length && c >= 0 && c < grid[r].length;

  static bool isEmptyCell(List<List<String>> grid, int r, int c) => grid[r][c].isEmpty;

  /// Every valid, not-yet-used word that passes through the (already
  /// filled) cell [row],[col]. Returns an empty list if the cell is empty.
  /// Never mutates [grid].
  static List<WordHit> wordsThrough(
    List<List<String>> grid,
    int row,
    int col,
    WordList words,
    Set<String> usedWords,
  ) {
    final hits = <WordHit>[];
    final letter = grid[row][col];
    if (letter.isEmpty) return hits;

    // A single letter is a word on its own ("A", "I"). Counted once here,
    // not once per axis.
    if (words.contains(letter) && !usedWords.contains(letter)) {
      hits.add(WordHit(letter, [Cell(row, col)]));
    }

    for (final axis in axes) {
      final dr = axis[0];
      final dc = axis[1];

      // How many contiguous filled cells lie behind / ahead of the cell.
      var back = 0;
      while (_inBounds(grid, row - (back + 1) * dr, col - (back + 1) * dc) &&
          grid[row - (back + 1) * dr][col - (back + 1) * dc].isNotEmpty) {
        back++;
      }
      var ahead = 0;
      while (_inBounds(grid, row + (ahead + 1) * dr, col + (ahead + 1) * dc) &&
          grid[row + (ahead + 1) * dr][col + (ahead + 1) * dc].isNotEmpty) {
        ahead++;
      }
      if (back == 0 && ahead == 0) continue;

      // Every contiguous segment on this line that contains the cell.
      for (var i = 0; i <= back; i++) {
        for (var j = 0; j <= ahead; j++) {
          if (i + j == 0) continue; // single letter handled above
          final cells = <Cell>[];
          final buf = StringBuffer();
          for (var k = -i; k <= j; k++) {
            final r = row + k * dr;
            final c = col + k * dc;
            cells.add(Cell(r, c));
            buf.write(grid[r][c]);
          }
          final forward = buf.toString();
          if (words.contains(forward) && !usedWords.contains(forward)) {
            hits.add(WordHit(forward, cells));
          }
          final backward = String.fromCharCodes(forward.codeUnits.reversed);
          if (backward != forward && words.contains(backward) && !usedWords.contains(backward)) {
            hits.add(WordHit(backward, cells.reversed.toList()));
          }
        }
      }
    }
    return hits;
  }

  /// The single word claimed for a turn when several are formed: the
  /// longest (most points); ties broken alphabetically so the choice is
  /// deterministic. Returns null if [hits] is empty.
  static WordHit? bestClaim(List<WordHit> hits) {
    WordHit? best;
    for (final h in hits) {
      if (best == null ||
          h.score > best.score ||
          (h.score == best.score && h.word.compareTo(best.word) < 0)) {
        best = h;
      }
    }
    return best;
  }
}
