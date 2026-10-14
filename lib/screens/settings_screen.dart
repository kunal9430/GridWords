import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/backup_service.dart';
import '../services/brightness_controller.dart';
import '../services/profile_service.dart';
import '../services/theme_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/gw_kit.dart';
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
          final scheme = Theme.of(context).colorScheme;
          return GWScaffold(
            title: 'Settings',
            bottom: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  gradient: LinearGradient(colors: GW.brand(context)),
                  borderRadius: BorderRadius.circular(14),
                ),
                labelColor: GW.onColor(scheme.primary),
                unselectedLabelColor: scheme.onSurface.withOpacity(0.7),
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(height: 40, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.palette_outlined, size: 18), SizedBox(width: 6), Text('Appearance')])),
                  Tab(height: 40, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.brightness_6_outlined, size: 18), SizedBox(width: 6), Text('Display')])),
                  Tab(height: 40, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.person_outline, size: 18), SizedBox(width: 6), Text('Profile')])),
                  Tab(height: 40, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.backup_outlined, size: 18), SizedBox(width: 6), Text('Backup')])),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        GWReveal(child: _AppearanceCard(controller: controller, platformBrightness: platformBrightness)),
      ],
    );
  }
}

class _DisplayTab extends StatelessWidget {
  const _DisplayTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: const [
        GWReveal(child: _BrightnessCard()),
      ],
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        GWReveal(
          child: GWCard(
            gradient: LinearGradient(
              colors: [primary.withOpacity(0.16), scheme.tertiary.withOpacity(0.14)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: ValueListenableBuilder<Profile>(
              valueListenable: ProfileService.current,
              builder: (context, profile, _) {
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: GW.brand(context)),
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: scheme.surface,
                        backgroundImage: profile.hasPhoto ? MemoryImage(base64Decode(profile.photoBase64!)) : null,
                        child: !profile.hasPhoto ? Icon(Icons.person, size: 30, color: primary) : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name.isEmpty ? 'No name set' : profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profile.email.isEmpty ? 'No email set' : profile.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: scheme.onSurface.withOpacity(0.65), fontSize: 13),
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
        GWReveal(
          index: 1,
          child: GWCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
            child: const Row(
              children: [
                GWIconTile(icon: Icons.edit_rounded, size: 38),
                SizedBox(width: 12),
                Expanded(child: Text('Edit Profile Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ],
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
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        GWReveal(
          child: GWCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GWSectionTitle(
                  icon: Icons.cloud_sync_rounded,
                  title: 'Backup & Restore',
                  subtitle: 'Keep your profile and saved games safe',
                ),
                const SizedBox(height: 14),
                Text(
                  'Back up your profile and saved games, or restore them from a file.',
                  style: TextStyle(fontSize: 13, height: 1.4, color: scheme.onSurface.withOpacity(0.7)),
                ),
                const SizedBox(height: 20),
                GWGradientButton(
                  label: 'Create & Share Backup',
                  icon: Icons.ios_share,
                  loading: _busy,
                  onPressed: _busy ? null : _createBackup,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _restoreBackup,
                    icon: const Icon(Icons.file_open_outlined),
                    label: const Text('Restore from Backup File'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
    return GWCard(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GWSectionTitle(icon: Icons.contrast_rounded, title: 'Mode', subtitle: 'Follow the device, or pick light / dark'),
            const SizedBox(height: 12),
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
            const GWSectionTitle(icon: Icons.format_size_rounded, title: 'Font Size'),
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
    return GWCard(
      child: Padding(
        padding: EdgeInsets.zero,
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
                      child: GWSectionTitle(icon: Icons.brightness_6_rounded, title: 'App Screen Brightness'),
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
                  style: TextStyle(fontSize: 12, color: Colors.grey),
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
