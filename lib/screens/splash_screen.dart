import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backup_service.dart';
import 'home_screen.dart';

/// A short branded opening screen shown once at launch. Pure Flutter,
/// no extra packages: a fade + scale entrance for the app mark, then an
/// automatic hand-off to the Home screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const String _backupPromptShownKey = 'backup_first_run_prompt_shown';

  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeIn));
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101018) : primary,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Icon(Icons.grid_on, size: 56, color: primary),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Grid Words',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.2),
                      ),
                    ],
                  ),
                ),
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
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
