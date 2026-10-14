import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../config/app_links.dart';
import '../models/game_state.dart';
import '../services/online_service.dart';
import '../services/profile_service.dart';
import '../widgets/gw_kit.dart';
import 'game_screen.dart';

/// "Play Online": create a room or join one with a code, so people on
/// different devices can play the same board.
class OnlineScreen extends StatefulWidget {
  const OnlineScreen({super.key});

  @override
  State<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends State<OnlineScreen> {
  static const int _maxNameLength = 20;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _rowsController = TextEditingController(text: '5');
  final _colsController = TextEditingController(text: '5');
  final OnlineService _service = OnlineService();

  bool _creating = true;
  int _maxPlayers = 2;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ProfileService.loadDisplayName().then((n) {
      if (mounted && n.isNotEmpty && _nameController.text.isEmpty) _nameController.text = n;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _rowsController.dispose();
    _colsController.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter your name';
    if (v.trim().length > _maxNameLength) return 'Max $_maxNameLength characters';
    return null;
  }

  String? _validateDim(String? v) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null || n < 1 || n > 10) return '1 to 10';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final String code;
      if (_creating) {
        final rows = int.parse(_rowsController.text.trim());
        final cols = int.parse(_colsController.text.trim());
        if (rows == 1 && cols == 1) {
          throw const OnlineException('Rows and Columns cannot both be 1.');
        }
        code = await _service.createRoom(hostName: name, maxPlayers: _maxPlayers, rows: rows, cols: cols);
      } else {
        code = OnlineService.normalizeCode(_codeController.text);
        await _service.joinRoom(code, name);
      }
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OnlineLobbyScreen(code: code, service: _service, isHost: _creating)),
      );
    } on OnlineException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GWScaffold(
      title: 'Play Online',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_service.configured) ...[
                GWCard(
                  borderColor: Colors.orange,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Online play has not been connected to a database yet. The app owner needs to set '
                          'AppLinks.firebaseDbUrl (see docs/online-play.md).',
                          style: TextStyle(fontSize: 13, height: 1.4, color: scheme.onSurface.withOpacity(0.8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Row(
                children: [
                  Expanded(
                    child: GWChoice(
                      label: 'Create Room',
                      caption: 'Get a code to share',
                      icon: Icons.add_circle_outline_rounded,
                      selected: _creating,
                      onTap: () => setState(() {
                        _creating = true;
                        _error = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GWChoice(
                      label: 'Join Room',
                      caption: 'Enter a friend\'s code',
                      icon: Icons.login_rounded,
                      selected: !_creating,
                      onTap: () => setState(() {
                        _creating = false;
                        _error = null;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GWCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const GWSectionTitle(icon: Icons.person_rounded, title: 'Your name'),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nameController,
                      maxLength: _maxNameLength,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                        counterText: '',
                      ),
                      validator: _validateName,
                    ),
                    if (!_creating) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: 'Room code',
                          prefixIcon: Icon(Icons.vpn_key_rounded),
                          counterText: '',
                        ),
                        validator: (v) =>
                            OnlineService.normalizeCode(v ?? '').length == 6 ? null : 'Enter the 6-character code',
                      ),
                    ],
                  ],
                ),
              ),
              if (_creating) ...[
                const SizedBox(height: 14),
                GWCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const GWSectionTitle(
                        icon: Icons.groups_rounded,
                        title: 'Players allowed',
                        subtitle: 'Up to 4 people can join',
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          for (final n in const [2, 3, 4]) ...[
                            Expanded(
                              child: GWChoice(
                                label: '$n',
                                caption: 'players',
                                icon: Icons.person_rounded,
                                selected: _maxPlayers == n,
                                onTap: () => setState(() => _maxPlayers = n),
                              ),
                            ),
                            if (n != 4) const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GWCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const GWSectionTitle(
                        icon: Icons.grid_view_rounded,
                        title: 'Board size',
                        subtitle: 'Rows and columns from 1 to 10',
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _rowsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Rows (R)',
                                prefixIcon: Icon(Icons.table_rows_rounded),
                              ),
                              validator: _validateDim,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _colsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Columns (C)',
                                prefixIcon: Icon(Icons.view_column_rounded),
                              ),
                              validator: _validateDim,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              GWGradientButton(
                label: _busy ? 'PLEASE WAIT…' : (_creating ? 'CREATE ROOM' : 'JOIN ROOM'),
                icon: _creating ? Icons.add_rounded : Icons.login_rounded,
                height: 56,
                onPressed: (_busy || !_service.configured) ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Waiting room: shows the room code and who has joined. The host starts
/// the match; everyone else is taken to the board automatically.
class OnlineLobbyScreen extends StatefulWidget {
  final String code;
  final OnlineService service;
  final bool isHost;

  const OnlineLobbyScreen({super.key, required this.code, required this.service, required this.isHost});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  Lobby? _lobby;
  Timer? _timer;
  bool _starting = false;
  bool _opening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_opening) return;
    try {
      final lobby = await widget.service.fetchLobby(widget.code);
      if (!mounted) return;
      if (lobby == null) {
        setState(() => _error = 'This room no longer exists.');
        return;
      }
      setState(() {
        _lobby = lobby;
        _error = null;
      });
      if (lobby.started) await _openGame();
    } on OnlineException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _openGame() async {
    if (_opening) return;
    _opening = true;
    _timer?.cancel();
    try {
      final remote = await widget.service.fetchGame(widget.code);
      if (!mounted) return;
      if (remote == null) {
        _opening = false; // not written yet; the next poll retries
        _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _refresh());
        return;
      }
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GameScreen(
            gameState: remote.state,
            online: OnlineLink(code: widget.code, service: widget.service, rev: remote.rev),
          ),
        ),
      );
    } on OnlineException catch (e) {
      _opening = false;
      if (mounted) {
        setState(() => _error = e.message);
        _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _refresh());
      }
    }
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      await widget.service.startGame(widget.code);
      await _refresh(); // sees started == true and opens the board
    } on OnlineException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lobby = _lobby;
    final count = lobby?.players.length ?? 0;
    final max = lobby?.maxPlayers ?? 4;
    return GWScaffold(
      title: 'Waiting Room',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          GWCard(
            child: Column(
              children: [
                Text('Room code', style: TextStyle(fontSize: 13, color: scheme.onSurface.withOpacity(0.6))),
                const SizedBox(height: 6),
                SelectableText(
                  widget.code,
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: widget.code));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Share.share(
                        '🎮 Join my Grid Words game! Open the app, tap Play Online > Join Room and enter code '
                        '${widget.code}.\n\nGet the app: ${AppLinks.downloadUrl}',
                        subject: 'Grid Words room ${widget.code}',
                      ),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GWCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GWSectionTitle(
                  icon: Icons.groups_rounded,
                  title: 'Players ($count / $max)',
                  subtitle: lobby == null ? 'Connecting…' : '${lobby.rows} × ${lobby.cols} board',
                ),
                const SizedBox(height: 12),
                if (lobby != null)
                  for (var i = 0; i < max; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: i < count ? GW.playerColor(context, i) : scheme.onSurface.withOpacity(0.08),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: i < count ? GW.onColor(GW.playerColor(context, i)) : scheme.onSurface.withOpacity(0.4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              i < count ? lobby.players[i] + (i == 0 ? '  (host)' : '') : 'Waiting for player…',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: i < count ? FontWeight.w700 : FontWeight.w500,
                                color: i < count ? scheme.onSurface : scheme.onSurface.withOpacity(0.4),
                                fontFamilyFallback: const ['Noto Color Emoji', 'Apple Color Emoji', 'Segoe UI Emoji'],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                else
                  const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 20),
          if (widget.isHost)
            GWGradientButton(
              label: _starting ? 'STARTING…' : 'START GAME',
              icon: Icons.play_arrow_rounded,
              height: 56,
              onPressed: (_starting || count < GameState.minPlayers) ? null : _start,
            )
          else
            Center(
              child: Text(
                'Waiting for the host to start the game…',
                style: TextStyle(fontSize: 14, color: scheme.onSurface.withOpacity(0.65)),
              ),
            ),
          if (widget.isHost && count < GameState.minPlayers)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  'Share the code - at least 2 players are needed.',
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withOpacity(0.6)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
