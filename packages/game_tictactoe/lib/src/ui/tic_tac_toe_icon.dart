import 'package:flutter/material.dart';
import 'package:game_audio/game_audio.dart';

/// Icon của cờ caro, vẽ bằng [CustomPaint] chứ không dùng file ảnh.
///
/// Vẽ thay vì nhúng PNG vì icon phải sắc nét ở mọi kích thước (56px trong lưới,
/// 90px trong thẻ lớn, 44px trong phòng chờ) mà không kéo theo một bộ ảnh
/// nhiều độ phân giải, và vì nó phải nằm trong package của game — ràng buộc
/// "thêm game mới chỉ chạm 4 chỗ" không cho phép đổ ảnh vào `app/assets`.
///
/// Màu lấy đúng từ bàn cờ thật: nền giấy trắng, X xanh, O đỏ, và vệt vàng của
/// đường thắng.
class TicTacToeIcon extends StatelessWidget {
  const TicTacToeIcon({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: const _TicTacToeIconPainter()),
      );
}

const _paper = Color(0xFFFDFDFE);
const _paperEdge = Color(0xFFE6EAF1);
const _grid = Color(0xFFBCC5D3);
const _markX = Color(0xFF2547E0);
const _markO = Color(0xFFE8342A);
const _winStreak = Color(0xFFFFE175);

class _TicTacToeIconPainter extends CustomPainter {
  const _TicTacToeIconPainter();

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
          colors: [_paper, _paperEdge],
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipRRect(tile);

    // Lưới 3x3 — đủ để đọc ra "caro" ở 56px, nhiều ô hơn sẽ thành nhiễu.
    final pad = side * .17;
    final board = Rect.fromLTRB(pad, pad, size.width - pad, size.height - pad);
    final step = board.width / 3;

    final gridPaint = Paint()
      ..color = _grid
      ..strokeWidth = side * .022
      ..strokeCap = StrokeCap.round;

    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(board.left + step * i, board.top),
        Offset(board.left + step * i, board.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(board.left, board.top + step * i),
        Offset(board.right, board.top + step * i),
        gridPaint,
      );
    }

    Offset cellCenter(int column, int row) => Offset(
          board.left + step * (column + .5),
          board.top + step * (row + .5),
        );

    // Vệt đường thắng nằm dưới ba quân X — nhắc lại luật "xếp thành hàng".
    canvas.drawLine(
      cellCenter(0, 0),
      cellCenter(2, 2),
      Paint()
        ..color = _winStreak
        ..strokeWidth = step * .72
        ..strokeCap = StrokeCap.round,
    );

    final arm = step * .26;
    final stroke = side * .062;

    final xPaint = Paint()
      ..color = _markX
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    for (final index in [0, 1, 2]) {
      final center = cellCenter(index, index);
      canvas.drawLine(
        center + Offset(-arm, -arm),
        center + Offset(arm, arm),
        xPaint,
      );
      canvas.drawLine(
        center + Offset(arm, -arm),
        center + Offset(-arm, arm),
        xPaint,
      );
    }

    final oPaint = Paint()
      ..color = _markO
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    canvas.drawCircle(cellCenter(2, 0), arm * 1.2, oPaint);
    canvas.drawCircle(cellCenter(0, 2), arm * 1.2, oPaint);

    canvas.restore();

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
  bool shouldRepaint(_TicTacToeIconPainter oldDelegate) => false;
}
