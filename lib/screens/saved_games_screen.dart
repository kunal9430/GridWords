import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../services/storage_service.dart';
import 'game_screen.dart';

class SavedGamesScreen extends StatefulWidget {
  const SavedGamesScreen({super.key});

  @override
  State<SavedGamesScreen> createState() => _SavedGamesScreenState();
}

class _SavedGamesScreenState extends State<SavedGamesScreen> {
  List<GameState> _games = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    final games = await StorageService.loadAllGames();
    if (!mounted) return;
    setState(() {
      _games = games;
      _loading = false;
    });
  }

  Future<void> _deleteGame(GameState game) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Saved Game'),
        content: Text('Delete the match between ${game.player1Name} and ${game.player2Name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await StorageService.deleteGame(game.id);
      _loadGames();
    }
  }

  String _formatTimestamp(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  /// Null for a tie, otherwise the display name of whichever player has
  /// the higher score in a finished game.
  String? _winnerName(GameState game) {
    if (game.score1 == game.score2) return null;
    return game.score1 > game.score2 ? game.player1Name : game.player2Name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resume Saved Game')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _games.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.inbox, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No saved games found.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _games.length,
                    itemBuilder: (context, index) {
                      final game = _games[index];
                      final winner = game.isComplete ? _winnerName(game) : null;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${game.player1Initials} vs ${game.player2Initials}',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        fontFamilyFallback: ['Noto Color Emoji', 'Apple Color Emoji', 'Segoe UI Emoji'],
                                      ),
                                    ),
                                  ),
                                  if (game.isComplete)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.green.withOpacity(0.4)),
                                      ),
                                      child: const Text(
                                        'Completed',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (game.isComplete) ...[
                                const SizedBox(height: 2),
                                Text(
                                  winner != null ? 'Winner: $winner' : 'Tie game',
                                  style: const TextStyle(color: Colors.green, fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text('${game.player1Name} (${game.score1}) - (${game.score2}) ${game.player2Name}'),
                              const SizedBox(height: 4),
                              Text('${game.rows} x ${game.cols} Grid'),
                              const SizedBox(height: 4),
                              Text(
                                'Last saved: ${_formatTimestamp(game.lastSaved)}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _deleteGame(game),
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        foregroundColor: Colors.white),
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => GameScreen(gameState: game)),
                                      );
                                      _loadGames();
                                    },
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Resume'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
