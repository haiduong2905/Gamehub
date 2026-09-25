import 'package:flutter/material.dart';
import 'package:game_audio/game_audio.dart';

/// Bảng màu của Game Hub.
///
/// Chủ ý giữ trầm: nền trung tính, đúng một màu nhấn, bo góc đều tay. Bàn cờ
/// mới là thứ người chơi cần nhìn, phần khung không nên tranh sự chú ý.
const _seed = Color(0xFF4C6EF5);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    // Một kiểu chuyển màn duy nhất cho mọi nền tảng.
    //
    // Mặc định của Material đổi theo nền tảng: Android trượt-phóng, Windows
    // và web lại kiểu khác. Ứng dụng này chạy trên cả ba, và cùng một thao
    // tác thì phải cho ra cùng một chuyển động — nếu không, thứ đo được khi
    // thử trên máy bàn lại không phải thứ người dùng thấy trên điện thoại.
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: const _FadeThroughTransitions(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
  );
}

/// Màn mới trượt lên một đoạn ngắn và hiện dần; màn cũ mờ đi tại chỗ.
///
/// Nhẹ hơn kiểu trượt ngang toàn màn hình của Material: ở đây phần lớn thao
/// tác là mở một màn con rồi quay lại ngay (danh sách phòng, cài đặt, ván
/// đấu), nên chuyển động phải ngắn và không kéo mắt đi xa.
class _FadeThroughTransitions extends PageTransitionsBuilder {
  const _FadeThroughTransitions();

  @override
  Duration get transitionDuration => GameMotion.page;

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: GameMotion.curve,
      reverseCurve: GameMotion.curveIn.flipped,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
