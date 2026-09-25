import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_xiangqi/game_xiangqi.dart';
import 'package:platform_core/platform_core.dart';

Widget _board(SeriesScore series) {
  const game = XiangqiGame();
  final state = game.createInitialState(['host', 'guest'], seed: 0);
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 400,
          height: 700,
          child: XiangqiBoard(
            view: GameView(
              state: game.encodeState(state),
              me: 'host',
              seatOrder: const ['host', 'guest'],
              nicknames: const {'host': 'Chủ', 'guest': 'Khách'},
              currentActors: const ['host'],
              series: series,
              onAction: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

/// Ti so tren hai the nguoi choi.
void main() {
  testWidgets('moi the mang so cua chinh chu', (tester) async {
    await tester.pumpWidget(
      _board(const SeriesScore(wins: {'host': 3, 'guest': 1})),
    );

    expect(find.text('3'), findsOneWidget, reason: 'the cua minh');
    expect(find.text('1'), findsOneWidget, reason: 'the doi thu');
  });

  testWidgets('huy hieu phe cu da nhuong cho cho ti so', (tester) async {
    await tester.pumpWidget(_board(SeriesScore.empty));

    expect(find.text('ĐỎ'), findsNothing);
    expect(find.text('ĐEN'), findsNothing);
    expect(
      find.text('0'),
      findsNWidgets(2),
      reason: 'phe van doc duoc o dong ten, con day la cho cua diem',
    );
  });

  testWidgets('phe van con doc duoc o dong ten', (tester) async {
    await tester.pumpWidget(_board(SeriesScore.empty));

    expect(find.text('Chủ · Đỏ'), findsOneWidget);
    expect(find.text('Khách · Đen'), findsOneWidget);
  });
}
