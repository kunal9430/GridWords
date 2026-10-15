import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grid_word_game/ai/board_rules.dart';
import 'package:grid_word_game/ai/computer_player.dart';
import 'package:grid_word_game/ai/computer_turn.dart';
import 'package:grid_word_game/ai/difficulty.dart';
import 'package:grid_word_game/ai/move_generator.dart';
import 'package:grid_word_game/ai/word_list.dart';
import 'package:grid_word_game/models/game_state.dart';
import 'package:grid_word_game/services/scoreboard_name_resolver.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a grid from rows of text; '.' is an empty cell.
List<List<String>> grid(List<String> rows) => [
      for (final r in rows) [for (final ch in r.split('')) ch == '.' ? '' : ch],
    ];

List<List<String>> copyGrid(List<List<String>> g) => [for (final row in g) List<String>.from(row)];

int filled(List<List<String>> g) => g.fold(0, (n, row) => n + row.where((c) => c.isNotEmpty).length);

Set<String> hitWords(List<WordHit> hits) => {for (final h in hits) h.word};

/// Checks a move is legal under the game rules: vacant cell, and (if it
/// claims a word) a dictionary word, not already used, spelled by
/// contiguous cells on ONE straight line that include the new letter.
void expectLegal(Move move, List<List<String>> before, WordList words, Set<String> used) {
  expect(before[move.row][move.col], isEmpty, reason: 'must play a vacant cell');
  final after = copyGrid(before)..[move.row][move.col] = move.letter;
  final claim = move.claim;
  if (claim == null) {
    expect(move.score, 0);
    return;
  }
  expect(words.contains(claim.word), isTrue, reason: '${claim.word} must be a dictionary word');
  expect(used.contains(claim.word), isFalse, reason: '${claim.word} was already scored');
  expect(claim.cells.contains(Cell(move.row, move.col)), isTrue, reason: 'word must use the new letter');
  expect(claim.cells.map((c) => after[c.row][c.col]).join(), claim.word);
  expect(move.score, claim.word.length);
  for (var i = 1; i < claim.cells.length; i++) {
    final dr = claim.cells[i].row - claim.cells[i - 1].row;
    final dc = claim.cells[i].col - claim.cells[i - 1].col;
    expect(dr.abs() <= 1 && dc.abs() <= 1 && (dr != 0 || dc != 0), isTrue, reason: 'cells must touch');
    if (i > 1) {
      expect(dr, claim.cells[1].row - claim.cells[0].row, reason: 'must be a straight line');
      expect(dc, claim.cells[1].col - claim.cells[0].col, reason: 'must be a straight line');
    }
  }
}

/// The scoring move that puts [letter] at ([r],[c]) - fails the test if the
/// board offers no such move.
Move pickMove(List<List<String>> g, WordList words, int r, int c, String letter) =>
    MoveGenerator.scoringMoves(copyGrid(g), words, {}).singleWhere((m) => m.row == r && m.col == c && m.letter == letter);

final WordList catWords = WordList.fromWords(const ['CAT', 'AT', 'TO']);

GameState computerGame(List<String> rows, {AiDifficulty difficulty = AiDifficulty.medium}) {
  final s = GameState.newComputerGame(
    humanNames: ['Sam'],
    rows: rows.length,
    cols: rows.first.length,
    difficulty: difficulty,
  );
  s.grid = grid(rows);
  s.locked = [for (final r in rows) [for (final ch in r.split('')) ch != '.']];
  return s;
}

ComputerMoveResult asResult(Move m) => ComputerMoveResult(
      row: m.row,
      col: m.col,
      letter: m.letter,
      word: m.claim?.word,
      wordCells: m.claim == null ? const [] : [for (final c in m.claim!.cells) ...[c.row, c.col]],
    );

/// A small, fully-known vocabulary of real English words.
final WordList smallWords = WordList.fromWords(const [
  'AN', 'ANE', 'ANT', 'ANTA', 'ANTAE', 'ANTE', 'ANTES', 'ASEA', 'AT', 'ATE', 'ATES', 'ATT', 'EAST', 'EAT',
  'EATS', 'EN', 'ETA', 'ETAS', 'ETNA', 'NA', 'NE', 'NEAT', 'NEST', 'NET', 'NETS', 'NETT', 'NTH', 'SAT',
  'SATE', 'SEA', 'SEAT', 'SENT', 'SET', 'TA', 'TAN', 'TANS', 'TANSY', 'TAT', 'TATE', 'TEA', 'TEAS', 'TEAT',
  'TEN', 'TENT', 'TENTS', //
]);

void main() {
  // -------------------------------------------------------------------------
  group('Word finding (BoardRules)', () {
    final cat = WordList.fromWords(const ['CAT']);

    test('horizontal', () {
      final g = grid(['CA.'])..[0][2] = 'T';
      final hits = BoardRules.wordsThrough(g, 0, 2, cat, {});
      expect(hitWords(hits), {'CAT'});
      expect(hits.single.cells, [const Cell(0, 0), const Cell(0, 1), const Cell(0, 2)]);
    });

    test('vertical', () {
      final g = grid(['C', 'A', '.'])..[2][0] = 'T';
      expect(hitWords(BoardRules.wordsThrough(g, 2, 0, cat, {})), {'CAT'});
    });

    test('diagonal down-right', () {
      final g = grid(['C..', '.A.', '...'])..[2][2] = 'T';
      final hits = BoardRules.wordsThrough(g, 2, 2, cat, {});
      expect(hits.single.cells, [const Cell(0, 0), const Cell(1, 1), const Cell(2, 2)]);
    });

    test('diagonal down-left', () {
      final g = grid(['..C', '.A.', '...'])..[2][0] = 'T';
      final hits = BoardRules.wordsThrough(g, 2, 0, cat, {});
      expect(hits.single.cells, [const Cell(0, 2), const Cell(1, 1), const Cell(2, 0)]);
    });

    test('words can be read backwards along the line', () {
      final g = grid(['TA.'])..[0][2] = 'C'; // reads TAC left-to-right, CAT right-to-left
      final hits = BoardRules.wordsThrough(g, 0, 2, cat, {});
      expect(hitWords(hits), {'CAT'});
      expect(hits.single.cells, [const Cell(0, 2), const Cell(0, 1), const Cell(0, 0)]);
    });

    test('words cannot skip an empty cell', () {
      final ct = WordList.fromWords(const ['CT']);
      expect(BoardRules.wordsThrough(grid(['C.T']), 0, 0, ct, {}), isEmpty);
      expect(BoardRules.wordsThrough(grid(['C.T']), 0, 2, ct, {}), isEmpty);
      // diagonal gap too
      expect(BoardRules.wordsThrough(grid(['C..', '...', '..T']), 2, 2, ct, {}), isEmpty);
    });

    test('a word that does not pass through the new letter is not counted', () {
      // CAT already sits in row 0; placing a letter in row 2 must not "find" it.
      final g = grid(['CAT', '...', '.X.']);
      expect(BoardRules.wordsThrough(g, 2, 1, cat, {}), isEmpty);
    });

    test('a previously scored word cannot score again', () {
      final g = grid(['CA.'])..[0][2] = 'T';
      expect(BoardRules.wordsThrough(g, 0, 2, cat, {'CAT'}), isEmpty);
      final moves = MoveGenerator.scoringMoves(grid(['CA.']), cat, {'CAT'});
      expect(moves, isEmpty);
      final fresh = MoveGenerator.scoringMoves(grid(['CA.']), cat, {});
      expect(fresh.single.letter, 'T');
    });

    test('finds every eligible word one placement creates (and claims the longest)', () {
      // Placing T at (0,2): CAT across, AT inside it, TO downwards.
      final vocab = WordList.fromWords(const ['CAT', 'AT', 'TO']);
      final g = grid(['CA.', '..O']);
      final moves = MoveGenerator.scoringMoves(g, vocab, {});
      final t = moves.singleWhere((m) => m.row == 0 && m.col == 2 && m.letter == 'T');
      expect(hitWords(t.hits), {'CAT', 'AT', 'TO'});
      expect(t.claim!.word, 'CAT');
      expect(t.score, 3, reason: 'one word is scored per turn: the longest');
    });

    test('one-letter words A and I count (once)', () {
      final vocab = WordList.fromText('AT\n');
      expect(vocab.contains('A'), isTrue);
      expect(vocab.contains('I'), isTrue);
      expect(vocab.contains('B'), isFalse);
      final g = grid(['.']);
      expect(hitWords(BoardRules.wordsThrough(g..[0][0] = 'A', 0, 0, vocab, {})), {'A'});
      expect(BoardRules.wordsThrough(g, 0, 0, vocab, {'A'}), isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('Move generation', () {
    test('never proposes an occupied cell and never mutates the board', () {
      final g = grid(['STE..S', 'T.....']);
      final before = copyGrid(g);
      final moves = MoveGenerator.scoringMoves(g, smallWords, {});
      expect(g, before);
      expect(moves, isNotEmpty);
      for (final m in moves) {
        expect(before[m.row][m.col], isEmpty);
      }
      final fillers = MoveGenerator.fillerMoves(g, smallWords, {}, 5);
      expect(g, before);
      for (final m in fillers) {
        expect(before[m.row][m.col], isEmpty);
        expect(m.score, 0);
      }
    });
  });

  // -------------------------------------------------------------------------
  group('ComputerPlayer', () {
    final boards = <List<String>>[
      ['STE..S'],
      ['SEAT..', 'T.....', 'E..N..'],
      ['STEN', '....', '.A..', '...T'],
      ['A.S..', '.....', '..T..'],
    ];

    test('every difficulty always returns a legal move (many boards, many seeds)', () {
      final player = ComputerPlayer(smallWords);
      for (final rows in boards) {
        for (final d in AiDifficulty.values) {
          for (var seed = 0; seed < 4; seed++) {
            final g = grid(rows);
            final used = <String>{'SET'};
            final move = player.chooseMove(
              grid: g,
              usedWords: used,
              difficulty: d,
              seed: seed,
              timeBudget: const Duration(seconds: 2),
            );
            expect(move, isNotNull, reason: '${d.label} on $rows');
            expectLegal(move!, grid(rows), smallWords, used);
          }
        }
      }
    });

    test('does not modify the grid it is given', () {
      final g = grid(['SEAT..', 'T.....', 'E..N..']);
      final before = copyGrid(g);
      for (final d in AiDifficulty.values) {
        ComputerPlayer(smallWords).chooseMove(
          grid: g,
          usedWords: const [],
          difficulty: d,
          timeBudget: const Duration(seconds: 2),
        );
        expect(g, before);
      }
    });

    test('same seed gives the same move (reproducible)', () {
      final p = ComputerPlayer(smallWords);
      final a = p.chooseMove(
        grid: grid(boards[1]),
        usedWords: const [],
        difficulty: AiDifficulty.hard,
        seed: 5,
        timeBudget: const Duration(minutes: 5), // never time-limited, so the result is fully deterministic
      );
      final b = p.chooseMove(
        grid: grid(boards[1]),
        usedWords: const [],
        difficulty: AiDifficulty.hard,
        seed: 5,
        timeBudget: const Duration(minutes: 5), // never time-limited, so the result is fully deterministic
      );
      expect('${a!.letter}${a.row}${a.col}', '${b!.letter}${b.row}${b.col}');
    });

    test('nearly full grid: plays the only vacant cell', () {
      final vocab = WordList.fromWords(const ['TOP']);
      for (final d in AiDifficulty.values) {
        final move = ComputerPlayer(vocab).chooseMove(
          grid: grid(['CAT', 'TO.']),
          usedWords: const [],
          difficulty: d,
        )!;
        expect([move.row, move.col, move.letter, move.claim?.word], [1, 2, 'P', 'TOP'], reason: d.label);
      }
    });

    test('completely full grid: nothing to play', () {
      for (final d in AiDifficulty.values) {
        expect(
          ComputerPlayer(smallWords).chooseMove(grid: grid(['SET', 'TEN']), usedWords: const [], difficulty: d),
          isNull,
        );
      }
    });

    test('no scoring move exists: still places one legal 0-point letter', () {
      final nothing = WordList.fromWords(const []);
      for (final d in AiDifficulty.values) {
        final g = grid(['.Q.', '...']);
        final move = ComputerPlayer(nothing).chooseMove(
          grid: g,
          usedWords: const [],
          difficulty: d,
          timeBudget: const Duration(seconds: 2),
        )!;
        expectLegal(move, g, nothing, {});
        expect(move.claim, isNull);
        expect(move.score, 0);
      }
    });

    test('Medium/Hard/Expert avoid a greedy trap that Easy-style greed falls into', () {
      // NETS (4 pts) is the biggest word available, but it leaves the
      // opponent a reply worth 5. SET (3 pts) leaves nothing, so searching
      // difficulties must prefer it.
      final g = grid(['STE..S']);
      final all = MoveGenerator.scoringMoves(copyGrid(g), smallWords, {});
      expect(all.map((m) => m.claim!.word).toSet(), containsAll(['NETS', 'SET']));
      expect(all.map((m) => m.score).reduce((a, b) => a > b ? a : b), 4, reason: 'greedy would take NETS');

      for (final d in [AiDifficulty.medium, AiDifficulty.hard, AiDifficulty.expert]) {
        for (var seed = 0; seed < 6; seed++) {
          final m = ComputerPlayer(smallWords).chooseMove(
            grid: copyGrid(g),
            usedWords: const [],
            difficulty: d,
            seed: seed,
            timeBudget: const Duration(seconds: 3),
          )!;
          expect(m.claim?.word, 'SET', reason: '${d.label} seed $seed picked ${m.claim?.word}');
          expect(m.score, 3);
        }
      }
    });

    test('works with the real bundled dictionary', () {
      final text = File('assets/words/words.txt').readAsStringSync();
      final real = WordList.fromText(text);
      expect(real.length, inInclusiveRange(20000, 40000));
      expect(real.isValid('example'), isTrue);
      expect(real.isValid('A'), isTrue);
      expect(real.isValid('I'), isTrue);
      expect(real.isValid('zzzzq'), isFalse);

      final g = grid([
        'SEAT....',
        'RNOP....',
        '.LDEA...',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      for (final d in AiDifficulty.values) {
        final used = <String>{};
        final move = ComputerPlayer(real).chooseMove(
          grid: g,
          usedWords: used,
          difficulty: d,
          seed: 3,
          timeBudget: const Duration(seconds: 3),
        )!;
        expectLegal(move, g, real, used);
        expect(move.score, greaterThan(0), reason: '${d.label} should find a word here');
      }
    });
  });

  // -------------------------------------------------------------------------
  group('Bundled dictionary quality', () {
    final lines = File('assets/words/words.txt').readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
    final entries = {for (final l in lines) l.split('\t').first: l.contains('\t') ? l.substring(l.indexOf('\t') + 1).trim() : ''};
    final words = entries.keys.toSet();

    test('every word has a meaning', () {
      final missing = entries.entries.where((e) => e.value.isEmpty).map((e) => e.key).toList();
      expect(missing, isEmpty);
      final defs = WordList.definitionsFromText(lines.join('\n'));
      expect(defs['BUSY'], isNotEmpty);
      expect(defs.length, entries.length);
    });

    test('plain lower-case letters only, 2-10 long, with a vowel (no abbreviations)', () {
      for (final w in words) {
        expect(RegExp(r'^[a-z]{2,10}$').hasMatch(w), isTrue, reason: w);
        expect(RegExp('[aeiouy]').hasMatch(w), isTrue, reason: '$w has no vowel');
      }
    });

    test('obscure words, plurals and inflected forms reported in play are rejected', () {
      const reported = ['pya', 'yom', 'thir', 'uta', 'adit', 'kris', 'irks', 'mems', 'tubs', 'lots', 'ours', 'subs', 'piny', 'nth'];
      for (final w in reported) {
        expect(words.contains(w), isFalse, reason: '$w must not be accepted');
      }
    });

    test('acronyms are rejected', () {
      for (final w in ['vat', 'asp', 'duff', 'laser', 'radar', 'scuba', 'sonar', 'snafu']) {
        expect(words.contains(w), isFalse, reason: '$w is an acronym and must not be accepted');
      }
    });

    test('only the 1st verb form: no 2nd / 3rd / 4th forms (past, participle, -ing)', () {
      const forms = [
        // V2 / V3, regular
        'walked', 'looked', 'stopped', 'carried', 'baked', 'tired', 'finished', 'unused',
        // V2 / V3, irregular
        'ran', 'went', 'gone', 'built', 'made', 'broken', 'eaten', 'ate', 'took', 'taken',
        'gave', 'given', 'saw', 'seen', 'was', 'were', 'been', 'had', 'did', 'done', 'got',
        // V4 (-ing)
        'walking', 'running', 'making', 'building', 'going', 'being', 'having', 'doing',
        'dying', 'lying', 'feeling', 'stopping',
        // V5 (-s) of irregular verbs
        'is', 'are', 'has',
      ];
      // 'saw' is also an ordinary noun (the tool) and is deliberately kept.
      final offenders = forms.where((w) => w != 'saw' && words.contains(w)).toList();
      expect(offenders, isEmpty, reason: '${offenders.join(' ')} are not the 1st verb form');
    });

    test('1st verb forms are still accepted', () {
      for (final w in ['walk', 'look', 'stop', 'carry', 'bake', 'tire', 'finish', 'use', 'run', 'go', 'build',
        'make', 'break', 'eat', 'take', 'give', 'see', 'be', 'have', 'do', 'get', 'read', 'put', 'cut', 'set']) {
        expect(words.contains(w), isTrue, reason: '$w should be accepted');
      }
    });

    test('no regular -ed / -ing form of another listed word', () {
      String? stemOf(String w) {
        if (w.length >= 5 && w.endsWith('ing')) {
          final b = w.substring(0, w.length - 3);
          for (final s in [b, '${b}e', if (b.length > 1 && b[b.length - 1] == b[b.length - 2]) b.substring(0, b.length - 1)]) {
            if (s.length >= 2 && words.contains(s)) return s;
          }
        }
        if (w.length >= 4 && w.endsWith('ed')) {
          final b = w.substring(0, w.length - 2);
          for (final s in [b, w.substring(0, w.length - 1), if (b.length > 1 && b[b.length - 1] == b[b.length - 2]) b.substring(0, b.length - 1)]) {
            if (s.length >= 3 && words.contains(s)) return s;
          }
        }
        return null;
      }

      // Ordinary nouns / adjectives that merely look inflected are kept on purpose
      // (see KEEP in tools/verb_forms.py), so a small tolerance is expected.
      final leftovers = words.where((w) => stemOf(w) != null).toList();
      expect(leftovers.length, lessThan(120), reason: leftovers.join(' '));
    });

    test('ordinary words are accepted', () {
      for (final w in ['zap', 'busy', 'memo', 'ion', 'cat', 'tub', 'sub', 'lot', 'our', 'it', 'of', 'the']) {
        expect(words.contains(w), isTrue, reason: '$w should be accepted');
      }
    });

    test('no plural of another listed word', () {
      final plurals = words.where((w) {
        if (w.length < 5 || RegExp(r'(ss|us|is|ous)$').hasMatch(w)) return false;
        if (w.endsWith('ies') && words.contains('${w.substring(0, w.length - 3)}y')) return true;
        if (w.endsWith('es') && words.contains(w.substring(0, w.length - 2))) return true;
        return w.endsWith('s') && words.contains(w.substring(0, w.length - 1));
      }).toList();
      // A handful of true singulars that merely look plural (tongs, pathos...) are tolerated.
      expect(plurals.length, lessThan(15), reason: plurals.join(' '));
    });

    test('the computer only ever claims words from this list', () {
      final real = WordList.fromText(File('assets/words/words.txt').readAsStringSync());
      final g = grid(['SEAT....', 'RNOP....', '.LDEA...', '........']);
      final used = <String>{};
      for (final d in AiDifficulty.values) {
        for (var seed = 0; seed < 3; seed++) {
          final m = ComputerPlayer(real).chooseMove(
            grid: g,
            usedWords: used,
            difficulty: d,
            seed: seed,
            timeBudget: const Duration(seconds: 3),
          )!;
          final w = m.claim?.word;
          if (w != null) {
            expect(words.contains(w.toLowerCase()) || WordList.singleLetterWords.contains(w), isTrue, reason: w);
          }
        }
      }
    });
  });

  // -------------------------------------------------------------------------
  group('Computer match flow (GameState)', () {
    test('turns alternate: human scores -> computer moves -> human again', () {
      final s = computerGame(['SEAT..', '......']);
      expect(s.vsComputer, isTrue);
      expect(s.currentTurn, 1);
      expect(s.isComputerTurn, isFalse, reason: "human's turn");

      // Computer can't move on the human's turn.
      expect(s.applyComputerMove(const ComputerMoveResult(row: 0, col: 4, letter: 'S', word: 'SEATS', wordCells: [0, 0, 0, 1, 0, 2, 0, 3, 0, 4])), isFalse);
      expect(s.score2, 0);

      // Human places a letter and records a score.
      s.grid[1][0] = 'T';
      s.locked[1][0] = true;
      s.pendingRow = 1;
      s.pendingCol = 0;
      s.scoringArmed = true;
      s.applyTurnScore(2);
      expect(s.score1, 2);
      expect(s.currentTurn, 2);
      expect(s.isComputerTurn, isTrue);

      final move = ComputerPlayer(smallWords).chooseMove(
        grid: s.grid,
        usedWords: s.usedWords,
        difficulty: AiDifficulty.hard,
        timeBudget: const Duration(seconds: 2),
      )!;
      final before = filled(s.grid);
      expect(s.applyComputerMove(asResult(move)), isTrue);
      expect(filled(s.grid), before + 1, reason: 'exactly one letter placed');
      expect(s.currentTurn, 1, reason: 'turn returns to the human');
      expect(s.isComputerTurn, isFalse);
      expect(s.scoringArmed, isFalse);
      expect(s.score1, 2, reason: "human's score untouched");
      expect(s.score2, move.score, reason: "computer's points added exactly once");
    });

    test('score = word length, added to the computer once; word recorded as used', () {
      final s = computerGame(['CA.', '..O']);
      s.currentTurn = 2;
      // T at (0,2) forms CAT, AT and TO; CAT (the longest) is claimed.
      final move = pickMove(s.grid, catWords, 0, 2, 'T');
      expect(move.claim?.word, 'CAT');
      expect(s.applyComputerMove(asResult(move)), isTrue);
      expect(s.score2, 3, reason: 'CAT only; AT and TO are not also scored');
      expect(s.usedWords, ['CAT']);
      expect(s.aiMoveRow, 0);
      expect(s.aiMoveCol, 2);
      expect(s.aiWord, 'CAT');
      expect(s.aiWordCells, [0, 0, 0, 1, 0, 2]);
    });

    test('a zero-point placement scores nothing and records no word', () {
      final s = computerGame(['..', '..']);
      s.currentTurn = 2;
      final ok = s.applyComputerMove(const ComputerMoveResult(row: 0, col: 0, letter: 'Q', word: null, wordCells: []));
      expect(ok, isTrue);
      expect(s.score2, 0);
      expect(s.usedWords, isEmpty);
      expect(s.currentTurn, 1);
    });

    test('rejects an occupied cell, an off-board cell, a used word and a word not on the board', () {
      final s = computerGame(['CA.', '...']);
      s.currentTurn = 2;
      ComputerMoveResult mv(int r, int c, String l, String? w, List<int> cells) =>
          ComputerMoveResult(row: r, col: c, letter: l, word: w, wordCells: cells);

      expect(s.applyComputerMove(mv(0, 0, 'X', null, [])), isFalse, reason: 'occupied');
      expect(s.applyComputerMove(mv(5, 5, 'X', null, [])), isFalse, reason: 'off board');
      expect(s.applyComputerMove(mv(0, 2, 'T', 'CAB', [0, 0, 0, 1, 0, 2])), isFalse, reason: 'word does not match letters');
      expect(s.applyComputerMove(mv(1, 2, 'T', 'CAT', [0, 0, 0, 1, 0, 2])), isFalse, reason: 'word must use the new letter');
      expect(s.applyComputerMove(mv(0, 2, 'T', 'CAT', [0, 0, 0, 2, 0, 1])), isFalse, reason: 'cells not in line order');
      s.addUsedWord('CAT');
      expect(s.applyComputerMove(mv(0, 2, 'T', 'CAT', [0, 0, 0, 1, 0, 2])), isFalse, reason: 'already scored');
      // Nothing changed through all of that.
      expect(filled(s.grid), 2);
      expect(s.score2, 0);
      expect(s.currentTurn, 2);
    });

    test('the computer cannot play once the game has ended', () {
      final s = computerGame(['CAT', 'TOP']);
      expect(s.isBoardFull, isTrue);
      expect(s.isComplete, isTrue);
      s.currentTurn = 2;
      expect(s.isComputerTurn, isFalse);
      expect(s.applyComputerMove(const ComputerMoveResult(row: 0, col: 0, letter: 'X', word: null, wordCells: [])), isFalse);
      expect(s.score2, 0);
    });

    test('the computer never moves while a score is outstanding or in a two-human match', () {
      final s = computerGame(['...', '...']);
      s.currentTurn = 2;
      s.scoringArmed = true;
      expect(s.isComputerTurn, isFalse);

      final humans = GameState.newGame(playerNames: ['A', 'B'], rows: 2, cols: 2);
      humans.currentTurn = 2;
      expect(humans.vsComputer, isFalse);
      expect(humans.isComputerTurn, isFalse);
    });

    test('two-human scoring is unchanged: score, then the turn passes', () {
      final s = GameState.newGame(playerNames: ['Ann', 'Bob'], rows: 3, cols: 3);
      s.scoringArmed = true;
      s.pendingRow = 0;
      s.pendingCol = 0;
      s.applyTurnScore(3);
      expect([s.score1, s.score2, s.currentTurn, s.scoringArmed, s.pendingRow], [3, 0, 2, false, null]);
      s.applyTurnScore(-1); // Bob subtracts
      expect([s.score1, s.score2, s.currentTurn], [3, -1, 1]);
    });

    test('restart (resetMatch) clears board, scores, words, highlight and hands the human the turn', () {
      final s = computerGame(['CA.', '..O']);
      s.currentTurn = 2;
      s.score1 = 4;
      final move = pickMove(s.grid, catWords, 0, 2, 'T');
      expect(s.applyComputerMove(asResult(move)), isTrue);
      s.currentTurn = 2;
      s.scoringArmed = true;
      s.pendingRow = 1;
      s.pendingCol = 1;

      s.resetMatch();

      expect(filled(s.grid), 0);
      expect(s.locked.every((row) => row.every((c) => !c)), isTrue);
      expect([s.score1, s.score2], [0, 0]);
      expect(s.usedWords, isEmpty);
      expect(s.scoringArmed, isFalse);
      expect([s.pendingRow, s.pendingCol], [null, null]);
      expect([s.aiMoveRow, s.aiMoveCol, s.aiWord], [null, null, null]);
      expect(s.aiWordCells, isEmpty);
      expect(s.currentTurn, 1);
      expect(s.vsComputer, isTrue, reason: 'still a computer match');
      expect(s.difficulty, 'medium', reason: 'difficulty is kept');
    });

    test('resetMatch leaves whose turn it is alone in a two-human match (original behaviour)', () {
      final s = GameState.newGame(playerNames: ['Ann', 'Bob'], rows: 2, cols: 2);
      s.currentTurn = 2;
      s.score2 = 5;
      s.resetMatch();
      expect(s.currentTurn, 2);
      expect([s.score1, s.score2], [0, 0]);
    });

    test('the computer can play the opening move, and keeps doing so after a restart', () {
      final s = GameState.newComputerGame(
        humanNames: ['Sam'],
        rows: 3,
        cols: 3,
        difficulty: AiDifficulty.hard,
        computerStarts: true,
      );
      expect(s.computerStarts, isTrue);
      expect(s.currentTurn, 2);
      expect(s.isComputerTurn, isTrue);
      s.score1 = 4;
      s.resetMatch();
      expect(s.currentTurn, 2);
      expect(GameState.decode(s.encode()).computerStarts, isTrue);

      final human = GameState.newComputerGame(humanNames: ['Sam'], rows: 3, cols: 3, difficulty: AiDifficulty.easy);
      expect(human.currentTurn, 1);
      expect(human.computerStarts, isFalse);
    });

    test('the human\'s next score clears the computer\'s highlight', () {
      final s = computerGame(['CA.', '..O']);
      s.currentTurn = 2;
      final move = pickMove(s.grid, catWords, 0, 2, 'T');
      s.applyComputerMove(asResult(move));
      expect(s.aiMoveRow, isNotNull);
      s.applyTurnScore(1); // human's turn now
      expect(s.aiMoveRow, isNull);
      expect(s.aiWordCells, isEmpty);
    });

    test('computer-match fields survive save/load; old saves load as two-human matches', () {
      final s = computerGame(['CA.', '..O'], difficulty: AiDifficulty.expert);
      s.currentTurn = 2;
      final move = pickMove(s.grid, catWords, 0, 2, 'T');
      s.applyComputerMove(asResult(move));

      final loaded = GameState.decode(s.encode());
      expect(loaded.vsComputer, isTrue);
      expect(loaded.aiDifficulty, AiDifficulty.expert);
      expect([loaded.aiMoveRow, loaded.aiMoveCol, loaded.aiWord], [0, 2, 'CAT']);
      expect(loaded.aiWordCells, [0, 0, 0, 1, 0, 2]);
      expect(loaded.score2, 3);

      final legacy = s.toJson()
        ..remove('vsComputer')
        ..remove('difficulty')
        ..remove('aiMoveRow')
        ..remove('aiMoveCol')
        ..remove('aiWord')
        ..remove('aiWordCells');
      final old = GameState.fromJson(legacy);
      expect(old.vsComputer, isFalse);
      expect(old.aiWordCells, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('"Word already used" challenge and final-word check', () {
    test('undoing the computer move removes its letter and points and keeps the word used', () {
      final s = computerGame(['CA.', '..O']);
      s.currentTurn = 2;
      final move = pickMove(s.grid, catWords, 0, 2, 'T');
      expect(s.applyComputerMove(asResult(move)), isTrue);
      expect(s.score2, 3);
      expect(s.canChallengeComputerMove, isTrue);

      expect(s.undoLastComputerMove(), isTrue);
      expect(s.grid[0][2], '');
      expect(s.locked[0][2], isFalse);
      expect(s.score2, 0);
      expect(s.usedWords, ['CAT'], reason: 'the challenged word stays on the used list');
      expect(s.currentTurn, 2, reason: 'the computer tries again');
      expect(s.isComputerTurn, isTrue);
      expect(s.aiWord, isNull);
      expect(s.canChallengeComputerMove, isFalse, reason: 'nothing left to challenge');
      expect(s.undoLastComputerMove(), isFalse);
    });

    test('the retry can never claim the challenged word again', () {
      final s = computerGame(['CA.', '..O']);
      s.currentTurn = 2;
      expect(s.applyComputerMove(asResult(pickMove(s.grid, catWords, 0, 2, 'T'))), isTrue);
      expect(s.undoLastComputerMove(), isTrue);
      final retry = ComputerPlayer(catWords).chooseMove(
        grid: s.grid,
        usedWords: s.usedWords,
        difficulty: AiDifficulty.hard,
        timeBudget: const Duration(seconds: 2),
      );
      expect(retry?.claim?.word, isNot('CAT'));
    });

    test('cannot challenge a zero-point move, on the computer turn, or in a two-human match', () {
      final s = computerGame(['..', '..']);
      s.currentTurn = 2;
      s.applyComputerMove(const ComputerMoveResult(row: 0, col: 0, letter: 'Q', word: null, wordCells: []));
      expect(s.canChallengeComputerMove, isFalse, reason: 'no word was claimed');
      expect(s.undoLastComputerMove(), isFalse);

      final humans = GameState.newGame(playerNames: ['A', 'B'], rows: 2, cols: 2);
      expect(humans.canChallengeComputerMove, isFalse);
      expect(humans.undoLastComputerMove(), isFalse);
    });

    test('cannot challenge once the human has started their own turn', () {
      final s = computerGame(['CA.', '..O']);
      s.currentTurn = 2;
      s.applyComputerMove(asResult(pickMove(s.grid, catWords, 0, 2, 'T')));
      expect(s.canChallengeComputerMove, isTrue);
      s.scoringArmed = true; // human placed a letter, score pending
      expect(s.canChallengeComputerMove, isFalse);
      expect(s.undoLastComputerMove(), isFalse);
      s.scoringArmed = false;
      s.applyTurnScore(1); // human scored: computer highlight is cleared
      expect(s.canChallengeComputerMove, isFalse);
    });

    test('the challenge survives save and load', () {
      final s = computerGame(['CA.', '..O']);
      s.currentTurn = 2;
      s.applyComputerMove(asResult(pickMove(s.grid, catWords, 0, 2, 'T')));
      final loaded = GameState.decode(s.encode());
      expect(loaded.canChallengeComputerMove, isTrue);
      expect(loaded.undoLastComputerMove(), isTrue);
      expect(loaded.score2, 0);
    });

    test('a move that fills the last cell with a word needs the final-word check', () {
      final s = computerGame(['CA.']);
      s.currentTurn = 2;
      expect(s.vacantCount, 1);
      final move = pickMove(s.grid, catWords, 0, 2, 'T');
      expect(s.endsGameWithWord(asResult(move)), isTrue);
    });

    test('no final-word check when cells remain, or when the last move claims no word', () {
      final s = computerGame(['CA..']);
      s.currentTurn = 2;
      expect(s.vacantCount, 2);
      final cat = ComputerMoveResult(row: 0, col: 2, letter: 'T', word: 'CAT', wordCells: const [0, 0, 0, 1, 0, 2]);
      expect(s.endsGameWithWord(cat), isFalse);

      final last = computerGame(['CAB.']);
      last.currentTurn = 2;
      const filler = ComputerMoveResult(row: 0, col: 3, letter: 'Q', word: null, wordCells: []);
      expect(last.endsGameWithWord(filler), isFalse);
    });

    test('a word the human says is used is added once and then excluded from the final move', () {
      final s = computerGame(['CA.']);
      s.currentTurn = 2;
      s.addUsedWord('cat'); // human: "CAT was already used"
      s.addUsedWord('CAT');
      expect(s.usedWords, ['CAT']);
      final next = ComputerPlayer(WordList.fromWords(const ['CAT'])).chooseMove(
        grid: s.grid,
        usedWords: s.usedWords,
        difficulty: AiDifficulty.expert,
        timeBudget: const Duration(seconds: 2),
      )!;
      expect(next.claim, isNull, reason: 'only CAT fits and it is used, so it places a filler letter');
    });
  });

  // -------------------------------------------------------------------------
  group('Isolate entry point', () {
    test('computeComputerMove returns plain data describing a legal move', () {
      const text = 'CAT\n';
      final g = grid(['CA.']); // one vacant cell: T (CAT, 3) beats A/I (1)
      final result = computeComputerMove(ComputerMoveRequest(
        wordsText: text,
        grid: g,
        usedWords: const [],
        difficultyName: 'hard',
        seed: 1,
      ))!;
      expect([result.row, result.col, result.letter, result.word, result.score], [0, 2, 'T', 'CAT', 3]);
      expect(result.wordCells, [0, 0, 0, 1, 0, 2]);
    });

    test('returns null on a full grid', () {
      final r = computeComputerMove(ComputerMoveRequest(
        wordsText: 'CAT\n',
        grid: grid(['CAT']),
        usedWords: const [],
        difficultyName: 'easy',
        seed: 1,
      ));
      expect(r, isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('Up to three players', () {
    test('pass and play rotates through every seat and wraps around', () {
      final s = GameState.newGame(playerNames: ['Ann', 'Bob', 'Cy'], rows: 3, cols: 3);
      expect(s.playerCount, 3);
      final seen = <int>[];
      for (var i = 0; i < 4; i++) {
        seen.add(s.currentTurn);
        s.applyTurnScore(i + 1);
      }
      expect(seen, [1, 2, 3, 1]);
      expect(s.scores, [1 + 4, 2, 3]);
    });

    test('computer sits in the last seat and moves after every human', () {
      final s = GameState.newComputerGame(
        humanNames: ['Ann', 'Bob'],
        rows: 3,
        cols: 3,
        difficulty: AiDifficulty.easy,
      );
      expect(s.playerCount, 3);
      expect(s.computerSeat, 3);
      expect(s.playerInitials.last, '🤖 CPU');
      expect(s.isComputerTurn, isFalse);
      s.applyTurnScore(1);
      expect(s.currentTurn, 2);
      expect(s.isComputerTurn, isFalse);
      s.applyTurnScore(1);
      expect(s.currentTurn, 3);
      expect(s.isComputerTurn, isTrue);
    });

    test('a computer opening move starts from the computer seat', () {
      final s = GameState.newComputerGame(
        humanNames: ['Ann', 'Bob'],
        rows: 2,
        cols: 2,
        difficulty: AiDifficulty.easy,
        computerStarts: true,
      );
      expect(s.currentTurn, 3);
      s.resetMatch();
      expect(s.currentTurn, 3);
    });

    test('computer move scores only the computer and hands over to player 1', () {
      final s = GameState.newComputerGame(
        humanNames: ['Ann', 'Bob'],
        rows: 2,
        cols: 3,
        difficulty: AiDifficulty.easy,
      );
      s.grid = grid(['CA.', '..O']);
      s.locked = [
        [true, true, false],
        [false, false, true],
      ];
      s.currentTurn = 3;
      expect(s.applyComputerMove(asResult(pickMove(s.grid, catWords, 0, 2, 'T'))), isTrue);
      expect(s.scores, [0, 0, 3]);
      expect(s.currentTurn, 1);
      expect(s.canChallengeComputerMove, isTrue);
      expect(s.undoLastComputerMove(), isTrue);
      expect(s.scores, [0, 0, 0]);
      expect(s.currentTurn, 3);
    });

    test('leaders reports ties', () {
      final s = GameState.newGame(playerNames: ['A', 'B', 'C'], rows: 2, cols: 2);
      s.scores = [3, 5, 5];
      expect(s.leaders, [2, 3]);
      s.scores = [3, 5, 4];
      expect(s.leaders, [2]);
    });

    test('3-player saves round-trip and old two-player saves still load', () {
      final s = GameState.newGame(playerNames: ['Ann', 'Bob', 'Cy'], rows: 3, cols: 3)
        ..scores = [1, 2, 3]
        ..currentTurn = 3;
      final loaded = GameState.decode(s.encode());
      expect(loaded.playerNames, ['Ann', 'Bob', 'Cy']);
      expect(loaded.scores, [1, 2, 3]);
      expect(loaded.currentTurn, 3);

      final legacy = s.toJson()
        ..remove('playerNames')
        ..remove('playerInitials')
        ..remove('scores');
      final old = GameState.fromJson(legacy);
      expect(old.playerCount, 2);
      expect(old.playerNames, ['Ann', 'Bob']);
      expect(old.scores, [1, 2]);
    });

    test('labels are unique for several players', () {
      for (final names in [
        ['Kunal Kumar', 'Kunal Kapoor', 'Kara Knight', 'Kunal Kumar'],
        ['Sam', 'Sam', 'Sam', 'Sam'],
        ['Alex', 'Alan', 'Zed', 'Alex'],
        ['😎', '😎', '🚀'],
      ]) {
        final labels = ScoreboardNameResolver.resolveMany(names);
        expect(labels.length, names.length);
        expect(labels.toSet().length, labels.length, reason: '$names -> $labels');
      }
    });
  });
}
