import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_audio/game_audio.dart';
import 'package:game_tictactoe/game_tictactoe.dart';
import 'package:platform_core/platform_core.dart';

/// Không phải test: dựng ảnh PNG để mắt người soi lại bố cục.
///
///     flutter test tool/render_preview_test.dart
void main() {
  const game = TicTacToeGame();

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // audioplayers không có plugin trong môi trường test; GameMusic sẽ ném
    // MissingPluginException. Chặn sẵn những kênh đoán trước được.
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
  });

  Future<void> shoot(WidgetTester tester, Widget child, String name) async {
    // Mỗi AudioPlayer còn mở một kênh sự kiện riêng có UUID trong tên nên
    // không giả lập trước được, và nó nổ ra bất đồng bộ sau khi chụp xong.
    // Bỏ qua đúng loại lỗi đó; mọi lỗi khác vẫn báo như thường.
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
        // initialRoute lồng hai tầng để Navigator.canPop() đúng true, giống
        // như khi màn này được đẩy từ danh sách phòng — nếu không sẽ không
        // thấy nút quay lại.
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

  /// Thế cờ giống trong bản thiết kế: một chuỗi X–O đan nhau ở giữa bàn.
  TicTacToeState played() {
    var state = game.createInitialState(const ['x-player', 'o-player'], seed: 0);
    int at(int row, int column) => row * TicTacToeGame.boardSize + column;
    for (final cell in [
      at(7, 8), at(7, 9), at(7, 10), // X, O, X
      at(8, 9), at(8, 10), at(8, 11), // X, O, X
      at(9, 11), at(9, 12), // O, X  (ô cuối là nước vừa đánh)
      at(10, 12),
    ]) {
      state = game.apply(state, state.currentPlayer, TicTacToeMove(cell));
    }
    return state;
  }

  testWidgets('anh: choi voi may', (tester) async {
    await shoot(tester, const TicTacToeLocalGameScreen(), 'caro-vs-may');
  });

  testWidgets('anh: choi voi nguoi', (tester) async {
    final state = played();
    final now = DateTime.now().millisecondsSinceEpoch;
    final view = GameView(
      state: game.encodeState(state),
      me: 'x-player',
      seatOrder: const ['x-player', 'o-player'],
      nicknames: const {'x-player': 'Bạn', 'o-player': 'Minh Anh'},
      currentActors: const ['x-player'],
      clocks: {
        'x-player': PlayerClock(
          moveMillis: 18000,
          matchMillis: 760000,
          running: true,
          asOfMillis: now,
        ),
        'o-player': PlayerClock(
          moveMillis: 26000,
          matchMillis: 832000,
          asOfMillis: now,
        ),
      },
      series: const SeriesScore(wins: {'x-player': 2, 'o-player': 1}, draws: 1),
      onAction: (_) {},
    );

    await shoot(tester, _NetworkPreview(view: view), 'caro-vs-nguoi');
  });
}

/// Bản sao bố cục mà `app` dựng cho ván qua mạng.
class _NetworkPreview extends StatelessWidget {
  const _NetworkPreview({required this.view});

  final GameView view;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: GameColors.page,
        appBar: gameAppBar(
          context: context,
          title: 'Cờ caro',
          background: GameColors.page,
          foreground: GameColors.ink,
          actions: const [GameAudioButton()],
        ),
        body: TicTacToeBoard(
          view: view,
          opponentSubtitle: 'Đối thủ trong phòng',
        ),
      );
}
