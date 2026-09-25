import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_audio/game_audio.dart';
import 'package:platform_core/platform_core.dart';

import '../state/catalog.dart';
import '../state/session.dart';
import 'app_ui.dart';
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
        await requestLeave(context, ref, client);
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

  /// Hỏi rồi rời phòng. Dùng chung cho nút quay lại của hệ thống và nút
  /// "Rời phòng" trong màn chờ — hai đường đó phải hỏi đúng một câu.
  static Future<void> requestLeave(
    BuildContext context,
    WidgetRef ref,
    RoomClientState client,
  ) async {
    if (!await _confirmLeave(context, client)) return;
    if (!context.mounted) return;
    await ref.read(sessionProvider.notifier).leave();
    if (context.mounted) Navigator.of(context).pop();
  }

  static Future<bool> _confirmLeave(
    BuildContext context,
    RoomClientState client,
  ) async {
    final playing = client.phase == ClientPhase.playing;
    final amHost = client.amHost;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmLeaveDialog(
        title: playing ? 'Rời trận đang chơi?' : 'Rời phòng?',
        // Chủ phòng rời đi thì cả phòng tan, nên câu cảnh báo phải nói ra hậu
        // quả cho người khác chứ không chỉ cho mình.
        message: amHost
            ? 'Bạn là người tạo phòng. Nếu bạn rời đi, phòng sẽ đóng và mọi '
                'người sẽ bị ngắt kết nối.'
            : (playing
                ? 'Ván đang dở sẽ tính là bạn bỏ cuộc.'
                : 'Bạn sẽ quay lại danh sách phòng.'),
        confirmLabel: amHost ? 'Rời và đóng phòng' : 'Rời phòng',
        severe: amHost || playing,
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

/// Màu và nhịp lấy từ [GameColors]/[GameMotion] của `game_audio`, đúng bộ mà
/// màn ván đấu đang dùng. Phòng chờ là chặng ngay trước bàn cờ, nên nó là chỗ
/// dễ thấy nhất nếu hai màn nói hai thứ tiếng màu.
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
    final missing = entry.minPlayers - room.players.length;

    return Scaffold(
      backgroundColor: GameColors.page,
      appBar: gameAppBar(
        context: context,
        title: 'Phòng chờ',
        centerTitle: false,
        background: GameColors.page,
        foreground: GameColors.ink,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          _GameBadge(entry: entry),
          const SizedBox(height: 16),
          _InviteCard(
            roomName: room.displayName,
            // Địa chỉ chỉ chủ phòng mới có: đó là cổng máy của chính họ đang
            // mở. Khách vào phòng thì thẻ này chỉ còn là tên phòng.
            address: session.isHost ? session.hostAddress : null,
          ),
          const SizedBox(height: 22),
          _SectionHeader(
            title: 'Người chơi',
            trailing: '${room.players.length}/${room.maxPlayers}',
          ),
          const SizedBox(height: 10),
          for (final slot in room.players) ...[
            _PlayerTile(slot: slot, isMe: slot.playerId == client.me),
            const SizedBox(height: 8),
          ],
          // Vẽ luôn cả chỗ còn trống. Người vào sau thế chỗ một ô đã có sẵn
          // nên danh sách không nở ra, và nhìn là biết phòng còn thiếu mấy
          // người mà không phải đọc con số.
          for (var i = room.players.length; i < room.maxPlayers; i++) ...[
            const _EmptySlotTile(),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          AppStatusPill(
            text: switch ((missing, everyoneReady, session.isHost)) {
              (> 0, _, _) => 'Cần thêm $missing người để bắt đầu ván',
              (_, false, _) => 'Đang chờ mọi người bấm sẵn sàng',
              (_, true, true) => 'Đủ người rồi — bấm Bắt đầu ván',
              (_, true, false) => 'Đang chờ chủ phòng bắt đầu ván',
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Đổi hẳn kiểu nút khi bấm sẵn sàng; chuyển mềm để mắt theo kịp.
            if (me != null)
              AnimatedSwitcher(
                duration: GameMotion.quick,
                switchInCurve: GameMotion.curve,
                switchOutCurve: GameMotion.curveIn,
                child: me.isReady
                    ? OutlinedButton.icon(
                        key: const ValueKey('ready'),
                        onPressed: () => ref
                            .read(sessionProvider.notifier)
                            .setReady(ready: false),
                        style: AppButtons.soft,
                        icon: const Icon(Icons.check_circle_rounded, size: 20),
                        label: const Text('Đã sẵn sàng'),
                      )
                    : FilledButton(
                        key: const ValueKey('not-ready'),
                        onPressed: () => ref
                            .read(sessionProvider.notifier)
                            .setReady(ready: true),
                        style: AppButtons.accent,
                        child: const Text('Sẵn sàng'),
                      ),
              ),
            if (session.isHost) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: everyoneReady && missing <= 0
                    ? () => ref.read(sessionProvider.notifier).startGame()
                    : null,
                style: AppButtons.accent,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Bắt đầu ván'),
              ),
            ],
            TextButton(
              onPressed: () => RoomScreen.requestLeave(context, ref, client),
              style: TextButton.styleFrom(
                foregroundColor: GameColors.muted,
                minimumSize: const Size.fromHeight(44),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              child: const Text('Rời phòng'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hàng đầu màn: icon game, tên game, và luật chỗ ngồi của game đó.
///
/// Dòng dưới nói về **game** chứ không nhắc lại tên phòng: tên phòng đã là
/// dòng to nhất của thẻ ngay bên dưới, in lại lần nữa cách đó trăm pixel thì
/// chỗ ấy không nói thêm được gì.
class _GameBadge extends StatelessWidget {
  const _GameBadge({required this.entry});

  final CatalogEntry entry;

  String get _seats => entry.minPlayers == entry.maxPlayers
      ? '${entry.minPlayers} người'
      : '${entry.minPlayers}–${entry.maxPlayers} người';

  @override
  Widget build(BuildContext context) => Row(
        children: [
          entry.buildIcon(48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: GameColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ván $_seats · cùng Wi-Fi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: GameColors.muted),
                ),
              ],
            ),
          ),
        ],
      );
}

/// Thẻ mời người khác vào phòng.
///
/// Địa chỉ `IP:port` là đường vào duy nhất khi mDNS bị mạng chặn, nên nó phải
/// đọc được và sao chép được chứ không phải một dòng chữ nhỏ ở góc.
class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.roomName, required this.address});

  final String roomName;
  final String? address;

  @override
  Widget build(BuildContext context) {
    final address = this.address;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GameColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GameColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            address == null ? 'BẠN ĐANG Ở TRONG PHÒNG' : 'MỜI BẠN CÙNG CHƠI',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: GameColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            roomName,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: GameColors.ink,
            ),
          ),
          if (address != null) ...[
            const SizedBox(height: 12),
            _AddressRow(address: address),
            const SizedBox(height: 10),
            const Text(
              'Nếu bạn bè không thấy phòng, hãy gửi địa chỉ này để '
              'họ kết nối cùng Wi-Fi.',
              style: TextStyle(
                  fontSize: 12, height: 1.35, color: GameColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
          color: GameColors.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GameColors.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: SelectableText(
                address,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: GameColors.ink,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: address));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép địa chỉ')),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: GameColors.accent,
                backgroundColor: GameColors.card,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                  side: const BorderSide(color: GameColors.cardBorder),
                ),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              icon: const Icon(Icons.copy_rounded, size: 14),
              label: const Text('Sao chép'),
            ),
          ],
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: GameColors.ink,
            ),
          ),
          const Spacer(),
          Text(
            trailing,
            style: const TextStyle(fontSize: 13, color: GameColors.muted),
          ),
        ],
      );
}

/// Chiều cao chung của một ô người chơi, kể cả ô còn trống.
///
/// Cố định để lúc có người vào, danh sách thế chỗ chứ không nở ra — cùng lý do
/// với mọi khối quanh bàn cờ.
const _slotHeight = 66.0;

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.slot, required this.isMe});

  final PlayerSlot slot;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final subtitle = slot.isConnected
        ? (slot.isHost ? 'Người tạo phòng' : 'Người chơi')
        : 'Mất kết nối — đang chờ quay lại';

    return _SlotFrame(
      child: Row(
        children: [
          _Avatar(letter: slot.nickname.characters.first, highlight: isMe),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        slot.nickname,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: GameColors.ink,
                        ),
                      ),
                    ),
                    if (isMe)
                      const Text(
                        ' · Bạn',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: GameColors.muted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        slot.isConnected ? GameColors.muted : GameColors.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Huy hiệu bên phải nói trạng thái sẵn sàng chứ không nhắc lại vai
          // trò: "Người tạo phòng" đã nằm ở dòng dưới tên rồi, còn ai đã bấm
          // sẵn sàng thì không đọc được ở đâu khác.
          if (!slot.isConnected)
            const _Chip(
              label: 'MẤT KẾT NỐI',
              foreground: GameColors.accent,
              background: GameColors.clockActive,
            )
          else if (slot.isReady)
            const _Chip(
              label: 'SẴN SÀNG',
              foreground: Colors.white,
              background: GameColors.accent,
            )
          else
            const _Chip(
              label: 'CHƯA SẴN SÀNG',
              foreground: GameColors.muted,
              background: GameColors.cardBorder,
            ),
        ],
      ),
    );
  }
}

class _EmptySlotTile extends StatelessWidget {
  const _EmptySlotTile();

  @override
  Widget build(BuildContext context) => _SlotFrame(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: GameColors.paper,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GameColors.cardBorder),
              ),
              child: const Icon(Icons.add_rounded,
                  size: 20, color: GameColors.muted),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Đang chờ người chơi',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: GameColors.muted,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Chưa có ai tham gia',
                    style: TextStyle(fontSize: 12, color: GameColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SlotFrame extends StatelessWidget {
  const _SlotFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        height: _slotHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: GameColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GameColors.cardBorder),
        ),
        child: child,
      );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.letter, required this.highlight});

  final String letter;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: highlight ? GameColors.accent : GameColors.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlight ? GameColors.accent : GameColors.cardBorder,
          ),
        ),
        child: Text(
          letter.toUpperCase(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: highlight ? Colors.white : GameColors.ink,
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  /// Bề rộng cố định cho mọi nhãn. Ba trạng thái dài ngắn khác nhau, mà đổi
  /// bề rộng thì tên người chơi bên trái co giãn theo — nhìn như cả dòng vừa
  /// bị đẩy đi.
  static const width = 100.0;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: GameMotion.quick,
        curve: GameMotion.curve,
        width: width,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: .5,
            color: foreground,
          ),
        ),
      );
}

/// Hộp thoại xác nhận rời phòng.
class _ConfirmLeaveDialog extends StatelessWidget {
  const _ConfirmLeaveDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.severe,
  });

  final String title;
  final String message;
  final String confirmLabel;

  /// Rời đi có hậu quả cho người khác, hoặc cho ván đang dở.
  final bool severe;

  @override
  Widget build(BuildContext context) => AppDialog(
        icon: Icons.priority_high_rounded,
        title: title,
        message: message,
        danger: severe,
        // Xếp dọc chứ không hai nút cạnh nhau: thao tác phá hủy không nên là
        // thứ ngón cái chạm trúng trước.
        stackActions: true,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: AppButtons.soft,
            child: const Text('Ở lại phòng'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: AppButtons.accent,
            child: Text(confirmLabel),
          ),
        ],
      );
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
      clocks: client.playerClocks,
      series: client.series,
      onAction: (action) =>
          ref.read(sessionProvider.notifier).sendAction(action),
    );

    final disconnected =
        room.players.where((p) => !p.isConnected).toList(growable: false);

    // Nhạc nền bọc cả màn ván đấu, không phải chỉ bàn cờ: rời màn hình là
    // nhạc tắt. Đặt ở đây nên **mọi game** có nhạc nền, kể cả game thêm sau
    // này — không game nào phải tự lo phần đó cho ván đấu qua mạng.
    return GameMusic(
      child: Scaffold(
        appBar: gameAppBar(
          context: context,
          title: entry.name,
          actions: const [GameAudioButton()],
        ),
        body: Column(
          children: [
            // Dải báo mất kết nối và bảng kết quả đều chen vào giữa lúc đang
            // chơi và đẩy bàn cờ đi. Cho chúng cao dần lên thay vì bật ra.
            _Reveal(
              child: disconnected.isEmpty
                  ? null
                  : _DisconnectBanner(nickname: disconnected.first.nickname),
            ),
            // Không có dải trạng thái ở đây: mỗi game tự vẽ nó ngay trên bàn
            // cờ của mình. Màn này không biết game nào đang chạy nên cũng
            // không biết chữ nào là đúng — "Lượt của bạn" với cờ caro, nhưng
            // cờ tướng còn phải nói tới chiếu tướng và cầu hòa.
            Expanded(child: entry.buildBoard(view)),
            _Reveal(
              child: client.result == null
                  ? null
                  : _ResultPanel(session: session, client: client),
            ),
          ],
        ),
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

/// Cho một khối chen vào hoặc biến đi bằng cách cao dần, không bật ra.
///
/// `if (x) Widget()` trong một [Column] làm phần còn lại nhảy đúng một khung
/// hình. Ở màn ván đấu thì phần còn lại là bàn cờ, nên cú nhảy đó rất rõ.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) => AnimatedSize(
        duration: GameMotion.normal,
        curve: GameMotion.curve,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: GameMotion.normal,
          switchInCurve: GameMotion.curve,
          switchOutCurve: GameMotion.curveIn,
          child: child ?? const SizedBox(width: double.infinity),
        ),
      );
}
