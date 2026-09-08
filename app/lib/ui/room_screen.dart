import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_core/platform_core.dart';

import '../state/catalog.dart';
import '../state/session.dart';
import 'messages.dart';

/// Một phòng, từ lúc chờ đến khi xong ván.
///
/// Màn hình này hoàn toàn không biết game nào đang chơi: nó lấy widget bàn cờ
/// từ catalog theo `gameId`. Thêm game mới không phải sửa file này - đúng
/// nguyên tắc "Generic Room + Game Metadata" của bản spec.
class RoomScreen extends ConsumerWidget {
  const RoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<SessionState>(sessionProvider, (previous, next) {
      final phase = next.client?.phase;
      if (phase == ClientPhase.closed || phase == ClientPhase.rejected) {
        _leaveWithReason(context, ref, next);
      }
    });

    final session = ref.watch(sessionProvider);
    final client = session.client;

    if (client == null || session.status == SessionStatus.busy) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final confirmed = await _confirmLeave(context, client);
        if (confirmed && context.mounted) {
          await ref.read(sessionProvider.notifier).leave();
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: switch (client.phase) {
        ClientPhase.joining => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        ClientPhase.inRoom => _WaitingRoom(session: session, client: client),
        ClientPhase.playing ||
        ClientPhase.finished =>
          _GameView(session: session, client: client),
        ClientPhase.rejected || ClientPhase.closed => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
      },
    );
  }

  static Future<bool> _confirmLeave(
    BuildContext context,
    RoomClientState client,
  ) async {
    final playing = client.phase == ClientPhase.playing;
    final amHost = client.amHost;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(playing ? 'Rời trận đang chơi?' : 'Rời phòng?'),
        content: Text(
          amHost
              ? 'Bạn là người tạo phòng. Rời đi thì phòng sẽ đóng lại với tất cả mọi người.'
              : (playing
                  ? 'Ván đang dở sẽ tính là bạn bỏ cuộc.'
                  : 'Bạn sẽ quay lại danh sách phòng.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rời phòng'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  static Future<void> _leaveWithReason(
    BuildContext context,
    WidgetRef ref,
    SessionState session,
  ) async {
    final code = session.client?.closeCode ?? session.client?.errorCode;
    await ref.read(sessionProvider.notifier).leave();

    if (!context.mounted) return;
    // Sau khi leave() thi session khong con client, nen nhanh render o tren
    // khong con boc PopScope - pop o day khong bat hop thoai xac nhan.
    // Quay ve danh sach phong chu khong day han ve man hinh chinh.
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(messageForCode(code))),
    );
  }
}

// ---------------------------------------------------------------------------
// Phòng chờ
// ---------------------------------------------------------------------------

class _WaitingRoom extends ConsumerWidget {
  const _WaitingRoom({required this.session, required this.client});

  final SessionState session;
  final RoomClientState client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = client.room!;
    final entry = ref.watch(gameCatalogProvider).require(room.gameId);
    final me = client.mySlot;
    final everyoneReady =
        room.players.isNotEmpty && room.players.every((p) => p.isReady);
    final enoughPlayers = room.players.length >= entry.minPlayers;

    return Scaffold(
      appBar: AppBar(title: Text(room.displayName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _GameBadge(entry: entry),
          if (session.isHost && session.hostAddress != null) ...[
            const SizedBox(height: 16),
            _HostAddressCard(address: session.hostAddress!),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'Người chơi',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Text(
                '${room.players.length}/${room.maxPlayers}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final slot in room.players) ...[
            _PlayerTile(slot: slot, isMe: slot.playerId == client.me),
            const SizedBox(height: 8),
          ],
          if (!enoughPlayers) ...[
            const SizedBox(height: 8),
            _Hint(
              'Đang chờ thêm người. Cần ít nhất ${entry.minPlayers} người để bắt đầu.',
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (me != null)
              me.isReady
                  ? OutlinedButton.icon(
                      onPressed: () => ref
                          .read(sessionProvider.notifier)
                          .setReady(ready: false),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Đã sẵn sàng'),
                    )
                  : FilledButton(
                      onPressed: () => ref
                          .read(sessionProvider.notifier)
                          .setReady(ready: true),
                      child: const Text('Sẵn sàng'),
                    ),
            if (session.isHost) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: everyoneReady && enoughPlayers
                    ? () => ref.read(sessionProvider.notifier).startGame()
                    : null,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Bắt đầu ván'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GameBadge extends StatelessWidget {
  const _GameBadge({required this.entry});

  final CatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(entry.icon, color: theme.colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Text(entry.name, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

class _HostAddressCard extends StatelessWidget {
  const _HostAddressCard({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Địa chỉ phòng',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  address,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 20),
                tooltip: 'Sao chép',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: address));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã sao chép địa chỉ')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Nếu máy kia không tự thấy phòng, cho họ nhập địa chỉ này.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.slot, required this.isMe});

  final PlayerSlot slot;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: slot.isConnected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: Text(
            slot.nickname.characters.first.toUpperCase(),
            style: TextStyle(
              color: slot.isConnected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Row(
          children: [
            Flexible(child: Text(slot.nickname, overflow: TextOverflow.ellipsis)),
            if (isMe) ...[
              const SizedBox(width: 6),
              Text(
                '(bạn)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          slot.isConnected
              ? (slot.isHost ? 'Người tạo phòng' : 'Người chơi')
              : 'Mất kết nối — đang chờ quay lại',
        ),
        trailing: slot.isConnected
            ? Icon(
                slot.isReady
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                color: slot.isReady
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              )
            : Icon(
                Icons.cloud_off_rounded,
                color: theme.colorScheme.error,
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Đang chơi
// ---------------------------------------------------------------------------

class _GameView extends ConsumerWidget {
  const _GameView({required this.session, required this.client});

  final SessionState session;
  final RoomClientState client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = client.room!;
    final entry = ref.watch(gameCatalogProvider).require(room.gameId);
    final nicknames = {
      for (final slot in room.players) slot.playerId: slot.nickname,
    };

    final view = GameView(
      state: client.gameState ?? const {},
      me: client.me,
      seatOrder: client.seatOrder,
      nicknames: nicknames,
      currentActors: client.currentActors,
      pendingActionId: client.pendingActionId,
      result: client.result,
      onAction: (action) =>
          ref.read(sessionProvider.notifier).sendAction(action),
    );

    final disconnected =
        room.players.where((p) => !p.isConnected).toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(entry.name)),
      body: Column(
        children: [
          _TurnBanner(view: view, finished: client.phase == ClientPhase.finished),
          if (disconnected.isNotEmpty)
            _DisconnectBanner(nickname: disconnected.first.nickname),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: entry.buildBoard(view),
            ),
          ),
          if (client.result != null)
            _ResultPanel(session: session, client: client),
        ],
      ),
    );
  }
}

class _TurnBanner extends StatelessWidget {
  const _TurnBanner({required this.view, required this.finished});

  final GameView view;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (label, color) = switch (true) {
      _ when finished => ('Ván đấu đã kết thúc', theme.colorScheme.onSurfaceVariant),
      _ when view.hasPendingAction => ('Đang gửi nước đi…', theme.colorScheme.onSurfaceVariant),
      _ when view.isMyTurn => ('Lượt của bạn', theme.colorScheme.primary),
      _ => (
          'Đang chờ ${view.nicknameOf(view.currentActors.firstOrNull ?? "")}',
          theme.colorScheme.onSurfaceVariant
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (view.hasPendingAction) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
          ],
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DisconnectBanner extends StatelessWidget {
  const _DisconnectBanner({required this.nickname});

  final String nickname;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 18,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$nickname mất kết nối. Đang chờ quay lại…',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultPanel extends ConsumerWidget {
  const _ResultPanel({required this.session, required this.client});

  final SessionState session;
  final RoomClientState client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final result = client.result!;
    final room = client.room!;

    final (title, icon) = switch (result.outcome) {
      GameOutcome.win when result.winners.contains(client.me) => (
          'Bạn thắng!',
          Icons.emoji_events_rounded,
        ),
      GameOutcome.win => (
          '${room.slotOf(result.winners.firstOrNull ?? "")?.nickname ?? "Đối thủ"} thắng',
          Icons.flag_rounded,
        ),
      GameOutcome.draw => ('Hoà', Icons.handshake_rounded),
      GameOutcome.abandoned => (
          messageForAbandonReason(result.reason),
          Icons.info_outline_rounded,
        ),
    };

    final everyoneReady =
        room.players.isNotEmpty && room.players.every((p) => p.isReady);
    final me = client.mySlot;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: theme.colorScheme.primary),
            const SizedBox(height: 10),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            if (me != null && !me.isReady)
              FilledButton(
                onPressed: () =>
                    ref.read(sessionProvider.notifier).setReady(ready: true),
                child: const Text('Chơi lại'),
              )
            else if (session.isHost)
              FilledButton(
                onPressed: everyoneReady
                    ? () => ref.read(sessionProvider.notifier).startGame()
                    : null,
                child: Text(
                  everyoneReady ? 'Bắt đầu ván mới' : 'Đang chờ đối thủ…',
                ),
              )
            else
              const Text('Đang chờ chủ phòng bắt đầu ván mới…'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await ref.read(sessionProvider.notifier).leave();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Rời phòng'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
