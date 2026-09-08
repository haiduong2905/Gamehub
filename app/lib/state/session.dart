import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_core/platform_core.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../transport/lan/local_network_permission.dart';
import '../transport/lan/network_interfaces.dart';
import 'catalog.dart';
import 'identity.dart';
import 'network_providers.dart';

enum SessionStatus {
  /// Chua o trong phong nao.
  idle,

  /// Dang mo phong hoac dang ket noi.
  busy,

  /// Da o trong phong.
  active,

  /// Khong vao duoc phong.
  failed,
}

class SessionState {
  const SessionState({
    this.status = SessionStatus.idle,
    this.client,
    this.gameId,
    this.isHost = false,
    this.hostAddress,
    this.errorCode,
    this.errorMessage,
  });

  final SessionStatus status;

  /// Trang thai do host gui xuong. Nguon su that duy nhat cho UI trong phong.
  final RoomClientState? client;

  final GameId? gameId;
  final bool isHost;

  /// Dia chi de nguoi khac nhap tay khi mDNS khong hoat dong. Chi co o host.
  final String? hostAddress;

  final String? errorCode;
  final String? errorMessage;

  bool get inRoom => status == SessionStatus.active && client != null;

  SessionState copyWith({
    SessionStatus? status,
    RoomClientState? client,
    GameId? gameId,
    bool? isHost,
    String? hostAddress,
    String? errorCode,
    String? errorMessage,
  }) =>
      SessionState(
        status: status ?? this.status,
        client: client ?? this.client,
        gameId: gameId ?? this.gameId,
        isHost: isHost ?? this.isHost,
        hostAddress: hostAddress ?? this.hostAddress,
        errorCode: errorCode ?? this.errorCode,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

/// Ghep core voi tang mang that.
///
/// Nguoi tao phong chay MOT LUC ca [RoomHost] lan [RoomClient]: host noi
/// chuyen voi chinh no qua mot ong trong bo nho, dung protocol y het nguoi
/// choi tu xa. Nho vay UI chi co mot duong code duy nhat, va bug khong the
/// chi lo ra o mot phia.
class SessionController extends Notifier<SessionState> {
  RoomHost? _host;
  RoomClient? _client;
  HostTransport? _hostTransport;
  DiscoveryService? _discovery;
  StreamSubscription<RoomClientState>? _clientSub;

  @override
  SessionState build() {
    // Hot restart khong tu dong dong HttpServer da bind. Thieu doan nay,
    // moi lan reload se de lai mot server zombie giu cong va quang ba trung.
    ref.onDispose(_teardown);
    return const SessionState();
  }

  /// Tao phong va tu vao luon.
  Future<void> createRoom({
    required GameId gameId,
    required String displayName,
    int? maxPlayers,
  }) async {
    final identity = ref.read(identityProvider).valueOrNull;
    if (identity == null) return;

    state = const SessionState(status: SessionStatus.busy);

    final access = await ref.read(localNetworkPermissionProvider).request();
    if (access != LocalNetworkAccess.granted) {
      _fail('NO_PERMISSION', _permissionMessage(access));
      return;
    }

    try {
      await _teardown();

      final transport = ref.read(hostTransportFactoryProvider)();
      final discovery = ref.read(discoveryFactoryProvider)();
      _hostTransport = transport;
      _discovery = discovery;

      final host = RoomHost(
        registry: ref.read(gameCatalogProvider).registry,
        transport: transport,
        discovery: discovery,
        roomId: _newRoomId(),
        gameId: gameId,
        displayName: displayName,
        hostPlayerId: identity.playerId,
        maxPlayers: maxPlayers,
      );
      _host = host;

      final localLink = await host.open();
      _attachClient(
        RoomClient(
          link: localLink,
          playerId: identity.playerId,
          nickname: identity.nickname,
        ),
      );

      final local = await bestLocalAddress();
      state = state.copyWith(
        status: SessionStatus.active,
        gameId: gameId,
        isHost: true,
        hostAddress:
            local == null ? null : '${local.address}:${host.port}',
      );
    } on Object catch (e) {
      await _teardown();
      _fail('HOST_FAILED', '$e');
    }
  }

  /// Vao phong cua nguoi khac.
  Future<void> joinRoom(RoomAddress address, {required GameId gameId}) async {
    final identity = ref.read(identityProvider).valueOrNull;
    if (identity == null) return;

    state = const SessionState(status: SessionStatus.busy);

    final access = await ref.read(localNetworkPermissionProvider).request();
    if (access != LocalNetworkAccess.granted) {
      _fail('NO_PERMISSION', _permissionMessage(access));
      return;
    }

    try {
      await _teardown();

      final link = await ref.read(clientTransportProvider).connect(address);
      _attachClient(
        RoomClient(
          link: link,
          playerId: identity.playerId,
          nickname: identity.nickname,
        ),
      );

      state = state.copyWith(
        status: SessionStatus.active,
        gameId: gameId,
        isHost: false,
      );
    } on TransportException catch (e) {
      await _teardown();
      _fail(e.code, e.message);
    } on Object catch (e) {
      await _teardown();
      _fail('CONNECT_FAILED', '$e');
    }
  }

  void setReady({required bool ready}) => _client?.setReady(ready: ready);

  void startGame() => _client?.startGame();

  void sendAction(Map<String, dynamic> action) => _client?.sendAction(action);

  /// Roi phong theo y nguoi dung.
  ///
  /// CHI goi khi nguoi dung that su bam roi phong. Tuyet doi khong goi khi
  /// app xuong nen: `AppLifecycleState.paused` ban ra ca khi keo thanh thong
  /// bao, mo Control Center, hay co cuoc goi den - da nguoi choi ra khoi
  /// phong vi nhung viec do la sai.
  Future<void> leave() async {
    _client?.leave();
    await _teardown();
    state = const SessionState();
  }

  void _attachClient(RoomClient client) {
    _client = client;
    _clientSub = client.states.listen((clientState) {
      state = state.copyWith(client: clientState);
      _syncWakelock(clientState);
    });
    client.join();
  }

  /// Giu man hinh sang trong luc dang choi.
  ///
  /// Khoa man hinh se khien he dieu hanh treo socket sau khoang 30 giay, va
  /// van dau chet mot cach kho hieu.
  void _syncWakelock(RoomClientState clientState) {
    _tryWakelock(clientState.phase == ClientPhase.playing);
  }

  /// Wakelock chi la tien nghi. Khong co plugin (vi du khi chay widget test)
  /// thi bo qua chu khong duoc lam hong ca phien choi.
  static void _tryWakelock(bool enable) {
    unawaited(
      WakelockPlus.toggle(enable: enable).catchError((Object _) {}),
    );
  }

  void _fail(String code, String? message) {
    state = SessionState(
      status: SessionStatus.failed,
      errorCode: code,
      errorMessage: message,
    );
  }

  Future<void> _teardown() async {
    await _clientSub?.cancel();
    _clientSub = null;

    await _client?.dispose();
    _client = null;

    await _host?.close();
    _host = null;

    // RoomHost.close() da dung transport va discovery cua no, nhung khi mo
    // phong that bai giua chung thi chung co the chua duoc dung.
    await _hostTransport?.stop();
    _hostTransport = null;
    await _discovery?.dispose();
    _discovery = null;

    _tryWakelock(false);
  }

  static String _newRoomId() {
    final random = Random.secure();
    final bytes = List<int>.generate(4, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _permissionMessage(LocalNetworkAccess access) =>
      access == LocalNetworkAccess.permanentlyDenied
          ? 'Ban da tu choi quyen truy cap mang noi bo. Vao Cai dat de bat lai.'
          : 'Can quyen truy cap mang noi bo de tim va ket noi voi may khac.';
}

final sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
