import 'package:flutter/material.dart';
import 'package:characters/characters.dart';
import '../models/game_state.dart';
import 'game_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static const int _minDimension = 1;
  static const int _maxDimension = 10;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _p1Controller = TextEditingController();
  final TextEditingController _p2Controller = TextEditingController();
  final TextEditingController _rowsController = TextEditingController();
  final TextEditingController _colsController = TextEditingController();
  final TextEditingController _maxWordLengthController = TextEditingController();

  String? _crossDimensionError;

  @override
  void initState() {
    super.initState();
    _rowsController.addListener(_updateDerivedFields);
    _colsController.addListener(_updateDerivedFields);
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
      return 'Enter a valid whole number';
    }
    if (n < _minDimension || n > _maxDimension) {
      return 'Must be between $_minDimension and $_maxDimension';
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

    final gameState = GameState.newGame(
      player1Name: _p1Controller.text.trim(),
      player2Name: _p2Controller.text.trim(),
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
    _p1Controller.dispose();
    _p2Controller.dispose();
    _rowsController.dispose();
    _colsController.dispose();
    _maxWordLengthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game Setup')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _p1Controller,
                  decoration: const InputDecoration(labelText: 'Player 1 Name'),
                  maxLength: _maxNameLength,
                  validator: _validateName,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _p2Controller,
                  decoration: const InputDecoration(labelText: 'Player 2 Name'),
                  maxLength: _maxNameLength,
                  validator: _validateName,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _rowsController,
                  decoration: const InputDecoration(
                    labelText: 'Total Rows (R)',
                    helperText: 'Whole number from 1 to 10',
                  ),
                  keyboardType: TextInputType.number,
                  validator: _validateDimension,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _colsController,
                  decoration: const InputDecoration(
                    labelText: 'Total Columns (C)',
                    helperText: 'Whole number from 1 to 10',
                  ),
                  keyboardType: TextInputType.number,
                  validator: _validateDimension,
                ),
                if (_crossDimensionError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _crossDimensionError!,
                    style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _maxWordLengthController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Max Word Length (auto)',
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade800
                        : Colors.grey.shade200,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _onPlayPressed,
                    child: const Text('PLAY', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
