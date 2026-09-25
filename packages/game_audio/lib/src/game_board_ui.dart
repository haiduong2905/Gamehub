import 'package:flutter/material.dart';
import 'package:platform_core/platform_core.dart';

import 'game_chrome.dart';

/// Bảng màu của màn ván đấu, dùng chung cho mọi game.
///
/// Cố định sáng, không theo chế độ tối của máy: bàn cờ là gỗ và giấy, đặt nó
/// trên nền tối thì mặt bàn nổi lên thành một ô sáng chói giữa màn hình. Đây
/// là lựa chọn có chủ đích chứ không phải quên xử lý chế độ tối.
abstract final class GameColors {
  static const page = Color(0xFFF4F1EC);
  static const card = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFE7E2D9);
  static const ink = Color(0xFF1F2937);
  static const muted = Color(0xFF8A8579);

  /// Màu nhấn, cũng là màu của bên Đỏ / bên X.
  static const accent = Color(0xFFC42C1D);
  static const dark = Color(0xFF292C2E);
  static const paper = Color(0xFFFFF7EA);

  /// Vàng của khung viền. Nhãn mục, viền thẻ và viền icon game dùng chung một
  /// sắc này — lấy từ nét trong của tấm biển `title_banner.png` (#DAB46E).
  /// Để mỗi chỗ tự khai một sắc nâu gần giống nhau thì chúng sẽ trôi khỏi
  /// nhau, và trên cùng một trang trông như lỗi in.
  static const frame = Color(0xFFD9B172);

  /// Nền ô đồng hồ: của bên đang đi thì ửng đỏ, của bên kia thì xám.
  static const clockActive = Color(0xFFFCE9E7);
  static const clockIdle = Color(0xFFF1F0ED);
}

/// Thẻ một bên trong màn ván đấu: tên, phe, và đồng hồ hoặc huy hiệu.
///
/// Nằm ở [game_audio] chứ không ở package của từng game vì mọi game đều cần
/// đúng cái thẻ này. Để mỗi game tự vẽ thì hai màn ván đấu sẽ trôi khác nhau
/// về sau — và người chơi đi từ game này sang game kia sẽ thấy hai app.
class GamePlayerCard extends StatelessWidget {
  const GamePlayerCard({
    required this.name,
    required this.sideLabel,
    required this.subtitle,
    required this.sideColor,
    required this.isTheirTurn,
    this.avatarLabel,
    this.clock,
    this.badge,
    this.score,
    this.footer,
    super.key,
  });

  /// Tên người chơi, ví dụ `Máy` hay `Minh Anh`.
  final String name;

  /// Phe, ví dụ `X`, `O`, `Đỏ`, `Đen`. Hiện sau tên, ngăn bằng dấu chấm giữa.
  final String sideLabel;

  final String subtitle;
  final Color sideColor;
  final bool isTheirTurn;

  /// Chữ trong ô vuông bên trái. Mặc định là chữ cái đầu của [name].
  final String? avatarLabel;

  /// Null khi ván không tính giờ — lúc đó [badge] chiếm chỗ đó.
  final PlayerClock? clock;

  /// Chữ trong huy hiệu khi không có đồng hồ lẫn tỉ số.
  final String? badge;

  /// Điểm của người trên thẻ này trong loạt đấu.
  ///
  /// Nó thay chỗ [badge] — huy hiệu phe chỉ nhắc lại chữ đã nằm ngay cạnh tên,
  /// còn điểm là thứ không đọc được ở đâu khác. Đứng cạnh được cả đồng hồ vì
  /// nó chỉ rộng bằng một con số.
  final GameScore? score;

  /// Dải phụ dưới cùng, ví dụ `Đã bắt` của cờ tướng.
  ///
  /// Nếu game dùng dải này thì nó phải **luôn** truyền vào, kể cả khi trống:
  /// truyền null lúc trống và truyền widget lúc có sẽ làm thẻ cao lên đúng
  /// lúc trạng thái đổi, và cả trang nhảy theo.
  final Widget? footer;

  static const _pad = 10.0;

  /// Chiều cao khối bên phải, chung cho cả đồng hồ lẫn huy hiệu.
  ///
  /// Cố định vì ván kết thúc là đồng hồ tắt và chỗ đó đổi sang huy hiệu. Hai
  /// thứ cao khác nhau thì trang nhảy đúng lúc người chơi đang đọc kết quả.
  static const trailingHeight = 40.0;

  /// Chiều cao của dải phụ.
  static const footerHeight = 20.0;

  /// Chiều cao trọn vẹn của thẻ, biết trước để bàn cờ tự tính được chỗ.
  static double heightOf({required bool withFooter}) =>
      _pad * 2 + trailingHeight + (withFooter ? 8 + footerHeight : 0);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: GameMotion.normal,
      curve: GameMotion.curve,
      padding: const EdgeInsets.fromLTRB(12, _pad, 12, _pad),
      decoration: BoxDecoration(
        color: GameColors.card,
        borderRadius: BorderRadius.circular(14),
        // Viền sáng lên ở bên đang đi: một tín hiệu nữa ngoài màu đồng hồ,
        // cho người nhìn lướt không phải đọc số.
        border: Border.all(
          color: isTheirTurn ? sideColor : GameColors.cardBorder,
          width: isTheirTurn ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _Avatar(
                label: avatarLabel ?? _initial(name),
                color: sideColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$name · $sideLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: GameColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: GameColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: trailingHeight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (clock != null)
                      GameClocks(clock: clock!, highlight: isTheirTurn)
                    else if (score == null && badge != null)
                      GameSideBadge(
                        label: badge!,
                        color: sideColor,
                        highlight: isTheirTurn,
                      ),
                    if (clock != null && score != null)
                      const SizedBox(width: 6),
                    if (score != null) GameScoreBox(score: score!),
                  ],
                ),
              ),
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: 8),
            SizedBox(height: footerHeight, child: footer),
          ],
        ],
      ),
    );
  }

  static String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      );
}

/// Huy hiệu thay chỗ đồng hồ khi ván không tính giờ.
class GameSideBadge extends StatelessWidget {
  const GameSideBadge({
    required this.label,
    required this.color,
    this.highlight = false,
    super.key,
  });

  final String label;
  final Color color;
  final bool highlight;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: GameMotion.normal,
        curve: GameMotion.curve,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: highlight ? GameColors.clockActive : GameColors.clockIdle,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: highlight ? color : GameColors.muted,
          ),
        ),
      );
}

/// Số ván một người đã thắng trong loạt đấu này.
///
/// Mỗi thẻ chỉ mang **số của chính chủ**, không mang cả cặp `2–1`: hai thẻ nằm
/// ngay trên dưới nhau nên đọc cả hai là ra tỉ số, còn in đủ cặp ở cả hai chỗ
/// thì cùng một thông tin hiện hai lần và phải kèm chữ "Tỉ số" mới hiểu được
/// con số nào của ai.
class GameScore {
  const GameScore({required this.wins, required this.opponentWins});

  final int wins;
  final int opponentWins;

  bool get leading => wins > opponentWins;
}

/// Ô điểm, cùng khuôn với ô đồng hồ để hai thứ đứng cạnh nhau không lệch.
class GameScoreBox extends StatelessWidget {
  const GameScoreBox({required this.score, super.key});

  final GameScore score;

  /// Rộng cố định, đủ cho hai chữ số.
  ///
  /// Để nó tự co theo bề rộng con số thì lúc điểm bước từ 9 lên 10, mọi thứ
  /// bên trái bị đẩy đi một nhịp — đúng lúc người chơi đang nhìn vào đó.
  static const width = 34.0;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: GameColors.clockIdle,
          borderRadius: BorderRadius.circular(10),
        ),
        child: AnimatedDefaultTextStyle(
          duration: GameMotion.normal,
          curve: GameMotion.curve,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
            // Đang dẫn thì đỏ lên — nhìn lướt là biết ai hơn, khỏi so hai số.
            color: score.leading ? GameColors.accent : GameColors.ink,
          ),
          child: Text('${score.wins}'),
        ),
      );
}

/// Hai ô đồng hồ của một người: nước đi và cả ván.
class GameClocks extends StatelessWidget {
  const GameClocks({
    required this.clock,
    required this.highlight,
    super.key,
  });

  final PlayerClock clock;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final move = clock.moveRemainingAt(now);
    final match = clock.matchRemainingAt(now);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (move != null)
          _ClockBox(label: 'Nước đi', millis: move, highlight: highlight),
        if (move != null && match != null) const SizedBox(width: 6),
        if (match != null)
          _ClockBox(label: 'Cả ván', millis: match, highlight: highlight),
      ],
    );
  }
}

class _ClockBox extends StatelessWidget {
  const _ClockBox({
    required this.label,
    required this.millis,
    required this.highlight,
  });

  final String label;
  final int millis;
  final bool highlight;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: GameMotion.normal,
        curve: GameMotion.curve,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: highlight ? GameColors.clockActive : GameColors.clockIdle,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: GameColors.muted),
            ),
            AnimatedDefaultTextStyle(
              duration: GameMotion.normal,
              curve: GameMotion.curve,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.15,
                // Chữ số đều bề ngang, nếu không ô đồng hồ sẽ nhấp nháy rộng
                // hẹp mỗi giây.
                fontFeatures: const [FontFeature.tabularFigures()],
                color: highlight ? GameColors.accent : GameColors.ink,
              ),
              child: Text(formatClock(millis)),
            ),
          ],
        ),
      );
}

/// `mm:ss`, không bao giờ âm.
String formatClock(int millis) {
  final total = (millis < 0 ? 0 : millis) ~/ 1000;
  final minutes = total ~/ 60;
  final seconds = total % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

/// Dải trạng thái giữa thẻ đối thủ và bàn cờ.
///
/// Nằm ngay trên bàn cờ chứ không phải trên cùng màn hình: mắt đang ở bàn cờ,
/// và đây là câu duy nhất người chơi cần đọc lại sau mỗi nước.
class GameStatusLine extends StatelessWidget {
  const GameStatusLine({
    required this.text,
    required this.color,
    super.key,
  });

  final String text;
  final Color color;

  /// Cao cố định hai dòng. Câu dài nhất — "BẠN THUA VÌ BỊ TỪ CHỐI CẦU HÒA 3
  /// LẦN" — xuống hai dòng, và nếu để dải tự co giãn thì bàn cờ nhảy đúng lúc
  /// ván kết thúc.
  static const height = 46.0;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: Center(
          child: AnimatedSwitcher(
            duration: GameMotion.quick,
            switchInCurve: GameMotion.curve,
            switchOutCurve: GameMotion.curveIn,
            child: Text(
              text,
              // Đổi chữ là đổi widget, để AnimatedSwitcher biết mà chuyển.
              key: ValueKey(text),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: color,
              ),
            ),
          ),
        ),
      );
}

/// Một nút trong hàng nút dưới bàn cờ.
class GameActionButton extends StatelessWidget {
  const GameActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.danger = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  /// Cao cố định cho mọi trạng thái của hàng nút.
  ///
  /// Ba nút, lời mời hòa, hay khoảng trống khi ván xong — tất cả phải cao
  /// bằng nhau, nếu không bàn cờ ở trên nhảy mỗi lần hàng nút đổi.
  static const barHeight = 46.0;

  @override
  Widget build(BuildContext context) {
    final color = danger ? GameColors.accent : GameColors.ink;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: GameColors.card,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        side: BorderSide(
          color: danger
              ? GameColors.accent.withValues(alpha: 0.55)
              : GameColors.cardBorder,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
