import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../config/app_links.dart';
import 'setup_screen.dart';
import 'saved_games_screen.dart';
import 'rules_screen.dart';
import 'about_screen.dart';
import '../services/theme_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Share with friends',
            icon: const Icon(Icons.share),
            onPressed: () => Share.share(
              '🎮 Check out Grid Words! A fun word-building board game '
              'for two players — build words together on a custom grid and keep score as you play.\n\n'
              'Get it here: ${AppLinks.playStoreUrl}',
              subject: 'Grid Words',
            ),
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.instance.themeMode,
            builder: (context, mode, _) {
              final platformBrightness = MediaQuery.platformBrightnessOf(context);
              final isDark = mode == ThemeMode.dark ||
                  (mode == ThemeMode.system && platformBrightness == Brightness.dark);
              return IconButton(
                tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => ThemeController.instance.toggleLightDark(platformBrightness),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.grid_on, size: 72, color: Color(0xFF5B4FE9)),
                const SizedBox(height: 12),
                const Text(
                  'Grid Words',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5B4FE9)),
                ),
                const SizedBox(height: 40),
                _HomeButton(
                  label: 'Start New Game',
                  icon: Icons.play_arrow,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SetupScreen()),
                  ),
                ),
                const SizedBox(height: 16),
                _HomeButton(
                  label: 'Resume Saved Game',
                  icon: Icons.folder_open,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SavedGamesScreen()),
                  ),
                ),
                const SizedBox(height: 16),
                _HomeButton(
                  label: 'Rules / How to Play',
                  icon: Icons.menu_book,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RulesScreen()),
                  ),
                ),
                const SizedBox(height: 16),
                _HomeButton(
                  label: 'About',
                  icon: Icons.info_outline,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _HomeButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5B4FE9),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 3,
        ),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
