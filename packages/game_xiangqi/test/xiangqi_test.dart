import 'package:flutter_test/flutter_test.dart';
import 'package:game_xiangqi/game_xiangqi.dart';

void main() {
  final game = XiangqiGame();

  group('initial board', () {
    test('chu phong chon Den thi khach cam Do va di truoc', () {
      final state = game.createInitialState(
        ['host-123', 'guest-456'],
        seed: 0,
        options: {'hostColor': 'black'},
      );
      expect(state.pieceColorOf('host-123'), XiangqiPieceColor.black);
      expect(state.pieceColorOf('guest-456'), XiangqiPieceColor.red);
      expect(state.currentPlayer, 'guest-456');
      expect(game.currentActors(state), ['guest-456']);
      expect(
          game
              .validate(state, 'host-123', const XiangqiMove(from: 27, to: 36))
              .isValid,
          isFalse);

      final restored = game.decodeState(game.encodeState(state));
      expect(restored.redPlayerIndex, 1);
      expect(restored.currentPlayer, 'guest-456');
      expect(restored.pieceColorOf('host-123'), XiangqiPieceColor.black);
    });

    test('ban dau co 90 o, co quan va luot di cua red', () {
      final state = game.createInitialState(['red', 'black'], seed: 0);
      expect(state.board.length, 90);
      expect(state.currentPlayer, 'red');
      expect(
          state.board.where((piece) => piece != null).length, greaterThan(0));
      expect(state.board[4], isNotNull);
      expect(state.board[85], isNotNull);
    });
  });

  group('move validation', () {
    test('quan bi an cua ca hai phe duoc luu va giu khi cau hoa', () {
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
      final received = game.decodeState(game.encodeState(afterBlack));
      expect(received.capturedPieces, [
        const XiangqiPiece(
            color: XiangqiPieceColor.black, type: XiangqiPieceType.pawn),
        const XiangqiPiece(
            color: XiangqiPieceColor.red, type: XiangqiPieceType.rook),
      ]);
      expect(received.lastMoveWasCapture, isTrue);
      final offered = game.apply(received, 'red', const XiangqiDrawOffer());
      expect(game.decodeState(game.encodeState(offered)).capturedPieces,
          received.capturedPieces);
    });

    test('nuoc bat quan va ket thuc co dau hieu de phat am thanh', () {
      final board = List<XiangqiPiece?>.filled(90, null);
      board[4] = const XiangqiPiece(
          color: XiangqiPieceColor.black, type: XiangqiPieceType.king);
      board[13] = const XiangqiPiece(
          color: XiangqiPieceColor.red, type: XiangqiPieceType.rook);
      board[85] = const XiangqiPiece(
          color: XiangqiPieceColor.red, type: XiangqiPieceType.king);
      final initial = XiangqiState(
          board: board, players: const ['red', 'black'], turnIndex: 0);

      final captured =
          game.apply(initial, 'red', const XiangqiMove(from: 13, to: 4));
      final received = game.decodeState(game.encodeState(captured));
      expect(received.ply, 1);
      expect(received.lastMoveWasCapture, isTrue);
      expect(game.getResult(received).reason, 'KING_CAPTURED');
    });

    test('cau hoa duoc dong y thi ca hai nhan ket qua hoa', () {
      final initial = game.createInitialState(['red', 'black'], seed: 0);
      final offered = game.apply(initial, 'red', const XiangqiDrawOffer());
      final received = game.decodeState(game.encodeState(offered));
      expect(received.drawOfferBy, 'red');
      expect(game.currentActors(received), ['black']);
      expect(
          game
              .validate(received, 'red', const XiangqiMove(from: 54, to: 45))
              .isValid,
          isFalse);
      expect(
          game.validate(received, 'black', const XiangqiDrawAccept()).isValid,
          isTrue);

      final agreed = game.apply(received, 'black', const XiangqiDrawAccept());
      final finalState = game.decodeState(game.encodeState(agreed));
      expect(game.isFinished(finalState), isTrue);
      expect(game.getResult(finalState).isDraw, isTrue);
      expect(game.getResult(finalState).reason, 'DRAW_AGREED');
    });

    test('ba lan bi tu choi cau hoa thi nguoi xin bi xu thua', () {
      var state = game.createInitialState(['red', 'black'], seed: 0);
      for (var count = 1; count <= 3; count++) {
        expect(game.validate(state, 'red', const XiangqiDrawOffer()).isValid,
            isTrue);
        state = game.apply(state, 'red', const XiangqiDrawOffer());
        state = game.decodeState(game.encodeState(state));
        state = game.apply(state, 'black', const XiangqiDrawReject());
        state = game.decodeState(game.encodeState(state));
        expect(state.drawRejectionsOf('red'), count);
        expect(game.isFinished(state), count == 3);
      }
      expect(game.getResult(state).winners, ['black']);
      expect(game.getResult(state).reason, 'DRAW_REJECTED_THREE_TIMES');
      expect(game.validate(state, 'red', const XiangqiDrawOffer()).isValid,
          isFalse);
    });

    test('xin thua ket thuc van va trao thang cho doi thu', () {
      final initial = game.createInitialState(['red', 'black'], seed: 0);
      final resigned = game.apply(initial, 'red', const XiangqiResign());
      final received = game.decodeState(game.encodeState(resigned));
      expect(game.isFinished(received), isTrue);
      expect(game.getResult(received).winners, ['black']);
      expect(game.getResult(received).reason, 'RESIGN');
    });

    test('nuoc vua di duoc luu va truyen qua state cho doi thu', () {
      final initial = game.createInitialState(['red', 'black'], seed: 0);
      expect(initial.lastMove, isNull);

      const redMove = XiangqiMove(from: 54, to: 45);
      final afterRed = game.apply(initial, 'red', redMove);
      final receivedByBlack = game.decodeState(game.encodeState(afterRed));
      expect(receivedByBlack.lastMove?.from, 54);
      expect(receivedByBlack.lastMove?.to, 45);
      expect(receivedByBlack.currentPlayer, 'black');

      const blackMove = XiangqiMove(from: 27, to: 36);
      final afterBlack = game.apply(receivedByBlack, 'black', blackMove);
      final receivedByRed = game.decodeState(game.encodeState(afterBlack));
      expect(receivedByRed.lastMove?.from, 27);
      expect(receivedByRed.lastMove?.to, 36);
      expect(receivedByRed.currentPlayer, 'red');
    });

    test('ID nguoi choi cua phong duoc gan theo thu tu ghe', () {
      final state = game.createInitialState(['host-123', 'guest-456'], seed: 0);
      expect(state.pieceColorOf('host-123'), XiangqiPieceColor.red);
      expect(state.pieceColorOf('guest-456'), XiangqiPieceColor.black);
      expect(
          game
              .validate(state, 'host-123', const XiangqiMove(from: 54, to: 45))
              .isValid,
          isTrue);
    });

    test('ma bi can chan khong duoc di', () {
      final board = List<XiangqiPiece?>.filled(90, null);
      board[4] = const XiangqiPiece(
          color: XiangqiPieceColor.black, type: XiangqiPieceType.king);
      board[85] = const XiangqiPiece(
          color: XiangqiPieceColor.red, type: XiangqiPieceType.king);
      board[82] = const XiangqiPiece(
          color: XiangqiPieceColor.red, type: XiangqiPieceType.knight);
      board[73] = const XiangqiPiece(
          color: XiangqiPieceColor.red, type: XiangqiPieceType.pawn);
      board[40] = const XiangqiPiece(
          color: XiangqiPieceColor.red, type: XiangqiPieceType.pawn);
      final state = XiangqiState(
          board: board, players: const ['red', 'black'], turnIndex: 0);
      expect(
          game
              .validate(state, 'red', const XiangqiMove(from: 82, to: 63))
              .isValid,
          isFalse);
    });

    test('phao chieu qua dung mot quan can', () {
      final board = List<XiangqiPiece?>.filled(90, null);
      board[4] = const XiangqiPiece(
          color: XiangqiPieceColor.black, type: XiangqiPieceType.king);
      board[85] = const XiangqiPiece(
          color: XiangqiPieceColor.red, type: XiangqiPieceType.king);
      board[40] = const XiangqiPiece(
          color: XiangqiPieceColor.red, type: XiangqiPieceType.cannon);
      board[22] = const XiangqiPiece(
          color: XiangqiPieceColor.black, type: XiangqiPieceType.pawn);
      final state = XiangqiState(
          board: board, players: const ['red', 'black'], turnIndex: 1);
      expect(XiangqiGame.isInCheck(state, 'black'), isTrue);
    });

    test('vua khong duoc di ngoai cung', () {
      final state = game.createInitialState(['red', 'black'], seed: 0);
      final invalid = game.validate(
        state,
        'red',
        const XiangqiMove(from: 85, to: 100),
      );
      expect(invalid.isValid, isFalse);
    });

    test('vuong khong duoc doi mat nhau', () {
      final board = List<XiangqiPiece?>.filled(90, null, growable: false);
      board[0 * 9 + 4] = const XiangqiPiece(
          color: XiangqiPieceColor.black, type: XiangqiPieceType.king);
      board[9 * 9 + 4] = const XiangqiPiece(
          color: XiangqiPieceColor.red, type: XiangqiPieceType.king);
      final state = XiangqiState(
          board: board, players: const ['red', 'black'], turnIndex: 0);
      final invalid = game.validate(
        state,
        'red',
        const XiangqiMove(from: 9 * 9 + 4, to: 8 * 9 + 4),
      );
      expect(invalid.isValid, isFalse);
    });
  });

  group('ai', () {
    test('pickMove phai tra ve nuoc hop le', () {
      final state = game.createInitialState(['red', 'black'], seed: 0);
      final legal = XiangqiGame.legalMovesFor(state, 'red');
      expect(legal, isNotEmpty);
      final move = XiangqiAi.pickMove(state, 'red', XiangqiDifficulty.easy);
      expect(move, isNotNull);
      expect(
          legal.any((entry) => entry.from == move!.from && entry.to == move.to),
          isTrue);
    });

    test('muc cao nhat nhan ra nuoc an Tuong ket thuc van', () {
      final board = List<XiangqiPiece?>.filled(90, null);
      board[4] = const XiangqiPiece(
          color: XiangqiPieceColor.black, type: XiangqiPieceType.king);
      board[13] = const XiangqiPiece(
          color: XiangqiPieceColor.red, type: XiangqiPieceType.rook);
      board[85] = const XiangqiPiece(
          color: XiangqiPieceColor.red, type: XiangqiPieceType.king);
      final state = XiangqiState(
          board: board, players: const ['red', 'black'], turnIndex: 0);

      final move = XiangqiAi.pickMove(state, 'red', XiangqiDifficulty.expert);
      expect(move?.from, 13);
      expect(move?.to, 4);
    });
  });
}
