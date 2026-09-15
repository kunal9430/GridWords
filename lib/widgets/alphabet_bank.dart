import 'package:flutter/material.dart';

/// A persistent, always-on-screen bank of the 26 uppercase letter buttons,
/// laid out as a compact non-scrolling grid (13 columns x 2 rows) so it
/// never needs its own scrollbar and never forces the page to scroll.
/// No numbers or symbols are ever rendered here, per the game spec.
class AlphabetBank extends StatelessWidget {
  final void Function(String letter) onLetterTap;
  final bool enabled;

  const AlphabetBank({
    super.key,
    required this.onLetterTap,
    this.enabled = true,
  });

  static const String _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const int _columns = 13;
  static const double _spacing = 3.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23232F) : const Color(0xFFEDEEFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF34344A) : const Color(0xFFD6D9F5)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final buttonSize =
              ((constraints.maxWidth - _spacing * (_columns - 1)) / _columns).clamp(20.0, 34.0);
          return Wrap(
            spacing: _spacing,
            runSpacing: _spacing,
            alignment: WrapAlignment.center,
            children: _letters.split('').map((letter) {
              return SizedBox(
                width: buttonSize,
                height: buttonSize,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: enabled ? const Color(0xFF5B4FE9) : (isDark ? Colors.grey.shade700 : Colors.grey.shade400),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    elevation: enabled ? 2 : 0,
                  ),
                  onPressed: enabled ? () => onLetterTap(letter) : null,
                  child: FittedBox(
                    child: Text(letter, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
