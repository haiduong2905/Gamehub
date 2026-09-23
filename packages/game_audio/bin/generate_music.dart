// Sinh nhạc nền của Game Hub bằng đúng Dart SDK.
//
//   dart run bin/generate_music.dart
//
// Tự tổng hợp chứ không tải nhạc về: không vướng giấy phép, và muốn đổi không
// khí thì sửa hợp âm rồi chạy lại.
//
// Yêu cầu khó nhất là **lặp không nghe thấy mối nối**. Cách xử lý: mọi tần số
// đều được làm tròn về bội của 1/độ-dài-vòng, nên sau đúng một vòng mỗi dao
// động đều về lại pha ban đầu; và đường bao của từng hợp âm bắt đầu lẫn kết
// thúc ở 0, nên biên độ tại giây cuối khớp với giây đầu.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Nhạc đệm chỉ có bồi âm tới khoảng 3kHz, 11025Hz là quá đủ — và giữ file
/// khoảng nửa MB thay vì một MB rưỡi.
const sampleRate = 11025;

/// Bốn hợp âm, mỗi hợp âm 6 giây.
const chordSeconds = 6.0;
const loopSeconds = chordSeconds * 4;

/// La thứ - Fa - Đô - Sol: vòng hoà âm trầm, không kéo sự chú ý khỏi ván cờ.
const chords = <List<double>>[
  [110.00, 130.81, 164.81], // Am
  [87.31, 110.00, 130.81], // F
  [130.81, 164.81, 196.00], // C
  [98.00, 123.47, 146.83], // G
];

void main() {
  Directory('assets/music').createSync(recursive: true);

  final frameCount = (sampleRate * loopSeconds).round();
  final bytes = Uint8List(44 + frameCount * 2);
  final data = ByteData.sublistView(bytes);
  _writeWavHeader(data, bytes, frameCount);

  for (var i = 0; i < frameCount; i++) {
    final t = i / sampleRate;
    final value = (_pad(t) + _bells(t)).clamp(-1.0, 1.0);
    data.setInt16(44 + i * 2, (value * 32767).round(), Endian.little);
  }

  File('assets/music/ambient.wav').writeAsBytesSync(bytes);
  stdout.writeln('assets/music/ambient.wav  '
      '(${(bytes.length / 1024).round()} KB, ${loopSeconds.round()}s)');
}

/// Nền hợp âm: mỗi hợp âm nở ra rồi lặn đi trong ô nhịp của nó.
double _pad(double t) {
  final index = (t ~/ chordSeconds) % chords.length;
  final local = t - index * chordSeconds;
  // sin(pi*u) bắt đầu và kết thúc đúng ở 0, nên các hợp âm nối vào nhau không
  // có mép.
  final envelope = pow(sin(pi * local / chordSeconds), 0.7).toDouble();

  var value = 0.0;
  for (final note in chords[index]) {
    final f = _snap(note);
    value += sin(2 * pi * f * t) * 0.085;
    // Bồi âm bậc hai rất nhẹ, đủ để tiếng không phẳng như sóng sin thuần.
    value += sin(2 * pi * _snap(note * 2) * t) * 0.018;
  }
  return value * envelope;
}

/// Chuông thưa: mỗi 3 giây một nốt, lấy từ hợp âm đang chạy, cao hai quãng tám.
double _bells(double t) {
  const every = 3.0;
  final strike = (t ~/ every).toInt();
  final local = t - strike * every;

  final chord = chords[((strike * every) ~/ chordSeconds) % chords.length];
  final note = _snap(chord[strike % chord.length] * 4);

  final envelope = exp(-2.6 * local) * (1 - exp(-90 * local));
  return (sin(2 * pi * note * t) * 0.05 +
          sin(2 * pi * _snap(note * 2.01) * t) * 0.012) *
      envelope;
}

/// Làm tròn tần số về bội của 1/[loopSeconds].
///
/// Sai số tối đa 1/48 Hz — không ai nghe ra, đổi lại vòng lặp khớp tuyệt đối.
double _snap(double frequency) =>
    (frequency * loopSeconds).roundToDouble() / loopSeconds;

void _writeWavHeader(ByteData data, Uint8List bytes, int frameCount) {
  void ascii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes[offset + i] = value.codeUnitAt(i);
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, frameCount * 2, Endian.little);
}
