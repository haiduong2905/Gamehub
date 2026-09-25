import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dựng lại toàn bộ icon của app từ một chỗ duy nhất.
///
///     cd app && flutter test tool/render_app_icon_test.dart
///
/// Không phải test — nó không khẳng định điều gì, nó ghi file. Để trong `tool/`
/// chứ không trong `test/` vì `flutter test` chạy cả thư mục `test/`, và một
/// lệnh ghi đè 27 file ảnh thì không được phép chạy lẫn vào kết quả test.
///
/// Trước đây bộ icon là sản phẩm thủ công: sửa hình một lần là phải xuất tay
/// 27 file cho Android, iOS, web và Windows, và chỉ cần bỏ sót một cái
/// là icon lệch nhau giữa các nền tảng mà không ai nhận ra.
void main() {
  testWidgets('dựng bộ icon', (tester) async {
    await tester.runAsync(() async {
      Future<Uint8List> render(int size) => _renderIcon(size);

      Future<void> write(String path, int size) async {
        final file = File(path);
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(await render(size));
      }

      // Nguồn thiết kế + ảnh dùng trong app.
      await write('assets/images/app_icon.png', 1024);

      // Android: mdpi 48 → xxxhdpi 192.
      const android = {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      };
      for (final entry in android.entries) {
        await write(
          'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
          entry.value,
        );
      }

      // iOS: tên file đã cố định trong Contents.json, không được đổi.
      const ios = {
        'Icon-App-20x20@1x': 20,
        'Icon-App-20x20@2x': 40,
        'Icon-App-20x20@3x': 60,
        'Icon-App-29x29@1x': 29,
        'Icon-App-29x29@2x': 58,
        'Icon-App-29x29@3x': 87,
        'Icon-App-40x40@1x': 40,
        'Icon-App-40x40@2x': 80,
        'Icon-App-40x40@3x': 120,
        'Icon-App-60x60@2x': 120,
        'Icon-App-60x60@3x': 180,
        'Icon-App-76x76@1x': 76,
        'Icon-App-76x76@2x': 152,
        'Icon-App-83.5x83.5@2x': 167,
        'Icon-App-1024x1024@1x': 1024,
      };
      for (final entry in ios.entries) {
        await write(
          'ios/Runner/Assets.xcassets/AppIcon.appiconset/${entry.key}.png',
          entry.value,
        );
      }

      await write('web/favicon.png', 16);
      for (final size in const [192, 512]) {
        await write('web/icons/Icon-$size.png', size);
        // Maskable dùng chung ảnh: nền đã phủ kín khung nên cắt kiểu gì cũng
        // không lòi ra khoảng trống.
        await write('web/icons/Icon-maskable-$size.png', size);
      }

      // Windows .ico: gói nhiều PNG vào một file, đúng định dạng Vista trở lên.
      final frames = <int, Uint8List>{
        for (final size in const [16, 32, 48, 64, 128, 256]) size: await render(size),
      };
      File('windows/runner/resources/app_icon.ico')
          .writeAsBytesSync(_buildIco(frames));
    });
  });
}

/// Hình học của khối lập phương, trong hệ toạ độ 512x512 của icon.
///
/// Ba con số này quyết định cả hình: nửa chiều rộng, nửa chiều cao của mặt
/// trên, và chiều cao thân. Tỉ lệ `w : r` giữ ở 1,72 — xấp xỉ căn ba — để khối
/// nhìn đúng phép chiếu đẳng cự.
const _w = 146.0; // nửa chiều rộng
const _r = 85.0; // nửa chiều cao mặt trên
const _b = 170.0; // chiều cao thân

Future<Uint8List> _renderIcon(int size) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final scale = size / 512.0;
  canvas.scale(scale, scale);
  _paintIcon(canvas);
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void _paintIcon(Canvas canvas) {
  const side = 512.0;
  final frame = RRect.fromRectAndRadius(
    const Rect.fromLTWH(0, 0, side, side),
    const Radius.circular(112),
  );

  canvas.drawRRect(
    frame,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F172A), Color(0xFF0B1120), Color(0xFF030712)],
        stops: [0, .5, 1],
      ).createShader(const Rect.fromLTWH(0, 0, side, side)),
  );

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(2, 2, side - 4, side - 4),
      const Radius.circular(110),
    ),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF38BDF8).withValues(alpha: .25),
  );

  canvas.save();
  canvas.translate(side / 2, side / 2);
  _paintCube(canvas);
  canvas.restore();
}

/// Nửa chiều cao của cả khối: mặt trên một nửa, mặt dưới một nửa, cộng thân.
const _halfHeight = _r + _b / 2;

void _paintCube(Canvas canvas) {
  // Bảy đỉnh nhìn thấy được. Gốc toạ độ là tâm khối.
  const t = Offset(0, -_halfHeight); // đỉnh trên
  const l = Offset(-_w, -_halfHeight + _r); // trái trên
  const rr = Offset(_w, -_halfHeight + _r); // phải trên
  const c = Offset(0, -_halfHeight + 2 * _r); // nơi ba mặt gặp nhau
  const bl = Offset(-_w, _halfHeight - _r); // trái dưới
  const br = Offset(_w, _halfHeight - _r); // phải dưới
  const bb = Offset(0, _halfHeight); // đỉnh dưới

  Path face(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  Paint fill(Gradient gradient) => Paint()
    ..shader = gradient.createShader(
      const Rect.fromLTRB(-_w, -_halfHeight, _w, _halfHeight),
    );

  canvas.drawPath(
    face([t, rr, c, l]),
    fill(const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
    )),
  );
  canvas.drawPath(
    face([l, c, bb, bl]),
    fill(const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF22D3EE), Color(0xFF06B6D4)],
    )),
  );
  canvas.drawPath(
    face([c, rr, br, bb]),
    fill(const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
    )),
  );

  // Mỗi mặt chia làm 2x2 chứ không phải 3x3. Ở cỡ 48px, ba đường kẻ trên một
  // mặt rộng chưa tới 20px là ba vệt xám nhoè vào nhau; một đường thì còn đọc
  // được ra là khối có chia ô.
  Offset mid(Offset a, Offset b) => Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);

  void grid(List<(Offset, Offset)> lines, Color color, double opacity) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: opacity);
    for (final (a, b) in lines) {
      canvas.drawLine(a, b, paint);
    }
  }

  grid([
    (mid(t, rr), mid(l, c)),
    (mid(t, l), mid(rr, c)),
  ], const Color(0xFFE0F2FE), .55);
  grid([
    (mid(l, c), mid(bl, bb)),
    (mid(l, bl), mid(c, bb)),
  ], const Color(0xFFCFFAFE), .45);
  grid([
    (mid(c, rr), mid(bb, br)),
    (mid(c, bb), mid(rr, br)),
  ], const Color(0xFF38BDF8), .55);

  canvas.drawPath(
    face([t, rr, br, bb, bl, l]),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF38BDF8),
  );
}

/// Gói các khung PNG thành một file .ico.
///
/// Định dạng từ Vista trở lên cho phép nhét thẳng PNG vào thay vì bitmap thô,
/// nên không phải tự dựng DIB header.
Uint8List _buildIco(Map<int, Uint8List> frames) {
  final entries = frames.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final header = BytesBuilder();
  final directory = BytesBuilder();

  var offset = 6 + entries.length * 16;
  for (final entry in entries) {
    final bytes = entry.value;
    directory.addByte(entry.key >= 256 ? 0 : entry.key); // rộng, 0 nghĩa là 256
    directory.addByte(entry.key >= 256 ? 0 : entry.key); // cao
    directory.addByte(0); // số màu bảng màu
    directory.addByte(0); // dành riêng
    directory.add(_le16(1)); // số mặt phẳng màu
    directory.add(_le16(32)); // bit mỗi điểm ảnh
    directory.add(_le32(bytes.length));
    directory.add(_le32(offset));
    offset += bytes.length;
  }

  header.add(_le16(0)); // dành riêng
  header.add(_le16(1)); // 1 là icon, 2 là con trỏ chuột
  header.add(_le16(entries.length));
  header.add(directory.toBytes());
  for (final entry in entries) {
    header.add(entry.value);
  }
  return header.toBytes();
}

Uint8List _le16(int value) => Uint8List(2)
  ..buffer.asByteData().setUint16(0, value, Endian.little);

Uint8List _le32(int value) => Uint8List(4)
  ..buffer.asByteData().setUint32(0, value, Endian.little);
