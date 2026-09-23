// Generate original, lightweight Xiangqi sounds using only the Dart SDK.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const sampleRate = 22050;

void main() {
  Directory('assets/sounds').createSync(recursive: true);
  // One short, dry wooden tap as a piece is set on the board.
  save('move', 0.16, (t, noise) {
    final attack = min(1.0, t / 0.0015);
    final wood = sin(2 * pi * (880 * t - 950 * t * t)) * exp(-38 * t);
    final grain = noise * exp(-110 * t);
    return attack * (0.45 * wood + 0.17 * grain);
  });
  // A brighter pickup followed by a low, weighty strike for a capture.
  save('capture', 0.43, (t, noise) {
    return 0.48 * captureStrike(t, noise) +
        (t >= 0.09 ? captureStrike(t - 0.09, noise) : 0);
  });
  // A descending three-note bell without any wooden click.
  save('checkmate', 1.35, (t, _) {
    return bell(t, 392) +
        (t >= 0.20 ? bell(t - 0.20, 330) * 0.85 : 0) +
        (t >= 0.40 ? bell(t - 0.40, 262) * 0.75 : 0);
  });
}

double captureStrike(double t, double noise) {
  final attack = min(1.0, t / 0.001);
  final lowThud = sin(2 * pi * (240 * t - 50 * t * t)) * exp(-20 * t);
  final hardClack = sin(2 * pi * 1480 * t) * exp(-27 * t);
  final scrape = noise * exp(-75 * t);
  return attack * (0.39 * lowThud + 0.14 * hardClack + 0.24 * scrape);
}

double bell(double t, double base) {
  final attack = min(1.0, t / 0.014);
  final tone = sin(2 * pi * base * t) * 0.29 +
      sin(2 * pi * base * 2.01 * t) * 0.11 +
      sin(2 * pi * base * 2.54 * t) * 0.06 +
      sin(2 * pi * base * 3.83 * t) * 0.035;
  return attack * tone * exp(-3.2 * t);
}

void save(String name, double seconds, double Function(double, double) sample) {
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

  final random = Random(1932);
  for (var i = 0; i < frameCount; i++) {
    final t = i / sampleRate;
    final value = sample(t, random.nextDouble() * 2 - 1).clamp(-1.0, 1.0);
    data.setInt16(44 + i * 2, (value * 32767).round(), Endian.little);
  }
  File('assets/sounds/$name.wav').writeAsBytesSync(bytes);
}
