import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_tictactoe/game_tictactoe.dart';

/// Độ dài của một file WAV mono 16-bit do `bin/generate_sounds.dart` sinh ra.
Duration _wavDuration(String path) {
  final bytes = ByteData.sublistView(File(path).readAsBytesSync());
  final sampleRate = bytes.getUint32(24, Endian.little);
  final bytesPerSecond = bytes.getUint32(28, Endian.little);
  final dataBytes = bytes.getUint32(40, Endian.little);
  expect(
    bytesPerSecond,
    sampleRate * 2,
    reason: 'công thức dưới đây chỉ đúng cho mono 16-bit',
  );
  return Duration(milliseconds: (dataBytes * 1000 / bytesPerSecond).round());
}

/// Tiếng bút và nét viết phải dài bằng nhau.
///
/// Hai con số nằm ở hai chỗ rời nhau — hằng số trong `tic_tac_toe_board.dart`
/// và công thức trong `bin/generate_sounds.dart` — nên chỉnh một bên rồi quên
/// bên kia là chuyện sẽ xảy ra. Lệch thì không có gì hỏng, chỉ là tiếng bút
/// kêu xong trước lúc quân vẽ xong (hoặc ngược lại), và cảm giác đó khó gọi
/// tên hơn hẳn một lỗi thật.
void main() {
  // Chênh lệch cho phép: đường bao biên độ tắt dần nên phần đuôi file có vài
  // mili giây gần như im, không đáng bắt bẻ.
  const tolerance = Duration(milliseconds: 25);

  void expectMatches(String asset, Duration animation) {
    final sound = _wavDuration('assets/sounds/$asset');
    expect(
      (sound - animation).abs(),
      lessThanOrEqualTo(tolerance),
      reason: '$asset dài ${sound.inMilliseconds}ms, '
          'nét viết ${animation.inMilliseconds}ms',
    );
  }

  test('tiếng bút X dài bằng nét viết X', () {
    expectMatches('pen_x.wav', TicTacToePenMotion.x);
  });

  test('tiếng bút O dài bằng nét viết O', () {
    expectMatches('pen_o.wav', TicTacToePenMotion.o);
  });

  test('đặt một quân xong trong vòng một phần tư giây', () {
    // Cờ caro là gõ liên tiếp: nét viết dài bằng tốc độ bút thật thì từng nét
    // nhìn đẹp hơn, nhưng cả ván nặng nề.
    for (final duration in [TicTacToePenMotion.x, TicTacToePenMotion.o]) {
      expect(duration, lessThanOrEqualTo(const Duration(milliseconds: 250)));
    }
  });
}
