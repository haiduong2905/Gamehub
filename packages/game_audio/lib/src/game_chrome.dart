import 'package:flutter/material.dart';

/// Nút biểu tượng hình vuông bo góc trên thanh tiêu đề màn ván đấu.
///
/// Lý do có widget này thay vì [IconButton] mặc định: thanh tiêu đề có một
/// nút bên trái và hai nút bên phải. Để nút quay lại trần trong khi hai nút
/// kia nằm trong khối thì hai bên nặng nhẹ khác nhau, và tiêu đề ở giữa trông
/// lệch dù nó được căn giữa chính xác. Cho cả ba cùng một khối và cùng một lề
/// thì hai bên mới cân.
class GameBarButton extends StatelessWidget {
  const GameBarButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  /// Cạnh của khối, dùng chung cho mọi nút trên thanh tiêu đề.
  static const size = 40.0;

  /// Lề ngoài mỗi bên, để trái và phải cân nhau.
  static const gutter = 8.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = SizedBox(
      width: size,
      height: size,
      child: Material(
        color: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Icon(icon, size: 20, color: scheme.onSurface),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Thanh tiêu đề của một màn ván đấu.
///
/// Dùng chung cho ván qua mạng (do `app` dựng) và ván với máy (do package của
/// game dựng), nên hai đường đó không thể trôi khác nhau về sau.
/// [centerTitle] để `false` cho những màn mà tiêu đề là chặng đường chứ không
/// phải tên ván đấu — "Phòng chờ" đọc như một nhãn tiếp nối nút quay lại, còn
/// tên game thì đứng giữa mới cân với hai nút hai bên.
PreferredSizeWidget gameAppBar({
  required BuildContext context,
  required String title,
  List<Widget> actions = const [],
  Color? background,
  Color? foreground,
  bool centerTitle = true,
  Widget? titleLeading,
}) {
  final scheme = Theme.of(context).colorScheme;
  final fg = foreground ?? scheme.onSurface;
  return AppBar(
    backgroundColor: background ?? scheme.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: centerTitle,
    titleSpacing: 0,
    // Đúng bằng gutter + size + gutter, để lề trái bằng lề phải.
    leadingWidth: GameBarButton.gutter * 2 + GameBarButton.size,
    leading: Navigator.of(context).canPop()
        ? Center(
            child: GameBarButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Quay lại',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          )
        : null,
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (titleLeading != null) ...[titleLeading, const SizedBox(width: 10)],
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 19,
            ),
          ),
        ),
      ],
    ),
    actions: [
      for (final action in actions) ...[
        const SizedBox(width: 6),
        Center(child: action),
      ],
      const SizedBox(width: GameBarButton.gutter),
    ],
  );
}

/// Nhịp chuyển động dùng chung cho mọi màn hình.
///
/// Gom vào một chỗ vì thứ làm giao diện trông rời rạc không phải là thiếu
/// animation, mà là mỗi chỗ một tốc độ khác nhau.
abstract final class GameMotion {
  /// Đổi màu, đổi chữ, hiện/ẩn một thứ nhỏ.
  static const quick = Duration(milliseconds: 160);

  /// Quân cờ chạy, thẻ đổi trạng thái, chuyển nội dung.
  static const normal = Duration(milliseconds: 240);

  /// Chuyển màn hình.
  static const page = Duration(milliseconds: 300);

  /// Vào nhanh, ra chậm: thứ đang xuất hiện thì bắt mắt ngay, thứ đang biến
  /// đi thì không giật.
  static const curve = Curves.easeOutCubic;
  static const curveIn = Curves.easeInCubic;
}
