import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../ai/computer_turn.dart';
import '../config/app_links.dart';
import '../models/game_state.dart';
import '../services/online_service.dart';
import '../services/storage_service.dart';
import '../services/word_list_service.dart';
import '../widgets/alphabet_bank.dart';
import '../widgets/gw_kit.dart';
import '../widgets/numeric_strip.dart';
import '../widgets/online_leaderboard.dart';
import '../widgets/player_score_card.dart';
import 'setup_screen.dart';

class GameScreen extends StatefulWidget {
  final GameState gameState;

  /// Set for an online match: the board is then shared live with the other
  /// devices in the room.
  final OnlineLink? online;
  const GameScreen({super.key, required this.gameState, this.online});

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

  // Computer opponent: true while the move is being calculated, and a
  // token bumped whenever a pending calculation must be discarded (board
  // cleared, screen closed) so a stale result can never be applied.
  bool _aiBusy = false;
  int _aiToken = 0;

  // Online play: live link to the other devices (null for a local match).
  OnlineSession? _online;
  bool _linkUp = true;

  /// This device's player in an online match (1-based seat), else null.
  int? _mySeat;

  /// In an online match only the player whose turn it is may place letters,
  /// score or clear cells. A local (pass-and-play / computer) match has one
  /// shared device, so it is always "your" turn.
  bool get _isMyTurn => _mySeat == null || (state.currentTurn == _mySeat && !state.isComplete);

  /// Sends this device's latest change to the other players.
  void _sync() {
    _online?.push();
  }

  /// Another player's newer board has just been copied into [state].
  void _onRemoteChange() {
    if (!mounted) return;
    setState(() {
      if (state.scoringArmed && state.pendingRow != null && state.pendingCol != null) {
        selectedRow = state.pendingRow;
        selectedCol = state.pendingCol;
      } else if (selectedRow != null &&
          (selectedRow! >= state.rows || selectedCol! >= state.cols)) {
        selectedRow = null;
        selectedCol = null;
      }
      if (!state.isComplete) _gameOverDialogShown = false;
    });
    _maybeShowGameOverDialog();
  }

  bool get _isComputersTurn => state.isComputerSeat(state.currentTurn);

  // Wraps the visible game area (scoreboard + grid + bottom panel) so
  // "Share" can capture exactly what the player currently sees as an image.
  final GlobalKey _captureBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    state = widget.gameState;
    if (state.scoringArmed && state.pendingRow != null && state.pendingCol != null) {
      selectedRow = state.pendingRow;
      selectedCol = state.pendingCol;
    }
    _gameOverDialogShown = state.isComplete;
    final link = widget.online;
    if (link != null) {
      _mySeat = link.mySeat;
      _online = OnlineSession(
        code: link.code,
        service: link.service,
        state: state,
        initialRev: link.rev,
        onRemoteChange: _onRemoteChange,
        onStatus: (up) {
          if (mounted) setState(() => _linkUp = up);
        },
      )..start();
    }
    WidgetsBinding.instance.addObserver(this);
    // Resuming a saved computer match that was left on the computer's turn.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRunComputerTurn());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _aiToken++; // discard any in-flight computer move
    _online?.dispose();
    _bannerTimer?.cancel();
    _usedWordsScrollController.dispose();
    super.dispose();
  }

  /// Silently persists progress whenever the app leaves the foreground —
  /// but only for matches still in progress. A finished match is only
  /// ever saved if the player explicitly taps Save.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (state.isComplete || _online != null) return; // online matches live in the room, not on disk
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
    if (_isComputersTurn) return; // the board is the computer's this turn
    if (!_isMyTurn) return; // online: wait for your turn
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
    final anyLettersOnBoard = state.locked.any((row) => row.any((cell) => cell));
    if (!anyLettersOnBoard) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Place some letters on the board before capturing a word.')),
      );
      return;
    }
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
    _sync();
    _showTopBanner(word, isWarning: false);
  }

  void _showTopBanner(String word, {required bool isWarning}) {
    _showBannerMessage(isWarning ? 'Word : $word 🥲' : 'Word : $word 🤠', isWarning: isWarning);
  }

  void _showBannerMessage(String text, {required bool isWarning, Duration duration = const Duration(seconds: 2)}) {
    _bannerTimer?.cancel();
    setState(() {
      _bannerText = text;
      _bannerIsWarning = isWarning;
    });
    _bannerTimer = Timer(duration, () {
      if (mounted) setState(() => _bannerText = null);
    });
  }

  Widget _buildTopBanner() {
    final scheme = Theme.of(context).colorScheme;
    final accent = _bannerIsWarning ? Colors.amber.shade800 : Colors.green.shade600;
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent, width: 1.6),
        boxShadow: [BoxShadow(color: accent.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Text(
        _bannerText ?? '',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: scheme.onSurface),
      ),
    );
  }

  final ScrollController _usedWordsScrollController = ScrollController();

  void _showRoomCode() {
    final code = _online?.code ?? '';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Room code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              code,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 4),
            ),
            const SizedBox(height: 8),
            const Text('Friends can join from the lobby with this code before the game starts.',
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  void _showUsedWordsDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            void deleteWord(String word) {
              setDialogState(() => state.usedWords.remove(word));
              setState(() {}); // keep the main screen's copy in sync too
              _sync();
            }

            return AlertDialog(
              title: const Text('Used Words'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.usedWords.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No words captured yet.'),
                      )
                    else ...[
                      Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Long-press and drag a word onto the bin below to remove it.',
                          style: TextStyle(fontSize: 12, color: Theme.of(dialogCtx).colorScheme.onSurface.withOpacity(0.6)),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: Scrollbar(
                          controller: _usedWordsScrollController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          interactive: true,
                          radius: const Radius.circular(8),
                          child: SingleChildScrollView(
                            controller: _usedWordsScrollController,
                            padding: const EdgeInsets.only(right: 12),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: state.usedWords.map((w) {
                                return LongPressDraggable<String>(
                                  data: w,
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: Chip(
                                      label: Text(w),
                                      backgroundColor: Colors.red.shade200,
                                      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.3,
                                    child: Chip(label: Text(w)),
                                  ),
                                  child: Chip(label: Text(w)),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DragTarget<String>(
                        onAccept: deleteWord,
                        builder: (ctx, candidateData, rejectedData) {
                          final isHovering = candidateData.isNotEmpty;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: isHovering ? Colors.red.withOpacity(0.14) : Theme.of(ctx).colorScheme.onSurface.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isHovering ? Colors.red : Theme.of(ctx).colorScheme.onSurface.withOpacity(0.25),
                                width: isHovering ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delete_outline, color: isHovering ? Colors.red : Theme.of(ctx).colorScheme.onSurface.withOpacity(0.6)),
                                const SizedBox(width: 6),
                                Text(
                                  isHovering ? 'Release to delete' : 'Drop here to delete',
                                  style: TextStyle(color: isHovering ? Colors.red : Theme.of(ctx).colorScheme.onSurface.withOpacity(0.6)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Close')),
              ],
            );
          },
        );
      },
    );
  }

  void _onLetterTap(String letter) {
    if (_isComputersTurn) return;
    if (!_isMyTurn) return;
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
    _sync();
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
    if (_mySeat != null && playerNumber != _mySeat) return; // online: only your own card
    if (state.isComputerSeat(playerNumber)) return; // never score for the computer by hand
    setState(() {
      if (state.scoringArmed && state.isAddMode == addMode) {
        state.scoringArmed = false; // second tap on the same button closes it
      } else {
        state.isAddMode = addMode;
        state.scoringArmed = true;
      }
    });
    _sync();
  }

  void _onNumberTap(int number) {
    if (!state.scoringArmed) return; // only active once armed
    if (!_isMyTurn) return;
    setState(() {
      final delta = state.isAddMode ? number : -number;
      // Clear the active highlight.
      selectedRow = null;
      selectedCol = null;
      // Applies the score, clears the pending cell, and automatically
      // switches the active turn / re-enables letter placement.
      state.applyTurnScore(delta);
    });
    _sync();
    if (state.isComplete && _online == null) {
      // Persist immediately, keyed by the same id, so a resumed match's
      // history entry reflects the finished result right away rather than
      // depending on the player remembering to tap Save.
      StorageService.saveGame(state);
    }
    _maybeShowGameOverDialog();
    _maybeRunComputerTurn();
  }

  /// Manually hands the active turn to [playerNumber] — e.g. to correct a
  /// mistake or let the other player go without recording a score. Allowed
  /// even while the Numeric Strip is armed — switching simply closes the
  /// pallet again rather than being blocked by it.
  void _switchTurn(int playerNumber) {
    if (state.isComplete) return;
    if (_mySeat != null) return; // online: the turn passes only when the scorer scores
    // The computer's seat is never handed over by hand, and its turn can't
    // be interrupted.
    if (state.isComputerSeat(playerNumber) || state.isComputerSeat(state.currentTurn)) return;
    if (state.currentTurn == playerNumber) return;
    setState(() {
      state.currentTurn = playerNumber;
      state.scoringArmed = false;
      state.isAddMode = true;
    });
    _sync();
  }

  // ---------------------------------------------------------------------
  // Computer opponent
  // ---------------------------------------------------------------------

  bool _sameBoard(List<List<String>> other) {
    for (var r = 0; r < state.rows; r++) {
      for (var c = 0; c < state.cols; c++) {
        if (state.grid[r][c] != other[r][c]) return false;
      }
    }
    return true;
  }

  /// Runs the computer's turn if (and only if) it is due: a computer match,
  /// Player 2's turn, the board not full, and no calculation already in
  /// flight. The search runs in a background isolate so the UI never
  /// freezes; the result is applied only if the board/turn are still
  /// exactly as they were when the calculation started.
  Future<void> _maybeRunComputerTurn() async {
    if (!mounted || _aiBusy || !state.isComputerTurn) return;
    _aiBusy = true;
    final token = ++_aiToken;
    setState(() {});
    var retry = false;
    try {
      final wordsText = await WordListService.loadText();
      final definitions = await WordListService.loadDefinitions();
      final gridSnapshot = [for (final row in state.grid) List<String>.from(row)];
      final request = ComputerMoveRequest(
        wordsText: wordsText,
        grid: gridSnapshot,
        usedWords: List<String>.from(state.usedWords),
        difficultyName: state.difficulty,
        seed: DateTime.now().microsecondsSinceEpoch & 0x7fffffff,
      );
      final started = DateTime.now();
      final result = await computeComputerMoveInBackground(request);
      // Even an instant answer waits a beat so the move feels like a turn.
      final elapsed = DateTime.now().difference(started);
      const minThink = Duration(milliseconds: 800);
      if (elapsed < minThink) await Future<void>.delayed(minThink - elapsed);

      if (!mounted || token != _aiToken || !state.isComputerTurn) return;
      if (result == null) return;
      if (!_sameBoard(gridSnapshot)) {
        retry = true; // board changed while thinking: think again
        return;
      }
      // The computer is about to end the game with a word: ask first
      // whether that word was already used, and try again if it was.
      if (state.endsGameWithWord(result)) {
        final alreadyUsed = await _confirmFinalWord(result.word!, result.score);
        if (!mounted || token != _aiToken || !state.isComputerTurn) return;
        if (alreadyUsed) {
          setState(() => state.addUsedWord(result.word!));
          _showBannerMessage('📝 ${result.word} added to used words.\n🤖 Trying another move…',
              isWarning: true);
          retry = true;
          return;
        }
      }
      var applied = false;
      setState(() {
        selectedRow = null;
        selectedCol = null;
        applied = state.applyComputerMove(result);
      });
      if (applied) {
        final meaning = result.word == null ? null : definitions[result.word!];
        _showBannerMessage(
          result.word == null
              ? '🤖 placed ${result.letter} (no word)'
              : '🤖 ${result.word} +${result.score}${meaning == null ? '' : '\n$meaning'}',
          isWarning: result.word == null,
          duration: const Duration(seconds: 5), // long enough to read the meaning
        );
        if (state.isComplete) StorageService.saveGame(state);
        _maybeShowGameOverDialog();
      }
    } catch (_) {
      if (mounted && token == _aiToken && state.isComputerTurn) {
        setState(() => state.currentTurn = 1);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("The computer couldn't move - it's your turn.")),
        );
      }
    } finally {
      _aiBusy = false; // only one calculation is ever in flight
      if (mounted) {
        setState(() {});
        if (retry) _maybeRunComputerTurn();
      }
    }
  }

  /// Asked before the computer's game-ending move. Returns true when the
  /// human says the word was already used (the computer must then retry).
  Future<bool> _confirmFinalWord(String word, int score) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('🤖 Last move!'),
        content: Text(
          'The computer can finish the game with "$word" (+$score).\n\n'
          'Has this word already been used?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, already used'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, play it'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// "Word already used": the human tells the computer that the word it
  /// just made was one they had already played. The computer's move is
  /// taken back, the word joins the used-words list, and it tries again.
  Future<void> _challengeComputerMove() async {
    if (_aiBusy || !state.canChallengeComputerMove) return;
    final word = state.aiWord!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Word already used?'),
        content: Text(
          'Was "$word" already used by you?\n\n'
          'The computer will take its move back, "$word" will be added to the '
          'used words, and the computer will try again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, undo it')),
        ],
      ),
    );
    if (confirmed != true || !mounted || !state.canChallengeComputerMove) return;
    var undone = false;
    setState(() {
      selectedRow = null;
      selectedCol = null;
      undone = state.undoLastComputerMove();
    });
    if (!undone) return;
    _showBannerMessage('📝 $word added to used words.\n🤖 Trying another move…', isWarning: true);
    _maybeRunComputerTurn();
  }

  // ---------------------------------------------------------------------
  // Clear actions
  // ---------------------------------------------------------------------

  void _clearSelected() {
    if (_aiBusy || _isComputersTurn) return;
    if (!_isMyTurn) return;
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
    _sync();
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
      _aiToken++; // any computer move calculated for the old board is stale
      setState(() {
        state.resetMatch();
        selectedRow = null;
        selectedCol = null;
        _gameOverDialogShown = false;
      });
      _sync();
      // If the computer opens this match, it plays its first move again.
      _maybeRunComputerTurn();
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
    final leaders = state.leaders;
    if (leaders.length == state.playerCount) return "It's a tie!";
    if (leaders.length == 1) return '${state.playerInitials[leaders.first - 1]} wins!';
    return '${leaders.map((i) => state.playerInitials[i - 1]).join(' & ')} tie for the win!';
  }

  /// One "INITIALS  score" pill per player, in the player's own color.
  List<Widget> _finalScoreChips() => [
        for (var i = 0; i < state.playerCount; i++)
          _finalScoreChip(state.playerInitials[i], state.scores[i], GW.playerColor(context, i)),
      ];

  /// "INITIALS  score" pill used in the game-over dialog and panel.
  Widget _finalScoreChip(String initials, int score, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        '$initials  $score',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          fontFamilyFallback: ['Noto Color Emoji', 'Apple Color Emoji', 'Segoe UI Emoji'],
        ),
      ),
    );
  }

  Future<void> _maybeShowGameOverDialog() async {
    if (!state.isComplete || _gameOverDialogShown) return;
    _gameOverDialogShown = true;
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('🎉 Game Over!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 6),
            Text(
              _winnerLabel(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: scheme.primary),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: _finalScoreChips(),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Back')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _leaveFinishedGame();
            },
            child: Text(_online != null ? 'Leave Room' : 'Start New Game'),
          ),
        ],
      ),
    );
  }

  /// After a finished match: a local game starts a fresh setup; an online
  /// game leaves the room and returns to the home screen.
  void _leaveFinishedGame() {
    if (_online != null) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SetupScreen()));
    }
  }

  String _shareText() =>
      '🎮 Grid Words result:\n'
      '${[for (var i = 0; i < state.playerCount; i++) '${state.playerInitials[i]}: ${state.scores[i]}'].join('  vs  ')}\n'
      '${_winnerLabel()}\n\n'
      'Play Grid Words yourself: ${AppLinks.downloadUrl}';

  /// From the Active Game screen, sharing sends BOTH the result text and a
  /// screenshot of the current board/scoreboard. If the screenshot capture
  /// fails for any reason, falls back to text-only rather than blocking
  /// the share entirely.
  Future<void> _shareResult() async {
    try {
      final boundary = _captureBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        await Share.share(_shareText());
        return;
      }
      final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        await Share.share(_shareText());
        return;
      }
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = await File(
        '${tempDir.path}/grid_words_result_${DateTime.now().millisecondsSinceEpoch}.png',
      ).create();
      await file.writeAsBytes(pngBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: _shareText(),
        subject: 'Grid Words result',
      );
    } catch (_) {
      // Any failure capturing/writing the screenshot still shouldn't
      // block sharing the result — fall back to text-only.
      await Share.share(_shareText());
    }
  }

  // ---------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------

  Widget _buildCell(int r, int c, double cellSize, bool isDark) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = selectedRow == r && selectedCol == c;
    final isLocked = state.locked[r][c];
    final letter = state.grid[r][c];
    final isAiNew = state.aiMoveRow == r && state.aiMoveCol == c;
    var isAiWord = false;
    for (var i = 0; i + 1 < state.aiWordCells.length; i += 2) {
      if (state.aiWordCells[i] == r && state.aiWordCells[i + 1] == c) {
        isAiWord = true;
        break;
      }
    }
    final accent = scheme.primary;
    final aiColor = state.vsComputer ? GW.playerColor(context, state.computerSeat - 1) : scheme.tertiary;
    final letterColor = isDark ? Color.lerp(accent, Colors.white, 0.7)! : GW.deepen(accent);
    final fontSize = (cellSize * 0.42).clamp(10.0, 34.0);
    final radius = (cellSize * 0.2).clamp(4.0, 10.0);

    final Color fill = isAiNew
        ? aiColor.withOpacity(isDark ? 0.5 : 0.4)
        : isAiWord
            ? Color.alphaBlend(aiColor.withOpacity(isDark ? 0.25 : 0.16), scheme.surface)
            : isLocked
                ? Color.alphaBlend(accent.withOpacity(isDark ? 0.3 : 0.14), scheme.surface)
                : scheme.surface;
    final Color border = isSelected
        ? Colors.deepOrange
        : (isAiNew || isAiWord)
            ? aiColor
            : isLocked
                ? accent.withOpacity(0.55)
                : scheme.onSurface.withOpacity(isDark ? 0.18 : 0.14);

    return GestureDetector(
      onTap: () => _onCellTap(r, c),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: cellSize - 3,
        height: cellSize - 3,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: border,
            width: isSelected ? 2.5 : (isAiNew ? 3 : (isAiWord ? 2 : 1)),
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.deepOrange.withOpacity(0.45), blurRadius: 8, spreadRadius: 0.5)]
              : const [],
        ),
        child: Stack(
          children: [
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                child: Text(
                  letter,
                  key: ValueKey<String>(letter),
                  // This size is already computed from the cell's own pixel
                  // size just above, so it must stay exact — the app-wide
                  // Settings font-size slider (applied globally as a
                  // MediaQuery textScaler in main.dart) is deliberately
                  // opted out of here, or a large slider value would make
                  // letters overflow their fixed-size grid cell.
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: letterColor),
                ),
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
  /// within the space [constraints] gives it — no scrolling, ever. The grid
  /// sits on a rounded "board" panel, whose padding is subtracted first.
  Widget _buildGrid(BoxConstraints constraints) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const double pad = 8;
    final double availW = constraints.maxWidth - pad * 2;
    final double availH = constraints.maxHeight - pad * 2;
    final double rawCell = (availW / state.cols) < (availH / state.rows) ? availW / state.cols : availH / state.rows;
    // Tiny safety margin (0.96x) against rounding, capped so cells never
    // look comically oversized on tablets/landscape.
    final double cellSize = (rawCell * 0.96).clamp(10.0, 72.0);

    return Center(
      child: Container(
        padding: const EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: scheme.onSurface.withOpacity(isDark ? 0.05 : 0.035),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.onSurface.withOpacity(isDark ? 0.1 : 0.06)),
        ),
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
      ),
    );
  }

  Widget _buildGameOverPanel() {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFE0B23B);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gold.withOpacity(isDark ? 0.22 : 0.28), scheme.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold.withOpacity(0.8), width: 1.5),
        boxShadow: [BoxShadow(color: gold.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _winnerLabel(),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: _finalScoreChips(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareResult,
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('Share', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _leaveFinishedGame,
                  icon: Icon(_online != null ? Icons.logout_rounded : Icons.refresh, size: 16),
                  label: Text(_online != null ? 'Leave' : 'New Game', style: const TextStyle(fontSize: 12)),
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
    final bankEnabled = !_isComputersTurn &&
        _isMyTurn &&
        !state.scoringArmed &&
        selectedRow != null &&
        selectedCol != null &&
        !state.locked[selectedRow!][selectedCol!];
    return AlphabetBank(onLetterTap: _onLetterTap, enabled: bankEnabled);
  }

  Widget _buildPlayerCard(int seat, {required bool compact, bool expanded = true}) {
    final isTurn = state.currentTurn == seat;
    // The computer scores itself; its +/- buttons are never available.
    final controlsEnabled = isTurn && !state.isComplete && !state.isComputerSeat(seat);
    return PlayerScoreCard(
      initials: state.playerInitials[seat - 1],
      score: state.scores[seat - 1],
      isAddActive: controlsEnabled && state.isAddMode,
      isMinusActive: controlsEnabled && !state.isAddMode,
      controlsEnabled: controlsEnabled,
      isCurrentTurn: isTurn,
      onAddPressed: () => _setScoreDirection(seat, true),
      onMinusPressed: () => _setScoreDirection(seat, false),
      onCardTap: (state.isComputerSeat(seat) || _mySeat != null) ? null : () => _switchTurn(seat),
      accentColor: GW.playerColor(context, seat - 1),
      compact: compact,
      expanded: expanded,
    );
  }

  /// Online match: only THIS player's score card (30% of the width) beside
  /// the live leaderboard of everyone's scores (70%). The card's +/- buttons
  /// work only while it is this player's turn.
  Widget _buildOnlineScoreRow(int mySeat) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            flex: 3,
            child: Align(
              alignment: Alignment.topCenter,
              child: _buildPlayerCard(mySeat, compact: true, expanded: false),
            ),
          ),
          Flexible(
            flex: 7,
            child: OnlineLeaderboard(
              names: state.playerNames,
              scores: state.scores,
              currentTurn: state.currentTurn,
              mySeat: mySeat,
              gameOver: state.isComplete,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreboard() {
    final compact = state.playerCount >= 3;
    final mySeat = _mySeat;
    return Column(
      children: [
        if (mySeat != null && mySeat >= 1 && mySeat <= state.playerCount)
          _buildOnlineScoreRow(mySeat)
        else
          Row(
            children: [
              for (var seat = 1; seat <= state.playerCount; seat++) _buildPlayerCard(seat, compact: compact),
            ],
          ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: NumericStrip(
            maxNumber: state.maxWordLength,
            enabled: state.scoringArmed && _isMyTurn,
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
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final fg = enabled ? color : scheme.onSurface.withOpacity(0.3);
    return Expanded(
      child: Material(
        color: enabled ? color.withOpacity(0.12) : scheme.onSurface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionRibbon() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          _ribbonButton(
              icon: Icons.delete_sweep, label: 'Board', onPressed: (state.isComplete || _aiBusy || !_isMyTurn) ? null : _clearBoard, color: Colors.red),
          const SizedBox(width: 6),
          _ribbonButton(
              icon: Icons.backspace_outlined,
              label: 'Cell',
              onPressed: (state.isComplete || _aiBusy || !_isMyTurn) ? null : _clearSelected,
              color: Colors.orange.shade800),
          const SizedBox(width: 6),
          _ribbonButton(
              icon: Icons.save, label: 'Save', onPressed: _saveGame, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          _ribbonButton(
              icon: Icons.text_fields,
              label: 'Capture',
              onPressed: (state.isComplete || _aiBusy || !state.locked.any((row) => row.any((cell) => cell)))
                  ? null
                  : _startCapture,
              color: Theme.of(context).colorScheme.tertiary),
          if (state.vsComputer) ...[
            const SizedBox(width: 6),
            _ribbonButton(
                icon: Icons.flag_outlined,
                label: 'Used?',
                onPressed: (!_aiBusy && state.canChallengeComputerMove) ? _challengeComputerMove : null,
                color: Colors.deepOrange),
          ],
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
        if (!state.isComplete && _online == null) {
          await StorageService.saveGame(state);
        }
        if (mounted) Navigator.of(context).pop();
      },
      child: GWScaffold(
        title: _online != null
            ? (_linkUp ? 'Room ${_online!.code}' : 'Reconnecting…')
            : (state.vsComputer ? 'Play Bot · ${state.aiDifficulty.label}' : 'Pass and Play'),
        actions: [
          if (_online != null)
            GWIconButton(
              icon: Icons.vpn_key_rounded,
              tooltip: 'Room code',
              onTap: () => _showRoomCode(),
            ),
          GWIconButton(icon: Icons.list_alt_rounded, tooltip: 'Used words', onTap: _showUsedWordsDialog),
          GWIconButton(icon: Icons.share_rounded, tooltip: 'Share match', onTap: _shareResult),
        ],
        body: Stack(
            children: [
              OrientationBuilder(
                builder: (context, orientation) {
                  final isLandscape = orientation == Orientation.landscape;
                  return Column(
                    children: [
                      Expanded(
                        child: RepaintBoundary(
                          key: _captureBoundaryKey,
                          child: GWBackground(
                            child: Column(
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
                              ],
                            ),
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
              if (_aiBusy)
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Theme.of(context).colorScheme.tertiary, width: 1.8),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.tertiary.withOpacity(0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Theme.of(context).colorScheme.tertiary),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Computer is thinking…',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (_bannerText != null)
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(_bannerText),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        builder: (context, t, child) => Opacity(
                          opacity: t,
                          child: Transform.translate(offset: Offset(0, (1 - t) * -14), child: child),
                        ),
                        child: _buildTopBanner(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ),
    );
  }
}
