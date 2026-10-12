/// An in-memory, offline dictionary of valid words used by the computer
/// opponent. Pure Dart (no Flutter imports) so it can run inside a
/// background isolate and in plain unit tests.
///
/// Words are stored upper-case. The bundled list is a curated set of common
/// English base-form words, each with a meaning (see
/// `assets/words/LICENSE_WORDS.md` and `tools/build_wordlist.py`).
class WordList {
  /// One-letter words accepted by the game. The bundled list has none, and the
  /// existing "Capture Word" rules say single letters count, so the only
  /// two genuine English one-letter words are added explicitly.
  static const Set<String> singleLetterWords = {'A', 'I'};

  final Set<String> _words;

  WordList._(this._words);

  /// Builds a list from explicit words (any casing). Used heavily by tests
  /// so a board can be checked against a tiny, fully known vocabulary.
  /// Does NOT add the one-letter words automatically.
  factory WordList.fromWords(Iterable<String> words) {
    final result = <String>{};
    for (final w in words) {
      final n = w.trim().toUpperCase();
      if (n.isNotEmpty) result.add(n);
    }
    return WordList._(result);
  }

  /// Parses the bundled asset: one entry per line, either just `word` or
  /// `word<TAB>meaning` (only the word part is used here).
  factory WordList.fromText(String text, {bool includeSingleLetters = true}) {
    final result = <String>{};
    for (final line in text.split('\n')) {
      final tab = line.indexOf('\t');
      final n = (tab < 0 ? line : line.substring(0, tab)).trim().toUpperCase();
      if (n.isNotEmpty) result.add(n);
    }
    if (includeSingleLetters) result.addAll(singleLetterWords);
    return WordList._(result);
  }

  /// Reads the `word<TAB>meaning` lines of the bundled asset into a map
  /// keyed by the UPPER-CASE word. Lines without a meaning are skipped.
  static Map<String, String> definitionsFromText(String text) {
    final defs = <String, String>{};
    for (final line in text.split('\n')) {
      final tab = line.indexOf('\t');
      if (tab <= 0) continue;
      final meaning = line.substring(tab + 1).trim();
      if (meaning.isNotEmpty) defs[line.substring(0, tab).trim().toUpperCase()] = meaning;
    }
    return defs;
  }

  int get length => _words.length;

  /// [word] must already be upper-case (hot path: called many thousands of
  /// times per move). Use [isValid] for arbitrary input.
  bool contains(String word) => _words.contains(word);

  /// Case/whitespace-insensitive lookup.
  bool isValid(String word) => _words.contains(word.trim().toUpperCase());
}
