import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_audio/game_audio.dart';
import 'package:game_hub/state/identity.dart';
import 'package:game_hub/state/network_providers.dart';
import 'package:game_hub/state/session.dart';
import 'package:game_hub/theme.dart';
import 'package:game_hub/ui/app_ui.dart';
import 'package:game_hub/ui/game_rooms_screen.dart';
import 'package:game_hub/ui/home_screen.dart';
import 'package:game_hub/ui/settings_screen.dart';
import 'package:game_hub/ui/room_screen.dart';
import 'package:platform_core/platform_core.dart';

import '../test/support/fake_network.dart';

/// LocalLink giao tin qua Timer, mà trong widget test Timer chạy trên đồng hồ
/// giả — nên mọi lệnh gọi settle() phải nằm trong `tester.runAsync`.
Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Không phải test: dựng ảnh PNG của các màn hình `app` để mắt người soi bố
/// cục.
///
///     cd app && flutter test tool/render_preview_test.dart
void main() {
  Future<void> shoot(WidgetTester tester, String name) async {
    final bytes = await tester.binding.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    Directory('build').createSync(recursive: true);
    File('build/$name.png').writeAsBytesSync(bytes!);
  }

  /// Phòng chờ của **chủ phòng**: chỉ vai này mới thấy thẻ địa chỉ.
  Future<ProviderContainer> hostRoom(WidgetTester tester) async {
    final network = LoopbackNetwork();
    final container = ProviderContainer(
      overrides: [
        identityProvider.overrideWith(
          () => FakeIdentity(playerId: 'host', nickname: 'Người chơi 70DD'),
        ),
        hostTransportFactoryProvider
            .overrideWithValue(() => LoopbackHostTransport(network)),
        clientTransportProvider
            .overrideWithValue(LoopbackClientTransport(network)),
        discoveryFactoryProvider
            .overrideWithValue(() => LoopbackDiscovery(network)),
        localNetworkPermissionProvider
            .overrideWithValue(const AlwaysGrantedPermission()),
      ],
    );
    addTearDown(container.dispose);

    await tester.runAsync(() async {
      await container.read(identityProvider.future);
      await container.read(sessionProvider.notifier).createRoom(
            gameId: 'tic-tac-toe',
            displayName: 'Phòng của Người chơi 70DD',
          );
      await settle();
    });

    tester.view
      ..physicalSize = const Size(1080, 2186)
      ..devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      RepaintBoundary(
        child: UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            // Lồng hai tầng để `Navigator.canPop()` đúng true, giống như khi
            // màn này được đẩy từ danh sách phòng — nếu không sẽ không thấy
            // nút quay lại.
            initialRoute: '/room',
            routes: {
              '/': (_) => const SizedBox(),
              '/room': (_) => const RoomScreen(),
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Màn tìm phòng, trạng thái chưa thấy phòng nào.
  Future<void> rooms(WidgetTester tester) async {
    final network = LoopbackNetwork();
    final container = ProviderContainer(
      overrides: [
        identityProvider.overrideWith(
          () => FakeIdentity(playerId: 'me', nickname: 'Người chơi 70DD'),
        ),
        hostTransportFactoryProvider
            .overrideWithValue(() => LoopbackHostTransport(network)),
        clientTransportProvider
            .overrideWithValue(LoopbackClientTransport(network)),
        discoveryFactoryProvider
            .overrideWithValue(() => LoopbackDiscovery(network)),
        localNetworkPermissionProvider
            .overrideWithValue(const AlwaysGrantedPermission()),
      ],
    );
    addTearDown(container.dispose);

    tester.view
      ..physicalSize = const Size(1080, 2186)
      ..devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      RepaintBoundary(
        child: UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            initialRoute: '/rooms',
            routes: {
              '/': (_) => const SizedBox(),
              '/rooms': (_) => const GameRoomsScreen(gameId: 'xiangqi'),
            },
          ),
        ),
      ),
    );
    // Quét mạng đi qua LoopbackDiscovery, mà nó giao tin bằng Timer thật —
    // trên đồng hồ giả của testWidgets thì lượt quét không bao giờ trả lời.
    // Và không dùng pumpAndSettle được: màn này quét lại theo chu kỳ nên
    // khung hình không bao giờ ngừng hẳn.
    await tester.pump();
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pump(GameMotion.normal);
  }

  /// Trang chủ và Cài đặt: không cần phòng, chỉ cần danh tính.
  Future<void> inkPage(WidgetTester tester, Widget screen) async {
    final container = ProviderContainer(overrides: [
      identityProvider.overrideWith(
        () => FakeIdentity(playerId: '70dd1fe9dfa3bfba', nickname: 'Nguoi choi 70DD'),
      ),
    ]);
    addTearDown(container.dispose);

    tester.view
      ..physicalSize = const Size(1080, 2186)
      ..devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      RepaintBoundary(
        child: UncontrolledProviderScope(
          container: container,
          child: GameAudioScope(
            controller: GameAudioController(),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildTheme(Brightness.light),
              initialRoute: '/screen',
              routes: {
                '/': (_) => const SizedBox(),
                '/screen': (_) => screen,
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(settle);
    // Ảnh giải mã bất đồng bộ; không nạp sẵn thì ảnh chụp ra trang trơn.
    await tester.runAsync(() async {
      final context = tester.element(find.byType(MaterialApp));
      for (final image in AppInkImages.all) {
        await precacheImage(image, context);
      }
    });
    await tester.pump();
    await tester.pump(GameMotion.page);
  }

  testWidgets('anh: trang chu', (tester) async {
    await inkPage(tester, const HomeScreen());
    await shoot(tester, 'trang-chu');
  });

  testWidgets('anh: cai dat', (tester) async {
    await inkPage(tester, const SettingsScreen());
    await shoot(tester, 'cai-dat');
  });

  testWidgets('anh: tim phong', (tester) async {
    await rooms(tester);
    await shoot(tester, 'tim-phong');
  });

  testWidgets('anh: thiet lap van', (tester) async {
    await rooms(tester);
    await tester.tap(find.text('Tạo phòng mới'));
    // Nhịp cố định chứ không pumpAndSettle: con trỏ nhấp nháy trong ô nhập và
    // lượt quét mạng lặp lại đều khiến khung hình không bao giờ ngừng.
    await tester.pump();
    await tester.pump(GameMotion.page);
    await shoot(tester, 'thiet-lap-van');
  });

  testWidgets('anh: nhap dia chi phong', (tester) async {
    await rooms(tester);
    await tester.tap(find.text('Nhập địa chỉ phòng'));
    await tester.pump();
    await tester.pump(GameMotion.page);
    await shoot(tester, 'nhap-dia-chi-phong');
  });

  testWidgets('anh: phong cho', (tester) async {
    await hostRoom(tester);
    await shoot(tester, 'phong-cho');
  });

  testWidgets('anh: xac nhan roi phong', (tester) async {
    final container = await hostRoom(tester);
    await tester.tap(find.text('Rời phòng'));
    await tester.pumpAndSettle();
    await shoot(tester, 'xac-nhan-roi-phong');

    // Đóng hộp thoại trước khi rời test, nếu không phòng vẫn còn mở.
    await tester.tap(find.text('Ở lại phòng'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => container.read(sessionProvider.notifier).leave(),
    );
  });
}
