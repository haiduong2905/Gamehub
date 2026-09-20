import 'package:game_xiangqi/game_xiangqi.dart';

void main() {
  final state = const XiangqiGame().createInitialState(['red','black'], seed: 0);
  final legal = XiangqiGame.legalMovesFor(state, 'red');
  print('count=${legal.length}');
  print(legal.take(20).map((m) => '${m.from}->${m.to}').join(', '));
}
