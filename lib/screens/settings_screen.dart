import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/backup_service.dart';
import '../services/brightness_controller.dart';
import '../services/profile_service.dart';
import '../services/theme_controller.dart';
import '../theme/app_theme.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Each section lives in its own tab instead of one long stacked
    // page — the Theme & Appearance section in particular used to push
    // Display/Profile far down the scroll; now every section gets the
    // full screen to itself and switching between them is one tap.
    return DefaultTabController(
      length: 4,
      child: Builder(
        builder: (context) {
          // AppBarTheme already computes a foreground color that contrasts
          // with the AppBar's background in both modes (see app_theme.dart)
          // -- the title and back arrow use it automatically. TabBar does
          // NOT inherit that though; it has its own default label colors
          // (Theme.of(context).colorScheme.primary for the selected tab),
          // which in light mode is the SAME color as the AppBar background
          // itself, making the active tab invisible. Pin the TabBar's
          // colors to the same contrasting foreground explicitly.
          final tabForeground = Theme.of(context).appBarTheme.foregroundColor ?? Theme.of(context).colorScheme.onPrimary;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Settings'),
              bottom: TabBar(
                isScrollable: true,
                // Material 3's default for a scrollable TabBar adds a
                // leading inset (TabAlignment.startOffset) sized to sit
                // next to a leading widget -- that's what was pushing the
                // tabs to the right and cutting "Backup" off screen.
                // TabAlignment.start removes that inset so tabs sit flush
                // against the left edge.
                tabAlignment: TabAlignment.start,
                labelColor: tabForeground,
                unselectedLabelColor: tabForeground.withOpacity(0.7),
                indicatorColor: tabForeground,
                tabs: const [
                  Tab(icon: Icon(Icons.palette_outlined), text: 'Appearance'),
                  Tab(icon: Icon(Icons.brightness_6_outlined), text: 'Display'),
                  Tab(icon: Icon(Icons.person_outline), text: 'Profile'),
                  Tab(icon: Icon(Icons.backup_outlined), text: 'Backup'),
                ],
              ),
            ),
            body: const TabBarView(
              children: [
                _AppearanceTab(),
                _DisplayTab(),
                _ProfileTab(),
                _BackupTab(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AppearanceTab extends StatelessWidget {
  const _AppearanceTab();

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AppearanceCard(controller: controller, platformBrightness: platformBrightness),
        ],
      ),
    );
  }
}

class _DisplayTab extends StatelessWidget {
  const _DisplayTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _BrightnessCard(),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ValueListenableBuilder<Profile>(
                valueListenable: ProfileService.current,
                builder: (context, profile, _) {
                  return Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: primary.withOpacity(0.15),
                        backgroundImage: profile.hasPhoto ? MemoryImage(base64Decode(profile.photoBase64!)) : null,
                        child: !profile.hasPhoto ? Icon(Icons.person, size: 28, color: primary) : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.name.isEmpty ? 'No name set' : profile.name,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              profile.email.isEmpty ? 'No email set' : profile.email,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Profile Details'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupTab extends StatefulWidget {
  const _BackupTab();

  @override
  State<_BackupTab> createState() => _BackupTabState();
}

class _BackupTabState extends State<_BackupTab> {
  bool _busy = false;

  Future<void> _createBackup() async {
    setState(() => _busy = true);
    try {
      await BackupService.shareBackup();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't create the backup file. Please try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text(
          'This will replace your current profile and appearance settings, and add every saved game from '
          'the backup file. This cannot be undone. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: false,
      );
      final path = result?.files.single.path;
      if (path == null) {
        setState(() => _busy = false);
        return;
      }
      final summary = await BackupService.restoreFromFile(File(path));
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restored ${summary.restoredGames} saved game(s) and your profile.')),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't read that backup file.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Backup & Restore', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    'Back up your profile and saved games, or restore them from a file.',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _createBackup,
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Create & Share Backup'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _restoreBackup,
                      icon: const Icon(Icons.file_open_outlined),
                      label: const Text('Restore from Backup File'),
                    ),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  final ThemeController controller;
  final Brightness platformBrightness;

  const _AppearanceCard({required this.controller, required this.platformBrightness});

  bool _effectiveIsDark(ThemeMode mode) =>
      mode == ThemeMode.dark || (mode == ThemeMode.system && platformBrightness == Brightness.dark);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mode', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: controller.themeMode,
              builder: (context, mode, _) {
                return SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                  ],
                  selected: {mode},
                  onSelectionChanged: (selection) => controller.setThemeMode(selection.first),
                );
              },
            ),
            const SizedBox(height: 20),
            // Context-aware: System mode always uses the classic default
            // look (no swatch to pick, and picking System resets any
            // previously-chosen swatch back to classic), so the color
            // picker only appears once the player explicitly chooses
            // Light or Dark — and then shows only that mode's swatches.
            ValueListenableBuilder<ThemeMode>(
              valueListenable: controller.themeMode,
              builder: (context, mode, _) {
                if (mode == ThemeMode.system) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'System mode uses the classic Grid Words look and follows your device\'s '
                      'light/dark setting. Switch to Light or Dark below to pick a custom color theme.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  );
                }
                final isDark = _effectiveIsDark(mode);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDark ? 'Night Mode Colors' : 'Light Mode Colors',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    isDark
                        ? ValueListenableBuilder<int>(
                            valueListenable: controller.darkThemeIndex,
                            builder: (context, selectedIndex, _) => _ColorThemeRow(
                              options: AppTheme.darkThemes,
                              selectedIndex: selectedIndex,
                              onSelected: controller.setDarkThemeIndex,
                            ),
                          )
                        : ValueListenableBuilder<int>(
                            valueListenable: controller.lightThemeIndex,
                            builder: (context, selectedIndex, _) => _ColorThemeRow(
                              options: AppTheme.lightThemes,
                              selectedIndex: selectedIndex,
                              onSelected: controller.setLightThemeIndex,
                            ),
                          ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            const Text('Font Size', style: TextStyle(fontWeight: FontWeight.w600)),
            ValueListenableBuilder<double>(
              valueListenable: controller.fontScale,
              builder: (context, scale, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Slider(
                      value: scale,
                      min: 0.85,
                      max: 1.3,
                      divisions: 9,
                      label: '${(scale * 100).round()}%',
                      onChanged: (value) => controller.setFontScale(value),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Sample text at ${(scale * 100).round()}%',
                        // Wrapped so this preview shows the RAW size at
                        // this slider value, not the size multiplied by
                        // itself via the app-wide scaler this same
                        // slider also drives (see main.dart).
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(fontSize: 16 * scale),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BrightnessCard extends StatelessWidget {
  const _BrightnessCard();

  @override
  Widget build(BuildContext context) {
    final controller = BrightnessController.instance;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<double?>(
          valueListenable: controller.level,
          builder: (context, level, _) {
            final overrideEnabled = level != null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('App Screen Brightness', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Switch(
                      value: overrideEnabled,
                      onChanged: (enabled) {
                        if (enabled) {
                          controller.setLevel(level ?? 0.7);
                        } else {
                          controller.resetToSystem();
                        }
                      },
                    ),
                  ],
                ),
                const Text(
                  'Adjust the game screen brightness',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
                if (overrideEnabled) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.brightness_low, size: 18),
                      Expanded(
                        child: Slider(
                          value: level,
                          min: 0.05,
                          max: 1.0,
                          onChanged: controller.setLevel,
                        ),
                      ),
                      const Icon(Icons.brightness_high, size: 20),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ColorThemeRow extends StatelessWidget {
  final List<ColorThemeOption> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _ColorThemeRow({required this.options, required this.selectedIndex, required this.onSelected});

  static Widget _dot(Color color, bool selected) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 0.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 10,
      children: List.generate(options.length, (i) {
        final option = options[i];
        final isSelected = i == selectedIndex;
        return GestureDetector(
          onTap: () => onSelected(i),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: option.background,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? option.primary : Colors.grey.withOpacity(0.4),
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 3, offset: const Offset(0, 1))
                      ],
                    ),
                    // Three small dots — primary, secondary, tertiary — so
                    // the theme's real multi-color identity is visible at
                    // a glance, not just a single accent-on-background dot.
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _dot(option.primary, isSelected),
                          const SizedBox(width: 2),
                          _dot(option.secondary, false),
                          const SizedBox(width: 2),
                          _dot(option.tertiary, false),
                        ],
                      ),
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: option.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Icon(Icons.check, size: 10, color: AppTheme.onColorFor(option.primary)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 62,
                child: Text(
                  option.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
