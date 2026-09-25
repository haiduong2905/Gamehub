import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_hub/state/identity.dart';
import 'package:game_hub/state/network_providers.dart';
import 'package:game_hub/state/session.dart';
import 'package:game_hub/theme.dart';
import 'package:game_hub/ui/game_rooms_screen.dart';
import 'package:game_hub/transport/lan/local_network_permission.dart';
import 'package:platform_core/platform_core.dart';

import 'support/fake_network.dart';

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ProviderContainer _container(
  LoopbackNetwork network, {
  LocalNetworkPermission permission = const AlwaysGrantedPermission(),
}) =>
    ProviderContainer(
      overrides: [
        identityProvider.overrideWith(
          () => FakeIdentity(playerId: 'me', nickname: 'Vu'),
        ),
        hostTransportFactoryProvider
            .overrideWithValue(() => LoopbackHostTransport(network)),
        clientTransportProvider
            .overrideWithValue(LoopbackClientTransport(network)),
        discoveryFactoryProvider
            .overrideWithValue(() => LoopbackDiscovery(network)),
        localNetworkPermissionProvider.overrideWithValue(permission),
      ],
    );

/// Màn tìm phòng phải đi qua đúng những provider mà `network_providers.dart`
/// dựng ra.
///
/// Trước đây nó tự gọi `LocalNetworkPermission()` và `LanDiscovery()` ngay
/// trong `build`, nên mọi override đều bị bỏ qua: màn này là màn duy nhất
/// trong app không test được, và trên máy không có plugin thì nó rơi thẳng
/// vào trạng thái "Không quét được mạng".
void main() {
  Future<void> pump(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const GameRoomsScreen(gameId: 'tic-tac-toe'),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(_settle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('chưa thấy phòng nào thì mời người dùng kiểm tra Wi-Fi',
      (tester) async {
    await pump(tester, _container(LoopbackNetwork()));

    expect(find.text('Đang tìm phòng…'), findsOneWidget);
    expect(find.text('Đang quét phòng gần bạn'), findsOneWidget);
    expect(
      find.text('Không quét được mạng'),
      findsNothing,
      reason: 'quét qua transport giả thì không được coi là lỗi',
    );
  });

  testWidgets('phòng tìm thấy hiện thành một dòng chạm được', (tester) async {
    final network = LoopbackNetwork();
    final host = _container(network);
    addTearDown(host.dispose);

    await tester.runAsync(() async {
      await host.read(identityProvider.future);
      await host.read(sessionProvider.notifier).createRoom(
            gameId: 'tic-tac-toe',
            displayName: 'Phòng của Vu',
          );
      await _settle();
    });

    await pump(tester, _container(network));

    expect(find.text('Phòng của Vu'), findsOneWidget);

    await tester.runAsync(() => host.read(sessionProvider.notifier).leave());
  });

  testWidgets('bị từ chối quyền thì nói rõ và mở được Cài đặt', (tester) async {
    await pump(
      tester,
      _container(LoopbackNetwork(), permission: const DeniedPermission()),
    );

    expect(find.text('Chưa có quyền truy cập mạng nội bộ'), findsOneWidget);
    expect(find.text('Mở Cài đặt'), findsOneWidget);
    expect(find.text('Đang tìm phòng…'), findsNothing);
  });
}
