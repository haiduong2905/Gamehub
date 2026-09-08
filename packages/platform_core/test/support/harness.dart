import 'dart:async';

import 'package:platform_core/platform_core.dart';

/// Dung san mot phong tren LoopbackNetwork, kem cac client, de test khong
/// phai lap di lap lai phan noi day.
class RoomHarness {
  RoomHarness({
    required this.registry,
    required this.gameId,
    Duration rejoinGrace = const Duration(seconds: 30),
    Duration latency = Duration.zero,
    int? maxPlayers,
  })  : network = LoopbackNetwork(latency: latency),
        _rejoinGrace = rejoinGrace,
        _maxPlayers = maxPlayers;

  final GameRegistry registry;
  final GameId gameId;
  final LoopbackNetwork network;
  final Duration _rejoinGrace;
  final int? _maxPlayers;

  late final RoomHost host;
  late final RoomClient hostClient;

  final List<RoomClient> clients = <RoomClient>[];
  final List<LoopbackDiscovery> _discoveries = <LoopbackDiscovery>[];

  /// Mo phong va cho nguoi tao phong vao. Tra ve client cua host.
  Future<RoomClient> open({
    String hostPlayerId = 'host',
    String hostNickname = 'Host',
    String roomId = 'room-1',
    String displayName = 'Phong test',
  }) async {
    final discovery = LoopbackDiscovery(network);
    _discoveries.add(discovery);

    host = RoomHost(
      registry: registry,
      transport: LoopbackHostTransport(network),
      discovery: discovery,
      roomId: roomId,
      gameId: gameId,
      displayName: displayName,
      hostPlayerId: hostPlayerId,
      maxPlayers: _maxPlayers,
      rejoinGrace: _rejoinGrace,
    );

    final localLink = await host.open();
    hostClient = RoomClient(
      link: localLink,
      playerId: hostPlayerId,
      nickname: hostNickname,
    )..join();
    clients.add(hostClient);
    await settle();
    return hostClient;
  }

  /// Mot nguoi choi khac tim phong roi vao.
  Future<RoomClient> joinViaDiscovery({
    required String playerId,
    required String nickname,
    String? roomSecret,
  }) async {
    final discovery = LoopbackDiscovery(network);
    _discoveries.add(discovery);
    await discovery.startDiscovery(gameId: gameId);
    final found = await discovery.rooms.first;
    if (found.isEmpty) {
      throw StateError('Khong tim thay phong nao qua discovery');
    }
    return joinAt(
      found.first.address,
      playerId: playerId,
      nickname: nickname,
      roomSecret: roomSecret,
    );
  }

  Future<RoomClient> joinAt(
    RoomAddress address, {
    required String playerId,
    required String nickname,
    String? roomSecret,
  }) async {
    final link = await LoopbackClientTransport(network).connect(address);
    final client = RoomClient(
      link: link,
      playerId: playerId,
      nickname: nickname,
      roomSecret: roomSecret,
    )..join();
    clients.add(client);
    await settle();
    return client;
  }

  RoomAddress get address => RoomAddress(host: '127.0.0.1', port: host.port);

  /// Cho cho moi ban tin dang bay tren day den noi.
  ///
  /// LocalLink giao tin qua Timer nen phai nhuong event loop vai vong,
  /// khong dung await don thuan duoc.
  Future<void> settle([int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> dispose() async {
    for (final client in clients) {
      await client.dispose();
    }
    await host.close();
    for (final d in _discoveries) {
      await d.dispose();
    }
  }
}

/// Thu thap state cua mot client de kiem tra thu tu su kien.
class StateRecorder {
  StateRecorder(RoomClient client) {
    _sub = client.states.listen(states.add);
  }

  final List<RoomClientState> states = <RoomClientState>[];
  late final StreamSubscription<RoomClientState> _sub;

  Future<void> cancel() => _sub.cancel();
}
