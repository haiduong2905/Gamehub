import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_tictactoe/game_tictactoe.dart';

void main() {
  const game = TicTacToeGame();

  // Máy chạy ở isolate nền để khỏi khoá luồng giao diện. Mọi thứ đi qua ranh
  // giới isolate đều phải gửi được — thêm một closure hay một đối tượng lạ vào
  // TicTacToeAiRequest là lượt đầu tiên của máy nổ ngay trên máy thật, chứ
  // không phải chỉ chậm. Test này đi qua ranh giới thật để canh đúng chỗ đó.
  test('lượt của máy đi qua được ranh giới isolate', () async {
    var state = game.createInitialState(const ['x', 'o'], seed: 0);
    state = game.apply(state, 'x', TicTacToeMove(210));

    final cell = await compute(
      pickTicTacToeMove,
      TicTacToeAiRequest(
        state: game.encodeState(state),
        actor: 'o',
        difficulty: TicTacToeDifficulty.hard,
      ),
    );

    expect(cell, isNotNull);
    expect(state.board[cell!], isNull, reason: 'phải là một ô còn trống');
  });

  test('bàn đầy thì trả null chứ không ném lỗi', () async {
    final state = game.createInitialState(const ['x', 'o'], seed: 0);
    final full = game.encodeState(state)
      ..['board'] = List<String>.filled(state.board.length, Mark.x.name);

    final cell = await compute(
      pickTicTacToeMove,
      TicTacToeAiRequest(
        state: full,
        actor: 'o',
        difficulty: TicTacToeDifficulty.easy,
      ),
    );
    expect(cell, isNull);
  });
}
