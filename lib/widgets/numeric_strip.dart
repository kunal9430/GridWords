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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = maxNumber + 1; // 0..maxNumber inclusive

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: enabled
            ? (isDark ? const Color(0xFF3A2E12) : const Color(0xFFFFF3D6))
            : (isDark ? const Color(0xFF23232F) : const Color(0xFFF0F0F5)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: enabled ? const Color(0xFFE8A93B) : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
        ),
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
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: enabled ? const Color(0xFFE8863B) : (isDark ? Colors.grey.shade700 : Colors.grey.shade400),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: enabled ? () => onNumberTap(number) : null,
                      child: FittedBox(
                        child: Text('$number', style: const TextStyle(fontWeight: FontWeight.bold)),
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
