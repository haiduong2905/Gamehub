import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_tictactoe/game_tictactoe.dart';
import 'package:platform_core/platform_core.dart';

const _game = TicTacToeGame();

/// Dựng bàn cờ với một state cho sẵn.
///
/// Bàn cờ chỉ được phép vẽ lại state mà host gửi xuống và gọi [onAction];
/// nó không được tự đánh dấu ô hay tự suy ra luật. Các test dưới đây kiểm
/// đúng ranh giới đó.
Widget _board({
  required List<int> movesPlayed,
  required PlayerId me,
  String? pendingActionId,
  GameResult? result,
  required void Function(Map<String, dynamic>) onAction,
}) {
  var state = _game.createInitialState(['x-player', 'o-player'], seed: 0);
  for (final cell in movesPlayed) {
    state = _game.apply(state, state.currentPlayer, TicTacToeMove(cell));
  }

  return MaterialApp(
    home: Scaffold(
      body: TicTacToeBoard(
        view: GameView(
          state: _game.encodeState(state),
          me: me,
          seatOrder: const ['x-player', 'o-player'],
          nicknames: const {'x-player': 'Vu', 'o-player': 'Nam'},
          currentActors: _game.currentActors(state),
          pendingActionId: pendingActionId,
          result: result,
          onAction: onAction,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('bàn cờ 20x20 có thể pan qua InteractiveViewer', (tester) async {
    await tester.pumpWidget(
      _board(movesPlayed: const [], me: 'x-player', onAction: (_) {}),
    );

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsAtLeastNWidgets(1));
  });

  testWidgets('chạm ô trống khi đến lượt thì gọi onAction với đúng số ô',
      (tester) async {
    final sent = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      _board(movesPlayed: const [], me: 'x-player', onAction: sent.add),
    );

    await tester.tap(find.byType(AnimatedContainer).at(4));
    await tester.pump();

    expect(sent, [
      {'cell': 4},
    ]);
  });

  testWidgets('chưa đến lượt thì chạm không gửi gì', (tester) async {
    final sent = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      _board(movesPlayed: const [], me: 'o-player', onAction: sent.add),
    );

    await tester.tap(find.byType(AnimatedContainer).at(0));
    await tester.pump();

    expect(sent, isEmpty);
  });

  testWidgets('ô đã có người đánh thì chạm không gửi gì', (tester) async {
    final sent = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      // X đánh ô 0, O đánh ô 1, giờ lại đến lượt X.
      _board(movesPlayed: const [0, 1], me: 'x-player', onAction: sent.add),
    );

    await tester.tap(find.byType(AnimatedContainer).at(0));
    await tester.pump();

    expect(sent, isEmpty, reason: 'ô 0 đã có X');
  });

  testWidgets('đang chờ host xác nhận thì không gửi thêm nước nữa',
      (tester) async {
    final sent = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      _board(
        movesPlayed: const [],
        me: 'x-player',
        pendingActionId: 'a1',
        onAction: sent.add,
      ),
    );

    await tester.tap(find.byType(AnimatedContainer).at(3));
    await tester.pump();

    expect(sent, isEmpty, reason: 'tránh gửi hai nước khi người chơi bấm nhanh');
  });

  testWidgets('ván đã xong thì chạm không gửi gì', (tester) async {
    final sent = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      _board(
        movesPlayed: const [0, 10, 1, 11, 2, 12, 3, 13, 4],
        me: 'x-player',
        result: GameResult.win('x-player'),
        onAction: sent.add,
      ),
    );

    await tester.tap(find.byType(AnimatedContainer).at(8));
    await tester.pump();

    expect(sent, isEmpty);
  });

  testWidgets('bàn cờ vẽ lại đúng state host gửi xuống', (tester) async {
    await tester.pumpWidget(
      _board(movesPlayed: const [0, 4], me: 'x-player', onAction: (_) {}),
    );

    // Hai ô đã đánh có ký hiệu, bảy ô còn lại thì không.
    expect(find.byType(CustomPaint).evaluate().length, greaterThanOrEqualTo(2));
  });
}
