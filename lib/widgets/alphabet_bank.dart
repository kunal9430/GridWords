import 'package:flutter/material.dart';
import 'gw_kit.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final isDark = GW.isDark(context);
    final brand = GW.brand(context);
    final fg = GW.onColor(brand.first);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: enabled ? scheme.primary.withOpacity(0.45) : scheme.onSurface.withOpacity(isDark ? 0.12 : 0.08),
          width: enabled ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: enabled ? scheme.primary.withOpacity(0.18) : Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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
                child: Material(
                  type: enabled ? MaterialType.transparency : MaterialType.canvas,
                  color: enabled ? null : scheme.onSurface.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(9),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      gradient: enabled
                          ? LinearGradient(colors: brand, begin: Alignment.topLeft, end: Alignment.bottomRight)
                          : null,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: enabled ? () => onLetterTap(letter) : null,
                      child: Center(
                        child: FittedBox(
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Text(
                              letter,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: enabled ? fg : scheme.onSurface.withOpacity(0.35),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
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
