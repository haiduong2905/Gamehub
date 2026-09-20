import 'package:game_xiangqi/game_xiangqi.dart';

void main() {
  final state = const XiangqiGame().createInitialState(['red', 'black'], seed: 0);
  final legal = XiangqiGame.legalMovesFor(state, 'red');
  print('legal_count=${legal.length}');
  for (final move in legal.take(20)) {
    print('${move.from} -> ${move.to}');
  }
  print('board40=${state.board[40]}');
  print('board4=${state.board[4]}');
  print('board85=${state.board[85]}');
}
