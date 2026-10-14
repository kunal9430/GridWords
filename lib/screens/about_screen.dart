import 'package:flutter/material.dart';
import '../widgets/gw_kit.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GWScaffold(
      title: 'About Us',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          GWReveal(
            child: Column(
              children: [
                GWWordTiles(word: 'GRID', color: scheme.primary, size: 50),
                const SizedBox(height: 6),
                GWWordTiles(word: 'WORDS', color: scheme.tertiary, size: 50),
                const SizedBox(height: 14),
                const Wrap(
                  spacing: 8,
                  children: [
                    _Pill('Version 1.0.0'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GWReveal(
            index: 1,
            child: GWCard(
              child: Text(
                'A customizable word grid game for up to four players, with auto-calculated word lengths, '
                'a computer opponent, and saved games you can pick up any time.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.5, color: scheme.onSurface.withOpacity(0.85)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GWReveal(
            index: 2,
            child: GWCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _Feature(Icons.grid_view_rounded, 'Custom grids', 'Any board from 1 × 2 up to 10 × 10'),
                  SizedBox(height: 14),
                  _Feature(Icons.people_alt_rounded, 'Up to 4 players', 'Pass and Play with friends, or add the Bot'),
                  SizedBox(height: 14),
                  _Feature(Icons.smart_toy_rounded, 'Play Bot', 'Four levels, from Easy to Expert'),
                  SizedBox(height: 14),
                  _Feature(Icons.folder_open_rounded, 'Saved games', 'Pick any match up where you left it'),
                  SizedBox(height: 14),
                  _Feature(Icons.palette_rounded, 'Your look', 'Dozens of color themes and fonts'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GWReveal(
            index: 3,
            child: GWCard(
              child: Row(
                children: [
                  const GWIconTile(icon: Icons.code_rounded),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Developer', style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.6))),
                      const Text('Kunal Kumar 😎', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);

  @override
  Widget build(BuildContext context) =>
      GWBadge(text: text, color: Theme.of(context).colorScheme.primary, icon: Icons.verified_rounded);
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Feature(this.icon, this.title, this.subtitle);

  @override
  Widget build(BuildContext context) => GWSectionTitle(icon: icon, title: title, subtitle: subtitle);
}
