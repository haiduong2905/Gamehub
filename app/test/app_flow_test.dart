import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_hub/state/identity.dart';
import 'package:game_hub/state/network_providers.dart';
import 'package:game_hub/state/session.dart';
import 'package:game_hub/theme.dart';
import 'package:game_hub/ui/home_screen.dart';
import 'package:game_hub/ui/room_screen.dart';
import 'package:game_tictactoe/game_tictactoe.dart';
import 'package:game_xiangqi/game_xiangqi.dart';
import 'package:platform_core/platform_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_network.dart';

/// Dựng cả app trên LoopbackTransport.
///
/// Toàn bộ luồng tạo phòng → vào phòng → sẵn sàng → chơi → thắng được kiểm tra
/// ở đây, trên chính UI thật, mà không cần thiết bị, không cần quyền, không
/// cần Wi-Fi. Đó là lý do LoopbackTransport tồn tại.
ProviderContainer _container(
  LoopbackNetwork network, {
  required String playerId,
  required String nickname,
}) {
  return ProviderContainer(
    overrides: [
      identityProvider.overrideWith(
        () => FakeIdentity(playerId: playerId, nickname: nickname),
      ),
      hostTransportFactoryProvider
          .overrideWithValue(() => LoopbackHostTransport(network)),
      clientTransportProvider
          .overrideWithValue(LoopbackClientTransport(network)),
      discoveryFactoryProvider
          .overrideWithValue(() => LoopbackDiscovery(network)),
      localNetworkPermissionProvider.overrideWithValue(
        const AlwaysGrantedPermission(),
      ),
    ],
  );
}

/// Nhường event loop vài vòng cho bản tin đang bay trên dây đến nơi.
///
/// LocalLink giao tin qua Timer. Trong widget test, Timer chạy trên đồng hồ
/// giả nên await ở đây sẽ treo vĩnh viễn — vì vậy mọi lệnh gọi settle() bên
/// trong testWidgets đều phải nằm trong `tester.runAsync`.
Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('luồng đầy đủ trên Loopback', () {
    test('phòng cờ tướng: chủ chọn Đen, khách cầm Đỏ đi trước', () async {
      final network = LoopbackNetwork();
      final host = _container(network, playerId: 'host', nickname: 'Chủ');
      final guest = _container(network, playerId: 'guest', nickname: 'Khách');
      addTearDown(host.dispose);
      addTearDown(guest.dispose);

      await host.read(identityProvider.future);
      await guest.read(identityProvider.future);
      await host.read(sessionProvider.notifier).createRoom(
            gameId: 'xiangqi',
            displayName: 'Phòng cờ tướng',
            settings: const RoomSettings(gameOptions: {'hostColor': 'black'}),
          );
      await settle();

      final discovery = LoopbackDiscovery(network);
      await discovery.startDiscovery(gameId: 'xiangqi');
      final rooms = await discovery.rooms.first;
      await guest.read(sessionProvider.notifier).joinRoom(
            rooms.first.address,
            gameId: 'xiangqi',
          );
      await settle();

      host.read(sessionProvider.notifier).setReady(ready: true);
      guest.read(sessionProvider.notifier).setReady(ready: true);
      await settle();
      host.read(sessionProvider.notifier).startGame();
      await settle();

      final hostClient = host.read(sessionProvider).client!;
      final guestClient = guest.read(sessionProvider).client!;
      expect(hostClient.phase, ClientPhase.playing);
      expect(hostClient.currentActors, ['guest']);
      expect(guestClient.currentActors, ['guest']);
      final state = const XiangqiGame().decodeState(hostClient.gameState!);
      expect(state.pieceColorOf('host'), XiangqiPieceColor.black);
      expect(state.pieceColorOf('guest'), XiangqiPieceColor.red);

      guest.read(sessionProvider.notifier).sendAction({'from': 54, 'to': 45});
      await settle();
      final stateOnHost = const XiangqiGame()
          .decodeState(host.read(sessionProvider).client!.gameState!);
      final stateOnGuest = const XiangqiGame()
          .decodeState(guest.read(sessionProvider).client!.gameState!);
      expect(stateOnHost.lastMove?.from, 54);
      expect(stateOnHost.lastMove?.to, 45);
      expect(stateOnGuest.lastMove?.from, 54);
      expect(stateOnGuest.lastMove?.to, 45);
      expect(stateOnHost.currentPlayer, 'host');

      host.read(sessionProvider.notifier).sendAction({'from': 27, 'to': 36});
      await settle();
      guest.read(sessionProvider.notifier).sendAction({'from': 45, 'to': 36});
      await settle();
      final capturedOnHost = const XiangqiGame()
          .decodeState(host.read(sessionProvider).client!.gameState!);
      final capturedOnGuest = const XiangqiGame()
          .decodeState(guest.read(sessionProvider).client!.gameState!);
      expect(capturedOnHost.capturedPieces, [
        const XiangqiPiece(
            color: XiangqiPieceColor.black, type: XiangqiPieceType.pawn),
      ]);
      expect(capturedOnGuest.capturedPieces, capturedOnHost.capturedPieces);

      for (var count = 1; count <= 3; count++) {
        host.read(sessionProvider.notifier).sendAction({'type': 'offerDraw'});
        await settle();
        final offered = const XiangqiGame()
            .decodeState(guest.read(sessionProvider).client!.gameState!);
        expect(offered.drawOfferBy, 'host');
        expect(guest.read(sessionProvider).client!.currentActors, ['guest']);

        guest.read(sessionProvider.notifier).sendAction({'type': 'rejectDraw'});
        await settle();
        final rejected = const XiangqiGame()
            .decodeState(host.read(sessionProvider).client!.gameState!);
        expect(rejected.drawRejectionsOf('host'), count);
      }
      expect(host.read(sessionProvider).client!.result!.winners, ['guest']);
      expect(guest.read(sessionProvider).client!.result!.reason,
          'DRAW_REJECTED_THREE_TIMES');

      await discovery.dispose();
      await host.read(sessionProvider.notifier).leave();
      await guest.read(sessionProvider.notifier).leave();
    });

    test('hai người chơi trọn một ván cờ caro qua đúng tầng mạng của app',
        () async {
      final network = LoopbackNetwork();

      final hostSide = _container(network, playerId: 'host', nickname: 'Vu');
      final guestSide = _container(network, playerId: 'guest', nickname: 'Nam');
      addTearDown(hostSide.dispose);
      addTearDown(guestSide.dispose);

      await hostSide.read(identityProvider.future);
      await guestSide.read(identityProvider.future);

      await hostSide.read(sessionProvider.notifier).createRoom(
            gameId: 'tic-tac-toe',
            displayName: 'Phong cua Vu',
          );
      await settle();

      expect(hostSide.read(sessionProvider).status, SessionStatus.active);
      expect(hostSide.read(sessionProvider).isHost, isTrue);

      // Khách tìm thấy phòng qua discovery, đúng như trên máy thật.
      final discovery = LoopbackDiscovery(network);
      await discovery.startDiscovery(gameId: 'tic-tac-toe');
      final rooms = await discovery.rooms.first;
      expect(rooms, hasLength(1));
      expect(rooms.first.advertisement.displayName, 'Phong cua Vu');

      await guestSide.read(sessionProvider.notifier).joinRoom(
            rooms.first.address,
            gameId: 'tic-tac-toe',
          );
      await settle();

      expect(guestSide.read(sessionProvider).status, SessionStatus.active);
      expect(
        hostSide.read(sessionProvider).client!.room!.players,
        hasLength(2),
      );

      hostSide.read(sessionProvider.notifier).setReady(ready: true);
      guestSide.read(sessionProvider.notifier).setReady(ready: true);
      await settle();
      hostSide.read(sessionProvider.notifier).startGame();
      await settle();

      expect(hostSide.read(sessionProvider).client!.phase, ClientPhase.playing);

      // Host là X và thắng bằng hàng trên cùng.
      for (final move in [
        (hostSide, 0),
        (guestSide, 10),
        (hostSide, 1),
        (guestSide, 11),
        (hostSide, 2),
        (guestSide, 12),
        (hostSide, 3),
        (guestSide, 13),
        (hostSide, 4),
      ]) {
        move.$1.read(sessionProvider.notifier).sendAction({'cell': move.$2});
        await settle();
      }

      expect(hostSide.read(sessionProvider).client!.result!.winners, ['host']);
      expect(
        guestSide.read(sessionProvider).client!.result!.winners,
        ['host'],
        reason: 'hai máy phải nhận cùng một kết quả từ host',
      );

      final board = const TicTacToeGame()
          .decodeState(guestSide.read(sessionProvider).client!.gameState!);
      expect(board.winningLine, [0, 1, 2, 3, 4]);

      await discovery.dispose();
      await hostSide.read(sessionProvider.notifier).leave();
      await guestSide.read(sessionProvider.notifier).leave();
    });

    test('không có quyền mạng nội bộ thì báo lỗi rõ ràng', () async {
      final network = LoopbackNetwork();
      final container = ProviderContainer(
        overrides: [
          identityProvider.overrideWith(
            () => FakeIdentity(playerId: 'p1', nickname: 'Vu'),
          ),
          hostTransportFactoryProvider
              .overrideWithValue(() => LoopbackHostTransport(network)),
          discoveryFactoryProvider
              .overrideWithValue(() => LoopbackDiscovery(network)),
          localNetworkPermissionProvider
              .overrideWithValue(const DeniedPermission()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(identityProvider.future);

      await container.read(sessionProvider.notifier).createRoom(
            gameId: 'tic-tac-toe',
            displayName: 'Phong',
          );

      final session = container.read(sessionProvider);
      expect(session.status, SessionStatus.failed);
      expect(session.errorCode, 'NO_PERMISSION');
    });
  });

  group('giao diện', () {
    testWidgets('màn hình chính liệt kê game đã đăng ký', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HomeScreen())),
      );
      await tester.pump();

      expect(find.text('Xin chào'), findsOneWidget,
          reason: 'đầu trang là avatar và tên người chơi');
      expect(find.text('GAME SẴN CÓ'), findsOneWidget);
      expect(find.text('Cờ caro'), findsWidgets);
      expect(find.textContaining('Wi-Fi'), findsWidgets);
    });

    testWidgets('phòng chờ hiện người chơi và khoá nút bắt đầu khi thiếu người',
        (tester) async {
      final network = LoopbackNetwork();
      final container = _container(network, playerId: 'host', nickname: 'Vu');
      addTearDown(container.dispose);

      // runAsync để Timer của LocalLink chạy trên đồng hồ thật.
      await tester.runAsync(() async {
        await container.read(identityProvider.future);
        await container.read(sessionProvider.notifier).createRoom(
              gameId: 'tic-tac-toe',
              displayName: 'Phong cua Vu',
            );
        await settle();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: const RoomScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Phong cua Vu'), findsOneWidget);
      expect(find.text('Vu'), findsOneWidget);
      expect(find.text('Sẵn sàng'), findsOneWidget);

      final startButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Bắt đầu ván'),
      );
      expect(
        startButton.onPressed,
        isNull,
        reason: 'một mình thì chưa được bắt đầu',
      );

      await tester.runAsync(
        () => container.read(sessionProvider.notifier).leave(),
      );
    });

    testWidgets('màn hình ván đấu vẽ bàn cờ và cho biết đang là lượt ai',
        (tester) async {
      final network = LoopbackNetwork();
      final hostSide = _container(network, playerId: 'host', nickname: 'Vu');
      final guestSide = _container(network, playerId: 'guest', nickname: 'Nam');
      addTearDown(hostSide.dispose);
      addTearDown(guestSide.dispose);

      late RoomAddress address;

      await tester.runAsync(() async {
        await hostSide.read(identityProvider.future);
        await guestSide.read(identityProvider.future);

        await hostSide.read(sessionProvider.notifier).createRoom(
              gameId: 'tic-tac-toe',
              displayName: 'Phong',
            );
        await settle();

        final discovery = LoopbackDiscovery(network);
        await discovery.startDiscovery(gameId: 'tic-tac-toe');
        address = (await discovery.rooms.first).first.address;
        await discovery.dispose();

        await guestSide
            .read(sessionProvider.notifier)
            .joinRoom(address, gameId: 'tic-tac-toe');
        await settle();

        hostSide.read(sessionProvider.notifier).setReady(ready: true);
        guestSide.read(sessionProvider.notifier).setReady(ready: true);
        await settle();
        hostSide.read(sessionProvider.notifier).startGame();
        await settle();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: hostSide,
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: const RoomScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Lượt của bạn'), findsOneWidget);
      const cells = TicTacToeGame.boardSize * TicTacToeGame.boardSize;
      expect(find.byType(AnimatedContainer), findsNWidgets(cells),
          reason: 'mỗi ô bàn cờ là một AnimatedContainer');

      // Việc chạm ô rồi nước đi chạy qua host được kiểm tra ở hai chỗ khác,
      // mỗi chỗ đúng tầng của nó: test đầu file kiểm tra trọn ván qua đúng
      // tầng mạng của app, còn game_tictactoe kiểm tra chạm ô thì bàn cờ gọi
      // onAction với đúng số ô.

      await tester.runAsync(() async {
        await hostSide.read(sessionProvider.notifier).leave();
        await guestSide.read(sessionProvider.notifier).leave();
      });
    });
  });
}
