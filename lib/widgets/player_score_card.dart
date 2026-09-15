import 'package:flutter/material.dart';

/// Displays a single player's initials, current score, and the
/// Add(+)/Minus(-) score-mode buttons. Per the active-HUD spec, only
/// initials are shown here (full names still appear on the Setup and
/// Saved Games screens). The score uses [AnimatedSwitcher] to visibly
/// pop whenever it changes, and the whole card gets a high-contrast
/// highlight — filled background, thicker accent border, glow shadow —
/// while it is that player's turn.
class PlayerScoreCard extends StatelessWidget {
  final String initials;
  final int score;
  final bool isAddActive;
  final bool isMinusActive;
  final bool controlsEnabled;
  final bool isCurrentTurn;
  final VoidCallback onAddPressed;
  final VoidCallback onMinusPressed;
  final VoidCallback? onCardTap;
  final Color accentColor;

  const PlayerScoreCard({
    super.key,
    required this.initials,
    required this.score,
    required this.isAddActive,
    required this.isMinusActive,
    required this.controlsEnabled,
    required this.isCurrentTurn,
    required this.onAddPressed,
    required this.onMinusPressed,
    this.onCardTap,
    this.accentColor = const Color(0xFF5B4FE9),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final dimForeground = isDark ? Colors.grey.shade600 : Colors.grey.shade400;
    final dimBorder = isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    return Expanded(
      child: GestureDetector(
        onTap: onCardTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isCurrentTurn ? accentColor.withOpacity(isDark ? 0.24 : 0.13) : surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrentTurn ? accentColor : accentColor.withOpacity(isDark ? 0.5 : 0.3),
            width: isCurrentTurn ? 3 : 1,
          ),
          boxShadow: [
            if (isCurrentTurn)
              BoxShadow(color: accentColor.withOpacity(0.45), blurRadius: 14, spreadRadius: 1)
            else
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(8)),
                  constraints: const BoxConstraints(maxWidth: 72),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      initials.isEmpty ? '?' : initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.5,
                        fontFamilyFallback: ['Noto Color Emoji', 'Apple Color Emoji', 'Segoe UI Emoji'],
                      ),
                    ),
                  ),
                ),
                if (isCurrentTurn)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.shade700,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'TURN',
                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: FittedBox(
                key: ValueKey<int>(score),
                fit: BoxFit.scaleDown,
                child: Text(
                  'Score : $score',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: accentColor),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isAddActive ? Colors.green : Colors.transparent,
                      foregroundColor: isAddActive ? Colors.white : (controlsEnabled ? Colors.green : dimForeground),
                      side: BorderSide(color: controlsEnabled ? Colors.green : dimBorder),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    onPressed: controlsEnabled ? onAddPressed : null,
                    child: const Text('+', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isMinusActive ? Colors.red : Colors.transparent,
                      foregroundColor: isMinusActive ? Colors.white : (controlsEnabled ? Colors.red : dimForeground),
                      side: BorderSide(color: controlsEnabled ? Colors.red : dimBorder),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    onPressed: controlsEnabled ? onMinusPressed : null,
                    child: const Text('−', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}
