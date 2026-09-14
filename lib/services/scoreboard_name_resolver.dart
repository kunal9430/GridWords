import 'package:characters/characters.dart';

/// The two scoreboard labels (monograms) resolved for a match, one per
/// player, guaranteed non-identical whenever at least one player supplied
/// a non-empty name.
class ResolvedNames {
  final String player1Label;
  final String player2Label;

  const ResolvedNames({required this.player1Label, required this.player2Label});
}

/// Pure, stateless derivation of the short scoreboard label ("monogram")
/// shown for each player, from their free-form (Unicode/emoji-safe) name.
///
/// Rules implemented (see spec for full detail):
/// 1. A name that contains any letter or digit anywhere is treated as text:
///    non-alphanumeric symbols/emoji are stripped, and the label is the
///    first letter of each of the first two words (or the first one/two
///    letters of a single word), uppercased.
/// 2. A name with no letters or digits at all (pure emoji/symbols) is
///    treated as an emoji name: the label is its first one or two
///    grapheme clusters, exactly as typed (no case changes).
/// 3. If both players end up with the same label, it's disambiguated —
///    progressively pulling in more of each name, and falling back to a
///    numeric suffix ("K1"/"K2") if the names are otherwise identical.
///
/// All grapheme-cluster handling goes through the `characters` package so
/// multi-code-unit emoji, ZWJ sequences, and combining accents are never
/// split apart.
class ScoreboardNameResolver {
  ScoreboardNameResolver._();

  static final RegExp _alnum = RegExp(r'[\p{L}\p{Nd}]', unicode: true);
  static final RegExp _alnumOrSpace = RegExp(r'[\p{L}\p{Nd}\s]', unicode: true);

  /// Resolves both players' scoreboard labels in one call so collisions
  /// between them can be detected and fixed.
  static ResolvedNames resolve({
    required String player1,
    required String player2,
  }) {
    final name1 = player1.trim();
    final name2 = player2.trim();
    final isText1 = _hasAlphanumeric(name1);
    final isText2 = _hasAlphanumeric(name2);

    final label1 = _deriveLabel(name1, isText1);
    final label2 = _deriveLabel(name2, isText2);

    if (label1.isEmpty || label2.isEmpty || label1 != label2) {
      return ResolvedNames(player1Label: label1, player2Label: label2);
    }

    // Collision: both players resolved to the same label.
    if (isText1 && isText2) {
      return _resolveTextCollision(name1, name2);
    }
    // Emoji/symbol collision (or an emoji label happening to match a text
    // label — practically impossible, but handled the same safe way).
    return ResolvedNames(player1Label: '${label1}1', player2Label: '${label2}2');
  }

  // -------------------------------------------------------------------
  // Classification & single-name derivation
  // -------------------------------------------------------------------

  static bool _hasAlphanumeric(String name) => _alnum.hasMatch(name);

  static String _deriveLabel(String name, bool isText) {
    if (name.isEmpty) return '';
    if (isText) return _deriveTextMonogram(_stripToAlnumWords(name));
    return _deriveEmojiLabel(name);
  }

  /// Strips everything except letters, digits, and whitespace (used to
  /// pull the "real" words out of a name that also contains emoji, e.g.
  /// "😎 Kunal 🚀" -> "Kunal").
  static String _stripToAlnumWords(String name) {
    final buffer = StringBuffer();
    for (final cluster in name.characters) {
      if (_alnumOrSpace.hasMatch(cluster)) buffer.write(cluster);
    }
    return buffer.toString().trim();
  }

  static List<String> _wordsOf(String cleanedName) {
    if (cleanedName.isEmpty) return const [];
    return cleanedName.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  }

  static String _deriveTextMonogram(String cleanedName) {
    final words = _wordsOf(cleanedName);
    if (words.isEmpty) return '';
    if (words.length >= 2) {
      final c1 = words[0].characters.take(1).join();
      final c2 = words[1].characters.take(1).join();
      return (c1 + c2).toUpperCase();
    }
    final chars = words[0].characters;
    if (chars.length == 1) return chars.first.toUpperCase();
    return chars.take(2).join().toUpperCase();
  }

  /// First one or two grapheme clusters, preserved exactly as typed.
  static String _deriveEmojiLabel(String name) {
    final clusters = name.characters;
    if (clusters.isEmpty) return '';
    if (clusters.length == 1) return clusters.first;
    return clusters.take(2).join();
  }

  // -------------------------------------------------------------------
  // Collision resolution — both names are text
  // -------------------------------------------------------------------

  static ResolvedNames _resolveTextCollision(String name1, String name2) {
    final words1 = _wordsOf(_stripToAlnumWords(name1));
    final words2 = _wordsOf(_stripToAlnumWords(name2));
    final bothMultiWord = words1.length >= 2 && words2.length >= 2;

    if (bothMultiWord) {
      return _resolveMultiWordCollision(words1, words2);
    }
    return _resolveSingleWordCollision(
      words1.isNotEmpty ? words1[0] : '',
      words2.isNotEmpty ? words2[0] : '',
    );
  }

  static ResolvedNames _resolveMultiWordCollision(List<String> words1, List<String> words2) {
    final firstWord1 = words1[0];
    final firstWord2 = words2[0];

    // Tier 1: first two letters of each player's first word.
    final cand1 = firstWord1.characters.take(2).join().toUpperCase();
    final cand2 = firstWord2.characters.take(2).join().toUpperCase();
    if (cand1 != cand2) {
      return ResolvedNames(player1Label: cand1, player2Label: cand2);
    }

    // Tier 2: first words are identical too (e.g. both "Kunal ...") —
    // pull in the second word to differentiate.
    final secondWord1 = words1.length > 1 ? words1[1] : '';
    final secondWord2 = words2.length > 1 ? words2[1] : '';
    final deep1 = _firstLetterPlusSecondLetter(firstWord1, secondWord1);
    final deep2 = _firstLetterPlusSecondLetter(firstWord2, secondWord2);
    if (deep1 != deep2) {
      return ResolvedNames(player1Label: deep1, player2Label: deep2);
    }

    // Tier 3: genuinely indistinguishable names — numeric suffix.
    final base = firstWord1.characters.take(1).join().toUpperCase();
    return ResolvedNames(player1Label: '${base}1', player2Label: '${base}2');
  }

  static String _firstLetterPlusSecondLetter(String word1, String word2) {
    final first = word1.characters.isNotEmpty ? word1.characters.first.toUpperCase() : '?';
    final word2Chars = word2.characters;
    final second = word2Chars.length > 1
        ? word2Chars.elementAt(1).toUpperCase()
        : (word2Chars.isNotEmpty ? word2Chars.first.toUpperCase() : first);
    return first + second;
  }

  static ResolvedNames _resolveSingleWordCollision(String word1, String word2) {
    // Tier 1: first + last letter of each word (e.g. "Alex" -> "AX",
    // "Alan" -> "AN").
    final cand1 = _firstPlusLastLetter(word1);
    final cand2 = _firstPlusLastLetter(word2);
    if (cand1 != cand2) {
      return ResolvedNames(player1Label: cand1, player2Label: cand2);
    }

    // Tier 2: still identical (e.g. both literally "Kunal") — numeric suffix.
    final base = word1.characters.isNotEmpty ? word1.characters.first.toUpperCase() : '?';
    return ResolvedNames(player1Label: '${base}1', player2Label: '${base}2');
  }

  static String _firstPlusLastLetter(String word) {
    final chars = word.characters;
    if (chars.isEmpty) return '';
    if (chars.length == 1) return chars.first.toUpperCase();
    return (chars.first + chars.last).toUpperCase();
  }
}
