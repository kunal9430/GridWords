import 'package:flutter/material.dart';
import 'gw_kit.dart';

/// Live ranking shown next to the player's own score card in an online match:
/// every player's rank, name and score, with the player whose turn it is
/// marked and the viewer's own row labelled "You".
class OnlineLeaderboard extends StatelessWidget {
  /// Full display names, by seat (index 0 = seat 1).
  final List<String> names;
  final List<int> scores;

  /// 1-based seat whose turn it is.
  final int currentTurn;

  /// 1-based seat of the player looking at this screen.
  final int mySeat;
  final bool gameOver;

  const OnlineLeaderboard({
    super.key,
    required this.names,
    required this.scores,
    required this.currentTurn,
    required this.mySeat,
    this.gameOver = false,
  });

  /// Seats ordered from highest score to lowest (ties keep seat order).
  static List<int> rankedSeats(List<int> scores) {
    final order = List<int>.generate(scores.length, (i) => i);
    order.sort((a, b) {
      final byScore = scores[b].compareTo(scores[a]);
      return byScore != 0 ? byScore : a.compareTo(b);
    });
    return order;
  }

  /// Competition rank (1, 1, 3...) of the player at 0-based index [i].
  static int rankOf(List<int> scores, int i) => 1 + scores.where((s) => s > scores[i]).length;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = GW.isDark(context);
    final order = rankedSeats(scores);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.onSurface.withOpacity(isDark ? 0.18 : 0.1), width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, size: 14, color: scheme.primary),
              const SizedBox(width: 4),
              Text(
                'LEADERBOARD',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: scheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final i in order) _row(context, i),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, int i) {
    final scheme = Theme.of(context).colorScheme;
    final seat = i + 1;
    final color = GW.playerColor(context, i);
    final isMe = seat == mySeat;
    final isTurn = !gameOver && seat == currentTurn;
    final rank = rankOf(scores, i);
    final name = (i < names.length ? names[i] : 'Player $seat');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isMe ? color.withOpacity(0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: isTurn ? color : Colors.transparent, width: 1.4),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              rank == 1 ? '🥇' : '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: rank == 1 ? 14 : 12.5,
                fontWeight: FontWeight.w900,
                color: scheme.onSurface.withOpacity(0.7),
                fontFamilyFallback: const ['Noto Color Emoji', 'Apple Color Emoji', 'Segoe UI Emoji'],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isMe ? '$name (You)' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                color: scheme.onSurface,
                fontFamilyFallback: const ['Noto Color Emoji', 'Apple Color Emoji', 'Segoe UI Emoji'],
              ),
            ),
          ),
          if (isTurn)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.bolt_rounded, size: 15, color: color),
            ),
          const SizedBox(width: 6),
          Text(
            '${scores[i]}',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: scheme.onSurface),
          ),
        ],
      ),
    );
  }
}
