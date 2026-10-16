import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grid_word_game/models/game_state.dart';
import 'package:grid_word_game/services/online_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A tiny in-memory stand-in for the Firebase Realtime Database REST API:
/// JSON values per path, an ETag that changes on every write, and
/// `if-match` support (including `null_etag`).
MockClient fakeDatabase({void Function(http.Request)? onRequest}) {
  final data = <String, String>{}; // path -> json
  final etags = <String, int>{};
  return MockClient((req) async {
    onRequest?.call(req);
    final path = req.url.path; // /rooms/CODE/lobby.json
    final current = data[path];
    final etag = current == null ? 'null_etag' : 'e${etags[path]}';
    if (req.method == 'GET') {
      return http.Response(current ?? 'null', 200, headers: {'etag': etag});
    }
    if (req.method == 'PUT') {
      final ifMatch = req.headers['if-match'];
      if (ifMatch != null && ifMatch != etag) return http.Response('', 412);
      data[path] = req.body;
      etags[path] = (etags[path] ?? 0) + 1;
      return http.Response(req.body, 200, headers: {'etag': 'e${etags[path]}'});
    }
    return http.Response('', 405);
  });
}

OnlineService newService(MockClient c) => OnlineService(client: c, baseUrl: 'https://example.test');

void main() {
  test('create, join, start and share a board', () async {
    final client = fakeDatabase();
    final host = newService(client);
    final guest = newService(client);

    final code = await host.createRoom(hostName: 'Ann', hostUid: 'uA', maxPlayers: 3, rows: 4, cols: 5);
    expect(code.length, 6);

    final lobby = await guest.joinRoom(code, 'Bob', 'uB');
    expect(lobby.players, ['Ann', 'Bob']);
    expect(lobby.seatOf('uA'), 0);
    expect(lobby.seatOf('uB'), 1);
    expect(lobby.seatOf('nobody'), -1);

    final game = await host.startGame(code);
    expect(game.playerNames, ['Ann', 'Bob']);
    expect(game.rows, 4);
    expect(game.cols, 5);
    expect((await guest.fetchLobby(code))!.started, isTrue);

    final remote = (await guest.fetchGame(code))!;
    expect(remote.rev, 1);
    expect(remote.state.playerNames, ['Ann', 'Bob']);
  });

  test('room full, unknown code and started rooms are refused', () async {
    final client = fakeDatabase();
    final s = newService(client);
    final code = await s.createRoom(hostName: 'A', hostUid: 'uA', maxPlayers: 2, rows: 3, cols: 3);
    await s.joinRoom(code, 'B', 'uB');
    await expectLater(() => s.joinRoom(code, 'C', 'uC'), throwsA(isA<OnlineException>()));
    await expectLater(() => s.joinRoom('ZZZZZZ', 'C', 'uC'), throwsA(isA<OnlineException>()));
    await s.startGame(code);
    await expectLater(() => s.joinRoom(code, 'D', 'uD'), throwsA(isA<OnlineException>()));
  });

  test('a stale write is rejected and the newer board is adopted', () async {
    final client = fakeDatabase();
    final a = newService(client);
    final code = await a.createRoom(hostName: 'A', hostUid: 'uA', maxPlayers: 2, rows: 3, cols: 3);
    await a.joinRoom(code, 'B', 'uB');
    final g = await a.startGame(code);

    final stateA = GameState.decode(g.encode());
    final stateB = GameState.decode(g.encode());
    var changedA = 0;
    var changedB = 0;
    final sa = OnlineSession(code: code, service: a, state: stateA, onRemoteChange: () => changedA++);
    final sb = OnlineSession(code: code, service: newService(client), state: stateB, onRemoteChange: () => changedB++);
    await sa.poll(); // learns the current etag
    await sb.poll();

    stateA.grid[0][0] = 'A';
    stateA.locked[0][0] = true;
    expect(await sa.push(), isTrue);

    // B did not see A's move yet and writes on top of the old board.
    stateB.grid[1][1] = 'B';
    stateB.locked[1][1] = true;
    expect(await sb.push(), isFalse);
    expect(changedB, 1);
    expect(stateB.grid[0][0], 'A', reason: "B adopted A's board");
    expect(stateB.grid[1][1], '', reason: "B's clashing change was dropped");

    // A later poll on A sees nothing new.
    await sa.poll();
    expect(changedA, 0);

    // B can now move normally.
    stateB.grid[1][1] = 'B';
    stateB.locked[1][1] = true;
    expect(await sb.push(), isTrue);
    await sa.poll();
    expect(changedA, 1);
    expect(stateA.grid[1][1], 'B');
    expect(jsonDecode(stateA.encode()), isA<Map>());
  });

  test('a player who was in the room can re-join after the game started', () async {
    final client = fakeDatabase();
    final s = newService(client);
    final code = await s.createRoom(hostName: 'A', hostUid: 'uA', maxPlayers: 2, rows: 3, cols: 3);
    await s.joinRoom(code, 'B', 'uB');
    await s.startGame(code, byUid: 'uA');

    // Both original players can come back, in their original seats,
    // even though the room is started AND full.
    final backB = await s.joinRoom(code, 'Bobby', 'uB');
    expect(backB.seatOf('uB'), 1);
    expect(backB.players, ['A', 'B'], reason: 're-joining must not add a second seat or rename the player');
    final backA = await s.joinRoom(code, 'A', 'uA');
    expect(backA.seatOf('uA'), 0);

    // A stranger is still turned away.
    await expectLater(() => s.joinRoom(code, 'Eve', 'uE'), throwsA(isA<OnlineException>()));
  });

  test('a player can re-join a room that has not started without taking a second seat', () async {
    final client = fakeDatabase();
    final s = newService(client);
    final code = await s.createRoom(hostName: 'A', hostUid: 'uA', maxPlayers: 3, rows: 3, cols: 3);
    await s.joinRoom(code, 'B', 'uB');
    final again = await s.joinRoom(code, 'B', 'uB');
    expect(again.players, ['A', 'B']);
    final c = await s.joinRoom(code, 'C', 'uC');
    expect(c.seatOf('uC'), 2);
  });

  test('only the host can start the game', () async {
    final client = fakeDatabase();
    final s = newService(client);
    final code = await s.createRoom(hostName: 'A', hostUid: 'uA', maxPlayers: 2, rows: 3, cols: 3);
    await s.joinRoom(code, 'B', 'uB');
    await expectLater(() => s.startGame(code, byUid: 'uB'), throwsA(isA<OnlineException>()));
    expect((await s.fetchLobby(code))!.started, isFalse);
    await s.startGame(code, byUid: 'uA');
    expect((await s.fetchLobby(code))!.started, isTrue);
  });

  test('the sign-in token is sent as ?auth= on every request', () async {
    final seen = <String>[];
    final client = fakeDatabase(onRequest: (req) => seen.add(req.url.queryParameters['auth'] ?? ''));
    final s = OnlineService(client: client, baseUrl: 'https://example.test', tokenProvider: () async => 'tok123');
    final code = await s.createRoom(hostName: 'A', hostUid: 'uA', maxPlayers: 2, rows: 3, cols: 3);
    await s.fetchLobby(code);
    expect(seen, isNotEmpty);
    expect(seen.every((a) => a == 'tok123'), isTrue);
  });

  test('room codes avoid look-alike characters', () {
    for (var i = 0; i < 50; i++) {
      expect(OnlineService.randomCode(), matches(RegExp(r'^[A-HJ-NP-Z2-9]{6}$')));
    }
    expect(OnlineService.normalizeCode(' ab-12 cd '), 'AB12CD');
  });
}
