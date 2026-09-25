import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/catalog.dart';
import '../state/identity.dart';
import 'package:game_audio/game_audio.dart';

import 'app_ui.dart';
import 'game_rooms_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _pages = PageController(viewportFraction: .88);
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

  void _openSettings() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(gameCatalogProvider).entries;
    final nickname = ref.watch(identityProvider).valueOrNull?.nickname;

    return AppInkPage(
      header: AppInkHeader(
        dark: true,
        height: 96,
        child: _Greeting(nickname: nickname, onSettings: _openSettings),
      ),
      bottomBar: _BottomBar(
        onSelected: (index) {
          if (index == 3) {
            _openSettings();
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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 22, 0, 24),
        children: [
          const AppInkSectionTitle('GAME SẴN CÓ'),
          const SizedBox(height: 14),
          SizedBox(
            height: 118,
            child: PageView.builder(
              controller: _pages,
              itemCount: entries.length,
              onPageChanged: (value) => setState(() => _currentPage = value),
              itemBuilder: (_, index) => Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 18 : 6,
                  right: index == entries.length - 1 ? 18 : 6,
                ),
                child: _GameCard(
                  entry: entries[index],
                  onTap: () => _open(entries[index]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _PageDots(count: entries.length, selected: _currentPage),
          const SizedBox(height: 22),
          const AppInkSectionTitle('KẾT NỐI'),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: _WifiNote(),
          ),
          const SizedBox(height: 26),
          const AppInkSectionTitle('CHƠI NHANH'),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final entry in entries)
                  _QuickTile(
                    label: entry.name,
                    onTap: () => _open(entry),
                    builder: entry.buildIcon,
                  ),
                // Một ô "Sắp có" ở cuối: giữ hàng cân, và nói thật rằng danh
                // sách còn ngắn thay vì độn thêm game không tồn tại.
                const _ComingSoonTile(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lời chào và nút sang Cài đặt trên dải đầu trang.
///
/// Chạm vào tên cũng sang Cài đặt — đó là chỗ đổi tên, và cũng là chỗ sẽ đặt
/// việc đổi ảnh đại diện sau này. Không dựng một màn hồ sơ riêng khi chưa có
/// gì để đựng trong đó.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.nickname, required this.onSettings});

  final String? nickname;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 10, 0),
        child: Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onSettings,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        _Avatar(nickname: nickname, size: 48),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Xin chào',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                nickname ?? '…',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  height: 1.15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Cài đặt',
              color: AppInk.gold,
              icon: const Icon(Icons.settings_rounded, size: 26),
              onPressed: onSettings,
            ),
          ],
        ),
      );
}

/// Thanh điều hướng dưới cùng: một tấm gỗ **nổi** trên trang, không phải một
/// dải màu dán vào đáy màn hình.
///
/// Tự khai báo hết màu, không để mặc cho theme: trang này tô nền gỗ trong khi
/// theme của app vẫn là theme sáng, nên `elevation` mặc định và màu icon lấy
/// từ bảng màu sáng sẽ khiến cả thanh bạc màu so với phần còn lại.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onSelected});

  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    WidgetStateProperty<T> byState<T>(T selected, T idle) =>
        WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? selected : idle,
        );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppInk.wood,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppInk.gold.withValues(alpha: .45)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                iconTheme: byState(
                  const IconThemeData(size: 25, color: AppInk.gold),
                  const IconThemeData(size: 24, color: AppInk.goldIdle),
                ),
                labelTextStyle: byState(
                  const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppInk.gold,
                  ),
                  const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppInk.goldIdle,
                  ),
                ),
              ),
              child: NavigationBar(
                height: 66,
                elevation: 0,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                indicatorColor: AppInk.gold.withValues(alpha: .16),
                indicatorShape: const StadiumBorder(
                  side: BorderSide(color: AppInk.gold),
                ),
                overlayColor: WidgetStatePropertyAll(
                  AppInk.gold.withValues(alpha: .08),
                ),
                selectedIndex: 0,
                onDestinationSelected: onSelected,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_rounded),
                    label: 'Trang chủ',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    label: 'Hồ sơ',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.emoji_events_outlined),
                    label: 'Thách đấu',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    label: 'Cài đặt',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ảnh đại diện mặc định: chữ cái đầu của tên trên nền tròn.
///
/// Chưa có hệ thống ảnh đại diện, mà một icon người chung chung thì mọi máy
/// giống hệt nhau. Lấy chữ cái đầu và chọn màu theo tên: hai người trong cùng
/// một phòng nhìn là phân biệt được ngay, và cùng một tên luôn ra cùng một màu
/// trên mọi máy. Khi có ảnh thật thì chỉ việc thay ruột widget này.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.nickname, required this.size});

  final String? nickname;
  final double size;

  /// Các sắc lấy từ hộp màu tranh thuỷ mặc: son, chàm, lục, gỗ, tím.
  static const _palette = [
    Color(0xFFC42C1D),
    Color(0xFF2F5D7C),
    Color(0xFF3F7A4F),
    Color(0xFFA9752A),
    Color(0xFF6B4A7A),
    Color(0xFF2E7C74),
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
          border: Border.all(
            color: Colors.white.withValues(alpha: .5),
            width: 1.5,
          ),
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

/// Một game trong băng chuyền: icon, tên, số người chơi.
class _GameCard extends StatelessWidget {
  const _GameCard({required this.entry, required this.onTap});

  final CatalogEntry entry;
  final VoidCallback onTap;

  String get _players => entry.minPlayers == entry.maxPlayers
      ? '${entry.minPlayers} người chơi'
      : '${entry.minPlayers}-${entry.maxPlayers} người chơi';

  @override
  Widget build(BuildContext context) => AppInkCard(
        onTap: onTap,
        selected: true,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            entry.buildIcon(66),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppInk.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _players,
                    style: const TextStyle(fontSize: 13, color: AppInk.muted),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppInk.woodLight,
              size: 26,
            ),
          ],
        ),
      );
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.selected});

  final int count;
  final int selected;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < count; index++)
            AnimatedContainer(
              duration: GameMotion.quick,
              curve: GameMotion.curve,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: index == selected ? 20 : 8,
              height: 6,
              decoration: BoxDecoration(
                color: index == selected ? AppInk.woodLight : AppInk.cardBorder,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      );
}

/// Điều kiện duy nhất để chơi được, nói ngay ở trang chủ.
///
/// "Không cần Internet" là thứ người dùng không tự đoán ra, và là lý do họ
/// khỏi đi tìm lỗi khi mạng nhà không vào được mạng.
class _WifiNote extends StatelessWidget {
  const _WifiNote();

  @override
  Widget build(BuildContext context) => const AppInkCard(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.wifi_rounded, size: 26, color: AppInk.woodLight),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Các thiết bị phải kết nối cùng một mạng Wi-Fi. '
                'Không cần kết nối Internet.',
                style:
                    TextStyle(fontSize: 13.5, height: 1.4, color: AppInk.ink),
              ),
            ),
          ],
        ),
      );
}

/// Ô vuông trong hàng "Chơi nhanh": **chính icon của game**, tên ở dưới.
///
/// Không bọc icon trong một thẻ kem rồi thu nhỏ nó lại: icon của mỗi game đã
/// tự vẽ nền riêng — caro là tấm lưới trắng, cờ tướng là mặt gỗ — nên bọc thêm
/// một lớp nữa là hai khung lồng nhau, và icon còn lại bé tí giữa ô.
class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.label,
    required this.builder,
    this.onTap,
    this.dimmed = false,
  });

  /// Bề rộng ô. Cố định chứ không chia đều bề ngang màn hình: chia đều thì ô
  /// phình theo màn rộng và icon game bị kéo to quá cỡ nó được vẽ.
  static const size = 88.0;

  final String label;
  final Widget Function(double size) builder;
  final VoidCallback? onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(18),
                child: builder(size),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: dimmed ? AppInk.muted : AppInk.ink,
              ),
            ),
          ],
        ),
      );
}

class _ComingSoonTile extends StatelessWidget {
  const _ComingSoonTile();

  @override
  Widget build(BuildContext context) => _QuickTile(
        label: 'Sắp có',
        dimmed: true,
        builder: (size) => SizedBox(
          width: size,
          height: size,
          child: const AppInkCard(
            radius: 18,
            padding: EdgeInsets.zero,
            child: Center(
              child: Icon(
                Icons.more_horiz_rounded,
                size: 30,
                color: AppInk.muted,
              ),
            ),
          ),
        ),
      );
}
