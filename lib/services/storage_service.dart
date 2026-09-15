import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_state.dart';

/// Handles reading/writing saved matches to on-device local storage.
/// Each match is stored as an encoded JSON string inside a single
/// SharedPreferences string list, keyed by [GameState.id].
class StorageService {
  static const String _key = 'grid_word_game_saved_games';

  static Future<List<GameState>> loadAllGames() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];
    final games = raw.map((s) => GameState.decode(s)).toList();
    games.sort((a, b) => b.lastSaved.compareTo(a.lastSaved));
    return games;
  }

  static Future<void> saveGame(GameState game) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];
    final list = raw.map((s) => GameState.decode(s)).toList();

    game.lastSaved = DateTime.now();
    final index = list.indexWhere((g) => g.id == game.id);
    if (index >= 0) {
      list[index] = game;
    } else {
      list.add(game);
    }

    final encodedList = list.map((g) => g.encode()).toList();
    await prefs.setStringList(_key, encodedList);
  }

  static Future<void> deleteGame(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];
    final list = raw.map((s) => GameState.decode(s)).toList();
    list.removeWhere((g) => g.id == id);
    final encodedList = list.map((g) => g.encode()).toList();
    await prefs.setStringList(_key, encodedList);
  }
}
