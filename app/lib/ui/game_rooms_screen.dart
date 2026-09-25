import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_audio/game_audio.dart';
import 'package:platform_core/platform_core.dart';

import '../state/catalog.dart';
import '../state/identity.dart';
import '../state/room_browser.dart';
import '../state/session.dart';
import '../transport/lan/local_network_permission.dart';
import 'app_ui.dart';
import 'messages.dart';
import 'room_screen.dart';

/// Tìm phòng của một game, hoặc tự tạo phòng mới.
class GameRoomsScreen extends ConsumerWidget {
  const GameRoomsScreen({required this.gameId, super.key});

  final GameId gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(gameCatalogProvider).require(gameId);
    final browser = ref.watch(roomBrowserProvider(gameId));

    return Scaffold(
      backgroundColor: GameColors.page,
      appBar: gameAppBar(
        context: context,
        title: entry.name,
        centerTitle: false,
        titleLeading: entry.buildIcon(30),
        background: GameColors.page,
        foreground: GameColors.ink,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSectionLabel('PHÒNG TRONG CÙNG WI-FI'),
            const SizedBox(height: 10),
            Expanded(
              child: AppPanel(
                child: RefreshIndicator(
                  color: GameColors.accent,
                  onRefresh: () async {
                    ref.read(roomBrowserProvider(gameId).notifier).refresh();
                    // Chờ lượt quét mới, để vòng xoay không biến mất ngay.
                    await ref.read(roomBrowserProvider(gameId).future);
                  },
                  // Quét mạng xong là nội dung đổi hẳn: vòng xoay → danh sách,
                  // hoặc → lời nhắn "chưa thấy phòng nào". Đổi thẳng thì nó
                  // chớp một cái.
                  child: AnimatedSwitcher(
                    duration: GameMotion.normal,
                    switchInCurve: GameMotion.curve,
                    switchOutCurve: GameMotion.curveIn,
                    child: browser.when(
                      loading: () => const _Centered(
                        key: ValueKey('loading'),
                        child: CircularProgressIndicator(
                          color: GameColors.accent,
                        ),
                      ),
                      error: (e, _) => _Scrollable(
                        key: const ValueKey('error'),
                        child: AppNotice(
                          icon: Icons.error_outline_rounded,
                          title: 'Không quét được mạng',
                          detail: '$e',
                        ),
                      ),
                      data: (state) => state.blockedByPermission
                          ? _PermissionBlocked(
                              key: const ValueKey('blocked'),
                              gameId: gameId,
                            )
                          : _RoomList(
                              key: ValueKey('rooms-${state.rooms.length}'),
                              gameId: gameId,
                              rooms: state.rooms,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(2, 16, 0, 8),
              child: Text(
                'Bắt đầu theo cách của bạn',
                style: TextStyle(fontSize: 12.5, color: GameColors.muted),
              ),
            ),
            // Chỉ hiện khi game thật sự có máy đánh. Màn hình do chính game
            // dựng; màn này không biết đó là game gì.
            if (entry.buildLocalGame case final buildLocalGame?) ...[
              AppTile(
                icon: Icons.smart_toy_outlined,
                title: 'Chơi với máy',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => buildLocalGame()),
                ),
              ),
              const SizedBox(height: 8),
            ],
            AppTile(
              icon: Icons.add_rounded,
              title: 'Tạo phòng mới',
              accent: true,
              onTap: () => _createRoom(context, ref, entry),
            ),
            const SizedBox(height: 8),
            AppTile(
              icon: Icons.keyboard_rounded,
              title: 'Nhập địa chỉ phòng',
              onTap: () => _joinByAddress(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createRoom(
    BuildContext context,
    WidgetRef ref,
    CatalogEntry entry,
  ) async {
    final nickname =
        ref.read(identityProvider).valueOrNull?.nickname ?? 'Chủ phòng';
    final settings = await showDialog<RoomSettings>(
      context: context,
      builder: (_) => CreateRoomDialog(entry: entry),
    );
    if (settings == null || !context.mounted) return;

    await ref.read(sessionProvider.notifier).createRoom(
          gameId: gameId,
          displayName: 'Phòng của $nickname',
          settings: settings,
        );

    if (!context.mounted) return;
    _openRoomOrShowError(context, ref);
  }

  Future<void> _joinByAddress(BuildContext context, WidgetRef ref) async {
    final address = await showDialog<RoomAddress>(
      context: context,
      builder: (_) => const _ManualAddressDialog(),
    );
    if (address == null || !context.mounted) return;

    await ref.read(sessionProvider.notifier).joinRoom(address, gameId: gameId);

    if (!context.mounted) return;
    _openRoomOrShowError(context, ref);
  }
}

/// Hộp thoại chọn luật thời gian trước khi mở phòng.
class CreateRoomDialog extends StatefulWidget {
  const CreateRoomDialog({required this.entry, super.key});

  final CatalogEntry entry;

  @override
  State<CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<CreateRoomDialog> {
  String? _hostSide;
  int? _gameMinutes = 10;
  int? _turnSeconds = 60;

  @override
  Widget build(BuildContext context) {
    final option = widget.entry.hostSideOption;

    return AppDialog(
      icon: Icons.tune_rounded,
      title: 'Thiết lập ván chơi',
      message: 'Chọn luật thời gian trước khi tạo phòng.',
      fields: [
        if (option != null) ...[
          AppField(
            label: option.label,
            child: _Dropdown<String>(
              value: _hostSide ?? option.defaultValue,
              items: [
                for (final choice in option.choices)
                  DropdownMenuItem(
                    value: choice.value,
                    child: Text(choice.label),
                  ),
              ],
              onChanged: (value) => setState(() => _hostSide = value),
            ),
          ),
          const SizedBox(height: 14),
        ],
        AppField(
          label: 'Thời gian mỗi người cho cả ván',
          helper: 'Chỉ giảm khi đến lượt người chơi đó.',
          child: _Dropdown<int?>(
            value: _gameMinutes,
            items: const [
              DropdownMenuItem(value: 3, child: Text('3 phút')),
              DropdownMenuItem(value: 5, child: Text('5 phút')),
              DropdownMenuItem(value: 10, child: Text('10 phút')),
              DropdownMenuItem(value: null, child: Text('Không giới hạn')),
            ],
            onChanged: (value) => setState(() => _gameMinutes = value),
          ),
        ),
        const SizedBox(height: 14),
        AppField(
          label: 'Thời gian tối đa cho mỗi nước đi',
          child: _Dropdown<int?>(
            value: _turnSeconds,
            items: const [
              DropdownMenuItem(value: 15, child: Text('15 giây')),
              DropdownMenuItem(value: 30, child: Text('30 giây')),
              DropdownMenuItem(value: 60, child: Text('60 giây')),
              DropdownMenuItem(value: null, child: Text('Không giới hạn')),
            ],
            onChanged: (value) => setState(() => _turnSeconds = value),
          ),
        ),
      ],
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: AppButtons.soft,
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            RoomSettings(
              gameOptions: option == null
                  ? const {}
                  : {option.key: _hostSide ?? option.defaultValue},
              matchTimeLimit: _gameMinutes == null
                  ? null
                  : Duration(minutes: _gameMinutes!),
              moveTimeLimit: _turnSeconds == null
                  ? null
                  : Duration(seconds: _turnSeconds!),
            ),
          ),
          style: AppButtons.accent,
          child: const Text('Tạo phòng'),
        ),
      ],
    );
  }
}

/// Ô chọn trong hộp thoại, đã mang sẵn viền dùng chung.
class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        borderRadius: BorderRadius.circular(12),
        dropdownColor: GameColors.card,
        icon: const Icon(Icons.expand_more_rounded,
            size: 20, color: GameColors.muted),
        style: const TextStyle(fontSize: 14, color: GameColors.ink),
        decoration: AppField.decoration(),
      );
}

Future<void> _joinDiscovered(
  BuildContext context,
  WidgetRef ref,
  DiscoveredRoom room,
) async {
  await ref.read(sessionProvider.notifier).joinRoom(
        room.address,
        gameId: room.advertisement.gameId,
      );

  if (!context.mounted) return;
  _openRoomOrShowError(context, ref);
}

void _openRoomOrShowError(BuildContext context, WidgetRef ref) {
  final session = ref.read(sessionProvider);

  if (session.status == SessionStatus.failed) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          messageForCode(session.errorCode, fallback: session.errorMessage),
        ),
      ),
    );
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const RoomScreen()),
  );
}

class _RoomList extends ConsumerWidget {
  const _RoomList({required this.gameId, required this.rooms, super.key});

  final GameId gameId;
  final List<DiscoveredRoom> rooms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rooms.isEmpty) {
      return const _Scrollable(
        child: AppNotice(
          icon: Icons.search_rounded,
          title: 'Đang tìm phòng…',
          detail: 'Chưa thấy phòng nào trong mạng này.\n'
              'Hãy kiểm tra hai thiết bị đang dùng chung Wi-Fi.',
          footer: AppStatusPill(
            text: 'Đang quét phòng gần bạn',
            tight: true,
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: rooms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final room = rooms[index];
        return AppTile(
          icon: Icons.meeting_room_outlined,
          title: room.advertisement.displayName,
          subtitle: '${room.address}',
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: GameColors.muted,
          ),
          onTap: () => _joinDiscovered(context, ref, room),
        );
      },
    );
  }
}

class _PermissionBlocked extends ConsumerWidget {
  const _PermissionBlocked({required this.gameId, super.key});

  final GameId gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _Scrollable(
        child: AppNotice(
          icon: Icons.wifi_off_rounded,
          title: 'Chưa có quyền truy cập mạng nội bộ',
          detail: 'Không có quyền này thì ứng dụng không thấy được máy khác '
              'trong cùng Wi-Fi.',
          footer: FilledButton(
            onPressed: () async {
              await const LocalNetworkPermission().openSettings();
              if (!context.mounted) return;
              ref.read(roomBrowserProvider(gameId).notifier).refresh();
            },
            style: AppButtons.accent,
            child: const Text('Mở Cài đặt'),
          ),
        ),
      );
}

/// Nhập thẳng `IP:cổng` để vào phòng.
///
/// Đây là tính năng hạng nhất chứ không phải phương án chữa cháy: một số
/// mạng doanh nghiệp chặn mDNS nhưng vẫn cho hai máy nói chuyện trực tiếp,
/// và đây cũng là cách chắc chắn nhất khi cần thử nghiệm.
class _ManualAddressDialog extends StatefulWidget {
  const _ManualAddressDialog();

  @override
  State<_ManualAddressDialog> createState() => _ManualAddressDialogState();
}

class _ManualAddressDialogState extends State<_ManualAddressDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = _parse(_controller.text);
    if (parsed == null) {
      setState(() => _error = 'Định dạng phải là 192.168.1.5:47821');
      return;
    }
    Navigator.of(context).pop(parsed);
  }

  static RoomAddress? _parse(String raw) {
    final text = raw.trim();
    final colon = text.lastIndexOf(':');
    if (colon <= 0) return null;

    final host = text.substring(0, colon);
    final port = int.tryParse(text.substring(colon + 1));
    if (port == null || port < 1 || port > 65535) return null;
    if (host.split('.').length != 4) return null;

    return RoomAddress(host: host, port: port);
  }

  @override
  Widget build(BuildContext context) => AppDialog(
        icon: Icons.travel_explore_rounded,
        title: 'Nhập địa chỉ phòng',
        message: 'Lấy địa chỉ hiển thị trên màn hình phòng chờ của người '
            'tạo phòng.',
        fields: [
          AppField(
            label: 'Địa chỉ IP và cổng',
            child: TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(fontSize: 14, color: GameColors.ink),
              decoration: AppField.decoration(
                hint: '192.168.1.5:47821',
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: 12),
          const AppStatusPill(
            icon: Icons.info_outline_rounded,
            text: 'Hai thiết bị cần dùng chung Wi-Fi để kết nối trực tiếp.',
          ),
        ],
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: AppButtons.soft,
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: _submit,
            style: AppButtons.accent,
            child: const Text('Vào phòng'),
          ),
        ],
      );
}

/// Bọc nội dung để kéo-để-làm-mới vẫn chạy khi khối chỉ có một thông báo.
class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        ),
      );
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(child: child);
}
