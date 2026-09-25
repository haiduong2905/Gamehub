import 'package:flutter/material.dart';
import 'package:game_audio/game_audio.dart';

import '../logic/xiangqi.dart';

/// Bảng màu của màn cờ tướng.
///
/// Chỉ là tên gọi riêng cho [GameColors] dùng chung, để trong file này không
/// phải viết `GameColors.` ở mọi chỗ. Một nguồn duy nhất: đổi màu ở
/// `game_audio` là cả hai game đổi theo.
abstract final class XiangqiColors {
  static const page = GameColors.page;
  static const card = GameColors.card;
  static const cardBorder = GameColors.cardBorder;
  static const ink = GameColors.ink;
  static const muted = GameColors.muted;
  static const red = GameColors.accent;
  static const black = GameColors.dark;
  static const paper = GameColors.paper;
}

/// Một quân cờ hình tròn.
///
/// Dùng cả trên bàn cờ lẫn trong dải quân đã bắt, nên nó công khai trong
/// package: vẽ hai lần ở hai chỗ thì sớm muộn hai chỗ sẽ trông khác nhau.
class XiangqiDisc extends StatelessWidget {
  const XiangqiDisc({
    required this.piece,
    required this.size,
    this.selected = false,
    this.lastMoved = false,
    super.key,
  });

  final XiangqiPiece piece;
  final double size;
  final bool selected;
  final bool lastMoved;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      foregroundDecoration: lastMoved
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFF2A23A),
                width: size * 0.075,
              ),
            )
          : null,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: piece.isRed ? XiangqiColors.red : XiangqiColors.black,
        border: Border.all(color: XiangqiColors.paper, width: size * 0.045),
        boxShadow: [
          BoxShadow(
            color: const Color(0x88000000),
            blurRadius: size * 0.12,
            offset: Offset(1, size * 0.08),
          ),
          if (selected)
            BoxShadow(
              color: const Color(0xFFFFC34C),
              blurRadius: size * 0.2,
              spreadRadius: size * 0.06,
            ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.09),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white70),
          ),
          child: Center(
            child: Text(
              piece.glyph,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.57,
                height: 1,
                fontFamily: 'XiangqiBrush',
                package: 'game_xiangqi',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
