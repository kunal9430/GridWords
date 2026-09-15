import 'package:flutter/material.dart';

/// Centralized light/dark theme definitions with shared component themes
/// (buttons, inputs, cards, app bars) so the whole app reads as one
/// consistent, "designed" product rather than a pile of per-widget colors.
class AppTheme {
  // A richer, more saturated seed than a flat default indigo — closer to
  // the punchy-but-professional palette of well-polished mobile games.
  static const Color _seed = Color(0xFF5B4FE9);
  static const double _radius = 14;

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    // Applied non-destructively (keeps every other TextStyle property) so
    // Unicode/emoji/symbol player names and monograms always render with
    // real glyphs instead of "tofu" boxes, across every Text widget in the
    // app — not just the scoreboard.
    final baseTextTheme = ThemeData(brightness: brightness).textTheme.apply(
          fontFamilyFallback: const ['Noto Color Emoji', 'Apple Color Emoji', 'Segoe UI Emoji'],
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: baseTextTheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF101018) : const Color(0xFFF4F5FB),
      cardColor: isDark ? const Color(0xFF1C1C27) : Colors.white,
      dividerColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF181822) : colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1C27) : Colors.white,
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1C1C27) : Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      ),
    );
  }
}
