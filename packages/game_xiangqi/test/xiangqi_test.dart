import 'package:flutter_test/flutter_test.dart';
import 'package:game_xiangqi/game_xiangqi.dart';
import 'package:platform_core/platform_core.dart';

void main() {
  final game = XiangqiGame();

  group('initial board', () {
    test('ban dau co 90 o, co quan va luot di cua red', () {
      final state = game.createInitialState(['red', 'black'], seed: 0);
      expect(state.board.length, 90);
      expect(state.currentPlayer, 'red');
      expect(state.board.where((piece) => piece != null).length, greaterThan(0));
      expect(state.board[4], isNotNull);
      expect(state.board[85], isNotNull);
    });
  });

  group('move validation', () {
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
      board[0 * 9 + 4] = const XiangqiPiece(color: XiangqiPieceColor.black, type: XiangqiPieceType.king);
      board[9 * 9 + 4] = const XiangqiPiece(color: XiangqiPieceColor.red, type: XiangqiPieceType.king);
      final state = XiangqiState(board: board, players: const ['red', 'black'], turnIndex: 0);
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
      expect(legal.any((entry) => entry.to == move), isTrue);
    });
  });
}
