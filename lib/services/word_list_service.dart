import 'package:flutter/services.dart' show rootBundle;

import '../ai/word_list.dart';

/// Loads the bundled offline word list (curated WordNet + SCOWL words, each
/// with a meaning - see `assets/words/LICENSE_WORDS.md`) once and caches it. The raw text
/// is what gets handed to the background isolate that picks the computer's
/// move, so nothing is downloaded or queried per move.
class WordListService {
  WordListService._();

  static const String assetPath = 'assets/words/words.txt';
  static Future<String>? _text;

  static Future<String> loadText() => _text ??= rootBundle.loadString(assetPath);

  static Future<Map<String, String>>? _definitions;

  /// UPPER-CASE word -> its meaning, for showing what a word means.
  static Future<Map<String, String>> loadDefinitions() =>
      _definitions ??= loadText().then(WordList.definitionsFromText);
}
