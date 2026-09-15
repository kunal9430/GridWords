import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../config/app_links.dart';
import '../models/game_state.dart';
import '../services/storage_service.dart';
import '../widgets/alphabet_bank.dart';
import '../widgets/numeric_strip.dart';
import '../widgets/player_score_card.dart';
import 'setup_screen.dart';

class GameScreen extends StatefulWidget {
  final GameState gameState;
  const GameScreen({super.key, required this.gameState});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late GameState state;

  // Ephemeral UI-only selection (not persisted): which cell is currently
  // highlighted while choosing where to place a letter. Restored to the
  // pending cell on resume so a mid-turn save doesn't lose the highlight.
  int? selectedRow;
  int? selectedCol;

  // ---------------------------------------------------------------------
  // Capture Word: a floating top banner confirms/warns after each capture
  // attempt. Auto-dismisses itself after a couple of seconds.
  // ---------------------------------------------------------------------
  String? _bannerText;
  bool _bannerIsWarning = false;
  Timer? _bannerTimer;

  // Guards the celebratory dialog so it only ever pops up once per
  // completion event, not every rebuild — and not at all when simply
  // resuming a match that was already finished when it was saved.
  bool _gameOverDialogShown = false;

  @override
  void initState() {
    super.initState();
    state = widget.gameState;
    if (state.scoringArmed && state.pendingRow != null && state.pendingCol != null) {
      selectedRow = state.pendingRow;
      selectedCol = state.pendingCol;
    }
    _gameOverDialogShown = state.isComplete;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerTimer?.cancel();
    super.dispose();
  }

  /// Silently persists progress whenever the app leaves the foreground —
  /// but only for matches still in progress. A finished match is only
  /// ever saved if the player explicitly taps Save.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (state.isComplete) return;
    if (lifecycleState == AppLifecycleState.inactive ||
        lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.detached) {
      StorageService.saveGame(state);
    }
  }

  // ---------------------------------------------------------------------
  // Phase A: Letter placement
  // ---------------------------------------------------------------------

  void _onCellTap(int r, int c) {
    // Highlighting a cell is always allowed — even while the Numeric
    // Strip is armed — the Alphabet Bank itself stays disabled until the
    // pallet is closed, so no letter can actually be entered meanwhile.
    setState(() {
      selectedRow = r;
      selectedCol = c;
    });
  }

  // ---------------------------------------------------------------------
  // Capture Word: type (or speak/glide-type via the device keyboard) the
  // word you formed. Checked against this match's usedWords list.
  // ---------------------------------------------------------------------

  void _startCapture() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Capture Word'),
          content: TextField(
            controller: controller,
            autofocus: true, // opens the device keyboard immediately
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: 'Type, speak, or glide the word'),
            onSubmitted: (_) => _submitCapturedWord(ctx, controller.text),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => _submitCapturedWord(ctx, controller.text),
              child: const Text('Save Word'),
            ),
          ],
        );
      },
    );
  }

  void _submitCapturedWord(BuildContext dialogContext, String rawInput) {
    // Strip anything that isn't a letter (stray spaces, punctuation the
    // keyboard/voice-typing might slip in) and uppercase. Single-letter
    // words are valid.
    final word = rawInput.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    if (word.isEmpty) return; // nothing typed — leave the dialog open
    Navigator.pop(dialogContext);
    if (state.isWordUsed(word)) {
      _showTopBanner(word, isWarning: true);
      return;
    }
    setState(() => state.addUsedWord(word));
    _showTopBanner(word, isWarning: false);
  }

  void _showTopBanner(String word, {required bool isWarning}) {
    _bannerTimer?.cancel();
    setState(() {
      _bannerText = isWarning ? 'Word : $word 🥲' : 'Word : $word 🤠';
      _bannerIsWarning = isWarning;
    });
    _bannerTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _bannerText = null);
    });
  }

  Widget _buildTopBanner() {
    final bg = _bannerIsWarning ? Colors.amber.shade200 : Colors.green.shade200;
    final border = _bannerIsWarning ? Colors.amber.shade700 : Colors.green.shade700;
    final fg = _bannerIsWarning ? Colors.amber.shade900 : Colors.green.shade900;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Text(
        _bannerText ?? '',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  void _showUsedWordsDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Used Words'),
        content: SizedBox(
          width: double.maxFinite,
          child: state.usedWords.isEmpty
              ? const Text('No words captured yet.')
              : SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: state.usedWords
                        .map((w) => Chip(label: Text(w)))
                        .toList(),
                  ),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _onLetterTap(String letter) {
    if (state.scoringArmed) return;
    if (selectedRow == null || selectedCol == null) return;
    final r = selectedRow!;
    final c = selectedCol!;
    if (state.locked[r][c]) return; // locked cells are non-editable
    setState(() {
      state.grid[r][c] = letter;
      state.locked[r][c] = true;
      state.pendingRow = r;
      state.pendingCol = c;
      state.scoringArmed = true;
    });
  }

  // ---------------------------------------------------------------------
  // Scoring — tapping Add(+)/Minus(-) immediately arms the Numeric Strip
  // for the active player, whether or not a letter has been placed yet.
  // ---------------------------------------------------------------------

  /// Tapping Add(+)/Minus(-) arms the Numeric Strip for the active player,
  /// whether or not a letter has been placed yet. Tapping the SAME
  /// already-active direction again toggles the pallet back off.
  void _setScoreDirection(int playerNumber, bool addMode) {
    if (state.currentTurn != playerNumber || state.isComplete) return;
    setState(() {
      if (state.scoringArmed && state.isAddMode == addMode) {
        state.scoringArmed = false; // second tap on the same button closes it
      } else {
        state.isAddMode = addMode;
        state.scoringArmed = true;
      }
    });
  }

  void _onNumberTap(int number) {
    if (!state.scoringArmed) return; // only active once armed
    setState(() {
      final delta = state.isAddMode ? number : -number;
      if (state.currentTurn == 1) {
        state.score1 += delta;
      } else {
        state.score2 += delta;
      }
      // Clear the active highlight.
      selectedRow = null;
      selectedCol = null;
      state.pendingRow = null;
      state.pendingCol = null;
      // Automatically switch the active turn and re-enable letter placement.
      state.currentTurn = state.currentTurn == 1 ? 2 : 1;
      state.scoringArmed = false;
      state.isAddMode = true;
    });
    _maybeShowGameOverDialog();
  }

  /// Manually hands the active turn to [playerNumber] — e.g. to correct a
  /// mistake or let the other player go without recording a score. Allowed
  /// even while the Numeric Strip is armed — switching simply closes the
  /// pallet again rather than being blocked by it.
  void _switchTurn(int playerNumber) {
    if (state.isComplete) return;
    if (state.currentTurn == playerNumber) return;
    setState(() {
      state.currentTurn = playerNumber;
      state.scoringArmed = false;
      state.isAddMode = true;
    });
  }

  // ---------------------------------------------------------------------
  // Clear actions
  // ---------------------------------------------------------------------

  void _clearSelected() {
    if (selectedRow == null || selectedCol == null) return;
    final r = selectedRow!;
    final c = selectedCol!;
    if (!state.locked[r][c]) return;
    setState(() {
      state.grid[r][c] = '';
      state.locked[r][c] = false;
      // If this was the letter awaiting a score this turn, clean up the
      // pending pointer and close the pallet if it's still open — this
      // also applies if the pallet was already closed by a manual turn
      // switch, so the stale pointer doesn't linger.
      if (state.pendingRow == r && state.pendingCol == c) {
        state.scoringArmed = false;
        state.pendingRow = null;
        state.pendingCol = null;
        state.isAddMode = true;
      }
    });
  }

  Future<void> _clearBoard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Board'),
        content: const Text('This will clear all letters on the board. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        state.grid = List.generate(state.rows, (_) => List.generate(state.cols, (_) => ''));
        state.locked = List.generate(state.rows, (_) => List.generate(state.cols, (_) => false));
        selectedRow = null;
        selectedCol = null;
        state.scoringArmed = false;
        state.pendingRow = null;
        state.pendingCol = null;
        state.isAddMode = true;
        _gameOverDialogShown = false;
      });
    }
  }

  Future<void> _saveGame() async {
    await StorageService.saveGame(state);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Game saved successfully')),
    );
  }

  // ---------------------------------------------------------------------
  // Game-over detection
  // ---------------------------------------------------------------------

  String _winnerLabel() {
    if (state.score1 == state.score2) return "It's a tie!";
    return state.score1 > state.score2
        ? '${state.player1Initials} wins!'
        : '${state.player2Initials} wins!';
  }

  Future<void> _maybeShowGameOverDialog() async {
    if (!state.isComplete || _gameOverDialogShown) return;
    _gameOverDialogShown = true;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('🎉 Game Over!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_winnerLabel(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('${state.player1Initials}: ${state.score1}   •   ${state.player2Initials}: ${state.score2}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Back')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SetupScreen()),
              );
            },
            child: const Text('Start New Game'),
          ),
        ],
      ),
    );
  }

  void _shareResult() {
    Share.share(
      '🎮 Grid Words result:\n'
      '${state.player1Initials}: ${state.score1}  vs  ${state.player2Initials}: ${state.score2}\n'
      '${_winnerLabel()}\n\n'
      'Play Grid Words yourself: ${AppLinks.downloadUrl}',
    );
  }

  // ---------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------

  Widget _buildCell(int r, int c, double cellSize, bool isDark) {
    final isSelected = selectedRow == r && selectedCol == c;
    final isLocked = state.locked[r][c];
    final letter = state.grid[r][c];
    final letterColor = isDark ? Colors.indigo.shade100 : Colors.indigo.shade700;
    final fontSize = (cellSize * 0.42).clamp(10.0, 34.0);

    return GestureDetector(
      onTap: () => _onCellTap(r, c),
      child: Container(
        width: cellSize - 3,
        height: cellSize - 3,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: isLocked
              ? (isDark ? Colors.indigo.shade900 : const Color(0xFFDDE4FF))
              : (isDark ? const Color(0xFF1E1E28) : Colors.white),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? Colors.deepOrange : (isDark ? Colors.grey.shade700 : Colors.grey.shade400),
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                letter,
                style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: letterColor),
              ),
            ),
            // Lock icon gives locked cells a non-color-dependent
            // affordance for colorblind accessibility.
            if (isLocked && cellSize > 26)
              Positioned(
                right: 2,
                bottom: 1,
                child: Icon(Icons.lock, size: (cellSize * 0.18).clamp(7.0, 12.0), color: letterColor.withOpacity(0.65)),
              ),
          ],
        ),
      ),
    );
  }

  /// Computes an exact cell size that guarantees the whole R x C grid fits
  /// within the space [constraints] gives it — no scrolling, ever.
  Widget _buildGrid(BoxConstraints constraints) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double rawCell = (constraints.maxWidth / state.cols) < (constraints.maxHeight / state.rows)
        ? constraints.maxWidth / state.cols
        : constraints.maxHeight / state.rows;
    // Tiny safety margin (0.96x) against rounding, capped so cells never
    // look comically oversized on tablets/landscape.
    final double cellSize = (rawCell * 0.96).clamp(10.0, 72.0);

    return Center(
      child: SizedBox(
        width: cellSize * state.cols,
        height: cellSize * state.rows,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            state.rows,
            (r) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(state.cols, (c) => _buildCell(r, c, cellSize, isDark)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2510) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0B23B)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 24)),
          const SizedBox(height: 2),
          Text(_winnerLabel(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareResult,
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('Share', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const SetupScreen()),
                  ),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('New Game', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The Alphabet Bank always stays on screen — it never disappears —
  /// but is disabled (greyed out, non-tappable) whenever a score is
  /// outstanding or no valid empty cell is selected yet. Once the match
  /// is finished it's replaced by the winner summary instead.
  Widget _buildBottomPanel() {
    if (state.isComplete) return _buildGameOverPanel();
    final bankEnabled = !state.scoringArmed &&
        selectedRow != null &&
        selectedCol != null &&
        !state.locked[selectedRow!][selectedCol!];
    return AlphabetBank(onLetterTap: _onLetterTap, enabled: bankEnabled);
  }

  Widget _buildScoreboard() {
    final p1ControlsEnabled = state.currentTurn == 1 && !state.isComplete;
    final p2ControlsEnabled = state.currentTurn == 2 && !state.isComplete;
    return Column(
      children: [
        Row(
          children: [
            PlayerScoreCard(
              initials: state.player1Initials,
              score: state.score1,
              isAddActive: p1ControlsEnabled && state.isAddMode,
              isMinusActive: p1ControlsEnabled && !state.isAddMode,
              controlsEnabled: p1ControlsEnabled,
              isCurrentTurn: state.currentTurn == 1,
              onAddPressed: () => _setScoreDirection(1, true),
              onMinusPressed: () => _setScoreDirection(1, false),
              onCardTap: () => _switchTurn(1),
              accentColor: const Color(0xFF5B4FE9),
            ),
            PlayerScoreCard(
              initials: state.player2Initials,
              score: state.score2,
              isAddActive: p2ControlsEnabled && state.isAddMode,
              isMinusActive: p2ControlsEnabled && !state.isAddMode,
              controlsEnabled: p2ControlsEnabled,
              isCurrentTurn: state.currentTurn == 2,
              onAddPressed: () => _setScoreDirection(2, true),
              onMinusPressed: () => _setScoreDirection(2, false),
              onCardTap: () => _switchTurn(2),
              accentColor: const Color(0xFF17A398),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: NumericStrip(
            maxNumber: state.maxWordLength,
            enabled: state.scoringArmed,
            onNumberTap: _onNumberTap,
          ),
        ),
      ],
    );
  }

  Widget _ribbonButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRibbon() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          _ribbonButton(icon: Icons.delete_sweep, label: 'Board', onPressed: _clearBoard, color: Colors.red),
          const SizedBox(width: 6),
          _ribbonButton(
              icon: Icons.backspace_outlined, label: 'Cell', onPressed: _clearSelected, color: Colors.orange.shade800),
          const SizedBox(width: 6),
          _ribbonButton(icon: Icons.save, label: 'Save', onPressed: _saveGame, color: const Color(0xFF5B4FE9)),
          const SizedBox(width: 6),
          _ribbonButton(
              icon: Icons.text_fields,
              label: 'Capture',
              onPressed: state.isComplete ? null : _startCapture,
              color: Colors.teal),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        // Auto-save on the way out — but never for a finished match unless
        // the player explicitly tapped Save.
        if (!state.isComplete) {
          await StorageService.saveGame(state);
        }
        if (mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Active Game'),
          actions: [
            IconButton(
              tooltip: 'Used words',
              icon: const Icon(Icons.list_alt),
              onPressed: _showUsedWordsDialog,
            ),
            IconButton(
              tooltip: 'Share match',
              icon: const Icon(Icons.share),
              onPressed: _shareResult,
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              OrientationBuilder(
                builder: (context, orientation) {
                  final isLandscape = orientation == Orientation.landscape;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: _buildScoreboard(),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: isLandscape
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: LayoutBuilder(builder: (context, c) => _buildGrid(c)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(flex: 2, child: _buildBottomPanel()),
                                  ],
                                )
                              : Column(
                                  children: [
                                    Expanded(child: LayoutBuilder(builder: (context, c) => _buildGrid(c))),
                                    const SizedBox(height: 8),
                                    _buildBottomPanel(),
                                  ],
                                ),
                        ),
                      ),
                      _buildActionRibbon(),
                    ],
                  );
                },
              ),
              // Floating "Word : ..." confirmation/warning banner, centered
              // just below the app bar. Purely visual — doesn't block taps
              // on anything underneath it.
              if (_bannerText != null)
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(child: _buildTopBanner()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
