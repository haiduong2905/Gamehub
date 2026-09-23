// Sinh tiếng bút viết cho cờ caro bằng đúng Dart SDK.
//
//   dart run bin/generate_sounds.dart
//
// Tự tổng hợp chứ không tải file về: không vướng giấy phép, file chỉ vài KB,
// và muốn chỉnh sắc thái thì sửa công thức rồi chạy lại.
//
// Tiếng bút trên giấy về bản chất là **nhiễu băng hẹp**, không phải một nốt
// nhạc. Nên cách làm là lấy nhiễu trắng, lọc còn dải 1.5-6kHz (tiếng "xoạt"),
// rồi nhân với đường bao biên độ hình chuông theo tốc độ ngòi bút — bút nhanh
// nhất ở giữa nét và dừng ở hai đầu.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const sampleRate = 22050;

void main() {
  Directory('assets/sounds').createSync(recursive: true);

  // X là hai nét chéo: hai tiếng xoạt ngắn, gọn, cách nhau một nhịp nghỉ tay.
  save('pen_x', 0.30, (pen) {
    return pen.stroke(begin: 0.0, length: 0.105, gain: 0.40, tone: 1.0) +
        pen.stroke(begin: 0.168, length: 0.105, gain: 0.37, tone: 1.12);
  });

  // O là một nét vòng liền: dài hơn, đều tay hơn, trầm hơn một chút.
  save('pen_o', 0.32, (pen) {
    return pen.stroke(
      begin: 0.0,
      length: 0.265,
      gain: 0.34,
      tone: 0.82,
      steadiness: 1.6,
    );
  });
}

/// Trạng thái tổng hợp tại một mẫu.
///
/// Hai bộ lọc một cực giữ trạng thái giữa các mẫu, nên lớp này phải sống suốt
/// cả file chứ không tạo mới từng mẫu.
class Pen {
  Pen(this.random);

  final Random random;

  double t = 0;
  double _low = 0;
  double _high = 0;
  double _grain = 0;

  /// Một nét bút bắt đầu ở giây [begin], kéo dài [length] giây.
  ///
  /// [tone] đẩy dải tần lên hay xuống (nét ngắn nghe cao hơn nét vòng).
  /// [steadiness] > 1 làm đường bao phẳng hơn ở giữa: tay đưa đều, không giật.
  double stroke({
    required double begin,
    required double length,
    required double gain,
    required double tone,
    double steadiness = 1.0,
  }) {
    final local = t - begin;
    if (local < 0 || local > length) return 0;

    final progress = local / length;

    // Đường bao: lên rất nhanh (ngòi chạm giấy), giữ, rồi tắt mềm.
    final envelope = pow(sin(pi * progress), 0.55 / steadiness).toDouble();
    final contact = exp(-90 * local); // tiếng "tách" lúc ngòi chạm giấy

    final white = random.nextDouble() * 2 - 1;

    // Thông thấp một cực -> lấy phần thấp; hiệu số cho ra phần cao.
    final lowCut = _coefficient(1400 * tone);
    _low += (white - _low) * lowCut;
    final bright = white - _low;

    // Thông thấp lần hai để chặn phần chói trên 6kHz.
    final highCut = _coefficient(6000 * tone);
    _high += (bright - _high) * highCut;

    // Hạt giấy: biên độ rung nhẹ và chậm, nhờ đó nét nghe có ma sát chứ không
    // phải tiếng rít điện tử.
    _grain += (random.nextDouble() - _grain) * 0.06;
    final friction = 0.78 + 0.42 * _grain;

    return gain * envelope * friction * (_high + 0.22 * contact * white);
  }

  double _coefficient(double cutoffHz) =>
      1 - exp(-2 * pi * cutoffHz / sampleRate);
}

void save(String name, double seconds, double Function(Pen) sample) {
  final frameCount = (sampleRate * seconds).round();
  final bytes = Uint8List(44 + frameCount * 2);
  final data = ByteData.sublistView(bytes);

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

  final pen = Pen(Random(4711));
  for (var i = 0; i < frameCount; i++) {
    pen.t = i / sampleRate;
    final value = sample(pen).clamp(-1.0, 1.0);
    data.setInt16(44 + i * 2, (value * 32767).round(), Endian.little);
  }

  File('assets/sounds/$name.wav').writeAsBytesSync(bytes);
  stdout.writeln('assets/sounds/$name.wav  (${bytes.length} byte)');
}
