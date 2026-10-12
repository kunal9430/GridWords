import 'board_rules.dart';
import 'word_list.dart';

/// A candidate turn: put [letter] in the vacant cell ([row],[col]).
/// [hits] are all valid, unused words the placement forms; [claim] is the
/// one word scored for the turn (null for a 0-point move).
class Move {
  final int row;
  final int col;
  final String letter;
  final List<WordHit> hits;
  final WordHit? claim;

  const Move(this.row, this.col, this.letter, this.hits, this.claim);

  int get score => claim?.score ?? 0;

  /// Best score first; ties left in whatever order the caller arranged.
  static int compareByScore(Move a, Move b) => b.score - a.score;

  /// Search order: best score first, then a fixed positional order so runs
  /// are reproducible.
  static int compareForSearch(Move a, Move b) {
    if (a.score != b.score) return b.score - a.score;
    if (a.row != b.row) return a.row - b.row;
    if (a.col != b.col) return a.col - b.col;
    return a.letter.compareTo(b.letter);
  }

  @override
  String toString() => 'Move($letter@$row,$col ${claim ?? '-'} =$score)';
}

/// Enumerates legal moves. All "what if" work happens by temporarily
/// writing a letter into the supplied grid and restoring it, so callers
/// pass a private copy (see `ComputerPlayer`); the grid is always left
/// exactly as it was found.
class MoveGenerator {
  MoveGenerator._();

  static const List<String> alphabet = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', //
  ];

  /// Letters tried, in order, when the computer must place a letter that
  /// scores nothing: awkward letters first, since they are the hardest for
  /// the opponent to build on.
  static const List<String> _fillerLetters = [
    'Q', 'J', 'X', 'Z', 'V', 'K', 'W', 'F', 'H', 'B', 'Y', 'G', 'C', 'M', 'P', //
  ];

  static int vacantCount(List<List<String>> grid) {
    var n = 0;
    for (final row in grid) {
      for (final cell in row) {
        if (cell.isEmpty) n++;
      }
    }
    return n;
  }

  /// Every (vacant cell, letter) that forms at least one valid unused
  /// word, with all words found. Occupied cells are never considered.
  static List<Move> scoringMoves(
    List<List<String>> grid,
    WordList words,
    Set<String> usedWords,
  ) {
    final moves = <Move>[];
    for (var r = 0; r < grid.length; r++) {
      for (var c = 0; c < grid[r].length; c++) {
        if (grid[r][c].isNotEmpty) continue;
        for (final letter in alphabet) {
          grid[r][c] = letter;
          final hits = BoardRules.wordsThrough(grid, r, c, words, usedWords);
          grid[r][c] = '';
          if (hits.isNotEmpty) {
            moves.add(Move(r, c, letter, hits, BoardRules.bestClaim(hits)));
          }
        }
      }
    }
    return moves;
  }

  /// Up to [count] zero-point moves (a placement that forms no word). The
  /// game lets a player score 0, and a turn must place a letter, so when
  /// nothing scores - or when scoring would hand the opponent a bigger
  /// reply - these are the alternatives. Cells touching the most filled
  /// neighbours are preferred (they smother the most opportunities); the
  /// letter is the awkwardest one that creates no word there.
  static List<Move> fillerMoves(
    List<List<String>> grid,
    WordList words,
    Set<String> usedWords,
    int count,
  ) {
    if (count <= 0) return const [];
    final ranked = <List<int>>[]; // [neighbours, row, col]
    for (var r = 0; r < grid.length; r++) {
      for (var c = 0; c < grid[r].length; c++) {
        if (grid[r][c].isNotEmpty) continue;
        var n = 0;
        for (var dr = -1; dr <= 1; dr++) {
          for (var dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            final rr = r + dr;
            final cc = c + dc;
            if (rr >= 0 && rr < grid.length && cc >= 0 && cc < grid[rr].length && grid[rr][cc].isNotEmpty) {
              n++;
            }
          }
        }
        ranked.add([n, r, c]);
      }
    }
    ranked.sort((a, b) {
      if (a[0] != b[0]) return b[0] - a[0];
      if (a[1] != b[1]) return a[1] - b[1];
      return a[2] - b[2];
    });

    final out = <Move>[];
    for (final cell in ranked) {
      if (out.length >= count) break;
      final r = cell[1];
      final c = cell[2];
      for (final letter in _fillerLetters) {
        grid[r][c] = letter;
        final hits = BoardRules.wordsThrough(grid, r, c, words, usedWords);
        grid[r][c] = '';
        if (hits.isEmpty) {
          out.add(Move(r, c, letter, const [], null));
          break;
        }
      }
    }
    return out;
  }
}
