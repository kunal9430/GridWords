import 'package:flutter/material.dart';
import '../widgets/gw_kit.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  static const List<_Rule> _rules = [
    _Rule('1', 'Game Objective', Icons.flag_rounded,
        'Two or three players take turns building words on a shared grid, one letter per turn, '
                    'earning points for each turn as they go.'),
    _Rule('2', 'Setup Rules', Icons.tune_rounded,
        'Pick Pass and Play or Play Bot, then how many players (2 or 3 in total, the Computer included). Choose Rows (R) and Columns (C) for the board, each from 1 to 10, with at least one of '
                    'them greater than 1. Max Word Length is automatically calculated as the larger of R and '
                    'C (so always 1 to 10), and sets the range of the scoring number strip.'),
    _Rule('3', 'Placing a Letter', Icons.touch_app_rounded,
        'On your turn, tap any empty grid cell to highlight it, then tap an uppercase letter '
                    '(A-Z) from the Alphabet Bank to lock it into that cell. The Alphabet Bank stays on '
                    'screen the whole time — placing a letter simply greys it out until you record a score.'),
    _Rule('4', 'Scoring the Turn', Icons.calculate_rounded,
        'Tap + or − on the active player\'s card to arm the Numeric Strip (0 to Max Word '
                    'Length) for adding or subtracting — you can do this before or right after placing a '
                    'letter. Then tap a number to apply it (0 is available for a failed attempt).'),
    _Rule('5', 'Automatic Turn Switching', Icons.swap_horiz_rounded,
        'As soon as a score is applied, the highlight clears and the turn automatically passes '
                    'to the next player, whose Alphabet Bank re-enables. If you change your mind before '
                    'scoring, tap "Clear Selected" to remove the placed letter and re-enable the Alphabet '
                    'Bank without switching turns.'),
    _Rule('6', 'Switching Players Manually', Icons.people_alt_rounded,
        'Tap another player\'s card at any time — even while the Numeric Strip is open — '
                    'to hand them the turn directly; doing so closes the pallet again. Handy for '
                    'correcting a mistake or letting someone go out of order.'),
    _Rule('7', 'Fixing Mistakes', Icons.undo_rounded,
        'Tap any previously locked cell and use "Clear Selected" to wipe it. Use "Clear Board" '
                    'to reset every cell on the grid back to empty (confirmation required).'),
    _Rule('8', 'Capturing a Word', Icons.text_fields_rounded,
        'Tap "Capture" at any time to open a text box — type, speak, or glide-type the word you '
                    'formed using your device\'s own keyboard, then tap "Save Word" (or just hit done/enter). '
                    'Single letters count too. If that exact word was already captured earlier in this match, '
                    'you\'ll see a "Word : 🥲" warning and it won\'t save again; a new word shows "Word : 🤠" to '
                    'confirm it. Check the list icon in the top bar any time to see every word captured so far.'),
    _Rule('9', 'Play Bot', Icons.smart_toy_rounded,
        'Choose "Play Bot" and a difficulty (Easy, Medium, Hard, Expert) on the setup screen. '
                    'The computer always plays last: with you alone it is Player 2, and with friends it takes the final turn of every round. Pick who plays first under "Who plays first?". After the last person records their score, '
                    'the computer places one letter, scores itself, and hands the turn back to Player 1 — highlighted in '
                    'the computer\'s color on the board. It plays by the same rules: words are runs of touching letters in a '
                    'straight line (across, down or diagonally, read either way) that include its new letter, '
                    'a word scores its length, and a word can only score once per match. If one letter forms '
                    'several words it claims the longest. When nothing scores it still has to place a letter, '
                    'for 0.\n\n'
                    'Think the computer used a word you had already played? Tap "Used?" in the bottom bar. '
                    'It takes its move back, adds that word to the used words and tries again. '
                    'Before the computer finishes the game with a word it will ask you whether that word '
                    'was already used, and picks another move if you say yes.'),
    _Rule('10', 'Computer Vocabulary', Icons.spellcheck_rounded,
        'The computer only plays the base (1st) form of a verb — walk, build, go — and never the past '
        '(walked, ran), the past participle (gone, broken) or the -ing form (walking, building).'),
    _Rule('11', 'Playing Online', Icons.public_rounded,
        'Tap "Play Online" on the home screen and sign in with Google (online play is the only part that needs an '
        'account). One person creates a room and shares its 6-character code; up to two friends join with it on '
        'their own phones, then the host starts the game. Your screen shows your own score card beside a live '
        'leaderboard, and you can place a letter and score only on your turn. If you leave or lose your connection, '
        'sign in with the same Google account and enter the same code to jump back into your seat, even after the '
        'game has started. Online games have no computer player.'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GWScaffold(
      title: 'How to Play',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          GWReveal(
            child: GWCard(
              gradient: LinearGradient(
                colors: [scheme.primary.withOpacity(0.16), scheme.tertiary.withOpacity(0.14)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: Column(
                children: [
                  GWWordTiles(word: 'GRID', color: scheme.primary, size: 38),
                  const SizedBox(height: 5),
                  GWWordTiles(word: 'WORDS', color: scheme.tertiary, size: 38),
                  const SizedBox(height: 12),
                  Text(
                    'Everything you need to know in ${_rules.length} quick steps',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: scheme.onSurface.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < _rules.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GWReveal(index: i + 1, child: _RuleSection(rule: _rules[i])),
            ),
        ],
      ),
    );
  }
}

class _Rule {
  final String number;
  final String title;
  final IconData icon;
  final String body;
  const _Rule(this.number, this.title, this.icon, this.body);
}

class _RuleSection extends StatelessWidget {
  final _Rule rule;

  const _RuleSection({required this.rule});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = GW.brand(context);
    return GWCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: brand, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  rule.number,
                  style: TextStyle(color: GW.onColor(brand.first), fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(rule.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              Icon(rule.icon, size: 22, color: scheme.primary.withOpacity(0.7)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rule.body,
            style: TextStyle(fontSize: 14, height: 1.45, color: scheme.onSurface.withOpacity(0.85)),
          ),
        ],
      ),
    );
  }
}
