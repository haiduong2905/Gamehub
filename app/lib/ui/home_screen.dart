import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/catalog.dart';
import '../state/identity.dart';
import 'game_rooms_screen.dart';
import 'settings_screen.dart';

const _cyan = Color(0xFF46D7FF);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _pages = PageController(viewportFraction: .91);
  int _currentPage = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _open(CatalogEntry entry) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GameRoomsScreen(gameId: entry.id),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(gameCatalogProvider).entries;
    final nickname = ref.watch(identityProvider).valueOrNull?.nickname;
    return Scaffold(
      backgroundColor: const Color(0xFF070B24),
      body: Stack(
        children: [
          const Positioned.fill(child: _NeonBackground()),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  sliver: SliverList.list(children: [
                    _Header(nickname: nickname),
                    const SizedBox(height: 36),
                    const _SectionTitle('GAME SẴN CÓ'),
                  ]),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 176,
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: entries.length,
                      onPageChanged: (value) =>
                          setState(() => _currentPage = value),
                      itemBuilder: (_, index) => Padding(
                        padding: EdgeInsets.fromLTRB(
                          index == 0 ? 24 : 8,
                          14,
                          index == entries.length - 1 ? 24 : 8,
                          14,
                        ),
                        child: _GameCard(
                          entry: entries[index],
                          onTap: () => _open(entries[index]),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child:
                      _PageDots(count: entries.length, selected: _currentPage),
                ),
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
                  sliver: SliverToBoxAdapter(
                    child: _SectionTitle('KẾT NỐI', centered: true),
                  ),
                ),
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverToBoxAdapter(child: _WifiNote()),
                ),
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(24, 26, 24, 4),
                  sliver: SliverToBoxAdapter(child: _SectionTitle('CHƠI NHANH')),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 112),
                  sliver: SliverGrid.builder(
                    // Một ô "Sắp có" ở cuối: giữ lưới cân, và nói thật rằng
                    // danh sách còn ngắn thay vì độn thêm game không tồn tại.
                    itemCount: entries.length + 1,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 14,
                      childAspectRatio: .82,
                    ),
                    itemBuilder: (_, index) => index == entries.length
                        ? const _ComingSoonTile()
                        : _GameTile(
                            entry: entries[index],
                            onTap: () => _open(entries[index]),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        onSelected: (index) {
          if (index == 3) {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const SettingsScreen(),
            ));
            return;
          }
          if (index == 0) return;
          // Hai tab còn lại chưa có màn hình. Nói ra thay vì im lặng không
          // phản ứng — người dùng sẽ tưởng app bị treo.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
              content: Text('Phần này đang làm, chưa dùng được.'),
            ),
          );
        },
      ),
    );
  }
}

/// Thanh điều hướng dưới cùng.
///
/// Phải tự khai báo hết màu, không được để mặc cho theme, vì trang chủ tự tô
/// nền tối trong khi theme của app vẫn là theme sáng của hệ thống. Hai chỗ
/// khiến thanh này bạc màu so với phần còn lại của trang:
///
/// * `elevation` mặc định là 3, và Material 3 phủ một lớp `surfaceTint` lấy từ
///   `ColorScheme` sáng lên trên nền navy — ra màu xám.
/// * màu icon và nhãn cũng lấy từ bảng màu sáng (`onSurfaceVariant` là một màu
///   xám trung tính), đặt trên nền tối thì chìm.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onSelected});

  final ValueChanged<int> onSelected;

  static const _idle = Color(0xFF8C9BBC);

  @override
  Widget build(BuildContext context) {
    WidgetStateProperty<T> byState<T>(T selected, T idle) =>
        WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? selected : idle,
        );

    return DecoratedBox(
      decoration: const BoxDecoration(
        // Cùng họ với nền trang, sáng hơn một chút để tách ra, và một đường
        // kẻ mảnh phía trên thay cho bóng đổ.
        color: Color(0xFF0C1533),
        border: Border(top: BorderSide(color: Color(0xFF243357))),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          iconTheme: byState(
            const IconThemeData(size: 25, color: _cyan),
            const IconThemeData(size: 24, color: _idle),
          ),
          labelTextStyle: byState(
            const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: _cyan),
            const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500, color: _idle),
          ),
        ),
        child: NavigationBar(
          height: 72,
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          indicatorColor: _cyan.withValues(alpha: .16),
          overlayColor:
              WidgetStatePropertyAll(_cyan.withValues(alpha: .08)),
          selectedIndex: 0,
          onDestinationSelected: onSelected,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_rounded), label: 'Trang chủ'),
            NavigationDestination(
                icon: Icon(Icons.person_outline), label: 'Hồ sơ'),
            NavigationDestination(
                icon: Icon(Icons.emoji_events_outlined), label: 'Thách đấu'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined), label: 'Cài đặt'),
          ],
        ),
      ),
    );
  }
}

/// Avatar và tên người chơi trên máy này.
///
/// Chạm vào là sang Cài đặt — đó là chỗ đổi tên, và cũng là chỗ sẽ đặt việc
/// đổi avatar sau này. Không làm thêm màn hình hồ sơ riêng khi chưa có gì để
/// đựng trong đó.
class _Header extends StatelessWidget {
  const _Header({this.nickname});
  final String? nickname;

  void _openSettings(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      );

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openSettings(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    _Avatar(nickname: nickname, size: 52),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Xin chào',
                              style: TextStyle(
                                  color: Color(0xFF8C9BBC), fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(nickname ?? '...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  height: 1.15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.2)),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Cài đặt',
            color: const Color(0xFFB5C4DC),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _openSettings(context),
          ),
        ],
      );
}

/// Avatar mặc định: chữ cái đầu của tên trên nền tròn.
///
/// Chưa có hệ thống ảnh đại diện, mà một icon người chung chung thì mọi máy
/// giống hệt nhau. Lấy chữ cái đầu và chọn màu theo tên: hai người trong cùng
/// một phòng nhìn là phân biệt được ngay. Khi có ảnh thật thì chỉ việc thay
/// ruột widget này.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.nickname, required this.size});

  final String? nickname;
  final double size;

  /// Vài sắc lạnh hợp với nền tối, đủ khác nhau để phân biệt.
  static const _palette = [
    Color(0xFF2E6BE6),
    Color(0xFF1FA6A6),
    Color(0xFF7A5BE0),
    Color(0xFFC2543F),
    Color(0xFF2F8F52),
    Color(0xFFB8842A),
  ];

  String get _initial {
    final name = nickname?.trim() ?? '';
    for (final rune in name.runes) {
      final char = String.fromCharCode(rune);
      if (char.trim().isNotEmpty) return char.toUpperCase();
    }
    return '?';
  }

  Color get _background {
    final name = nickname ?? '';
    // Tổng mã ký tự: đủ để tên khác nhau ra màu khác nhau, và cùng một tên
    // thì luôn ra cùng một màu trên mọi máy.
    final hash = name.runes.fold<int>(0, (sum, rune) => sum + rune);
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _background,
          border: Border.all(color: _cyan.withValues(alpha: .45), width: 1.5),
          boxShadow: [
            BoxShadow(color: _cyan.withValues(alpha: .14), blurRadius: 12),
          ],
        ),
        child: Text(
          _initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * .42,
            height: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.centered = false});
  final String text;
  final bool centered;
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: const TextStyle(
          color: Color(0xFFAAB3C8),
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1));
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.entry, required this.onTap});
  final CatalogEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
              colors: [Color(0xE81B395E), Color(0xE812183B)]),
          border: Border.all(color: _cyan.withValues(alpha: .7), width: 1.4),
          boxShadow: [
            BoxShadow(color: _cyan.withValues(alpha: .22), blurRadius: 18)
          ],
        ),
        child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: onTap,
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    _GameIcon(entry: entry, size: 90),
                    const SizedBox(width: 18),
                    Expanded(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(entry.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(entry.playersLabel,
                              style: const TextStyle(
                                  color: Color(0xFFD2DCF0), fontSize: 15)),
                        ])),
                    const Icon(Icons.chevron_right_rounded,
                        color: _cyan, size: 34),
                  ])),
            )),
      );
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.selected});
  final int count;
  final int selected;
  @override
  Widget build(BuildContext context) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
          count,
          (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: selected == index ? 24 : 8,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                  color: selected == index ? _cyan : const Color(0xFF39415E),
                  borderRadius: BorderRadius.circular(4)))));
}

class _WifiNote extends StatelessWidget {
  const _WifiNote();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
            color: const Color(0xA9222942),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFF3B4664))),
        child: const Row(children: [
          Icon(Icons.wifi_rounded, size: 36, color: Color(0xFF22D3EE)),
          SizedBox(width: 16),
          Expanded(
              child: Text(
                  'Các thiết bị phải kết nối cùng một mạng Wi-Fi. Không cần kết nối Internet.',
                  style: TextStyle(
                      color: Color(0xFFD0D7E7), height: 1.4, fontSize: 13))),
        ]),
      );
}

class _GameTile extends StatelessWidget {
  const _GameTile({required this.entry, required this.onTap});
  final CatalogEntry entry;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Column(children: [
            _GameIcon(entry: entry, size: 64),
            const SizedBox(height: 9),
            Flexible(
              child: Text(entry.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFFE2E8F4),
                      fontSize: 12.5,
                      height: 1.25,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      );
}

class _ComingSoonTile extends StatelessWidget {
  const _ComingSoonTile();
  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(64 * .22),
              border: Border.all(color: const Color(0xFF334262))),
          child: const Icon(Icons.more_horiz_rounded,
              color: Color(0xFF6C7CA0), size: 28),
        ),
        const SizedBox(height: 9),
        const Text('Sắp có',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color(0xFF8593B3),
                fontSize: 12.5,
                height: 1.25,
                fontWeight: FontWeight.w600)),
      ]);
}

/// Icon do chính game vẽ, đặt trong khung bo góc có quầng sáng.
///
/// Quầng sáng nằm ở đây chứ không nằm trong package game: nó thuộc về nền tối
/// của Game Hub, còn game chỉ cần biết vẽ chính nó.
class _GameIcon extends StatelessWidget {
  const _GameIcon({required this.entry, required this.size});
  final CatalogEntry entry;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * .22),
            boxShadow: [
              BoxShadow(color: _cyan.withValues(alpha: .18), blurRadius: 14)
            ]),
        child: entry.buildIcon(size),
      );
}

class _NeonBackground extends StatelessWidget {
  const _NeonBackground();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
      decoration: BoxDecoration(
          gradient: RadialGradient(
              center: Alignment(1.2, -.9),
              radius: 1.3,
              colors: [Color(0xFF103B60), Color(0xFF0A1335), Color(0xFF07071F)],
              stops: [0, .43, 1])),
      child: CustomPaint(painter: _LinePainter()));
}

class _LinePainter extends CustomPainter {
  const _LinePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _cyan.withValues(alpha: .10)
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
        Path()
          ..moveTo(size.width * .58, 0)
          ..lineTo(size.width, size.height * .25)
          ..lineTo(size.width * .72, size.height * .42)
          ..lineTo(size.width, size.height * .58),
        paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
