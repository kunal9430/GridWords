import 'package:flutter/material.dart';
import 'gw_kit.dart';

/// Displays a single player's initials, current score, and the
/// Add(+)/Minus(-) score-mode buttons. Per the active-HUD spec, only
/// initials are shown here (full names still appear on the Setup and
/// Saved Games screens). The score uses [AnimatedSwitcher] to visibly
/// pop whenever it changes, and the whole card fills with its player's
/// accent gradient and glows while it is that player's turn.
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

  /// Slimmer layout used when 3 or 4 players share the scoreboard row.
  final bool compact;

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
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = GW.isDark(context);
    final onAccent = GW.onColor(accentColor);
    // Text colors: on the filled (turn) card use the contrast color; on the
    // quiet card use the accent itself, darkened when needed for light mode.
    final nameFg = isCurrentTurn ? onAccent : (isDark ? accentColor : GW.deepen(accentColor));
    final accentEnd = Color.lerp(accentColor, scheme.surface, isDark ? 0.25 : 0.3)!;

    final initialsChip = Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: isCurrentTurn ? onAccent.withOpacity(0.2) : accentColor,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: BoxConstraints(maxWidth: compact ? 62 : 72),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: TextStyle(
            color: onAccent,
            fontWeight: FontWeight.w800,
            fontSize: compact ? 13 : 15,
            letterSpacing: 0.5,
            fontFamilyFallback: const ['Noto Color Emoji', 'Apple Color Emoji', 'Segoe UI Emoji'],
          ),
        ),
      ),
    );

    return Expanded(
      child: GestureDetector(
        onTap: onCardTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          margin: EdgeInsets.symmetric(horizontal: compact ? 2 : 4, vertical: 4),
          padding: compact ? const EdgeInsets.fromLTRB(5, 7, 5, 7) : const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            gradient: isCurrentTurn
                ? LinearGradient(colors: [accentColor, accentEnd], begin: Alignment.topLeft, end: Alignment.bottomRight)
                : null,
            color: isCurrentTurn ? null : scheme.surface,
            borderRadius: BorderRadius.circular(compact ? 14 : 18),
            border: Border.all(
              color: isCurrentTurn ? Colors.transparent : accentColor.withOpacity(isDark ? 0.45 : 0.3),
              width: 1.5,
            ),
            boxShadow: [
              if (isCurrentTurn)
                BoxShadow(color: accentColor.withOpacity(0.45), blurRadius: 14, offset: const Offset(0, 5))
              else
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (compact)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(child: initialsChip),
                    if (isCurrentTurn) ...[
                      const SizedBox(width: 2),
                      Icon(Icons.bolt_rounded, size: 15, color: onAccent),
                    ],
                  ],
                )
              else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  initialsChip,
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isCurrentTurn ? 1 : 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: onAccent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, size: 11, color: accentColor),
                          Text(
                            'TURN',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!compact) ...[
                        Text(
                          'SCORE',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: nameFg.withOpacity(0.75),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        '$score',
                        style: TextStyle(fontSize: compact ? 24 : 26, fontWeight: FontWeight.w900, height: 1.1, color: nameFg),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _ScoreButton(
                      label: '+',
                      color: Colors.green.shade600,
                      compact: compact,
                      active: isAddActive,
                      enabled: controlsEnabled,
                      onTap: onAddPressed,
                    ),
                  ),
                  SizedBox(width: compact ? 3 : 6),
                  Expanded(
                    child: _ScoreButton(
                      label: '−',
                      color: Colors.red.shade600,
                      compact: compact,
                      active: isMinusActive,
                      enabled: controlsEnabled,
                      onTap: onMinusPressed,
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

/// One of the two +/− buttons: solid when armed, outlined when available,
/// flat grey when it is not this player's turn.
class _ScoreButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final bool enabled;
  final bool compact;
  final VoidCallback onTap;

  const _ScoreButton({
    required this.label,
    required this.color,
    required this.compact,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = !enabled ? scheme.onSurface.withOpacity(0.07) : (active ? color : scheme.surface);
    final fg = !enabled ? scheme.onSurface.withOpacity(0.3) : (active ? Colors.white : color);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: enabled ? onTap : null,
        child: Container(
          height: compact ? 32 : 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: !enabled ? Colors.transparent : color.withOpacity(active ? 1 : 0.55),
              width: 1.4,
            ),
          ),
          child: Text(label, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: fg, height: 1.0)),
        ),
      ),
    );
  }
}
