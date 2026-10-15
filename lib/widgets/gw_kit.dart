import 'package:flutter/material.dart';

/// Shared building blocks that carry the Home screen's look (soft gradient
/// page, lettered tiles, rounded gradient cards, staggered entrances) to
/// every other screen, so the whole app reads as one product.
class GW {
  GW._();

  static const double radius = 20;

  /// Readable text color (near-black / white) for any filled background.
  static Color onColor(Color c) =>
      ThemeData.estimateBrightnessForColor(c) == Brightness.dark ? Colors.white : Colors.black87;

  /// A darker version of [c] that stays readable as text on a light surface
  /// (some themes use light accents such as yellow or cyan).
  static Color deepen(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness(hsl.lightness.clamp(0.0, 0.42)).toColor();
  }

  /// The two-color gradient used for primary actions and icon tiles.
  static List<Color> brand(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return [s.primary, Color.lerp(s.primary, s.tertiary, 0.45)!];
  }

  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  /// Accent color for player [index] (0-based, up to 4 players). The first
  /// two follow the theme (as in a two-player game); seats 3 and 4 use
  /// fixed teal and orange so all four stay easy to tell apart.
  static Color playerColor(BuildContext context, int index) {
    final s = Theme.of(context).colorScheme;
    switch (index) {
      case 0:
        return s.primary;
      case 1:
        return s.tertiary;
      case 2:
        return const Color(0xFF14A38B);
      default:
        return const Color(0xFFE8833A);
    }
  }
}

/// The Home screen's soft page gradient (primary tint -> page color ->
/// tertiary tint), reusable behind any screen.
class GWBackground extends StatelessWidget {
  final Widget child;
  const GWBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.primary.withOpacity(0.18),
            Theme.of(context).scaffoldBackgroundColor,
            scheme.tertiary.withOpacity(0.10),
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
      child: child,
    );
  }
}

/// Rounded tile button used in headers (back, share, ...).
class GWIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  const GWIconButton({super.key, required this.icon, required this.tooltip, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        elevation: 1.5,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 20, color: onTap == null ? scheme.onSurface.withOpacity(0.35) : (color ?? scheme.onSurface)),
          ),
        ),
      ),
    );
  }
}

/// Page scaffold: the Home gradient, a bold title row with a rounded back
/// button, optional header actions, and an optional [bottom] strip (e.g.
/// tabs) under the title.
class GWScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? bottom;
  final bool showBack;

  const GWScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.bottom,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: GWBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    if (showBack) ...[
                      GWIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        tooltip: 'Back',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                    ] else
                      const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: scheme.onSurface),
                      ),
                    ),
                    for (final a in actions) Padding(padding: const EdgeInsets.only(left: 8), child: a),
                  ],
                ),
              ),
              if (bottom != null) bottom!,
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

/// A surface card with the app's rounded corners, hairline border and soft
/// shadow. Becomes tappable (with ripple) when [onTap] is given.
class GWCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final Color? borderColor;

  const GWCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.gradient,
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = GW.isDark(context);
    final shape = BorderRadius.circular(GW.radius);
    final content = Padding(padding: padding, child: child);
    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? scheme.surface : null,
        gradient: gradient,
        borderRadius: shape,
        border: Border.all(color: borderColor ?? scheme.onSurface.withOpacity(dark ? 0.08 : 0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(dark ? 0.30 : 0.06), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: onTap == null
          ? content
          : Material(
              type: MaterialType.transparency,
              child: InkWell(borderRadius: shape, onTap: onTap, child: content),
            ),
    );
  }
}

/// Square gradient tile holding an icon.
class GWIconTile extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;

  const GWIconTile({super.key, required this.icon, this.color, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = color ?? scheme.primary;
    final end = Color.lerp(base, scheme.tertiary, 0.4)!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [base, end], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [BoxShadow(color: base.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Icon(icon, size: size * 0.52, color: GW.onColor(base)),
    );
  }
}

/// Icon tile + bold title (+ optional caption) heading a card section.
class GWSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;

  const GWSectionTitle({super.key, required this.icon, required this.title, this.subtitle, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        GWIconTile(icon: icon, color: color, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.6))),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Large gradient call-to-action button (same look as the Home mode cards).
class GWGradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final List<Color>? colors;
  final double height;
  final bool loading;

  const GWGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.colors,
    this.height = 54,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = colors ?? GW.brand(context);
    final enabled = onPressed != null && !loading;
    final fg = GW.onColor(cs.first);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        borderRadius: BorderRadius.circular(18),
        elevation: enabled ? 4 : 0,
        shadowColor: cs.first.withOpacity(0.5),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(colors: cs, begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: Center(
                child: loading
                    ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[Icon(icon, color: fg), const SizedBox(width: 8)],
                          Text(
                            label,
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: fg, letterSpacing: 0.5),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Selectable card/pill (icon over label) used for mode, difficulty and
/// "who starts" choices. Fills with the brand gradient when selected.
class GWChoice extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? caption;

  const GWChoice({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = GW.brand(context);
    final fg = selected ? GW.onColor(brand.first) : scheme.onSurface;
    final shape = BorderRadius.circular(16);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: selected
            ? LinearGradient(colors: brand, begin: Alignment.topLeft, end: Alignment.bottomRight)
            : null,
        color: selected ? null : scheme.surface,
        borderRadius: shape,
        border: Border.all(
          color: selected ? Colors.transparent : scheme.onSurface.withOpacity(0.14),
          width: 1.2,
        ),
        boxShadow: selected
            ? [BoxShadow(color: brand.first.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))]
            : const [],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 24, color: selected ? fg : scheme.primary),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: fg),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    caption!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: fg.withOpacity(0.8)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small rounded pill with optional icon, for status / meta information.
class GWBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const GWBadge({super.key, required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// Fades and slides its child in, [index] steps after the screen opens, so
/// lists and card stacks appear one after another like the Home screen.
class GWReveal extends StatefulWidget {
  final int index;
  final Widget child;

  const GWReveal({super.key, required this.child, this.index = 0});

  @override
  State<GWReveal> createState() => _GWRevealState();
}

class _GWRevealState extends State<GWReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    final step = widget.index > 8 ? 8 : widget.index;
    Future<void>.delayed(Duration(milliseconds: 60 * step), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(offset: Offset(0, (1 - _curve.value) * 22), child: child),
      ),
      child: widget.child,
    );
  }
}

/// A single lettered game tile. Pops in with [animation] when one is given
/// and bounces when tapped (same tile as the Home screen's logo).
class GWTile extends StatefulWidget {
  final String letter;
  final Color color;
  final double size;
  final Animation<double>? animation;

  const GWTile({super.key, required this.letter, required this.color, this.size = 44, this.animation});

  @override
  State<GWTile> createState() => _GWTileState();
}

class _GWTileState extends State<GWTile> {
  bool _pressed = false;

  Future<void> _bounce() async {
    setState(() => _pressed = true);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (mounted) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final tile = GestureDetector(
      onTap: _bounce,
      child: AnimatedScale(
        scale: _pressed ? 0.82 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: size,
          height: size,
          margin: EdgeInsets.symmetric(horizontal: size * 0.06),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(size * 0.25),
            boxShadow: [
              BoxShadow(color: widget.color.withOpacity(0.4), blurRadius: size / 6, offset: Offset(0, size / 12)),
            ],
          ),
          child: Text(
            widget.letter,
            textScaler: TextScaler.noScaling,
            style: TextStyle(fontSize: size * 0.54, fontWeight: FontWeight.w800, color: GW.onColor(widget.color)),
          ),
        ),
      ),
    );
    final anim = widget.animation;
    if (anim == null) return tile;
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) => Transform.scale(
        scale: anim.value.clamp(0.0, 1.3),
        child: Opacity(opacity: anim.value.clamp(0.0, 1.0), child: child),
      ),
      child: tile,
    );
  }
}

/// A word spelled out in [GWTile]s. Pass a [controller] to have the tiles
/// pop in one after another (starting [startIndex] tiles into the sequence).
class GWWordTiles extends StatelessWidget {
  final String word;
  final Color color;
  final double size;
  final AnimationController? controller;
  final int startIndex;

  const GWWordTiles({
    super.key,
    required this.word,
    required this.color,
    this.size = 40,
    this.controller,
    this.startIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < word.length; i++)
          GWTile(
            letter: word[i],
            color: color,
            size: size,
            animation: controller == null
                ? null
                : CurvedAnimation(
                    parent: controller!,
                    curve: Interval(
                      ((startIndex + i) * 0.06).clamp(0.0, 0.7),
                      (((startIndex + i) * 0.06) + 0.3).clamp(0.0, 1.0),
                      curve: Curves.elasticOut,
                    ),
                  ),
          ),
      ],
    );
  }
}
