import 'package:flutter/material.dart';
import 'package:game_audio/game_audio.dart';

/// Icon của cờ tướng, vẽ bằng [CustomPaint] chứ không dùng file ảnh.
///
/// Cùng lý do như icon của các game khác: phải sắc nét ở mọi kích thước và
/// phải nằm trong package của chính game, không đổ ảnh vào `app/assets`.
///
/// Màu lấy đúng từ bàn cờ thật: nền gỗ, đường kẻ nâu, quân giấy viền đỏ, và
/// chữ 帥 viết bằng font XiangqiBrush của package này.
class XiangqiIcon extends StatelessWidget {
  const XiangqiIcon({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: const _XiangqiIconPainter()),
      );
}

const _woodLight = Color(0xFFF6E6CE);
const _woodDark = Color(0xFFE6CDA6);
const _line = Color(0xFFCCA271);
const _paper = Color(0xFFFFF7EA);
const _red = Color(0xFFC42C1D);

class _XiangqiIconPainter extends CustomPainter {
  const _XiangqiIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final tile = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(side * .22),
    );

    canvas.drawRRect(
      tile,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_woodLight, _woodDark],
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipRRect(tile);

    // Vài đường kẻ gợi bàn cờ, có chừa sông ở giữa. Ở 56px chỉ còn là kết cấu
    // nền, nhưng nhờ nó icon không phẳng lì như một cái nhãn dán.
    final pad = side * .15;
    final board = Rect.fromLTRB(pad, pad, size.width - pad, size.height - pad);
    final columnStep = board.width / 4;
    final rowStep = board.height / 6;
    final riverTop = board.top + rowStep * 3;
    final riverBottom = board.top + rowStep * 4;

    final linePaint = Paint()
      ..color = _line
      ..strokeWidth = side * .013
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i <= 4; i++) {
      final x = board.left + columnStep * i;
      if (i == 0 || i == 4) {
        canvas.drawLine(Offset(x, board.top), Offset(x, board.bottom), linePaint);
      } else {
        canvas.drawLine(Offset(x, board.top), Offset(x, riverTop), linePaint);
        canvas.drawLine(
            Offset(x, riverBottom), Offset(x, board.bottom), linePaint);
      }
    }

    for (var i = 0; i <= 6; i++) {
      final y = board.top + rowStep * i;
      canvas.drawLine(Offset(board.left, y), Offset(board.right, y), linePaint);
    }

    canvas.restore();

    // Quân Soái đặt giữa, đè lên bàn cờ.
    final center = size.center(Offset.zero);
    final radius = side * .305;

    canvas.drawCircle(
      center + Offset(0, side * .018),
      radius,
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    canvas.drawCircle(center, radius, Paint()..color = _paper);
    canvas.drawCircle(
      center,
      radius - side * .012,
      Paint()
        ..color = _red
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * .024,
    );

    final glyph = TextPainter(
      text: TextSpan(
        text: '帥',
        style: TextStyle(
          color: _red,
          fontSize: radius * 1.28,
          height: 1,
          fontFamily: 'XiangqiBrush',
          package: 'game_xiangqi',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    glyph.paint(
      canvas,
      center - Offset(glyph.width / 2, glyph.height / 2),
    );

    // Viền khung: cùng sắc vàng với nhãn mục và viền thẻ ở màn hình chủ, nên
    // icon nằm trên trang nào cũng thuộc về trang đó.
    canvas.drawRRect(
      tile.deflate(side * .012),
      Paint()
        ..color = GameColors.frame
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * .025,
    );
  }

  @override
  bool shouldRepaint(_XiangqiIconPainter oldDelegate) => false;
}
