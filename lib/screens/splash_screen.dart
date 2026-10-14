import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backup_service.dart';
import '../widgets/gw_kit.dart';
import 'home_screen.dart';

/// A short branded opening screen shown once at launch. Pure Flutter,
/// no extra packages: the same lettered GRID / WORDS tiles as the Home
/// screen pop in one after another on the Home gradient, then an automatic
/// hand-off to the Home screen (so the logo seems to simply carry over).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const String _backupPromptShownKey = 'backup_first_run_prompt_shown';

  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _fade = CurvedAnimation(parent: _controller, curve: const Interval(0.55, 1.0, curve: Curves.easeIn));
    _controller.forward();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    await _maybeOfferBackupRestore();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  /// There's no sign-in (yet), so a reinstalled app looks exactly like a
  /// brand-new one — nothing on this device says "this player has a
  /// backup out there". The best we can do without a fixed guessed file
  /// path or broad storage permissions (both unreliable on modern,
  /// scoped-storage Android) is: the first time this device ever shows
  /// no local profile and no saved games, offer to restore from a
  /// backup file the player picks themselves. Shown at most once ever,
  /// so returning players are never interrupted by it again.
  Future<void> _maybeOfferBackupRestore() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_backupPromptShownKey) ?? false) return;

    final looksFresh = await BackupService.looksLikeFreshInstall();
    await prefs.setBool(_backupPromptShownKey, true);
    if (!looksFresh || !mounted) return;

    final wantsRestore = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Welcome to Grid Words'),
        content: const Text(
          "Looks like this is a fresh install. If you have a Grid Words backup file from before, "
          "you can restore your profile and saved games now — or skip and start fresh.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Skip')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore Backup')),
        ],
      ),
    );
    if (wantsRestore != true || !mounted) return;
    await _pickAndRestoreBackup();
  }

  Future<void> _pickAndRestoreBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: false,
      );
      final path = result?.files.single.path;
      if (path == null || !mounted) return;
      final summary = await BackupService.restoreFromFile(File(path));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restored ${summary.restoredGames} saved game(s) and your profile.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't read that backup file — you can try again anytime from Settings.")),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: GWBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GWWordTiles(word: 'GRID', color: scheme.primary, size: 52, controller: _controller),
                    const SizedBox(height: 8),
                    GWWordTiles(word: 'WORDS', color: scheme.tertiary, size: 52, controller: _controller, startIndex: 4),
                    const SizedBox(height: 22),
                    FadeTransition(
                      opacity: _fade,
                      child: Text(
                        'Build words. Claim points. Beat your rival.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: scheme.onSurface.withOpacity(0.6)),
                      ),
                    ),
                  ],
                ),
              ),
              // Developer credit, pinned to the bottom of the splash screen
              // rather than sitting directly under the title.
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: FadeTransition(
                  opacity: _fade,
                  child: Text(
                    'by Kunal Kumar 😎',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurface.withOpacity(0.5), fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
