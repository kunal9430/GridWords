import 'package:flutter/material.dart';

/// A persistent, non-scrolling strip of numbers 0..[maxNumber] (inclusive),
/// so a `0` can always be recorded for a failed/blank turn. Buttons are
/// only tappable while the turn-lock state machine is in the scoring
/// phase; tapping while disabled does nothing.
class NumericStrip extends StatelessWidget {
  final int maxNumber;
  final bool enabled;
  final void Function(int number) onNumberTap;

  const NumericStrip({
    super.key,
    required this.maxNumber,
    required this.onNumberTap,
    this.enabled = false,
  });

  static const Color _orange = Color(0xFFE8863B);
  static const Color _amber = Color(0xFFF4A947);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = maxNumber + 1; // 0..maxNumber inclusive

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: enabled
            ? (isDark ? const Color(0xFF3A2E12) : const Color(0xFFFFF3D6))
            : scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled ? _orange : scheme.onSurface.withOpacity(isDark ? 0.14 : 0.1),
          width: enabled ? 1.5 : 1,
        ),
        boxShadow: enabled
            ? [BoxShadow(color: _orange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))]
            : const [],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Always exactly one row: button width is derived from the
          // available width divided by the count, with no lower clamp
          // that could force a wrap onto a second line. FittedBox keeps
          // the digit legible even if the button shrinks on a narrow
          // screen with a high Max Word Length.
          const spacing = 3.0;
          final totalSpacing = spacing * (count - 1);
          final buttonWidth =
              ((constraints.maxWidth - totalSpacing) / count).clamp(1.0, 46.0);
          return SizedBox(
            height: 38,
            width: constraints.maxWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(count, (number) {
                return Padding(
                  padding: EdgeInsets.only(right: number == count - 1 ? 0 : spacing),
                  child: SizedBox(
                    width: buttonWidth,
                    height: 38,
                    child: Material(
                      color: enabled ? null : scheme.onSurface.withOpacity(0.07),
                      type: enabled ? MaterialType.transparency : MaterialType.canvas,
                      borderRadius: BorderRadius.circular(10),
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: enabled
                              ? const LinearGradient(
                                  colors: [_amber, _orange],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                )
                              : null,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: enabled ? () => onNumberTap(number) : null,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1),
                              child: FittedBox(
                                child: Text(
                                  '$number',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: enabled ? Colors.white : scheme.onSurface.withOpacity(0.35),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}
