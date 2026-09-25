import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_tictactoe/game_tictactoe.dart';
import 'package:platform_core/platform_core.dart';

const _game = TicTacToeGame();

Widget _board(SeriesScore series) {
  final state = _game.createInitialState(['x-player', 'o-player'], seed: 0);
  return MaterialApp(
    home: Scaffold(
      body: TicTacToeBoard(
        view: GameView(
          state: _game.encodeState(state),
          me: 'x-player',
          seatOrder: const ['x-player', 'o-player'],
          nicknames: const {'x-player': 'Vu', 'o-player': 'Nam'},
          currentActors: _game.currentActors(state),
          series: series,
          onAction: (_) {},
        ),
      ),
    ),
  );
}

/// Tỉ số trên hai thẻ người chơi.
///
/// Mỗi thẻ cầm số của chính chủ trước, nên thẻ nào cũng tự trả lời được "mình
/// đang hơn hay kém" mà không phải nhìn sang thẻ kia rồi trừ nhẩm.
void main() {
  testWidgets('thẻ của mình và thẻ đối thủ đọc ngược nhau', (tester) async {
    await tester.pumpWidget(
      _board(const SeriesScore(wins: {'x-player': 2, 'o-player': 1})),
    );

    expect(find.text('2'), findsOneWidget, reason: 'thẻ của mình');
    expect(find.text('1'), findsOneWidget, reason: 'thẻ đối thủ');
  });

  testWidgets('chưa chơi ván nào thì vẫn hiện 0 – 0', (tester) async {
    await tester.pumpWidget(_board(SeriesScore.empty));

    expect(
      find.text('0'),
      findsNWidgets(2),
      reason: 'ô điểm có mặt từ đầu, không bật ra giữa chừng làm nhảy bố cục',
    );
  });

  testWidgets('hoà không cộng cho bên nào', (tester) async {
    await tester.pumpWidget(
      _board(const SeriesScore(wins: {'x-player': 1, 'o-player': 1}, draws: 2)),
    );

    expect(find.text('1'), findsNWidgets(2));
  });

  testWidgets('huy hiệu phe cũ đã nhường chỗ cho tỉ số', (tester) async {
    await tester.pumpWidget(
      _board(const SeriesScore(wins: {'x-player': 1})),
    );

    expect(find.text('ĐANG ĐI'), findsNothing);
    expect(find.text('CHỜ LƯỢT'), findsNothing);
  });

  testWidgets('ván tính giờ: đồng hồ và tỉ số đứng cạnh nhau vẫn đủ chỗ',
      (tester) async {
    tester.view
      ..physicalSize = const Size(360, 780)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final now = DateTime.now().millisecondsSinceEpoch;
    final state = _game.createInitialState(['x-player', 'o-player'], seed: 0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TicTacToeBoard(
            view: GameView(
              state: _game.encodeState(state),
              me: 'x-player',
              seatOrder: const ['x-player', 'o-player'],
              // Tên dài nhất mà ô nhập biệt danh cho phép.
              nicknames: const {
                'x-player': 'Nguyễn Hoàng Minh',
                'o-player': 'Trần Thị Bích Ngọc',
              },
              currentActors: _game.currentActors(state),
              clocks: {
                'x-player': PlayerClock(
                  moveMillis: 30000,
                  matchMillis: 600000,
                  running: true,
                  asOfMillis: now,
                ),
                'o-player': PlayerClock(
                  moveMillis: 30000,
                  matchMillis: 600000,
                  asOfMillis: now,
                ),
              },
              series: const SeriesScore(
                wins: {'x-player': 12, 'o-player': 10},
                draws: 3,
              ),
              onAction: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(
      tester.takeException(),
      isNull,
      reason: 'thẻ người chơi không được tràn ra ngoài màn hình hẹp',
    );
  });
}
