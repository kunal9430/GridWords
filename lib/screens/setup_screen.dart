import 'package:flutter/material.dart';
import 'package:characters/characters.dart';
import '../ai/difficulty.dart';
import '../models/game_state.dart';
import '../services/profile_service.dart';
import '../widgets/gw_kit.dart';
import 'game_screen.dart';

class SetupScreen extends StatefulWidget {
  /// Opens the screen with "Play Bot" already selected (used by the
  /// home screen's "Play Bot" card).
  final bool initialVsComputer;
  const SetupScreen({super.key, this.initialVsComputer = false});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static const int _minDimension = 1;
  static const int _maxDimension = 10;

  final _formKey = GlobalKey<FormState>();
  // One name field per possible seat (a match has 2 to 4 players).
  final List<TextEditingController> _nameControllers =
      List.generate(GameState.maxPlayers, (_) => TextEditingController());
  final TextEditingController _rowsController = TextEditingController();
  final TextEditingController _colsController = TextEditingController();
  final TextEditingController _maxWordLengthController = TextEditingController();

  String? _crossDimensionError;

  // "Play Bot": the last seat becomes the computer.
  bool _vsComputer = false;
  // Total players in the match, INCLUDING the computer in a bot match (2-4).
  int _playerCount = 2;
  int get _humanCount => _vsComputer ? _playerCount - 1 : _playerCount;
  AiDifficulty _difficulty = AiDifficulty.medium;
  bool _computerStarts = false;

  @override
  void initState() {
    super.initState();
    _vsComputer = widget.initialVsComputer;
    _rowsController.addListener(_updateDerivedFields);
    _colsController.addListener(_updateDerivedFields);
    _prefillProfileName();
  }

  Future<void> _prefillProfileName() async {
    final savedName = await ProfileService.loadDisplayName();
    if (!mounted || savedName.isEmpty) return;
    setState(() => _nameControllers[0].text = savedName);
  }

  void _updateDerivedFields() {
    final rows = int.tryParse(_rowsController.text.trim());
    final cols = int.tryParse(_colsController.text.trim());
    final rowsValid = rows != null && rows >= _minDimension && rows <= _maxDimension;
    final colsValid = cols != null && cols >= _minDimension && cols <= _maxDimension;

    setState(() {
      if (rowsValid && colsValid) {
        _maxWordLengthController.text = (rows! > cols! ? rows : cols).toString();
        _crossDimensionError = (rows == 1 && cols == 1)
            ? 'Rows and Columns cannot both be 1 — at least one must be greater than 1.'
            : null;
      } else {
        _maxWordLengthController.text = '';
        _crossDimensionError = null;
      }
    });
  }

  static const int _maxNameLength = 20;

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name cannot be empty';
    }
    // Grapheme-cluster count, not raw UTF-16 code units, so a single
    // multi-part emoji (skin tone, ZWJ sequence, flag, etc.) still counts
    // as one character rather than several.
    if (value.trim().characters.length > _maxNameLength) {
      return 'Max $_maxNameLength characters';
    }
    return null;
  }

  String? _validateDimension(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    final n = int.tryParse(value.trim());
    if (n == null) {
      return 'Select a number from $_minDimension to $_maxDimension';
    }
    if (n < _minDimension || n > _maxDimension) {
      return 'Select a number from $_minDimension to $_maxDimension';
    }
    return null;
  }

  void _onPlayPressed() {
    if (!_formKey.currentState!.validate()) return;

    final rows = int.parse(_rowsController.text.trim());
    final cols = int.parse(_colsController.text.trim());

    if (rows == 1 && cols == 1) {
      setState(() {
        _crossDimensionError = 'Rows and Columns cannot both be 1 — at least one must be greater than 1.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one of Rows or Columns must be greater than 1.')),
      );
      return;
    }

    final names = [for (var i = 0; i < _humanCount; i++) _nameControllers[i].text.trim()];
    final gameState = _vsComputer
        ? GameState.newComputerGame(
            humanNames: names,
            rows: rows,
            cols: cols,
            difficulty: _difficulty,
            computerStarts: _computerStarts,
          )
        : GameState.newGame(
            playerNames: names,
            rows: rows,
            cols: cols,
          );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => GameScreen(gameState: gameState)),
    );
  }

  @override
  void dispose() {
    for (final c in _nameControllers) {
      c.dispose();
    }
    _rowsController.dispose();
    _colsController.dispose();
    _maxWordLengthController.dispose();
    super.dispose();
  }

  static const Map<AiDifficulty, IconData> _levelIcons = {
    AiDifficulty.easy: Icons.eco_rounded,
    AiDifficulty.medium: Icons.bolt_rounded,
    AiDifficulty.hard: Icons.local_fire_department_rounded,
    AiDifficulty.expert: Icons.psychology_rounded,
  };

  static String _levelBlurb(AiDifficulty d) {
    switch (d) {
      case AiDifficulty.easy:
        return 'Plays a random scoring word. Friendly and beatable.';
      case AiDifficulty.medium:
        return 'Looks one move ahead: its word minus your best reply.';
      case AiDifficulty.hard:
        return 'Thinks three moves ahead and blocks your best cells.';
      case AiDifficulty.expert:
        return 'Searches up to five moves deep. Ruthless.';
    }
  }

  Widget _buildModeCard() {
    return Row(
      children: [
        Expanded(
          child: GWChoice(
            label: 'Pass and Play',
            caption: 'Share one phone',
            icon: Icons.people_alt_rounded,
            selected: !_vsComputer,
            onTap: () => setState(() => _vsComputer = false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GWChoice(
            label: 'Play Bot',
            caption: 'Beat the computer',
            icon: Icons.smart_toy_rounded,
            selected: _vsComputer,
            onTap: () => setState(() => _vsComputer = true),
          ),
        ),
      ],
    );
  }

  /// "How many players?" - 2 to 4 in total. In a bot match the computer
  /// takes the last seat, so the choices count the humans only.
  Widget _buildPlayerCountCard() {
    final humanChoices = _vsComputer ? const [1, 2, 3] : const [2, 3, 4];
    return GWCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GWSectionTitle(
            icon: Icons.groups_rounded,
            title: 'How many players?',
            subtitle: _vsComputer ? 'Up to 4 in total, with the Computer' : 'Up to 4 people',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final h in humanChoices) ...[
                Expanded(
                  child: GWChoice(
                    label: '$h',
                    caption: _vsComputer ? (h == 1 ? 'player + Bot' : 'players + Bot') : 'players',
                    icon: Icons.person_rounded,
                    selected: _humanCount == h,
                    onTap: () => setState(() => _playerCount = _vsComputer ? h + 1 : h),
                  ),
                ),
                if (h != humanChoices.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersCard() {
    final soloVsBot = _vsComputer && _humanCount == 1;
    return GWCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GWSectionTitle(
            icon: Icons.person_rounded,
            title: soloVsBot ? 'You' : 'Players',
            subtitle: soloVsBot
                ? 'You are Player 1'
                : (_vsComputer ? 'Enter every name in turn order. The Computer plays last.' : 'Enter every name in turn order'),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < _humanCount; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            TextFormField(
              controller: _nameControllers[i],
              decoration: InputDecoration(
                labelText: soloVsBot ? 'Your Name' : 'Player ${i + 1} Name',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                counterText: '',
              ),
              maxLength: _maxNameLength,
              validator: _validateName,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDifficultyCard() {
    return GWCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GWSectionTitle(icon: Icons.smart_toy_rounded, title: 'Computer level'),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final d in AiDifficulty.values) ...[
                Expanded(
                  child: GWChoice(
                    label: d.label,
                    icon: _levelIcons[d] ?? Icons.bolt_rounded,
                    selected: _difficulty == d,
                    onTap: () => setState(() => _difficulty = d),
                  ),
                ),
                if (d != AiDifficulty.values.last) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _levelBlurb(_difficulty),
              key: ValueKey<AiDifficulty>(_difficulty),
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstPlayerCard() {
    return GWCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GWSectionTitle(icon: Icons.flag_rounded, title: 'Who plays first?'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GWChoice(
                  label: _humanCount == 1 ? 'Me' : 'Players',
                  icon: Icons.person_rounded,
                  selected: !_computerStarts,
                  onTap: () => setState(() => _computerStarts = false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GWChoice(
                  label: 'Computer',
                  icon: Icons.smart_toy_rounded,
                  selected: _computerStarts,
                  onTap: () => setState(() => _computerStarts = true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Small live drawing of the board that is about to be played.
  Widget _buildBoardPreview(int? rows, int? cols) {
    final scheme = Theme.of(context).colorScheme;
    if (rows == null ||
        cols == null ||
        rows < _minDimension ||
        rows > _maxDimension ||
        cols < _minDimension ||
        cols > _maxDimension) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: scheme.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'Enter rows and columns to preview your board',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withOpacity(0.6)),
        ),
      );
    }
    const box = 120.0;
    final cell = (box / (rows > cols ? rows : cols)).clamp(5.0, 18.0);
    final maxLen = rows > cols ? rows : cols;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: box,
            height: box,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var r = 0; r < rows; r++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var c = 0; c < cols; c++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: cell - 2,
                            height: cell - 2,
                            margin: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: (r + c).isEven ? scheme.primary.withOpacity(0.32) : scheme.tertiary.withOpacity(0.32),
                              borderRadius: BorderRadius.circular(cell > 9 ? 3 : 1.5),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$rows × $cols', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  '${rows * cols} cells',
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withOpacity(0.6)),
                ),
                const SizedBox(height: 10),
                GWBadge(text: 'Max word length: $maxLen', color: scheme.primary, icon: Icons.straighten_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardCard() {
    final rows = int.tryParse(_rowsController.text.trim());
    final cols = int.tryParse(_colsController.text.trim());
    return GWCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GWSectionTitle(
            icon: Icons.grid_view_rounded,
            title: 'Board size',
            subtitle: 'Pick rows and columns from 1 to 10',
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _rowsController,
                  decoration: const InputDecoration(
                    labelText: 'Rows (R)',
                    prefixIcon: Icon(Icons.table_rows_rounded),
                  ),
                  keyboardType: TextInputType.number,
                  validator: _validateDimension,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _colsController,
                  decoration: const InputDecoration(
                    labelText: 'Columns (C)',
                    prefixIcon: Icon(Icons.view_column_rounded),
                  ),
                  keyboardType: TextInputType.number,
                  validator: _validateDimension,
                ),
              ),
            ],
          ),
          if (_crossDimensionError != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, size: 16, color: Colors.red),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _crossDimensionError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _buildBoardPreview(rows, cols),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GWScaffold(
      title: 'Game Setup',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GWReveal(index: 0, child: _buildModeCard()),
              const SizedBox(height: 14),
              _buildPlayerCountCard(),
              const SizedBox(height: 14),
              _buildPlayersCard(),
              if (_vsComputer) ...[
                const SizedBox(height: 14),
                GWReveal(index: 2, child: _buildDifficultyCard()),
                const SizedBox(height: 14),
                GWReveal(index: 3, child: _buildFirstPlayerCard()),
              ],
              const SizedBox(height: 14),
              GWReveal(index: 4, child: _buildBoardCard()),
              const SizedBox(height: 22),
              GWReveal(
                index: 5,
                child: GWGradientButton(label: 'PLAY', icon: Icons.play_arrow_rounded, height: 56, onPressed: _onPlayPressed),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
