import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_xiangqi/game_xiangqi.dart';
import 'package:platform_core/platform_core.dart';

void main() {
  testWidgets('cham quan va giao diem gui nuoc di theo toa do ban co',
      (tester) async {
    const game = XiangqiGame();
    final state = game.createInitialState(['host', 'guest'], seed: 0);
    Map<String, dynamic>? action;
    final view = GameView(
      state: game.encodeState(state),
      me: 'host',
      seatOrder: const ['host', 'guest'],
      nicknames: const {'host': 'Chủ', 'guest': 'Khách'},
      currentActors: const ['host'],
      onAction: (value) => action = value,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 500,
              child: XiangqiBoard(view: view),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('cell-54')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('cell-45')));
    expect(action, {'from': 54, 'to': 45});
    expect(tester.takeException(), isNull);
  });

  testWidgets('cham do nam tren quan doi phuong co the an', (tester) async {
    final board = List<XiangqiPiece?>.filled(90, null);
    board[4] = const XiangqiPiece(
        color: XiangqiPieceColor.black, type: XiangqiPieceType.king);
    board[85] = const XiangqiPiece(
        color: XiangqiPieceColor.red, type: XiangqiPieceType.king);
    board[40] = const XiangqiPiece(
        color: XiangqiPieceColor.red, type: XiangqiPieceType.rook);
    board[31] = const XiangqiPiece(
        color: XiangqiPieceColor.black, type: XiangqiPieceType.pawn);
    const game = XiangqiGame();
    final state = XiangqiState(
        board: board, players: const ['red', 'black'], turnIndex: 0);
    Map<String, dynamic>? action;
    final view = GameView(
      state: game.encodeState(state),
      me: 'red',
      seatOrder: const ['red', 'black'],
      nicknames: const {'red': 'Đỏ', 'black': 'Đen'},
      currentActors: const ['red'],
      onAction: (value) => action = value,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 500,
            child: XiangqiBoard(view: view),
          ),
        ),
      ),
    ));

    await tester.tap(find.byKey(const ValueKey('cell-40')));
    await tester.pump();

    expect(find.text('卒'), findsOneWidget);
    expect(find.byKey(const ValueKey('target-31')), findsOneWidget);
    final pieceCenter = tester.getCenter(find.text('卒'));
    final dotCenter = tester.getCenter(find.byKey(const ValueKey('target-31')));
    expect(dotCenter.dx, closeTo(pieceCenter.dx, 0.01));
    expect(dotCenter.dy, closeTo(pieceCenter.dy, 0.01));
    await tester.tap(find.byKey(const ValueKey('cell-31')));
    expect(action, {'from': 40, 'to': 31});
    expect(tester.takeException(), isNull);
  });

  testWidgets('doi thu thay diem xuat phat va quan vua di', (tester) async {
    const game = XiangqiGame();
    final initial = game.createInitialState(['red', 'black'], seed: 0);
    final state =
        game.apply(initial, 'red', const XiangqiMove(from: 54, to: 45));
    final view = GameView(
      state: game.encodeState(state),
      me: 'black',
      seatOrder: const ['red', 'black'],
      nicknames: const {'red': 'Đỏ', 'black': 'Đen'},
      currentActors: const ['black'],
      onAction: (_) {},
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: XiangqiBoard(view: view)),
    ));

    expect(find.byKey(const ValueKey('last-from-54')), findsOneWidget);
    expect(find.byKey(const ValueKey('last-to-45')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ca hai nguoi thay quan Do va Den da bi an', (tester) async {
    const game = XiangqiGame();
    final board = List<XiangqiPiece?>.filled(90, null);
    board[4] = const XiangqiPiece(
        color: XiangqiPieceColor.black, type: XiangqiPieceType.king);
    board[85] = const XiangqiPiece(
        color: XiangqiPieceColor.red, type: XiangqiPieceType.king);
    board[40] = const XiangqiPiece(
        color: XiangqiPieceColor.red, type: XiangqiPieceType.rook);
    board[31] = const XiangqiPiece(
        color: XiangqiPieceColor.black, type: XiangqiPieceType.pawn);
    board[22] = const XiangqiPiece(
        color: XiangqiPieceColor.black, type: XiangqiPieceType.rook);
    final initial = XiangqiState(
        board: board, players: const ['red', 'black'], turnIndex: 0);
    final afterRed =
        game.apply(initial, 'red', const XiangqiMove(from: 40, to: 31));
    final afterBlack =
        game.apply(afterRed, 'black', const XiangqiMove(from: 22, to: 31));

    for (final me in ['red', 'black']) {
      final view = GameView(
        state: game.encodeState(afterBlack),
        me: me,
        seatOrder: const ['red', 'black'],
        nicknames: const {'red': 'Đỏ', 'black': 'Đen'},
        currentActors: const ['red'],
        onAction: (_) {},
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 500,
            child: XiangqiBoard(view: view),
          ),
        ),
      ));
      // Mỗi bên đã bắt được đúng một quân, nên cả hai thẻ đều có dải "Đã bắt".
      expect(find.text('Đã bắt'), findsNWidgets(2));
      final cards = tester
          .widgetList<XiangqiPlayerCard>(find.byType(XiangqiPlayerCard));
      expect(cards, hasLength(2));
      for (final card in cards) {
        expect(
          card.captured,
          hasLength(1),
          reason: 'quân bắt được phải nằm ở thẻ của NGƯỜI BẮT, '
              'không phải thẻ của người bị mất quân',
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('nut cau hoa va xin thua gui dung hanh dong', (tester) async {
    const game = XiangqiGame();
    final initial = game.createInitialState(['red', 'black'], seed: 0);
    Map<String, dynamic>? action;
    GameView view(XiangqiState state, String me, List<String> actors) =>
        GameView(
          state: game.encodeState(state),
          me: me,
          seatOrder: const ['red', 'black'],
          nicknames: const {'red': 'Đỏ', 'black': 'Đen'},
          currentActors: actors,
          onAction: (value) => action = value,
        );
    Future<void> showBoard(GameView gameView) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 500,
            child: XiangqiBoard(view: gameView),
          ),
        ),
      ));
    }

    await showBoard(view(initial, 'red', ['red']));
    await tester.tap(find.text('Cầu hòa'));
    expect(action, {'type': 'offerDraw'});

    action = null;
    final offered = game.apply(initial, 'red', const XiangqiDrawOffer());
    await showBoard(view(offered, 'black', ['black']));
    await tester.tap(find.text('Từ chối'));
    expect(action, {'type': 'rejectDraw'});

    action = null;
    await showBoard(view(initial, 'red', ['red']));
    await tester.tap(find.text('Xin thua'));
    await tester.pump();
    expect(find.text('Xin thua ván này?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Xin thua'));
    await tester.pump();
    expect(action, {'type': 'resign'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('bat quan dau tien khong lam bo cuc nhay len xuong',
      (tester) async {
    // Dai "Da bat" truoc day chi duoc dung khi da co quan, nen dung luc bat
    // quan dau tien the cao them mot dong va ca trang - ban co, the duoi,
    // hang nut - nhay len xuong. Bam "Van moi" giua chung cung vay, theo
    // chieu nguoc lai.
    const game = XiangqiGame();
    final board = List<XiangqiPiece?>.filled(90, null);
    board[4] = const XiangqiPiece(
        color: XiangqiPieceColor.black, type: XiangqiPieceType.king);
    board[85] = const XiangqiPiece(
        color: XiangqiPieceColor.red, type: XiangqiPieceType.king);
    board[40] = const XiangqiPiece(
        color: XiangqiPieceColor.red, type: XiangqiPieceType.rook);
    board[31] = const XiangqiPiece(
        color: XiangqiPieceColor.black, type: XiangqiPieceType.pawn);
    board[22] = const XiangqiPiece(
        color: XiangqiPieceColor.black, type: XiangqiPieceType.rook);
    final before = XiangqiState(
        board: board, players: const ['red', 'black'], turnIndex: 0);
    // Đỏ ăn tốt Đen, rồi Đen ăn lại Xe Đỏ: cả hai thẻ đều có quân.
    final afterRed =
        game.apply(before, 'red', const XiangqiMove(from: 40, to: 31));
    final after =
        game.apply(afterRed, 'black', const XiangqiMove(from: 22, to: 31));

    Future<(List<Size> cards, double boardTop)> measure(
        XiangqiState state) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: XiangqiBoard(
            view: GameView(
              state: game.encodeState(state),
              me: 'red',
              seatOrder: const ['red', 'black'],
              nicknames: const {'red': 'Đỏ', 'black': 'Đen'},
              currentActors: const ['red'],
              onAction: (_) {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return (
        tester
            .widgetList<XiangqiPlayerCard>(find.byType(XiangqiPlayerCard))
            .map((card) => tester.getSize(find.byWidget(card)))
            .toList(),
        tester.getTopLeft(find.byKey(const ValueKey('cell-0'))).dy,
      );
    }

    final empty = await measure(before);
    final withCapture = await measure(after);

    expect(withCapture.$1, empty.$1,
        reason: 'ca hai the phai cao y nguyen truoc va sau khi bat quan');
    expect(withCapture.$2, empty.$2,
        reason: 'ban co khong duoc bi day len xuong khi the tren no cao them');
  });
}
