import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../services/storage_service.dart';
import '../widgets/gw_kit.dart';
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

  Widget _buildEmpty() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: GWReveal(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GWIconTile(icon: Icons.folder_open_rounded, size: 84, color: scheme.primary),
              const SizedBox(height: 22),
              const Text('No saved games yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Matches you save, or leave part-way through, will wait for you here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, height: 1.4, color: scheme.onSurface.withOpacity(0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One player's name and score inside the match card.
  Widget _scoreColumn(String name, int score, Color color, CrossAxisAlignment align) {
    return Expanded(
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontFamilyFallback: const ['Noto Color Emoji', 'Apple Color Emoji', 'Segoe UI Emoji'],
            ),
          ),
          Text('$score', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1.15, color: color)),
        ],
      ),
    );
  }

  Widget _buildGameCard(GameState game) {
    final scheme = Theme.of(context).colorScheme;
    final dark = GW.isDark(context);
    final winner = game.isComplete ? _winnerName(game) : null;
    final p1Color = dark ? scheme.primary : GW.deepen(scheme.primary);
    final p2Color = dark ? scheme.tertiary : GW.deepen(scheme.tertiary);
    return GWCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GWIconTile(
                icon: game.vsComputer ? Icons.smart_toy_rounded : Icons.people_alt_rounded,
                size: 44,
                color: scheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${game.player1Initials} vs ${game.player2Initials}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    fontFamilyFallback: ['Noto Color Emoji', 'Apple Color Emoji', 'Segoe UI Emoji'],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (game.isComplete)
                const GWBadge(text: 'Completed', color: Colors.green, icon: Icons.check_circle_rounded)
              else
                GWBadge(text: 'In progress', color: scheme.primary, icon: Icons.timelapse_rounded),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.onSurface.withOpacity(dark ? 0.06 : 0.04),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _scoreColumn(game.player1Name, game.score1, p1Color, CrossAxisAlignment.start),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('–', style: TextStyle(fontSize: 22, color: scheme.onSurface.withOpacity(0.4))),
                ),
                _scoreColumn(game.player2Name, game.score2, p2Color, CrossAxisAlignment.end),
              ],
            ),
          ),
          if (game.isComplete) ...[
            const SizedBox(height: 10),
            GWBadge(
              text: winner != null ? 'Winner: $winner' : 'Tie game',
              color: const Color(0xFFD99A00),
              icon: Icons.emoji_events_rounded,
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              GWBadge(text: '${game.rows} × ${game.cols} grid', color: scheme.primary, icon: Icons.grid_view_rounded),
              if (game.vsComputer)
                GWBadge(text: 'Level: ${game.aiDifficulty.label}', color: scheme.tertiary, icon: Icons.smart_toy_rounded),
              GWBadge(
                text: _formatTimestamp(game.lastSaved),
                color: scheme.onSurface.withOpacity(0.6),
                icon: Icons.schedule_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => _deleteGame(game),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => GameScreen(gameState: game)),
                  );
                  _loadGames();
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(game.isComplete ? 'Open' : 'Resume'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GWScaffold(
      title: 'Saved Games',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _games.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: _games.length,
                  itemBuilder: (context, index) {
                    final game = _games[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GWReveal(index: index, child: _buildGameCard(game)),
                    );
                  },
                ),
    );
  }
}
