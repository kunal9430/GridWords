import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../config/app_links.dart';
import '../models/game_state.dart';
import 'auth_service.dart';

/// Thrown for any problem talking to the online database.
class OnlineException implements Exception {
  final String message;
  const OnlineException(this.message);
  @override
  String toString() => message;
}

/// The waiting room of an online match, before the board exists.
class Lobby {
  /// Display names in seat order (the host is first).
  final List<String> players;

  /// Who sits where: login user id -> 0-based seat. This is the record of
  /// who was in the match from the start; it is what lets a player who left
  /// come back with the room code, even after the game has started.
  final Map<String, int> members;
  final int maxPlayers;
  final int rows;
  final int cols;
  final bool started;

  const Lobby({
    required this.players,
    this.members = const {},
    required this.maxPlayers,
    required this.rows,
    required this.cols,
    required this.started,
  });

  factory Lobby.fromJson(Map<String, dynamic> j) {
    final rawMembers = j['members'];
    final members = <String, int>{};
    if (rawMembers is Map) {
      rawMembers.forEach((k, v) {
        final seat = v is int ? v : int.tryParse(v.toString());
        if (seat != null) members[k.toString()] = seat;
      });
    }
    return Lobby(
      players: (j['players'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      members: members,
      maxPlayers: j['max'] as int? ?? 3,
      rows: j['rows'] as int? ?? 5,
      cols: j['cols'] as int? ?? 5,
      started: j['started'] as bool? ?? false,
    );
  }

  /// 0-based seat of the player with login id [uid], or -1 if they were
  /// never part of this room.
  int seatOf(String uid) => members[uid] ?? -1;

  bool hasMember(String uid) => members.containsKey(uid);

  Lobby copyWith({List<String>? players, Map<String, int>? members, bool? started}) => Lobby(
        players: players ?? this.players,
        members: members ?? this.members,
        maxPlayers: maxPlayers,
        rows: rows,
        cols: cols,
        started: started ?? this.started,
      );

  Map<String, dynamic> toJson() => {
        'players': players,
        'members': members,
        'max': maxPlayers,
        'rows': rows,
        'cols': cols,
        'started': started,
      };
}

/// One version of the shared board as stored online.
class RemoteGame {
  final GameState state;
  final int rev;
  final String? etag;
  const RemoteGame(this.state, this.rev, this.etag);
}

/// Talks to a Firebase Realtime Database over its plain REST API - no
/// native Firebase setup needed. Layout:
///   rooms/CODE/lobby -> {players, members, max, rows, cols, started}
///   rooms/CODE/game  -> {rev, by, state}
/// Concurrent edits are made safe with the database's ETag / If-Match
/// support: a write based on an out-of-date version is rejected.
class OnlineService {
  final http.Client _client;
  final String baseUrl;

  /// [tokenProvider] supplies the signed-in player's Firebase ID token, sent
  /// as `?auth=` so the database rules can identify the caller. Leave it
  /// null only for an open (rules-free) test database.
  final Future<String?> Function()? tokenProvider;

  OnlineService({http.Client? client, String? baseUrl, this.tokenProvider})
      : _client = client ?? http.Client(),
        baseUrl = (baseUrl ?? AppLinks.firebaseDbUrl).replaceAll(RegExp(r'/+$'), '');

  bool get configured => baseUrl.isNotEmpty;

  static const Duration _timeout = Duration(seconds: 10);
  static const String _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I, O, 0, 1

  static String normalizeCode(String raw) => raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static String randomCode([Random? rng]) {
    final r = rng ?? Random.secure();
    return String.fromCharCodes(
      List.generate(6, (_) => _codeChars.codeUnitAt(r.nextInt(_codeChars.length))),
    );
  }

  Future<Uri> _uri(String path) async {
    String? token;
    try {
      token = await tokenProvider?.call();
    } on AuthException catch (e) {
      throw OnlineException(e.message);
    }
    final base = Uri.parse('$baseUrl/$path.json');
    return token == null ? base : base.replace(queryParameters: {'auth': token});
  }

  void _ensureConfigured() {
    if (!configured) {
      throw const OnlineException('Online play is not set up yet (no database address in the app).');
    }
  }

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(_timeout);
    } on TimeoutException {
      throw const OnlineException('The connection timed out. Check your internet and try again.');
    } catch (e) {
      if (e is OnlineException) rethrow;
      throw const OnlineException("Couldn't reach the server. Check your internet and try again.");
    }
  }

  Future<({Object? body, String? etag})> _get(String path) async {
    final uri = await _uri(path);
    final res = await _send(() => _client.get(uri, headers: {'X-Firebase-ETag': 'true'}));
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const OnlineException('The online database refused access. Sign in again, or check that the database rules are published (docs/online-play.md).');
    }
    if (res.statusCode != 200) throw OnlineException('Server error (${res.statusCode}).');
    return (body: jsonDecode(res.body), etag: res.headers['etag']);
  }

  /// Returns true when written, false when [etag] was out of date.
  Future<({bool ok, String? etag})> _put(String path, Object value, {String? etag}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Firebase-ETag': 'true',
      if (etag != null) 'if-match': etag,
    };
    final uri = await _uri(path);
    final res = await _send(() => _client.put(uri, headers: headers, body: jsonEncode(value)));
    if (res.statusCode == 412) return (ok: false, etag: null);
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const OnlineException('The online database refused access. Sign in again, or check that the database rules are published (docs/online-play.md).');
    }
    if (res.statusCode != 200) throw OnlineException('Server error (${res.statusCode}).');
    return (ok: true, etag: res.headers['etag']);
  }

  // ----------------------------------------------------------------------
  // Lobby
  // ----------------------------------------------------------------------

  /// Opens a new room with [hostName] (signed in as [hostUid]) as the first
  /// player and returns its code.
  Future<String> createRoom({
    required String hostName,
    required String hostUid,
    required int maxPlayers,
    required int rows,
    required int cols,
  }) async {
    _ensureConfigured();
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = randomCode();
      final existing = await _get('rooms/$code/lobby');
      if (existing.body != null) continue; // code already taken
      final lobby = Lobby(
        players: [hostName],
        members: {hostUid: 0},
        maxPlayers: maxPlayers,
        rows: rows,
        cols: cols,
        started: false,
      );
      // "null" etag means: only write if nothing exists there yet.
      final res = await _put('rooms/$code/lobby', lobby.toJson(), etag: 'null_etag');
      if (res.ok) return code;
    }
    throw const OnlineException("Couldn't create a room. Please try again.");
  }

  Future<Lobby?> fetchLobby(String code) async {
    _ensureConfigured();
    final r = await _get('rooms/$code/lobby');
    if (r.body == null) return null;
    return Lobby.fromJson(Map<String, dynamic>.from(r.body! as Map));
  }

  /// Puts the signed-in player [uid] into the room and returns the lobby.
  ///
  /// * A player who is ALREADY in the room's member list gets back in at
  ///   their original seat, whether or not the game has started and even if
  ///   the room is full - leaving never costs anyone their place.
  /// * A new player can only join before the game starts, and only while
  ///   there is a free seat.
  ///
  /// Safe when several people join at once: a clashing write is retried on
  /// the fresh lobby.
  Future<Lobby> joinRoom(String code, String name, String uid) async {
    _ensureConfigured();
    for (var attempt = 0; attempt < 6; attempt++) {
      final r = await _get('rooms/$code/lobby');
      if (r.body == null) throw const OnlineException('No room with that code.');
      final lobby = Lobby.fromJson(Map<String, dynamic>.from(r.body! as Map));
      if (lobby.hasMember(uid)) return lobby; // re-joining: nothing to write
      if (lobby.started) {
        throw const OnlineException('That game has already started, and you were not one of its players.');
      }
      if (lobby.players.length >= lobby.maxPlayers) throw const OnlineException('That room is full.');
      final updated = lobby.copyWith(
        players: [...lobby.players, name],
        members: {...lobby.members, uid: lobby.players.length},
      );
      final res = await _put('rooms/$code/lobby', updated.toJson(), etag: r.etag);
      if (res.ok) return updated;
    }
    throw const OnlineException("Couldn't join - the room is busy. Please try again.");
  }

  /// Host: creates the shared board from the lobby and marks the room started.
  /// When [byUid] is given it must be the host's (seat 1) login id.
  Future<GameState> startGame(String code, {String? byUid}) async {
    _ensureConfigured();
    final lobby = await fetchLobby(code);
    if (lobby == null) throw const OnlineException('The room no longer exists.');
    if (byUid != null && lobby.members.isNotEmpty && lobby.seatOf(byUid) != 0) {
      throw const OnlineException('Only the host can start the game.');
    }
    if (lobby.players.length < GameState.minPlayers) {
      throw const OnlineException('At least 2 players are needed to start.');
    }
    final game = GameState.newGame(playerNames: lobby.players, rows: lobby.rows, cols: lobby.cols)..id = 'online_$code';
    await _put('rooms/$code/game', {'rev': 1, 'by': 'host', 'state': game.toJson()});
    await _put('rooms/$code/lobby', lobby.copyWith(started: true).toJson());
    return game;
  }

  // ----------------------------------------------------------------------
  // Shared board
  // ----------------------------------------------------------------------

  Future<RemoteGame?> fetchGame(String code) async {
    _ensureConfigured();
    final r = await _get('rooms/$code/game');
    if (r.body == null) return null;
    final m = Map<String, dynamic>.from(r.body! as Map);
    final stateJson = Map<String, dynamic>.from(m['state'] as Map);
    return RemoteGame(GameState.fromJson(stateJson), m['rev'] as int? ?? 0, r.etag);
  }

  /// Writes [state] as revision [rev] ONLY if the stored board is still the
  /// one identified by [etag]. Returns the new etag on success, or null if
  /// someone else changed the board first.
  Future<({bool ok, String? etag})> pushGame(
    String code,
    GameState state, {
    required int rev,
    required String? etag,
    required String by,
  }) {
    _ensureConfigured();
    return _put('rooms/$code/game', {'rev': rev, 'by': by, 'state': state.toJson()}, etag: etag);
  }

  void close() => _client.close();
}

/// What the game screen needs to join an online match that is starting.
class OnlineLink {
  final String code;
  final OnlineService service;
  final int rev;

  /// This device's player: 1-based seat number on the shared board.
  final int mySeat;
  const OnlineLink({required this.code, required this.service, required this.rev, required this.mySeat});
}

/// A device's live link to one online match: polls for other players'
/// moves and uploads this device's own.
class OnlineSession {
  final String code;
  final OnlineService service;
  final GameState state;

  /// Called (on the UI isolate) after another device's newer board was
  /// copied into [state].
  final void Function() onRemoteChange;

  /// Called when the link goes down (false) or comes back (true).
  final void Function(bool connected)? onStatus;

  final String _deviceId = Random().nextInt(1 << 30).toRadixString(36);
  int _rev = 0;
  String? _etag;
  Timer? _timer;
  bool _polling = false;
  bool _disposed = false;
  bool _connected = true;
  Future<void> _queue = Future.value();

  OnlineSession({
    required this.code,
    required this.service,
    required this.state,
    required this.onRemoteChange,
    this.onStatus,
    int initialRev = 1,
  }) : _rev = initialRev;

  bool get connected => _connected;

  void start({Duration every = const Duration(milliseconds: 1500)}) {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => poll());
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }

  void _setConnected(bool v) {
    if (_connected == v) return;
    _connected = v;
    onStatus?.call(v);
  }

  /// Fetches the board and adopts it if it is newer than ours.
  Future<void> poll() => _enqueue(_pollNow);

  Future<void> _pollNow() async {
    if (_disposed || _polling) return;
    _polling = true;
    try {
      final remote = await service.fetchGame(code);
      _setConnected(true);
      if (remote == null || _disposed) return;
      if (remote.rev > _rev) {
        _adopt(remote);
        onRemoteChange();
      } else {
        _etag = remote.etag ?? _etag;
      }
    } catch (_) {
      _setConnected(false);
    } finally {
      _polling = false;
    }
  }

  void _adopt(RemoteGame remote) {
    state.copyFrom(remote.state);
    _rev = remote.rev;
    _etag = remote.etag;
  }

  /// Uploads this device's current [state]. Returns false if another
  /// player changed the board first - the newer board is then adopted
  /// (the caller's change is dropped) and [onRemoteChange] fires.
  Future<bool> push() {
    final completer = Completer<bool>();
    _enqueue(() async {
      if (_disposed) {
        completer.complete(false);
        return;
      }
      try {
        final res = await service.pushGame(code, state, rev: _rev + 1, etag: _etag, by: _deviceId);
        _setConnected(true);
        if (res.ok) {
          _rev += 1;
          _etag = res.etag;
          completer.complete(true);
        } else {
          final remote = await service.fetchGame(code);
          if (remote != null) {
            _adopt(remote);
            onRemoteChange();
          }
          completer.complete(false);
        }
      } catch (_) {
        _setConnected(false);
        completer.complete(false);
      }
    });
    return completer.future;
  }

  Future<void> _enqueue(Future<void> Function() job) {
    _queue = _queue.then((_) => job()).catchError((_) {});
    return _queue;
  }
}
