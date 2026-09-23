// Đo máy đánh cờ caro: nghĩ bao lâu, và mức trên có thật sự thắng mức dưới.
//
//   dart run bin/benchmark_ai.dart
//
// Không phải test tự động (kết quả có yếu tố ngẫu nhiên và phụ thuộc máy), mà
// là công cụ để trả lời hai câu hỏi khi chỉnh thuật toán: có nhanh không, và
// thang độ khó có đúng thứ tự không.
import 'dart:io';
import 'dart:math';

import 'package:game_tictactoe/src/logic/tic_tac_toe.dart';
import 'package:game_tictactoe/src/logic/tic_tac_toe_ai.dart';

const game = TicTacToeGame();
const first = 'p1';
const second = 'p2';

void main() {
  stdout.writeln('=== Thời gian nghĩ mỗi nước ===');
  for (final difficulty in TicTacToeDifficulty.values) {
    final times = _timeOneGame(difficulty);
    if (times.isEmpty) continue;
    times.sort();
    final total = times.reduce((a, b) => a + b);
    stdout.writeln(
      '${difficulty.label.padRight(12)} '
      'trung bình ${(total / times.length).toStringAsFixed(0).padLeft(5)}ms   '
      'chậm nhất ${times.last.toString().padLeft(5)}ms   '
      '(${times.length} nước)',
    );
  }

  stdout.writeln('\n=== Mức trên đấu mức dưới (mỗi cặp 4 ván, đổi bên) ===');
  const pairs = [
    (TicTacToeDifficulty.medium, TicTacToeDifficulty.easy),
    (TicTacToeDifficulty.hard, TicTacToeDifficulty.medium),
    (TicTacToeDifficulty.expert, TicTacToeDifficulty.hard),
  ];
  // Tách riêng đi trước / đi sau. Cờ caro tự do là thế cờ thắng của bên đi
  // trước, nên tổng tỉ số 2-2 có thể chỉ là nước đi trước quyết định chứ
  // không phải hai mức ngang nhau. Con số đáng tin là: **mức trên có thắng
  // được khi phải đi sau không.**
  for (final (strong, weak) in pairs) {
    var winsGoingFirst = 0;
    var winsGoingSecond = 0;
    for (var round = 0; round < 4; round++) {
      final strongGoesFirst = round.isEven;
      final winner = _play(
        strongGoesFirst ? strong : weak,
        strongGoesFirst ? weak : strong,
        seed: round,
      );
      if (winner == null) continue;
      final strongWon = (winner == first) == strongGoesFirst;
      if (!strongWon) continue;
      if (strongGoesFirst) {
        winsGoingFirst++;
      } else {
        winsGoingSecond++;
      }
    }
    stdout.writeln(
      '${strong.label.padRight(12)} vs ${weak.label.padRight(12)} '
      '=> thắng $winsGoingFirst/2 khi đi trước, '
      '$winsGoingSecond/2 khi đi sau',
    );
  }
}

/// Bấm giờ từng nước của một ván máy tự đánh với chính nó.
List<int> _timeOneGame(TicTacToeDifficulty difficulty) {
  final random = Random(7);
  var state = game.createInitialState([first, second], seed: 0);
  final times = <int>[];
  final clock = Stopwatch();

  for (var ply = 0; ply < 40 && !game.isFinished(state); ply++) {
    final actor = state.currentPlayer;
    clock
      ..reset()
      ..start();
    final cell = TicTacToeAi.pickMove(state, actor, difficulty, random: random);
    clock.stop();
    if (cell == null) break;
    times.add(clock.elapsedMilliseconds);
    state = game.apply(state, actor, TicTacToeMove(cell));
  }
  return times;
}

/// Một ván trọn vẹn. Trả về người thắng, hoặc null nếu hoà.
String? _play(
  TicTacToeDifficulty firstSide,
  TicTacToeDifficulty secondSide, {
  required int seed,
}) {
  final random = Random(seed);
  var state = game.createInitialState([first, second], seed: seed);

  while (!game.isFinished(state)) {
    final actor = state.currentPlayer;
    final cell = TicTacToeAi.pickMove(
      state,
      actor,
      actor == first ? firstSide : secondSide,
      random: random,
    );
    if (cell == null) break;
    state = game.apply(state, actor, TicTacToeMove(cell));
  }

  return state.winner;
}
