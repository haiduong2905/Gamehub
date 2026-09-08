import 'dart:async';

import '../protocol/ids.dart';
import 'local_link.dart';
import 'transport.dart';

/// Mot "mang LAN gia" nam gon trong bo nho.
///
/// Cho phep dung toan bo Room + Session + Game + UI va chay het mot van dau
/// ma khong can socket, khong can quyen, khong can thiet bi that. Day la thu
/// quyet dinh toc do phat trien cua ca du an.
///
/// Hai dieu kien de no khong thanh cai bay - ca hai deu duoc giu o day:
///
/// * Chuyen tin bang chuoi da serialize that su, khong dua thang tham chieu
///   object. Neu dua thang object, hai ben se dung chung mot instance va bug
///   aliasing se bi giau di, con codec thi khong he duoc test.
/// * Giao tin bat dong bo (xem [LocalLinkPair]).
///
/// [latency] va [dropIf] de gia lap mang xau trong test.
class LoopbackNetwork {
  LoopbackNetwork({
    this.latency = Duration.zero,
    bool Function(String data)? dropIf,
  }) : _dropIf = dropIf;

  final Duration latency;
  final bool Function(String data)? _dropIf;

  final Map<int, LoopbackHostTransport> _listeners = {};
  final Map<RoomId, DiscoveredRoom> _advertised = {};
  final List<StreamController<List<DiscoveredRoom>>> _watchers = [];

  int _nextPort = 40000;
  int _nextLink = 0;

  int _allocatePort() => _nextPort++;

  void _bind(int port, LoopbackHostTransport host) => _listeners[port] = host;

  void _unbind(int port) => _listeners.remove(port);

  void _publish(RoomAdvertisement ad, int port) {
    _advertised[ad.roomId] = DiscoveredRoom(
      advertisement: ad,
      address: RoomAddress(host: '127.0.0.1', port: port),
    );
    _notifyWatchers();
  }

  void _unpublish(RoomId roomId) {
    if (_advertised.remove(roomId) != null) _notifyWatchers();
  }

  void _notifyWatchers() {
    final snapshot = List<DiscoveredRoom>.unmodifiable(_advertised.values);
    for (final w in _watchers) {
      if (!w.isClosed) w.add(snapshot);
    }
  }

  List<DiscoveredRoom> get advertisedRooms =>
      List<DiscoveredRoom>.unmodifiable(_advertised.values);
}

class LoopbackHostTransport implements HostTransport {
  LoopbackHostTransport(this._network);

  final LoopbackNetwork _network;
  final StreamController<PeerLink> _connections =
      StreamController<PeerLink>.broadcast();

  int? _port;

  int get port => _port ?? (throw StateError('Chua goi start()'));

  @override
  Stream<PeerLink> get connections => _connections.stream;

  @override
  Future<int> start() async {
    final p = _network._allocatePort();
    _port = p;
    _network._bind(p, this);
    return p;
  }

  @override
  Future<void> stop() async {
    final p = _port;
    if (p != null) _network._unbind(p);
    _port = null;
    if (!_connections.isClosed) await _connections.close();
  }

  /// Duoc [LoopbackClientTransport] goi khi co client go cua.
  PeerLink _accept() {
    final pair = LocalLinkPair.create(
      linkId: 'loopback-${_network._nextLink++}',
      latency: _network.latency,
      dropIf: _network._dropIf,
    );
    // a la dau cua host, b la dau cua client.
    _connections.add(pair.a);
    return pair.b;
  }
}

class LoopbackClientTransport implements ClientTransport {
  LoopbackClientTransport(this._network);

  final LoopbackNetwork _network;

  @override
  Future<PeerLink> connect(
    RoomAddress address, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final host = _network._listeners[address.port];
    if (host == null) {
      throw const TransportException('REFUSED', 'Khong co ai lang nghe o cong nay');
    }
    return host._accept();
  }
}

class LoopbackDiscovery implements DiscoveryService {
  LoopbackDiscovery(this._network);

  final LoopbackNetwork _network;
  final StreamController<List<DiscoveredRoom>> _controller =
      StreamController<List<DiscoveredRoom>>.broadcast();

  RoomId? _myRoomId;
  GameId? _filterGameId;

  @override
  Stream<List<DiscoveredRoom>> get rooms => _controller.stream.map(_applyFilter);

  List<DiscoveredRoom> _applyFilter(List<DiscoveredRoom> all) {
    final gameId = _filterGameId;
    if (gameId == null) return all;
    return all
        .where((r) => r.advertisement.gameId == gameId)
        .toList(growable: false);
  }

  @override
  Future<void> advertise(RoomAdvertisement ad, {required int port}) async {
    _myRoomId = ad.roomId;
    _network._publish(ad, port);
  }

  @override
  Future<void> stopAdvertising() async {
    final id = _myRoomId;
    if (id != null) _network._unpublish(id);
    _myRoomId = null;
  }

  @override
  Future<void> startDiscovery({GameId? gameId}) async {
    _filterGameId = gameId;
    _network._watchers.add(_controller);
    // Phat ngay danh sach hien tai de UI khong phai cho su kien tiep theo.
    Timer.run(() {
      if (!_controller.isClosed) {
        _controller.add(_network.advertisedRooms);
      }
    });
  }

  @override
  Future<void> stopDiscovery() async {
    _network._watchers.remove(_controller);
  }

  @override
  Future<void> dispose() async {
    await stopDiscovery();
    await stopAdvertising();
    if (!_controller.isClosed) await _controller.close();
  }
}
