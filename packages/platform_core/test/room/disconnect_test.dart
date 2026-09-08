import 'package:platform_core/platform_core.dart';
import 'package:test/test.dart';

import '../support/harness.dart';
import '../support/race_game.dart';

GameRegistry _registry() => GameRegistry()..register(const RaceGame());

void main() {
  group('mat ket noi giua van', () {
    test('doi thu rot mang thi bi danh dau disconnected, chua bi loai',
        () async {
      final h = RoomHarness(
        registry: _registry(),
        gameId: 'race',
        rejoinGrace: const Duration(seconds: 30),
      );
      final host = await h.open();
      final guest = await h.joinViaDiscovery(playerId: 'p2', nickname: 'Nam');
      host.setReady(ready: true);
      guest.setReady(ready: true);
      await h.settle();
      host.startGame();
      await h.settle();

      // Mat ket noi dot ngot: dong link ma khong gui LEAVE_ROOM.
      await guest.dispose();
      await h.settle();

      final slot = host.state.room!.slotOf('p2')!;
      expect(slot.connection, PlayerConnectionState.disconnected);
      expect(host.state.room!.players, hasLength(2),
          reason: 'van con giu cho de doi quay lai');
      expect(host.state.phase, ClientPhase.playing,
          reason: 'van dau chua bi huy');

      await h.host.close();
    });

    test('quay lai bang roomSecret thi vao dung cho ngoi va nhan lai van dau',
        () async {
      final h = RoomHarness(
        registry: _registry(),
        gameId: 'race',
        rejoinGrace: const Duration(seconds: 30),
      );
      final host = await h.open();
      final guest = await h.joinViaDiscovery(playerId: 'p2', nickname: 'Nam');
      final secret = guest.roomSecret;
      host.setReady(ready: true);
      guest.setReady(ready: true);
      await h.settle();
      host.startGame();
      await h.settle();

      host.sendAction({'step': 2});
      await h.settle();
      final versionTruocKhiRot = host.state.stateVersion;

      await guest.dispose();
      await h.settle();

      final rejoined = await h.joinAt(
        h.address,
        playerId: 'p2',
        nickname: 'Nam',
        roomSecret: secret,
      );
      await h.settle();

      expect(rejoined.state.phase, ClientPhase.playing,
          reason: 'phai duoc dua thang tro lai van dang choi');
      expect(rejoined.state.stateVersion, versionTruocKhiRot);
      expect(rejoined.state.mySlot!.seat, 1);
      expect(rejoined.state.mySlot!.connection,
          PlayerConnectionState.connected);
      expect(rejoined.state.isMyTurn, isTrue);
      expect(host.state.room!.slotOf('p2')!.isConnected, isTrue);

      // Va choi tiep duoc binh thuong.
      rejoined.sendAction({'step': 2});
      await h.settle();
      expect(host.state.stateVersion, versionTruocKhiRot + 1);

      await h.host.close();
    });

    test('quay lai voi secret sai thi bi tu choi', () async {
      final h = RoomHarness(
        registry: _registry(),
        gameId: 'race',
        rejoinGrace: const Duration(seconds: 30),
      );
      await h.open();
      final guest = await h.joinViaDiscovery(playerId: 'p2', nickname: 'Nam');
      await guest.dispose();
      await h.settle();

      final imposter = await h.joinAt(
        h.address,
        playerId: 'p2',
        nickname: 'Ke mao danh',
        roomSecret: 'SAI-BET',
      );
      await h.settle();

      expect(imposter.state.phase, ClientPhase.rejected);
      expect(imposter.state.errorCode, 'ID_TAKEN');

      await h.host.close();
    });

    test('het thoi gian cho thi van dau bi bo do', () async {
      final h = RoomHarness(
        registry: _registry(),
        gameId: 'race',
        rejoinGrace: const Duration(milliseconds: 60),
      );
      final host = await h.open();
      final guest = await h.joinViaDiscovery(playerId: 'p2', nickname: 'Nam');
      host.setReady(ready: true);
      guest.setReady(ready: true);
      await h.settle();
      host.startGame();
      await h.settle();

      await guest.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await h.settle();

      expect(host.state.phase, ClientPhase.finished);
      expect(host.state.result!.isAbandoned, isTrue);
      expect(host.state.result!.reason, 'OPPONENT_LEFT');
      expect(host.state.room!.players, hasLength(1),
          reason: 'nguoi khong quay lai thi bi loai khoi phong');

      await h.host.close();
    });

    test('host thoat thi phong dong va client duoc bao ro ly do', () async {
      final h = RoomHarness(registry: _registry(), gameId: 'race');
      final host = await h.open();
      final guest = await h.joinViaDiscovery(playerId: 'p2', nickname: 'Nam');
      await h.settle();

      await host.dispose();
      await h.settle();

      expect(guest.state.phase, ClientPhase.closed);
      expect(guest.state.closeCode, 'HOST_LEFT');
    });

    test('roi phong chu dong thi bi loai ngay, khong cho', () async {
      final h = RoomHarness(
        registry: _registry(),
        gameId: 'race',
        rejoinGrace: const Duration(seconds: 30),
      );
      final host = await h.open();
      final guest = await h.joinViaDiscovery(playerId: 'p2', nickname: 'Nam');
      await h.settle();

      guest.leave();
      await h.settle();

      expect(host.state.room!.players, hasLength(1));
      await h.host.close();
    });
  });

  group('tu choi vao phong', () {
    test('phong day thi tu choi', () async {
      final h = RoomHarness(registry: _registry(), gameId: 'race');
      await h.open();
      await h.joinViaDiscovery(playerId: 'p2', nickname: 'B');
      await h.joinViaDiscovery(playerId: 'p3', nickname: 'C');
      await h.joinViaDiscovery(playerId: 'p4', nickname: 'D');
      final thua = await h.joinViaDiscovery(playerId: 'p5', nickname: 'E');
      await h.settle();

      expect(thua.state.phase, ClientPhase.rejected);
      expect(thua.state.errorCode, 'ROOM_FULL');

      await h.host.close();
    });

    test('van dang choi thi khong cho vao', () async {
      final h = RoomHarness(registry: _registry(), gameId: 'race');
      final host = await h.open();
      final guest = await h.joinViaDiscovery(playerId: 'p2', nickname: 'Nam');
      host.setReady(ready: true);
      guest.setReady(ready: true);
      await h.settle();
      host.startGame();
      await h.settle();

      final muon = await h.joinAt(h.address, playerId: 'p3', nickname: 'C');
      await h.settle();

      expect(muon.state.phase, ClientPhase.rejected);
      expect(muon.state.errorCode, 'GAME_IN_PROGRESS');

      await h.host.close();
    });
  });

  group('nhieu hon hai nguoi choi', () {
    test('bon nguoi choi lan luot theo dung thu tu cho ngoi', () async {
      final h = RoomHarness(registry: _registry(), gameId: 'race');
      final host = await h.open();
      final b = await h.joinViaDiscovery(playerId: 'p2', nickname: 'B');
      final c = await h.joinViaDiscovery(playerId: 'p3', nickname: 'C');
      final d = await h.joinViaDiscovery(playerId: 'p4', nickname: 'D');

      for (final client in [host, b, c, d]) {
        client.setReady(ready: true);
      }
      await h.settle();
      host.startGame();
      await h.settle();

      expect(host.state.seatOrder, ['host', 'p2', 'p3', 'p4']);
      expect(host.state.isMyTurn, isTrue);

      host.sendAction({'step': 1});
      await h.settle();
      expect(b.state.isMyTurn, isTrue);

      b.sendAction({'step': 1});
      await h.settle();
      expect(c.state.isMyTurn, isTrue);

      c.sendAction({'step': 1});
      await h.settle();
      expect(d.state.isMyTurn, isTrue);

      d.sendAction({'step': 1});
      await h.settle();
      expect(host.state.isMyTurn, isTrue, reason: 'quay vong lai host');

      await h.host.close();
    });

    test('mot nguoi rot khi con ba nguoi thi van dau van tiep tuc', () async {
      final h = RoomHarness(
        registry: _registry(),
        gameId: 'race',
        rejoinGrace: const Duration(milliseconds: 60),
      );
      final host = await h.open();
      final b = await h.joinViaDiscovery(playerId: 'p2', nickname: 'B');
      final c = await h.joinViaDiscovery(playerId: 'p3', nickname: 'C');
      for (final client in [host, b, c]) {
        client.setReady(ready: true);
      }
      await h.settle();
      host.startGame();
      await h.settle();

      await c.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await h.settle();

      expect(host.state.phase, ClientPhase.playing,
          reason: 'van con du nguoi toi thieu nen van dau khong bi huy');
      expect(host.state.room!.players, hasLength(2));

      await h.host.close();
    });
  });

  group('thong tin an', () {
    test('host khong gui bi mat cua nguoi nay cho nguoi kia', () async {
      final registry = GameRegistry()..register(const SecretNumberGame());
      final h = RoomHarness(registry: registry, gameId: 'secret');
      final host = await h.open();
      final guest = await h.joinViaDiscovery(playerId: 'p2', nickname: 'Nam');
      host.setReady(ready: true);
      guest.setReady(ready: true);
      await h.settle();
      host.startGame();
      await h.settle();

      final hostSees = (host.state.gameState!['secrets'] as Map)
          .cast<String, dynamic>();
      final guestSees = (guest.state.gameState!['secrets'] as Map)
          .cast<String, dynamic>();

      expect(hostSees['host'], 'host_secret');
      expect(hostSees['p2'], isNull, reason: 'khong duoc thay bai cua doi thu');
      expect(guestSees['p2'], 'p2_secret');
      expect(guestSees['host'], isNull);

      await h.host.close();
    });
  });
}
