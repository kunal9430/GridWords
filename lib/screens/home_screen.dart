import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../config/app_links.dart';
import '../models/game_state.dart';
import '../services/profile_service.dart';
import '../services/storage_service.dart';
import '../services/theme_controller.dart';
import '../widgets/gw_kit.dart';
import 'about_screen.dart';
import 'game_screen.dart';
import 'rules_screen.dart';
import 'edit_profile_screen.dart';
import 'saved_games_screen.dart';
import 'settings_screen.dart';
import 'setup_screen.dart';

/// Entries of the profile menu.
enum _MenuAction { profile, settings, share, theme, saved, howTo, about, help }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _intro;

  /// Most recently saved match that is still in progress, offered as a
  /// one-tap "Continue" card. Null when there is none.
  GameState? _lastGame;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
    _loadLastGame();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Future<void> _loadLastGame() async {
    try {
      final games = await StorageService.loadAllGames(); // newest first
      final open = games.where((g) => !g.isComplete).toList();
      if (!mounted) return;
      setState(() => _lastGame = open.isEmpty ? null : open.first);
    } catch (_) {
      if (mounted) setState(() => _lastGame = null);
    }
  }

  /// Opens [screen] and refreshes the "Continue" card when coming back,
  /// since the player may have saved, finished or deleted a match.
  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _loadLastGame();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final tertiary = scheme.tertiary;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primary.withOpacity(0.18),
              Theme.of(context).scaffoldBackgroundColor,
              tertiary.withOpacity(0.10),
            ],
            stops: const [0, 0.45, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Column(
                      children: [
                        const SizedBox(height: 10),
                        _buildHeroTiles(primary, tertiary),
                        const SizedBox(height: 6),
                        Text(
                          'Build words. Claim points. Beat your rivals.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: scheme.onSurface.withOpacity(0.6)),
                        ),
                        const SizedBox(height: 22),
                        _stagger(
                          0.35,
                          _ModeCard(
                            title: 'Play Bot',
                            subtitle: 'Easy · Medium · Hard · Expert',
                            icon: Icons.smart_toy_rounded,
                            colors: [tertiary, Color.lerp(tertiary, primary, 0.45)!],
                            onTap: () => _open(const SetupScreen(initialVsComputer: true)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _stagger(
                          0.5,
                          _ModeCard(
                            title: 'Pass and Play',
                            subtitle: 'Pass the phone around · 2 to 4 players',
                            icon: Icons.people_alt_rounded,
                            colors: [primary, Color.lerp(primary, tertiary, 0.35)!],
                            onTap: () => _open(const SetupScreen()),
                          ),
                        ),
                        if (_lastGame != null) ...[
                          const SizedBox(height: 12),
                          _stagger(0.62, _buildContinueCard(_lastGame!)),
                        ],
                      ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10, top: 4),
                child: Text(
                  'Developed by Kunal Kumar 😎',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Fades/slides a child in once the intro animation reaches [start].
  Widget _stagger(double start, Widget child) {
    final curve = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, (start + 0.35).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, _) => Opacity(
        opacity: curve.value,
        child: Transform.translate(offset: Offset(0, (1 - curve.value) * 24), child: child),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 4),
      child: Row(
        children: [
          _buildProfileMenu(context),
        ],
      ),
    );
  }

  void _onMenuSelected(_MenuAction action) {
    switch (action) {
      case _MenuAction.profile:
        _open(const EditProfileScreen());
      case _MenuAction.settings:
        _open(const SettingsScreen());
      case _MenuAction.share:
        Share.share(
          '🎮 Check out Grid Words! A fun word-building board game '
          'you can play with up to 3 friends or against the computer — build words on a custom grid '
          'and keep score as you play.\n\n'
          'Get it here: ${AppLinks.downloadUrl}',
          subject: 'Grid Words',
        );
      case _MenuAction.theme:
        ThemeController.instance.toggleLightDark(MediaQuery.platformBrightnessOf(context));
      case _MenuAction.saved:
        _open(const SavedGamesScreen());
      case _MenuAction.howTo:
        _open(const RulesScreen());
      case _MenuAction.about:
        _open(const AboutScreen());
      case _MenuAction.help:
        _showHelp();
    }
  }

  Future<void> _showHelp() {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Questions, feedback or a problem? Email us at:'),
            const SizedBox(height: 10),
            const SelectableText(
              AppLinks.supportEmail,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: AppLinks.supportEmail));
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email address copied')),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  /// Profile avatar (top left). Everything that used to crowd the home
  /// screen - settings, sharing, theme, saved games, how to play, about and
  /// help - lives in the menu it opens.
  Widget _buildProfileMenu(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    PopupMenuItem<_MenuAction> item(_MenuAction value, IconData icon, String label) {
      return PopupMenuItem<_MenuAction>(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 22, color: scheme.primary),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
    }

    return ValueListenableBuilder<Profile>(
      valueListenable: ProfileService.current,
      builder: (context, profile, _) {
        Widget avatar(double radius) => CircleAvatar(
              radius: radius,
              backgroundColor: scheme.primary.withOpacity(0.15),
              backgroundImage: profile.hasPhoto ? MemoryImage(base64Decode(profile.photoBase64!)) : null,
              child: !profile.hasPhoto ? Icon(Icons.person, size: radius * 1.1, color: scheme.primary) : null,
            );
        final hasName = profile.name.trim().isNotEmpty;
        return PopupMenuButton<_MenuAction>(
          tooltip: 'Profile and menu',
          offset: const Offset(0, 8),
          position: PopupMenuPosition.under,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          onSelected: _onMenuSelected,
          itemBuilder: (context) => [
            PopupMenuItem<_MenuAction>(
              value: _MenuAction.profile,
              child: Row(
                children: [
                  avatar(20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hasName ? profile.name : 'Your profile',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        Text(
                          profile.email.isEmpty ? 'Tap to edit' : profile.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.6)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            item(_MenuAction.settings, Icons.settings_outlined, 'Settings'),
            item(_MenuAction.share, Icons.share_outlined, 'Share with friends'),
            item(
              _MenuAction.theme,
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              isDark ? 'Switch to light mode' : 'Switch to dark mode',
            ),
            const PopupMenuDivider(),
            item(_MenuAction.saved, Icons.folder_open_rounded, 'Saved Games'),
            item(_MenuAction.howTo, Icons.menu_book_rounded, 'How to Play'),
            item(_MenuAction.about, Icons.info_outline_rounded, 'About Us'),
            item(_MenuAction.help, Icons.help_outline_rounded, 'Help'),
          ],
          child: Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: GW.brand(context)),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withOpacity(isDark ? 0.35 : 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: scheme.surface,
              child: avatar(20),
            ),
          ),
        );
      },
    );
  }

  /// "GRID" / "WORDS" as lettered game tiles that pop in one after another
  /// and bounce when tapped.
  Widget _buildHeroTiles(Color primary, Color tertiary) {
    Widget row(String word, int offset, Color color) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < word.length; i++)
            _PopTile(
              letter: word[i],
              color: color,
              animation: CurvedAnimation(
                parent: _intro,
                curve: Interval(
                  ((offset + i) * 0.06).clamp(0.0, 0.7),
                  (((offset + i) * 0.06) + 0.3).clamp(0.0, 1.0),
                  curve: Curves.elasticOut,
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      children: [
        row('GRID', 0, primary),
        const SizedBox(height: 6),
        row('WORDS', 4, tertiary),
      ],
    );
  }

  Widget _buildContinueCard(GameState game) {
    final scheme = Theme.of(context).colorScheme;
    final title = game.vsComputer
        ? '${game.playerNames.take(game.playerCount - 1).join(', ')} vs Computer · ${game.aiDifficulty.label}'
        : game.playerNames.join(' vs ');
    final score = game.scores.join(' – ');
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _open(GameScreen(gameState: game)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.play_circle_fill_rounded, color: scheme.primary, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Continue your game', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      '$title  ·  $score',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.65)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurface.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single lettered tile that scales in with [animation] and does a
/// little bounce each time it is tapped.
class _PopTile extends StatefulWidget {
  final String letter;
  final Color color;
  final Animation<double> animation;

  const _PopTile({required this.letter, required this.color, required this.animation});

  @override
  State<_PopTile> createState() => _PopTileState();
}

class _PopTileState extends State<_PopTile> {
  bool _pressed = false;

  Future<void> _bounce() async {
    setState(() => _pressed = true);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (mounted) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) => Transform.scale(
        scale: widget.animation.value.clamp(0.0, 1.3),
        child: Opacity(opacity: widget.animation.value.clamp(0.0, 1.0), child: child),
      ),
      child: GestureDetector(
        onTap: _bounce,
        child: AnimatedScale(
          scale: _pressed ? 0.82 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: widget.color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: Text(
              widget.letter,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: ThemeData.estimateBrightnessForColor(widget.color) == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A large gradient card for a way to start playing.
class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = ThemeData.estimateBrightnessForColor(colors.first) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    return Material(
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      shadowColor: colors.first.withOpacity(0.5),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: fg.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 30, color: fg),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: fg)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: TextStyle(fontSize: 12.5, color: fg.withOpacity(0.85))),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
