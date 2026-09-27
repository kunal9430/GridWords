import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../config/app_links.dart';
import '../services/profile_service.dart';
import 'setup_screen.dart';
import 'saved_games_screen.dart';
import 'rules_screen.dart';
import 'about_screen.dart';
import 'settings_screen.dart';
import '../services/theme_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          IconButton(
            tooltip: 'Share with friends',
            icon: const Icon(Icons.share),
            onPressed: () => Share.share(
              '🎮 Check out Grid Words! A fun word-building board game '
              'for two players — build words together on a custom grid and keep score as you play.\n\n'
              'Get it here: ${AppLinks.downloadUrl}',
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
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: ValueListenableBuilder<Profile>(
                    valueListenable: ProfileService.current,
                    builder: (context, profile, _) {
                      final hasName = profile.name.trim().isNotEmpty;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (hasName || profile.hasPhoto) ...[
                            CircleAvatar(
                              radius: 34,
                              backgroundColor: primary.withOpacity(0.15),
                              backgroundImage:
                                  profile.hasPhoto ? MemoryImage(base64Decode(profile.photoBase64!)) : null,
                              child: !profile.hasPhoto ? Icon(Icons.person, size: 34, color: primary) : null,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              hasName ? 'Welcome back, ${profile.name}!' : 'Welcome back!',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: primary),
                            ),
                            const SizedBox(height: 18),
                          ] else ...[
                            Icon(Icons.grid_on, size: 72, color: primary),
                            const SizedBox(height: 12),
                          ],
                          Text(
                            'Grid Words',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primary),
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
                      );
                    },
                  ),
                ),
              ),
            ),
            // Developer credit, pinned to the bottom of the screen the
            // player lands on when opening the app.
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 4),
              child: Text(
                'Developed by Kunal Kumar 😎',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
              ),
            ),
          ],
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
          backgroundColor: Theme.of(context).colorScheme.primary,
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
