import 'dart:convert';

import 'package:platform_core/platform_core.dart';
import 'package:test/test.dart';

/// Golden test cho protocol.
///
/// Codec viet tay chi an toan khi co bo test nay: doi khung ban tin ma quen
/// tang [kProtocolVersion] se lam do dung mot trong cac assert o day.
void main() {
  group('khung ban tin', () {
    test('encode ra dung khung {v, type, payload}', () {
      final raw = MessageCodec.encode(const PlayerReady(ready: true));
      final json = jsonDecode(raw) as Map<String, dynamic>;

      expect(json.keys.toSet(), {'v', 'type', 'payload'});
      expect(json['v'], kProtocolVersion);
      expect(json['type'], 'PLAYER_READY');
      expect(json['payload'], {'ready': true});
    });

    test('golden: JOIN_REQUEST giu nguyen hinh dang', () {
      final raw = MessageCodec.encode(
        const JoinRequest(playerId: 'p1', nickname: 'Vu'),
      );
      expect(
        jsonDecode(raw),
        {
          'v': 3,
          'type': 'JOIN_REQUEST',
          'payload': {
            'playerId': 'p1',
            'nickname': 'Vu',
            'protocolVersion': 3,
          },
        },
      );
    });

    test('golden: GAME_ACTION giu nguyen hinh dang', () {
      final raw = MessageCodec.encode(
        const GameActionMessage(
          actionId: 'a1',
          expectedStateVersion: 3,
          action: {'cell': 4},
        ),
      );
      expect(
        jsonDecode(raw),
        {
          'v': 3,
          'type': 'GAME_ACTION',
          'payload': {
            'actionId': 'a1',
            'expectedStateVersion': 3,
            'action': {'cell': 4},
          },
        },
      );
    });
  });

  group('round-trip', () {
    final snapshot = RoomSnapshot(
      roomId: 'r1',
      gameId: 'race',
      displayName: 'Phong cua Vu',
      status: RoomStatus.waiting,
      maxPlayers: 4,
      hostPlayerId: 'p1',
      players: const [
        PlayerSlot(
          playerId: 'p1',
          nickname: 'Vu',
          seat: 0,
          isHost: true,
          isReady: true,
        ),
        PlayerSlot(
          playerId: 'p2',
          nickname: 'Nam',
          seat: 1,
          isHost: false,
          connection: PlayerConnectionState.disconnected,
        ),
      ],
    );

    final samples = <String, Message>{
      'JOIN_REQUEST': const JoinRequest(
        playerId: 'p1',
        nickname: 'Vu',
        roomSecret: 'SECRET',
      ),
      'PLAYER_READY': const PlayerReady(ready: true),
      'START_GAME': const StartGame(),
      'GAME_ACTION': const GameActionMessage(
        actionId: 'a1',
        expectedStateVersion: 2,
        action: {'cell': 8},
      ),
      'LEAVE_ROOM': const LeaveRoom(),
      'PING': const Ping(nonce: 'n1', sentAtMillis: 123),
      'ROOM_JOINED': RoomJoined(you: 'p1', roomSecret: 'S', snapshot: snapshot),
      'JOIN_REJECTED': const JoinRejected(code: 'ROOM_FULL', message: 'day'),
      'ROOM_UPDATE': RoomUpdate(
        snapshot: snapshot,
        reason: RoomUpdateReason.playerJoined,
        actorPlayerId: 'p2',
      ),
      'GAME_START': const GameStart(
        gameId: 'race',
        stateVersion: 1,
        state: {'turnIndex': 0},
        currentActors: ['p1'],
        seatOrder: ['p1', 'p2'],
        playerClocks: {
          'p1': PlayerClock(moveMillis: 30000, matchMillis: 180000, running: true),
          'p2': PlayerClock(moveMillis: 30000, matchMillis: 180000),
        },
      ),
      'GAME_STATE': const GameStateMessage(
        stateVersion: 2,
        state: {'turnIndex': 1},
        currentActors: ['p2'],
        lastActionId: 'a1',
        playerClocks: {
          'p1': PlayerClock(moveMillis: 30000, matchMillis: 174320),
          'p2': PlayerClock(moveMillis: 28110, matchMillis: 171004, running: true),
        },
      ),
      'GAME_RESULT': GameResultMessage(
        stateVersion: 3,
        state: const {'turnIndex': 0},
        result: GameResult.win('p1'),
      ),
      'ROOM_CLOSED': const RoomClosed(code: 'HOST_LEFT'),
      'ERROR': const ErrorMessage(code: 'NOT_YOUR_TURN', actionId: 'a1'),
      'PONG': const Pong(nonce: 'n1', sentAtMillis: 123),
    };

    for (final entry in samples.entries) {
      test('${entry.key} giu nguyen sau encode/decode', () {
        final decoded = MessageCodec.decode(MessageCodec.encode(entry.value));
        expect(decoded.type, entry.key);
        expect(decoded.toPayload(), entry.value.toPayload());
      });
    }

    test('bao phu toan bo cac loai ban tin client va host gui', () {
      // Ep buoc: them mot loai ban tin moi ma quen test se lam do assert nay.
      expect(samples.length, 15);
    });

    test('RoomSnapshot song sot qua round-trip', () {
      final decoded = MessageCodec.decode(
        MessageCodec.encode(
          RoomJoined(you: 'p1', roomSecret: 'S', snapshot: snapshot),
        ),
      ) as RoomJoined;

      expect(decoded.snapshot.players, hasLength(2));
      expect(decoded.snapshot.players[1].connection,
          PlayerConnectionState.disconnected);
      expect(decoded.snapshot.status, RoomStatus.waiting);
      expect(decoded.snapshot.hostPlayerId, 'p1');
    });
  });

  group('tuong thich nguoc', () {
    test('type la thi tra ve UnknownMessage chu khong nem loi', () {
      final raw = jsonEncode({
        'v': kProtocolVersion,
        'type': 'GAME_TAUNT',
        'payload': {'emoji': ':)'},
      });

      final decoded = MessageCodec.decode(raw);
      expect(decoded, isA<UnknownMessage>());
      expect(decoded.type, 'GAME_TAUNT');
    });

    test('phien ban khac thi tra ve UnknownMessage', () {
      final raw = jsonEncode({
        'v': kProtocolVersion + 1,
        'type': 'PLAYER_READY',
        'payload': {'ready': true},
      });

      final decoded = MessageCodec.decode(raw);
      expect(decoded, isA<UnknownMessage>());
      expect((decoded as UnknownMessage).protocolVersion, kProtocolVersion + 1);
    });

    test('chuoi khong phai JSON thi nem FormatException', () {
      expect(() => MessageCodec.decode('khong phai json'),
          throwsA(isA<FormatException>()));
    });
  });
}
