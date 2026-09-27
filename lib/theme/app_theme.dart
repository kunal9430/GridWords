import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// One selectable color theme. Unlike a single Material "seed" (which lets
/// Flutter auto-derive secondary/tertiary — usually as muted, washed-out
/// grays, which is why a seed-only theme reads as "one color everywhere"),
/// every theme here carries its OWN primary/secondary/tertiary straight
/// from that theme's real, well-known palette, plus its own background and
/// card/surface color. That's what actually makes each one look distinct.
class ColorThemeOption {
  final String name;
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color background;
  final Color surface;
  const ColorThemeOption(this.name, this.primary, this.secondary, this.tertiary, this.background, this.surface);

  /// Kept for any older call site that only cares about the accent color.
  Color get seed => primary;
}

/// Centralized light/dark theme definitions with shared component themes
/// (buttons, inputs, cards, app bars) so the whole app reads as one
/// consistent, "designed" product rather than a pile of per-widget colors.
class AppTheme {
  static const double _radius = 14;

  /// Picks readable black/white text for any accent color, since themes
  /// here mix light accents (yellow, cyan) and dark ones (deep purple,
  /// red) — a single hardcoded text color would go unreadable on half of
  /// them.
  static Color onColorFor(Color c) =>
      ThemeData.estimateBrightnessForColor(c) == Brightness.dark ? Colors.white : Colors.black;

  // ---------------------------------------------------------------------
  // The original Grid Words look, from before the theme picker existed:
  // indigo primary + teal tertiary (exactly the two accent colors the
  // Active Game screen always used for Player 1 / Player 2). Selecting
  // "System" mode in Settings always uses this, regardless of whatever
  // color swatch was last picked for Light/Dark — "System" means "the
  // classic default", not "whatever I customized".
  // ---------------------------------------------------------------------
  static const ColorThemeOption originalLight = ColorThemeOption(
      'Classic (Default)', Color(0xFF5B4FE9), Color(0xFF17A398), Color(0xFF17A398), Color(0xFFF4F5FB), Colors.white);
  static const ColorThemeOption originalDark = ColorThemeOption('Classic (Default)', Color(0xFF5B4FE9),
      Color(0xFF17A398), Color(0xFF17A398), Color(0xFF101018), Color(0xFF1C1C27));

  // Ten well-known dark editor/app themes, each with its OWN real
  // multi-color accent trio (not one hue auto-stretched into three).
  // "Classic (Default)" is always first, so a fresh pick of explicit Dark
  // mode (e.g. via the home screen's quick toggle) lands on the familiar
  // look by default, not a random swatch.
  static const List<ColorThemeOption> darkThemes = [
    originalDark,
    ColorThemeOption('Dracula', Color(0xFFFF79C6), Color(0xFF50FA7B), Color(0xFF8BE9FD), Color(0xFF282A36), Color(0xFF44475A)),
    ColorThemeOption('Tokyo Night', Color(0xFF7AA2F7), Color(0xFFBB9AF7), Color(0xFF7DCFFF), Color(0xFF1A1B26), Color(0xFF24283B)),
    ColorThemeOption('One Dark Pro', Color(0xFF61AFEF), Color(0xFF98C379), Color(0xFFC678DD), Color(0xFF282C34), Color(0xFF2C313C)),
    ColorThemeOption('GitHub Dark', Color(0xFF58A6FF), Color(0xFF3FB950), Color(0xFFBC8CFF), Color(0xFF0D1117), Color(0xFF161B22)),
    ColorThemeOption('Nord', Color(0xFF88C0D0), Color(0xFFA3BE8C), Color(0xFFB48EAD), Color(0xFF2E3440), Color(0xFF3B4252)),
    ColorThemeOption('Night Owl', Color(0xFF7FDBCA), Color(0xFFC792EA), Color(0xFF82AAFF), Color(0xFF011627), Color(0xFF0E2338)),
    ColorThemeOption('Midnight Shadows', Color(0xFF8B7FD6), Color(0xFF5FA8A0), Color(0xFF6C7A96), Color(0xFF0A0A0F), Color(0xFF16161F)),
    ColorThemeOption('Obsidian Depths', Color(0xFF00E5FF), Color(0xFF39FF14), Color(0xFFFF2EC4), Color(0xFF121212), Color(0xFF1E1E1E)),
    ColorThemeOption('Cyber Neon', Color(0xFF39FF14), Color(0xFF00F0FF), Color(0xFFFF2EC4), Color(0xFF0D0D0D), Color(0xFF1A1A1A)),
    ColorThemeOption('Warm Charcoal', Color(0xFFFF8A65), Color(0xFFE0C097), Color(0xFFC97B4A), Color(0xFF1C1C1C), Color(0xFF272727)),
    // Brand-inspired extras
    ColorThemeOption('WhatsApp', Color(0xFF25D366), Color(0xFF128C7E), Color(0xFF34B7F1), Color(0xFF0B141A), Color(0xFF1F2C34)),
    ColorThemeOption('Netflix', Color(0xFFE50914), Color(0xFFB1060F), Color(0xFFE6B800), Color(0xFF141414), Color(0xFF1F1F1F)),
    ColorThemeOption('Spotify', Color(0xFF1DB954), Color(0xFF1AA34A), Color(0xFF4F9DDE), Color(0xFF121212), Color(0xFF1E1E1E)),
    ColorThemeOption('Instagram Glow', Color(0xFFE1306C), Color(0xFFF77737), Color(0xFF833AB4), Color(0xFF101010), Color(0xFF1C1C1C)),
  ];

  // Ten well-known light editor/app themes, plus brand-inspired extras —
  // same principle: each with its own three real accent colors. Classic
  // first, for the same reason as darkThemes above.
  static const List<ColorThemeOption> lightThemes = [
    originalLight,
    ColorThemeOption('GitHub Light', Color(0xFF0969DA), Color(0xFF1A7F37), Color(0xFF8250DF), Color(0xFFFFFFFF), Color(0xFFF6F8FA)),
    ColorThemeOption('One Light', Color(0xFF4078F2), Color(0xFF50A14F), Color(0xFFA626A4), Color(0xFFFAFAFA), Color(0xFFFFFFFF)),
    ColorThemeOption('Solarized Light', Color(0xFF268BD2), Color(0xFFCB4B16), Color(0xFFD33682), Color(0xFFFDF6E3), Color(0xFFEEE8D5)),
    ColorThemeOption('Aura Light', Color(0xFFA277FF), Color(0xFF3FBFA8), Color(0xFFFF6767), Color(0xFFF7F6F3), Color(0xFFFFFFFF)),
    ColorThemeOption('Tokyo Night Light', Color(0xFF5A72B3), Color(0xFF7AA787), Color(0xFFC57171), Color(0xFFE6E7EF), Color(0xFFF4F4F8)),
    ColorThemeOption('Nord Light', Color(0xFF5E81AC), Color(0xFF7A9D6F), Color(0xFF96688C), Color(0xFFECEFF4), Color(0xFFE5E9F0)),
    ColorThemeOption('Gruvbox Light', Color(0xFFAF3A03), Color(0xFF79740E), Color(0xFF076678), Color(0xFFFBF1C7), Color(0xFFF2E5BC)),
    ColorThemeOption('Quiet Light', Color(0xFF7C5CBF), Color(0xFF3D8F8A), Color(0xFFC15B6E), Color(0xFFF3F0FA), Color(0xFFFFFFFF)),
    ColorThemeOption('Ayu Mirage Light', Color(0xFFFF9940), Color(0xFFF07178), Color(0xFF5FB3A3), Color(0xFFFAF0E6), Color(0xFFFFF6EC)),
    ColorThemeOption('Minimal Chalk', Color(0xFF4A90E2), Color(0xFF6E9B4B), Color(0xFFD96C6C), Color(0xFFFFFFFF), Color(0xFFF5F5F5)),
    // Brand-inspired extras
    ColorThemeOption('Snapchat', Color(0xFFB8A600), Color(0xFF0FADFF), Color(0xFF1A1A1A), Color(0xFFFFFFFF), Color(0xFFFFFDE7)),
    ColorThemeOption('WhatsApp Light', Color(0xFF128C7E), Color(0xFF25D366), Color(0xFF34B7F1), Color(0xFFECE5DD), Color(0xFFFFFFFF)),
    ColorThemeOption('Instagram Light', Color(0xFFE1306C), Color(0xFFF77737), Color(0xFF833AB4), Color(0xFFFFFFFF), Color(0xFFFFF3F6)),
    ColorThemeOption('X (Twitter)', Color(0xFF1DA1F2), Color(0xFF17BF63), Color(0xFF0C4A6E), Color(0xFFFFFFFF), Color(0xFFF7F9FA)),
  ];

  // 50+ font choices via Google Fonts (fetched once, then cached locally —
  // needs internet the first time any given font is used, works offline
  // after that). `null` = platform default font.
  static const List<String?> fontOptions = [
    null, // Default (platform)
    'Roboto', 'Open Sans', 'Lato', 'Montserrat', 'Poppins', 'Nunito', 'Inter',
    'Raleway', 'Ubuntu', 'Merriweather', 'Playfair Display', 'Oswald',
    'PT Sans', 'Source Sans 3', 'Noto Sans', 'Work Sans', 'Rubik',
    'Quicksand', 'Karla', 'Mukta', 'Inconsolata', 'Fira Sans', 'Barlow',
    'DM Sans', 'Space Grotesk', 'Manrope', 'Josefin Sans', 'Cabin',
    'Titillium Web', 'Bitter', 'Crimson Text', 'Libre Baskerville',
    'EB Garamond', 'Lora', 'PT Serif', 'Roboto Slab', 'Roboto Mono',
    'JetBrains Mono', 'Fira Code', 'Courier Prime', 'Comfortaa', 'Baloo 2',
    'Pacifico', 'Dancing Script', 'Caveat', 'Shadows Into Light',
    'Indie Flower', 'Permanent Marker', 'Bebas Neue', 'Anton',
    'Archivo Black', 'Amatic SC', 'Abril Fatface',
  ];

  static String fontLabel(String? family) => family ?? 'Default';

  // `fontScale` is accepted here for backwards compatibility with call
  // sites, but is deliberately not baked into the returned ThemeData —
  // see the note on `_build`'s textTheme below for why.
  static ThemeData light({ColorThemeOption? theme, String? fontFamily, double fontScale = 1.0}) =>
      _build(Brightness.light, theme ?? originalLight, fontFamily);

  static ThemeData dark({ColorThemeOption? theme, String? fontFamily, double fontScale = 1.0}) =>
      _build(Brightness.dark, theme ?? originalDark, fontFamily);

  static ThemeData _build(Brightness brightness, ColorThemeOption option, String? fontFamily) {
    final isDark = brightness == Brightness.dark;

    // Start from a seed-derived scheme (so every M3 widget still has a
    // complete, valid palette to fall back on), then overwrite the parts
    // that actually define this theme's identity with its REAL colors —
    // this is what keeps every theme from collapsing into "one hue".
    final colorScheme = ColorScheme.fromSeed(seedColor: option.primary, brightness: brightness).copyWith(
      primary: option.primary,
      onPrimary: onColorFor(option.primary),
      secondary: option.secondary,
      onSecondary: onColorFor(option.secondary),
      tertiary: option.tertiary,
      onTertiary: onColorFor(option.tertiary),
      surface: option.surface,
      onSurface: isDark ? Colors.white.withOpacity(0.92) : Colors.black.withOpacity(0.87),
    );

    // Google Fonts already returns a fully-styled TextTheme (every size,
    // weight, etc. preserved from the platform base) — apply() on top just
    // layers in the emoji fallback (so Unicode player names/monograms
    // always render), without clobbering the font choice itself. Wrapped
    // in try/catch so a single bad/unavailable font name degrades to the
    // platform default instead of ever crashing the app.
    //
    // NOTE: the Settings font-SIZE multiplier is intentionally NOT baked
    // in here. Only Text widgets that read a size straight out of this
    // textTheme would ever see a factor applied here — but a lot of this
    // app's widgets (buttons, labels, dialogs, cards...) set their own
    // literal `fontSize:` values directly and never touch textTheme at
    // all, so they'd silently ignore the slider. Instead, the font-size
    // preference is applied once, app-wide, as a MediaQuery textScaler
    // override in main.dart's MaterialApp builder — that affects every
    // single Text widget in the tree uniformly, however it set its style.
    final platformBase = ThemeData(brightness: brightness).textTheme;
    TextTheme fontedTheme = platformBase;
    if (fontFamily != null) {
      try {
        fontedTheme = GoogleFonts.getTextTheme(fontFamily, platformBase);
      } catch (_) {
        fontedTheme = platformBase;
      }
    }
    final textTheme = fontedTheme.apply(
      fontFamilyFallback: const ['Noto Color Emoji', 'Apple Color Emoji', 'Segoe UI Emoji'],
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      // Set at both levels: textTheme carries the font into every specific
      // style (headings, body, buttons, ...), and the top-level fontFamily
      // covers any widget default that reads ThemeData.fontFamily directly
      // rather than a specific textTheme slot.
      fontFamily: fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: option.background,
      cardColor: option.surface,
      dividerColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? option.surface : option.primary,
        foregroundColor: onColorFor(isDark ? option.surface : option.primary),
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
        fillColor: option.surface,
      ),
      cardTheme: CardThemeData(
        color: option.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      ),
    );
  }
}
