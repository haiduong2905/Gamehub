import 'package:flutter/material.dart';
import 'package:game_audio/game_audio.dart';
import 'package:platform_core/platform_core.dart';

import '../logic/xiangqi.dart';
import 'xiangqi_theme.dart';

/// Thẻ một bên trong ván cờ tướng.
///
/// Phần khung — avatar, tên, đồng hồ, huy hiệu — là [GamePlayerCard] dùng
/// chung cho mọi game. Riêng dải quân đã bắt thì chỉ cờ tướng mới có, nên nó
/// đi vào chỗ `footer` mà thẻ chung chừa sẵn.
///
/// Quân bắt được nằm ngay dưới tên chủ nhân chứ không phải ở một dải riêng
/// cạnh bàn cờ: nhìn một chỗ là biết ai đang ăn hơn ai, không phải đối chiếu
/// hai dải với hai cái tên ở hai đầu màn hình.
class XiangqiPlayerCard extends StatelessWidget {
  const XiangqiPlayerCard({
    required this.name,
    required this.subtitle,
    required this.color,
    required this.captured,
    required this.clock,
    required this.score,
    required this.isTheirTurn,
    super.key,
  });

  final String name;
  final String subtitle;
  final XiangqiPieceColor color;

  /// Quân mà bên này đã bắt được (tức là quân của phe kia).
  final List<XiangqiPiece> captured;

  /// Null khi ván không tính giờ — lúc đó chỗ đó chỉ còn tỉ số.
  final PlayerClock? clock;

  /// Tỉ số cả loạt ván, nhìn từ phía bên này.
  final GameScore? score;

  final bool isTheirTurn;

  bool get _isRed => color == XiangqiPieceColor.red;

  /// Chiều cao trọn vẹn của thẻ. Cố định, nên bàn cờ ở giữa không bao giờ
  /// phải co lại vì thẻ cao lên.
  static double get height => GamePlayerCard.heightOf(withFooter: true);

  @override
  Widget build(BuildContext context) {
    final sideName = _isRed ? 'Đỏ' : 'Đen';
    return GamePlayerCard(
      name: name,
      sideLabel: sideName,
      subtitle: subtitle,
      sideColor: _isRed ? XiangqiColors.red : XiangqiColors.black,
      clock: clock,
      score: score,
      isTheirTurn: isTheirTurn,
      // Luôn truyền vào, kể cả khi chưa bắt được quân nào.
      //
      // Chỉ truyền khi đã có quân thì đúng lúc bắt quân đầu tiên thẻ cao thêm
      // một dòng, và cả trang — bàn cờ, thẻ dưới, hàng nút — nhảy lên xuống.
      // Chỗ trống trông thừa hơn hẳn một lần nhảy như vậy.
      footer: _CapturedStrip(pieces: captured),
    );
  }
}

/// `Đã bắt` kèm các quân đã ăn được.
class _CapturedStrip extends StatelessWidget {
  const _CapturedStrip({required this.pieces});

  final List<XiangqiPiece> pieces;

  @override
  Widget build(BuildContext context) {
    // Nhạt đi khi chưa bắt được gì, để dòng trống không đòi sự chú ý ngang
    // với dòng đã có quân.
    final labelColor = pieces.isEmpty
        ? XiangqiColors.muted.withValues(alpha: 0.45)
        : XiangqiColors.muted;

    return Row(
      children: [
        Text(
          'Đã bắt',
          style: TextStyle(fontSize: 11, color: labelColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: pieces.isEmpty
              ? Text('—', style: TextStyle(fontSize: 11, color: labelColor))
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: pieces.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 4),
                  itemBuilder: (context, index) => _PoppingDisc(
                    // Khoá theo vị trí trong danh sách: quân cũ giữ nguyên
                    // widget nên không chạy lại animation, chỉ quân mới thêm
                    // vào mới nảy lên.
                    key: ValueKey('captured-$index-${pieces[index].glyph}'),
                    piece: pieces[index],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Quân vừa bị bắt nảy vào dải thay vì hiện ra đột ngột.
class _PoppingDisc extends StatelessWidget {
  const _PoppingDisc({required this.piece, super.key});

  final XiangqiPiece piece;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: GameMotion.normal,
        curve: Curves.easeOutBack,
        builder: (context, value, child) => Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(scale: value, child: child),
        ),
        child: XiangqiDisc(
          piece: piece,
          size: GamePlayerCard.footerHeight,
        ),
      );
}
