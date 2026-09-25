import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_xiangqi/game_xiangqi.dart';

void main() {
  const game = XiangqiGame();

  // Máy chạy ở isolate nền để khỏi khoá luồng giao diện. Mọi thứ đi qua ranh
  // giới isolate đều phải gửi được — thêm một closure hay một đối tượng lạ vào
  // XiangqiAiRequest là lượt đầu tiên của máy nổ ngay trên máy thật, chứ không
  // phải chỉ chậm. Test này đi qua ranh giới thật để canh đúng chỗ đó.
  test('lượt của máy đi qua được ranh giới isolate', () async {
    final state = game.createInitialState(const ['red', 'black'], seed: 0);

    final encoded = await compute(
      pickXiangqiMove,
      XiangqiAiRequest(
        state: game.encodeState(state),
        actor: 'red',
        difficulty: XiangqiDifficulty.hard,
      ),
    );

    expect(encoded, isNotNull);
    final move = game.decodeAction(encoded!);
    expect(game.validate(state, 'red', move).isValid, isTrue);
  });

  test('không phải lượt mình thì trả null chứ không ném lỗi', () async {
    final state = game.createInitialState(const ['red', 'black'], seed: 0);

    final encoded = await compute(
      pickXiangqiMove,
      XiangqiAiRequest(
        state: game.encodeState(state),
        actor: 'black',
        difficulty: XiangqiDifficulty.easy,
      ),
    );
    expect(encoded, isNull);
  });
}
