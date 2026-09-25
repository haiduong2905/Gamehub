
/// Những mảnh giao diện dùng lại giữa các màn của `app`: hộp thoại, nút lớn,
/// nhãn mục, khung trang.
///
/// Khung màn **ván đấu** thì nằm ở `game_audio` vì mọi game đều cần. Những thứ
/// ở đây chỉ `app` dùng; để chung vào `game_audio` sẽ bắt mọi package game kéo
/// theo thứ chúng không bao giờ gọi.
///
/// Hai bảng màu cùng tồn tại có chủ ý: [GameColors] cho những màn dẫn tới bàn
/// cờ (phòng chờ, tìm phòng) và [AppInk] cho Trang chủ với Cài đặt. Màu nhấn
/// của cả hai là cùng một sắc đỏ, nên đường đi từ trang chủ tới bàn cờ không
/// thấy đứt đoạn.
library;

import 'package:flutter/material.dart';
import 'package:game_audio/game_audio.dart';

/// Bảng màu tranh thuỷ mặc của Trang chủ và Cài đặt.
///
/// Ấm hơn [GameColors] một bậc, vì hai màn này có bức tranh giấy làm nền còn
/// màn ván đấu thì bàn cờ mới là thứ phải nổi lên. Màu nhấn vẫn là cùng một
/// sắc đỏ với quân Đỏ và quân X, nên đi từ đây vào bàn cờ không thấy đứt đoạn.
abstract final class AppInk {
  /// Nền giấy, cùng tông với ảnh nền để mép ảnh không thành một đường cắt.
  static const paper = Color(0xFFF6EBD7);

  /// Mặt thẻ đặt trên nền giấy.
  static const card = Color(0xFFFCF5E8);

  /// Vàng của khung: lấy đúng từ nét trong của `title_banner.png` (#DAB46E),
  /// để viền thẻ và viền tấm biển là một màu chứ không phải hai sắc nâu gần
  /// giống nhau — hai sắc gần giống nhau trông như lỗi in.
  static const cardBorder = Color(0xFFD9B172);

  /// Nét ngoài đậm của khung, cũng lấy từ ảnh đó (#7E3C01).
  static const frame = Color(0xFF8A4205);

  /// Gỗ của thanh tiêu đề và thanh điều hướng.
  static const wood = Color(0xFF4A3021);
  static const woodLight = Color(0xFF6B4A2F);

  /// Mực: chữ chính và chữ phụ.
  static const ink = Color(0xFF3B2A1B);
  static const muted = Color(0xFF8C7355);

  /// Son, dùng cho con dấu và điểm nhấn.
  static const seal = Color(0xFFC42C1D);

  /// Kim nhũ: chữ và viền trên nền gỗ. Trên nền giấy thì không đọc được, nên
  /// chỉ dùng ở thanh đầu trang và thanh điều hướng.
  static const gold = Color(0xFFE3B55F);
  static const goldIdle = Color(0xFFB9A182);

  /// Nền ảnh: `assets/images/paper_landscape.png`.
  static const background = AssetImage('assets/images/paper_landscape.png');
}

abstract final class AppButtons {
  static final accent = FilledButton.styleFrom(
    backgroundColor: GameColors.accent,
    foregroundColor: Colors.white,
    disabledBackgroundColor: GameColors.cardBorder,
    disabledForegroundColor: GameColors.muted,
  );

  static final soft = OutlinedButton.styleFrom(
    backgroundColor: GameColors.card,
    foregroundColor: GameColors.ink,
    side: const BorderSide(color: GameColors.cardBorder),
  );
}

/// Nhãn in hoa nhỏ đặt trên một khối, ví dụ `PHÒNG TRONG CÙNG WI-FI`.
class AppSectionLabel extends StatelessWidget {
  const AppSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: GameColors.muted,
        ),
      );
}

/// Một dòng có ô biểu tượng bên trái: dùng cho nút lớn lẫn cho một phòng
/// trong danh sách.
///
/// Cùng một hình dáng cho cả hai vì chúng làm cùng một việc — chạm vào thì đi
/// tiếp. Nút bấm trông khác hẳn dòng danh sách sẽ khiến dòng danh sách không
/// còn trông như bấm được.
class AppTile extends StatelessWidget {
  const AppTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.accent = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Hành động chính của màn: nền đỏ, chữ trắng.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final ink = accent ? Colors.white : GameColors.ink;

    return Material(
      color: accent ? GameColors.accent : GameColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accent ? GameColors.accent : GameColors.cardBorder,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent
                      ? Colors.white.withValues(alpha: 0.18)
                      : GameColors.paper,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: accent ? Colors.transparent : GameColors.cardBorder,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: accent ? Colors.white : GameColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: accent
                              ? Colors.white.withValues(alpha: 0.8)
                              : GameColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dải nền nhạt nói một câu ngắn về trạng thái hiện tại.
///
/// Cao cố định: nội dung đổi theo trạng thái, để nó co giãn thì cả trang giật
/// theo đúng lúc người dùng đang đọc.
class AppStatusPill extends StatelessWidget {
  const AppStatusPill({
    required this.text,
    this.icon,
    this.tight = false,
    super.key,
  });

  final String text;

  /// Null thì vẽ một chấm đỏ nhỏ thay cho biểu tượng.
  final IconData? icon;

  /// Chỉ rộng bằng nội dung, thay vì kéo hết chiều ngang.
  final bool tight;

  @override
  Widget build(BuildContext context) => Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: GameColors.clockIdle,
          borderRadius: BorderRadius.circular(11),
          // Có viền vì dải này nằm cả trên nền trắng lẫn trên nền kem; thiếu
          // viền thì trên nền trắng nó gần như biến mất.
          border: Border.all(color: GameColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: tight ? MainAxisSize.min : MainAxisSize.max,
          children: [
            if (icon == null)
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: GameColors.accent,
                  shape: BoxShape.circle,
                ),
              )
            else
              Icon(icon, size: 14, color: GameColors.muted),
            const SizedBox(width: 9),
            Flexible(
              child: AnimatedSwitcher(
                duration: GameMotion.quick,
                switchInCurve: GameMotion.curve,
                switchOutCurve: GameMotion.curveIn,
                child: Text(
                  text,
                  key: ValueKey(text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: GameColors.ink,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

/// Khung chung của mọi hộp thoại trong app.
///
/// Biểu tượng và tiêu đề nằm **cùng một hàng**: hai thứ đó là một câu duy
/// nhất, tách ra hai tầng thì phần biểu tượng đọc như một món trang trí.
class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.icon,
    required this.title,
    required this.actions,
    this.message,
    this.fields = const [],
    this.danger = false,
    this.stackActions = false,
    super.key,
  });

  final IconData icon;
  final String title;

  /// Câu dẫn dưới tiêu đề.
  final String? message;

  /// Phần thân: các ô nhập, ô chọn, dải thông tin.
  final List<Widget> fields;

  /// Hàng nút dưới cùng, theo thứ tự trái sang phải (hoặc trên xuống dưới khi
  /// [stackActions]).
  final List<Widget> actions;

  /// Việc sắp làm có hậu quả không lấy lại được.
  final bool danger;

  /// Xếp nút theo chiều dọc, mỗi nút rộng hết hàng.
  final bool stackActions;

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: GameColors.paper,
        insetPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: danger ? GameColors.clockActive : GameColors.card,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color:
                            danger ? Colors.transparent : GameColors.cardBorder,
                      ),
                    ),
                    child: Icon(icon, size: 18, color: GameColors.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: GameColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(
                  message!,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: danger ? FontWeight.w600 : FontWeight.w400,
                    color: danger ? GameColors.accent : GameColors.muted,
                  ),
                ),
              ],
              if (fields.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...fields,
              ],
              const SizedBox(height: 20),
              if (stackActions)
                for (final (index, action) in actions.indexed) ...[
                  if (index > 0) const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: action),
                ]
              else
                Row(
                  children: [
                    for (final (index, action) in actions.indexed) ...[
                      if (index > 0) const SizedBox(width: 10),
                      Expanded(child: action),
                    ],
                  ],
                ),
            ],
          ),
        ),
      );
}

/// Một ô nhập hoặc ô chọn, có nhãn phía trên và chú thích phía dưới.
class AppField extends StatelessWidget {
  const AppField({
    required this.label,
    required this.child,
    this.helper,
    super.key,
  });

  final String label;
  final Widget child;
  final String? helper;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: GameColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          child,
          if (helper != null) ...[
            const SizedBox(height: 6),
            Text(
              helper!,
              style: const TextStyle(fontSize: 11.5, color: GameColors.muted),
            ),
          ],
        ],
      );

  /// Viền dùng chung cho mọi ô nhập và ô chọn.
  static InputDecoration decoration({String? hint, String? errorText}) =>
      InputDecoration(
        hintText: hint,
        errorText: errorText,
        filled: true,
        fillColor: GameColors.card,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: const TextStyle(color: GameColors.muted, fontSize: 14),
        border: _border(GameColors.cardBorder),
        enabledBorder: _border(GameColors.cardBorder),
        focusedBorder: _border(GameColors.accent),
        errorBorder: _border(GameColors.accent),
        focusedErrorBorder: _border(GameColors.accent),
      );

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color),
      );
}

/// Khối trắng chiếm phần thân màn hình, để nội dung không nằm trần trên nền.
class AppPanel extends StatelessWidget {
  const AppPanel({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: GameColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GameColors.cardBorder),
        ),
        child: child,
      );
}

/// Thông báo giữa khối trắng: biểu tượng lớn, một câu, và phần giải thích.
class AppNotice extends StatelessWidget {
  const AppNotice({
    required this.icon,
    required this.title,
    this.detail,
    this.footer,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: GameColors.paper,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: GameColors.cardBorder),
              ),
              child: Icon(icon, size: 24, color: GameColors.accent),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: GameColors.ink,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: GameColors.muted,
                ),
              ),
            ],
            if (footer != null) ...[
              const SizedBox(height: 18),
              footer!,
            ],
          ],
        ),
      );
}

/// Khung trang của Trang chủ và Cài đặt: nền tranh, dải đầu trang, và một tấm
/// giấy bo góc trên đựng nội dung.
///
/// Tấm giấy chồng lên mép dưới của dải đầu trang thay vì nằm sát dưới nó: hai
/// khối chạm nhau bằng một đường thẳng sẽ cắt bức tranh làm đôi.
class AppInkPage extends StatelessWidget {
  const AppInkPage({
    required this.header,
    required this.child,
    this.bottomBar,
    super.key,
  });

  final Widget header;
  final Widget child;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppInk.paper,
        body: Stack(
          children: [
            // Ảnh nền neo ở đáy: phần dày đặc nhất của bức tranh nằm ở dưới,
            // neo lên trên thì trang nào ngắn cũng chỉ thấy khoảng trời trống.
            Positioned.fill(
              child: Image(
                image: AppInk.background,
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
                opacity: const AlwaysStoppedAnimation(1),
              ),
            ),
            Column(
              children: [
                header,
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      // Hơi trong, để dãy núi và khóm trúc còn thấy được sau
                      // nội dung. Tô đặc thì bức tranh chỉ còn là một dải ở
                      // đầu trang, và trang mất hẳn chất giấy.
                      color: AppInk.paper.withValues(alpha: 0.40),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: child,
                  ),
                ),
              ],
            ),
          ],
        ),
        extendBody: true,
        bottomNavigationBar: bottomBar,
      );
}

/// Dải đầu trang có bức tranh làm nền.
///
/// [dark] cho Trang chủ — nền gỗ, chữ trắng; để `false` thì tranh hiện nguyên
/// sắc giấy và chữ là mực.
class AppInkHeader extends StatelessWidget {
  const AppInkHeader({
    required this.child,
    this.dark = false,
    this.height = 112,
    super.key,
  });

  final Widget child;
  final bool dark;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height + MediaQuery.paddingOf(context).top,
        // Bo hai góc dưới: dải gỗ là một tấm đặt lên trang, không phải một
        // mảng màu cắt ngang màn hình.
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(22),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image(
                image: AppInk.background,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                color: dark ? AppInk.wood.withValues(alpha: 0.88) : null,
                colorBlendMode: dark ? BlendMode.srcATop : null,
              ),
              if (dark)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0x33000000)],
                    ),
                  ),
                ),
              SafeArea(bottom: false, child: child),
            ],
          ),
        ),
      );
}

/// Nhãn mục: tấm biển chạm treo giữa trang.
///
/// Dùng **nguyên một ảnh**, không cắt mảnh rồi ghép lại lúc dựng. Ghép mảnh
/// thì bề rộng tấm biển chạy theo độ dài nhãn, nên "KẾT NỐI" ra một tấm ngắn
/// còn "CHƠI NHANH" ra một tấm dài — ba mục trên cùng một trang thành ba tấm
/// biển khác nhau. Một ảnh nguyên thì ba tấm giống hệt nhau, đúng như thiết kế.
///
/// Đổi lại, chữ phải lọt vào lòng biển vốn cố định: lòng biển chiếm [_plate]
/// bề ngang của ảnh, nên nhãn dài hơn thế sẽ bị cắt bớt.
class AppInkSectionTitle extends StatelessWidget {
  const AppInkSectionTitle(this.text, {super.key});

  static const _banner = AssetImage('assets/images/title_banner.png');

  /// Tỉ lệ của ảnh, đo từ chính file (1085x150).
  static const _ratio = 1085 / 150;

  /// Bề ngang lòng biển, tính theo bề ngang cả ảnh. Đo trên ảnh gốc: lòng
  /// biển nằm giữa, chiếm 39%; chừa mỗi bên một chút nên lấy 0.34.
  static const _plate = 0.34;

  /// Chặn trên của bề rộng tấm biển. Không có thì trên máy tính bảng tấm biển
  /// kéo ngang cả màn và mất dáng.
  static const _maxWidth = 290.0;

  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.clamp(0.0, _maxWidth);
            return SizedBox(
              width: width,
              height: width / _ratio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Positioned.fill(
                    child: Image(image: _banner, fit: BoxFit.fill),
                  ),
                  SizedBox(
                    width: width * _plate,
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: AppInk.ink,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
}

/// Thẻ giấy trong trang mực nho.
///
/// Nền để hơi trong chứ không tô đặc: bức tranh phải còn thấy được qua thẻ.
/// Tô đặc thì mỗi thẻ thành một mảng kem chết dán lên tranh, và cả trang lại
/// thành hai lớp rời nhau.
///
/// [selected] đổi viền đơn thành **khung kép** — nét đậm màu gỗ bọc ngoài, nét
/// mảnh màu cát lùi vào trong. Đó là cách một tấm bảng chạm được đóng khung,
/// và nó phân biệt thẻ chính của trang với những thẻ chỉ để đọc.
class AppInkCard extends StatelessWidget {
  const AppInkCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.selected = false,
    this.radius = 16,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool selected;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final body = AnimatedContainer(
      duration: GameMotion.quick,
      curve: GameMotion.curve,
      decoration: BoxDecoration(
        color: AppInk.card.withValues(alpha: selected ? 0.72 : 0.58),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: selected ? AppInk.frame : AppInk.cardBorder,
          width: selected ? 2.2 : 1.2,
        ),
      ),
      child: selected
          ? Container(
              margin: const EdgeInsets.all(3),
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius - 5),
                border: Border.all(color: AppInk.cardBorder),
              ),
              child: child,
            )
          : Padding(padding: padding, child: child),
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: body,
      ),
    );
  }
}

/// Mọi ảnh của bộ giao diện mực nho, gom lại một chỗ.
///
/// Tồn tại vì công cụ dựng ảnh: `AssetImage` giải mã bất đồng bộ, mà đồng hồ
/// của `flutter test` là đồng hồ giả nên không chạy tới đó. Không nạp sẵn thì
/// ảnh chụp ra trang trơn — công cụ mất đúng thứ nó sinh ra để soi. Thêm ảnh
/// mới vào bộ này thì thêm vào đây, đừng liệt kê lại ở phía công cụ.
abstract final class AppInkImages {
  static const all = <ImageProvider<Object>>[
    AppInk.background,
    AppInkSectionTitle._banner,
  ];
}
