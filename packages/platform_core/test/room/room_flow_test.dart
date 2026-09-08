import 'package:platform_core/platform_core.dart';
import 'package:test/test.dart';

import '../support/harness.dart';
import '../support/race_game.dart';

GameRegistry _registry() => GameRegistry()..register(const RaceGame());

void main() {
  group('vong doi phong', () {
    late RoomHarness h;

    setUp(() {
      h = RoomHarness(registry: _registry(), gameId: 'race');
    });

    tearDown(() => h.dispose());

    test('host mo phong thi tu no vao phong qua dung protocol', () async {
      final host = await h.open();

      expect(host.state.phase, ClientPhase.inRoom);
      expect(host.state.room!.players, hasLength(1));
      expect(host.state.mySlot!.isHost, isTrue);
      expect(host.state.amHost, isTrue);
      expect(host.roomSecret, isNotNull);
    });

    test('nguoi choi khac tim thay phong roi vao duoc', () async {
      final host = await h.open();
      final guest = await h.joinViaDiscovery(playerId: 'p2', nickname: 'Nam');
      await h.settle();

      expect(guest.state.phase, ClientPhase.inRoom);
      expect(guest.state.room!.players, hasLength(2));
      // Ca hai ben nhin thay cung mot su that.
      expect(host.state.room!.players, hasLength(2));
      expect(host.state.room!.status, RoomStatus.waiting);
      expect(guest.state.mySlot!.seat, 1);
    });

    test('discovery loc theo gameId', () async {
      await h.open();
      final discovery = LoopbackDiscovery(h.network);
      await discovery.startDiscovery(gameId: 'game-khac');
      final rooms = await discovery.rooms.first;

      expect(rooms, isEmpty);
      await discovery.dispose();
    });

    test('du nguoi va tat ca san sang thi phong chuyen sang ready', () async {
      final host = await h.open();
      final guest = await h.joinViaDiscovery(playerId: 'p2', nickname: 'Nam');

      host.setReady(ready: true);
      await h.settle();
      expect(host.state.room!.status, RoomStatus.waiting);

      guest.setReady(ready: true);
      await h.settle();
      expect(host.state.room!.status, RoomStatus.ready);
      expect(guest.state.room!.status, RoomStatus.ready);
    });
  });

  group('choi het mot van', () {
    late RoomHarness h;
    late RoomClient host;
    late RoomClient guest;

    setUp(() async {
      h = RoomHarness(registry: _registry(), gameId: 'race');
      host = await h.open();
      guest = await h.joinViaDiscovery(playerId: 'p2', nickname: 'Nam');
      host.setReady(ready: true);
      guest.setReady(ready: true);
      await h.settle();
    });

    tearDown(() => h.dispose());

    test('host bat dau van thi ca hai nhan duoc GAME_START', () async {
      host.startGame();
      await h.settle();

      expect(host.state.phase, ClientPhase.playing);
      expect(guest.state.phase, ClientPhase.playing);
      expect(host.state.seatOrder, ['host', 'p2']);
      expect(host.state.isMyTurn, isTrue);
      expect(guest.state.isMyTurn, isFalse);
      expect(host.state.stateVersion, 1);
    });

    test('chi host duoc bat dau van', () async {
      guest.startGame();
      await h.settle();

      expect(guest.state.errorCode, 'NOT_HOST');
      expect(guest.state.phase, ClientPhase.inRoom);
    });

    test('nuoc di di qua host va den ca hai ben', () async {
      host.startGame();
      await h.settle();

      host.sendAction({'step': 2});
      expect(host.state.hasPendingAction, isTrue,
          reason: 'UI phai biet nuoc di dang cho host xac nhan');
      await h.settle();

      expect(host.state.hasPendingAction, isFalse);
      expect(host.state.stateVersion, 2);
      expect(guest.state.stateVersion, 2);
      expect(guest.state.isMyTurn, isTrue);
      expect(host.state.isMyTurn, isFalse);

      final scores = (guest.state.gameState!['scores'] as Map)
          .cast<String, dynamic>();
      expect(scores['host'], 2);
    });

    test('di khi chua den luot thi bi tu choi', () async {
      host.startGame();
      await h.settle();

      guest.sendAction({'step': 1});
      await h.settle();

      expect(guest.state.errorCode, 'NOT_YOUR_TURN');
      expect(guest.state.hasPendingAction, isFalse);
      expect(guest.state.stateVersion, 1, reason: 'state khong duoc thay doi');
    });

    test('nuoc di khong hop le theo luat game thi bi tu choi', () async {
      host.startGame();
      await h.settle();

      host.sendAction({'step': 9});
      await h.settle();

      expect(host.state.errorCode, 'BAD_STEP');
      expect(host.state.stateVersion, 1);
    });

    test('choi den khi co nguoi thang', () async {
      host.startGame();
      await h.settle();

      // Race toi 5 diem: host 2, guest 2, host 2, guest 2, host 2 -> host thang.
      for (var i = 0; i < 5; i++) {
        final actor = i.isEven ? host : guest;
        actor.sendAction({'step': 2});
        await h.settle();
      }

      expect(host.state.phase, ClientPhase.finished);
      expect(guest.state.phase, ClientPhase.finished);
      expect(host.state.result!.isWin, isTrue);
      expect(host.state.result!.winners, ['host']);
      // Ca hai ben nhan cung mot ket qua tu host.
      expect(guest.state.result!.winners, ['host']);
      expect(host.state.currentActors, isEmpty);
    });

    test('nguoi vao phong sau khi van vua xong thi vao phong cho', () async {
      host.startGame();
      await h.settle();
      for (var i = 0; i < 5; i++) {
        (i.isEven ? host : guest).sendAction({'step': 2});
        await h.settle();
      }

      final nguoiMoi =
          await h.joinViaDiscovery(playerId: 'p3', nickname: 'C');
      await h.settle();

      // Khong duoc dua vao man van dau: nguoi nay khong he co state game nao,
      // renderer se do khi ve mot ban co rong.
      expect(nguoiMoi.state.phase, ClientPhase.inRoom);
      expect(nguoiMoi.state.gameState, isNull);
      // Con hai nguoi vua choi thi van o man ket qua.
      expect(host.state.phase, ClientPhase.finished);
    });

    test('mot nguoi bam choi lai thi man ket qua chua bien mat', () async {
      host.startGame();
      await h.settle();
      for (var i = 0; i < 5; i++) {
        (i.isEven ? host : guest).sendAction({'step': 2});
        await h.settle();
      }

      host.setReady(ready: true);
      await h.settle();

      expect(host.state.phase, ClientPhase.finished,
          reason: 'nguoi kia chua bam thi chua duoc nhay ve phong cho');
      expect(guest.state.phase, ClientPhase.finished);
      expect(host.state.room!.slotOf('host')!.isReady, isTrue);
      expect(host.state.result, isNotNull);
    });

    test('van moi thi moi nguoi phai bam san sang lai', () async {
      host.startGame();
      await h.settle();
      for (var i = 0; i < 5; i++) {
        (i.isEven ? host : guest).sendAction({'step': 2});
        await h.settle();
      }

      expect(host.state.room!.players.every((p) => !p.isReady), isTrue);

      host.setReady(ready: true);
      guest.setReady(ready: true);
      await h.settle();
      host.startGame();
      await h.settle();

      expect(host.state.phase, ClientPhase.playing);
      expect(host.state.result, isNull, reason: 'ket qua van cu phai bi xoa');
      expect(host.state.stateVersion, 1);
    });
  });

  group('idempotency va state version', () {
    late RoomHarness h;
    late RoomClient host;
    late RoomClient guest;

    setUp(() async {
      h = RoomHarness(registry: _registry(), gameId: 'race');
      host = await h.open();
      guest = await h.joinViaDiscovery(playerId: 'p2', nickname: 'Nam');
      host.setReady(ready: true);
      guest.setReady(ready: true);
      await h.settle();
      host.startGame();
      await h.settle();
    });

    tearDown(() => h.dispose());

    test('cung mot actionId gui hai lan chi duoc ap dung mot lan', () async {
      // Gui thang qua link de mo phong dung tinh huong gui lai sau reconnect.
      const duplicate = GameActionMessage(
        actionId: 'a-fixed',
        expectedStateVersion: 1,
        action: {'step': 2},
      );

      final session = h.host.session!;
      final first = session.applyAction(
        actor: 'host',
        actionId: duplicate.actionId,
        expectedStateVersion: 1,
        action: duplicate.action,
      );
      final second = session.applyAction(
        actor: 'host',
        actionId: duplicate.actionId,
        expectedStateVersion: 2,
        action: duplicate.action,
      );

      expect(first, isA<ActionApplied>());
      expect(second, isA<ActionDuplicate>());
      expect(session.stateVersion, 2, reason: 'chi tang dung mot lan');
    });

    test('nuoc di dua tren state cu bi tu choi', () async {
      final session = h.host.session!;
      final outcome = session.applyAction(
        actor: 'host',
        actionId: 'a-stale',
        expectedStateVersion: 99,
        action: const {'step': 1},
      );

      expect(outcome, isA<ActionRejected>());
      expect((outcome as ActionRejected).code, 'STALE_STATE');
    });
  });
}
