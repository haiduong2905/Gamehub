import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_core/platform_core.dart';

import '../state/catalog.dart';
import '../state/identity.dart';
import '../state/room_browser.dart';
import '../state/session.dart';
import '../transport/lan/local_network_permission.dart';
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
      appBar: AppBar(title: Text(entry.name)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(roomBrowserProvider(gameId).notifier).refresh();
          // Chờ lượt quét mới, để vòng xoay không biến mất ngay lập tức.
          await ref.read(roomBrowserProvider(gameId).future);
        },
        child: browser.when(
          loading: () => const _Centered(child: CircularProgressIndicator()),
          error: (e, _) => _Centered(
            child: _Notice(
              icon: Icons.error_outline,
              title: 'Không quét được mạng',
              detail: '$e',
            ),
          ),
          data: (state) => state.blockedByPermission
              ? _PermissionBlocked(gameId: gameId)
              : _RoomList(gameId: gameId, rooms: state.rooms),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: () => _createRoom(context, ref, entry),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tạo phòng mới'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _joinByAddress(context, ref),
              icon: const Icon(Icons.keyboard_rounded),
              label: const Text('Nhập địa chỉ phòng'),
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
    final nickname = ref.read(identityProvider).valueOrNull?.nickname ?? 'Chủ phòng';

    await ref.read(sessionProvider.notifier).createRoom(
          gameId: gameId,
          displayName: 'Phòng của $nickname',
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
  const _RoomList({required this.gameId, required this.rooms});

  final GameId gameId;
  final List<DiscoveredRoom> rooms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rooms.isEmpty) {
      return ListView(
        // Phải cuộn được thì kéo-để-làm-mới mới hoạt động khi danh sách rỗng.
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          _Notice(
            icon: Icons.search_rounded,
            title: 'Đang tìm phòng…',
            detail: 'Chưa thấy phòng nào trong mạng này.\n'
                'Hãy chắc chắn máy kia đã tạo phòng và đang dùng chung Wi-Fi.',
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      itemCount: rooms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final room = rooms[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: const Icon(Icons.meeting_room_outlined),
            title: Text(room.advertisement.displayName),
            subtitle: Text('${room.address}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _joinDiscovered(context, ref, room),
          ),
        );
      },
    );
  }
}

class _PermissionBlocked extends ConsumerWidget {
  const _PermissionBlocked({required this.gameId});

  final GameId gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 60),
        const _Notice(
          icon: Icons.wifi_off_rounded,
          title: 'Chưa có quyền truy cập mạng nội bộ',
          detail: 'Không có quyền này thì ứng dụng không thấy được máy khác '
              'trong cùng Wi-Fi.',
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () async {
            await const LocalNetworkPermission().openSettings();
            if (!context.mounted) return;
            ref.read(roomBrowserProvider(gameId).notifier).refresh();
          },
          child: const Text('Mở Cài đặt'),
        ),
      ],
    );
  }
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
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nhập địa chỉ phòng'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Địa chỉ hiện ở màn hình chờ trên máy tạo phòng.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              hintText: '192.168.1.5:47821',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Huỷ'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Vào phòng')),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, this.detail});

  final IconData icon;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(child: child);
}
