import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_audio/game_audio.dart';
import 'package:game_xiangqi/game_xiangqi.dart';
import 'package:platform_core/platform_core.dart';

/// Không phải test: dựng ảnh PNG để mắt người soi lại bố cục.
///
///     flutter test test/render_preview_test.dart
void main() {
  const game = XiangqiGame();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // audioplayers không có plugin trong môi trường test. Không chặn lại thì
    // GameMusic ném MissingPluginException và công cụ này báo đỏ dù ảnh vẫn
    // dựng ra đúng.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in const [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (call) async => null,
      );
    }
    messenger.setMockStreamHandler(
      const EventChannel('xyz.luan/audioplayers.global/events'),
      MockStreamHandler.inline(onListen: (_, __) {}),
    );
    final loader = FontLoader('packages/game_xiangqi/XiangqiBrush')
      ..addFont(rootBundle
          .load('packages/game_xiangqi/assets/fonts/XiangqiBrush-Regular.ttf'));
    await loader.load();
  });

  Future<void> shoot(WidgetTester tester, Widget child, String name) async {
    // Mỗi AudioPlayer mở một kênh sự kiện riêng có UUID trong tên nên không
    // giả lập trước được, và nó nổ ra bất đồng bộ sau khi chụp xong. Bỏ qua
    // đúng loại lỗi đó; mọi lỗi khác vẫn báo như thường.
    //
    // Đặt ở đây chứ không ở setUpAll vì flutter_test cài lại onError của nó
    // ở đầu mỗi test.
    final reportError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is MissingPluginException) return;
      reportError?.call(details);
    };
    addTearDown(() => FlutterError.onError = reportError);

    tester.view
      ..physicalSize = const Size(1080, 2186)
      ..devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepaintBoundary(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        // initialRoute long hai tang de Navigator.canPop() dung true, dung
        // nhu khi man nay duoc day tu danh sach phong - neu khong se khong
        // thay nut quay lai.
        initialRoute: '/game',
        routes: {
          '/': (_) => const SizedBox(),
          '/game': (_) => GameAudioScope(
                controller: GameAudioController(),
                child: child,
              ),
        },
      ),
    ));
    await tester.pumpAndSettle();
    // audioplayers khong co plugin trong moi truong test; GameMusic nem ra
    // MissingPluginException. Khong lien quan den bo cuc dang chup.
    // Mỗi AudioPlayer còn mở một kênh sự kiện riêng tên chứa UUID, không
    // đăng ký trước được, nên vẫn còn vài MissingPluginException. Dọn hết.
    while (tester.takeException() != null) {}

    final bytes = await tester.binding.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    File('build/$name.png').writeAsBytesSync(bytes!);
  }

  XiangqiState played() {
    var state = game.createInitialState(const ['red', 'black'], seed: 0);
    for (final move in const [
      XiangqiMove(from: 64, to: 55),
      XiangqiMove(from: 25, to: 34),
      XiangqiMove(from: 70, to: 52),
      XiangqiMove(from: 19, to: 37),
      XiangqiMove(from: 52, to: 34),
      XiangqiMove(from: 37, to: 55),
    ]) {
      state = game.apply(state, state.currentPlayer, move);
    }
    return state;
  }

  testWidgets('anh: choi voi may', (tester) async {
    await shoot(tester, const XiangqiLocalGameScreen(), 'xiangqi-vs-may');
  });

  testWidgets('anh: choi voi nguoi', (tester) async {
    final state = played();
    final now = DateTime.now().millisecondsSinceEpoch;
    final view = GameView(
      state: game.encodeState(state),
      me: 'red',
      seatOrder: const ['red', 'black'],
      nicknames: const {'red': 'Bạn', 'black': 'Minh Anh'},
      currentActors: const ['red'],
      clocks: {
        'red': PlayerClock(
          moveMillis: 18000,
          matchMillis: 768000,
          running: true,
          asOfMillis: now,
        ),
        'black': PlayerClock(
          moveMillis: 24000,
          matchMillis: 876000,
          asOfMillis: now,
        ),
      },
      series: const SeriesScore(wins: {'red': 2, 'black': 1}),
      onAction: (_) {},
    );

    await shoot(tester, _NetworkPreview(view: view), 'xiangqi-vs-nguoi');
  });
}

/// Bản sao bố cục mà `app` dựng cho ván qua mạng.
class _NetworkPreview extends StatelessWidget {
  const _NetworkPreview({required this.view});

  final GameView view;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: XiangqiColors.page,
        appBar: gameAppBar(
          context: context,
          title: 'Cờ tướng',
          background: XiangqiColors.page,
          foreground: XiangqiColors.ink,
          actions: const [GameAudioButton()],
        ),
        body: XiangqiBoard(
          view: view,
          opponentSubtitle: 'Đối thủ trong phòng',
        ),
      );
}
