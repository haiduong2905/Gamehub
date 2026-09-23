import 'package:game_xiangqi/src/logic/xiangqi.dart';
import 'package:game_xiangqi/src/logic/xiangqi_ai.dart';

void main() {
  const game = XiangqiGame();
  final initial = game.createInitialState(['red', 'black'], seed: 0);
  final state = game.apply(initial, 'red', const XiangqiMove(from: 54, to: 45));

  for (final difficulty in XiangqiDifficulty.values) {
    final watch = Stopwatch()..start();
    final move = XiangqiAi.pickMove(state, 'black', difficulty);
    watch.stop();
    print(
        '${difficulty.name}: ${watch.elapsedMilliseconds} ms, ${move ?? 'no move'}');
  }
}
