import 'package:flutter/material.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rules / How to Play')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RuleSection(
                number: '1',
                title: 'Game Objective',
                body:
                    'Two players take turns building words on a shared grid, one letter per turn, '
                    'earning points for each turn as they go.',
              ),
              _RuleSection(
                number: '2',
                title: 'Setup Rules',
                body:
                    'Choose Rows (R) and Columns (C) for the board, each from 1 to 10, with at least one of '
                    'them greater than 1. Max Word Length is automatically calculated as the larger of R and '
                    'C (so always 1 to 10), and sets the range of the scoring number strip.',
              ),
              _RuleSection(
                number: '3',
                title: 'Placing a Letter',
                body:
                    'On your turn, tap any empty grid cell to highlight it, then tap an uppercase letter '
                    '(A-Z) from the Alphabet Bank to lock it into that cell. The Alphabet Bank stays on '
                    'screen the whole time — placing a letter simply greys it out until you record a score.',
              ),
              _RuleSection(
                number: '4',
                title: 'Scoring the Turn',
                body:
                    'Tap + or − on the active player\'s card to arm the Numeric Strip (0 to Max Word '
                    'Length) for adding or subtracting — you can do this before or right after placing a '
                    'letter. Then tap a number to apply it (0 is available for a failed attempt).',
              ),
              _RuleSection(
                number: '5',
                title: 'Automatic Turn Switching',
                body:
                    'As soon as a score is applied, the highlight clears and the turn automatically passes '
                    'to the other player, whose Alphabet Bank re-enables. If you change your mind before '
                    'scoring, tap "Clear Selected" to remove the placed letter and re-enable the Alphabet '
                    'Bank without switching turns.',
              ),
              _RuleSection(
                number: '6',
                title: 'Switching Players Manually',
                body:
                    'Tap the other player\'s card at any time — even while the Numeric Strip is open — '
                    'to hand them the turn directly; doing so closes the pallet again. Handy for '
                    'correcting a mistake or letting someone go out of order.',
              ),
              _RuleSection(
                number: '7',
                title: 'Fixing Mistakes',
                body:
                    'Tap any previously locked cell and use "Clear Selected" to wipe it. Use "Clear Board" '
                    'to reset every cell on the grid back to empty (confirmation required).',
              ),
              _RuleSection(
                number: '8',
                title: 'Capturing a Word',
                body:
                    'Tap "Capture" at any time to open a text box — type, speak, or glide-type the word you '
                    'formed using your device\'s own keyboard, then tap "Save Word" (or just hit done/enter). '
                    'Single letters count too. If that exact word was already captured earlier in this match, '
                    'you\'ll see a "Word : 🥲" warning and it won\'t save again; a new word shows "Word : 🤠" to '
                    'confirm it. Check the list icon in the top bar any time to see every word captured so far.',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleSection extends StatelessWidget {
  final String number;
  final String title;
  final String body;

  const _RuleSection({required this.number, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFF5B4FE9),
            child: Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(fontSize: 14, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
