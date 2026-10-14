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
        content: Text('Delete the match between ${game.playerNames.join(', ')}?'),
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

  Future<void> _deleteAll() async {
    final count = _games.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Saved Games'),
        content: Text(
          'Delete all $count saved ${count == 1 ? 'game' : 'games'}? This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await StorageService.deleteAllGames();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All saved games deleted')));
    _loadGames();
  }

  String _formatTimestamp(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  /// Display names of the winner(s) of a finished game; empty when every
  /// player is level.
  List<String> _winnerNames(GameState game) {
    final leaders = game.leaders;
    if (leaders.length == game.playerCount) return const [];
    return [for (final seat in leaders) game.playerNames[seat - 1]];
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

  static const _emojiFonts = ['Noto Color Emoji', 'Apple Color Emoji', 'Segoe UI Emoji'];

  /// Compact one-line scoreboard, e.g. "Ann 12 · Bob 9 · Cy 4".
  Widget _buildScoreLine(GameState game) {
    final scheme = Theme.of(context).colorScheme;
    final dark = GW.isDark(context);
    final leaders = game.isComplete ? game.leaders : const <int>[];
    final spans = <InlineSpan>[];
    for (var i = 0; i < game.playerCount; i++) {
      if (i > 0) {
        spans.add(TextSpan(text: '  ·  ', style: TextStyle(color: scheme.onSurface.withOpacity(0.35))));
      }
      final color = GW.playerColor(context, i);
      final isLeader = leaders.length < game.playerCount && leaders.contains(i + 1);
      spans.add(TextSpan(
        text: '${isLeader ? '🏆 ' : ''}${game.playerInitials[i]} ',
        style: TextStyle(color: scheme.onSurface.withOpacity(0.7)),
      ));
      spans.add(TextSpan(
        text: '${game.scores[i]}',
        style: TextStyle(fontWeight: FontWeight.w900, color: dark ? color : GW.deepen(color)),
      ));
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13.5, fontFamilyFallback: _emojiFonts),
    );
  }

  /// A short, tappable row per match: tap to resume/open, bin to delete.
  Widget _buildGameCard(GameState game) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withOpacity(0.6);
    final winners = game.isComplete ? _winnerNames(game) : const <String>[];
    final meta = [
      '${game.rows}×${game.cols}',
      if (game.vsComputer) game.aiDifficulty.label,
      _formatTimestamp(game.lastSaved),
    ].join(' · ');
    return GWCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GameScreen(gameState: game)),
        );
        _loadGames();
      },
      child: Row(
        children: [
          GWIconTile(
            icon: game.vsComputer ? Icons.smart_toy_rounded : Icons.people_alt_rounded,
            size: 38,
            color: scheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        game.matchTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, fontFamilyFallback: _emojiFonts),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      game.isComplete ? Icons.check_circle_rounded : Icons.timelapse_rounded,
                      size: 15,
                      color: game.isComplete ? Colors.green : scheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                _buildScoreLine(game),
                const SizedBox(height: 2),
                Text(
                  game.isComplete
                      ? (winners.isEmpty ? 'Tie game · $meta' : 'Winner: ${winners.join(' & ')} · $meta')
                      : 'Tap to resume · $meta',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: muted, fontFamilyFallback: _emojiFonts),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
            onPressed: () => _deleteGame(game),
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GWScaffold(
      title: 'Saved Games',
      actions: [
        if (_games.isNotEmpty)
          GWIconButton(
            icon: Icons.delete_sweep_rounded,
            tooltip: 'Delete all saved games',
            color: Colors.red,
            onTap: _deleteAll,
          ),
      ],
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
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GWReveal(index: index, child: _buildGameCard(game)),
                    );
                  },
                ),
    );
  }
}
