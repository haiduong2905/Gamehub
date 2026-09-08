import 'dart:async';
import 'dart:io';

import 'package:platform_core/platform_core.dart';

/// Ping/pong o tang WebSocket.
///
/// Day moi la thu phat hien mat ket noi, KHONG phai mot heartbeat tu viet o
/// tang ung dung. Ly do:
///
/// * `dart:io` da tu gui ping va tu dong socket khi khong nhan duoc pong -
///   dung thu can de bat "half-open connection" luc ai do rot Wi-Fi dot ngot
///   (TCP keepalive mac dinh 2 tieng, hoan toan vo dung o day).
/// * Mot [Timer] 3 giay do tay se danh thuc CPU lien tuc va bi Doze cua
///   Android xu ly, vua ton pin vua khong dang tin.
const Duration kWebSocketPingInterval = Duration(seconds: 5);

/// Boc mot [WebSocket] thanh [PeerLink] cua core.
class WebSocketLink implements PeerLink {
  WebSocketLink(this._socket, this.linkId) {
    _subscription = _socket.listen(
      (dynamic data) {
        if (data is String) _incoming.add(data);
        // Khung nhi phan khong thuoc protocol nay: bo qua.
      },
      onError: (Object _) => _finish(),
      onDone: _finish,
      cancelOnError: false,
    );
  }

  final WebSocket _socket;

  @override
  final String linkId;

  final StreamController<String> _incoming =
      StreamController<String>.broadcast();
  final Completer<void> _done = Completer<void>();
  late final StreamSubscription<dynamic> _subscription;

  bool _closed = false;

  @override
  Stream<String> get incoming => _incoming.stream;

  @override
  bool get isClosed => _closed;

  @override
  Future<void> get done => _done.future;

  @override
  void send(String data) {
    if (_closed) return;
    try {
      _socket.add(data);
    } on StateError {
      // Socket vua dong ngay truoc khi gui. Mat ket noi la chuyen binh thuong,
      // khong phai loi lap trinh.
      _finish();
    }
  }

  @override
  Future<void> close([String? reason]) async {
    if (_closed) return;
    _closed = true;
    await _subscription.cancel();
    try {
      await _socket.close(WebSocketStatus.normalClosure, reason);
    } on Object {
      // Socket co the da chet san.
    }
    await _finishAsync();
  }

  void _finish() {
    unawaited(_finishAsync());
  }

  Future<void> _finishAsync() async {
    _closed = true;
    if (!_incoming.isClosed) await _incoming.close();
    if (!_done.isCompleted) _done.complete();
  }
}

/// Phia host: mot HTTP server nho chi de nang cap len WebSocket.
class LanHostTransport implements HostTransport {
  final StreamController<PeerLink> _connections =
      StreamController<PeerLink>.broadcast();

  HttpServer? _server;
  int _nextLinkId = 0;

  @override
  Stream<PeerLink> get connections => _connections.stream;

  /// Cong that su dang lang nghe. Chi co sau [start].
  int get port => _server?.port ?? (throw StateError('Chua goi start()'));

  @override
  Future<int> start() async {
    // Cong 0 = xin he dieu hanh mot cong trong, roi doc lai cong that.
    // Khong hardcode cong: hai app cung may (hoac mot lan hot restart chua
    // don sach) se dam nhau.
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server = server;

    server.listen(
      (request) async {
        if (!WebSocketTransformer.isUpgradeRequest(request)) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.write('Game Hub: chi chap nhan ket noi WebSocket.');
          await request.response.close();
          return;
        }
        try {
          final socket = await WebSocketTransformer.upgrade(request);
          socket.pingInterval = kWebSocketPingInterval;
          if (_connections.isClosed) {
            await socket.close();
            return;
          }
          _connections.add(WebSocketLink(socket, 'lan-in-${_nextLinkId++}'));
        } on Object {
          // Nang cap that bai: bo qua ket noi nay.
        }
      },
      onError: (Object _) {},
      cancelOnError: false,
    );

    return server.port;
  }

  @override
  Future<void> stop() async {
    // force: true rat quan trong khi hot restart - neu khong, server cu con
    // song se giu cong va tich tu server zombie qua moi lan reload.
    await _server?.close(force: true);
    _server = null;
    if (!_connections.isClosed) await _connections.close();
  }
}

/// Phia client: mo WebSocket toi host.
class LanClientTransport implements ClientTransport {
  int _nextLinkId = 0;

  @override
  Future<PeerLink> connect(
    RoomAddress address, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    // IPv6 phai boc trong ngoac vuong. MVP chi dung IPv4 nhung giu cho chac.
    final host = address.host.contains(':') ? '[${address.host}]' : address.host;
    final url = 'ws://$host:${address.port}';

    try {
      // `WebSocket.connect` KHONG co tham so timeout. Thieu doan .timeout()
      // nay, khi thieu quyen mang noi bo tren Android 16/17 app se treo cho
      // het TCP timeout cua he thong thay vi bao loi ngay.
      final socket = await WebSocket.connect(url).timeout(timeout);
      socket.pingInterval = kWebSocketPingInterval;
      return WebSocketLink(socket, 'lan-out-${_nextLinkId++}');
    } on TimeoutException {
      throw const TransportException(
        'TIMEOUT',
        'Khong ket noi duoc trong thoi gian cho phep',
      );
    } on SocketException catch (e) {
      throw TransportException(_codeFor(e), e.osError?.message ?? e.message);
    } on WebSocketException catch (e) {
      throw TransportException('REFUSED', e.message);
    }
  }

  /// Doi ma loi he thong thanh ma on dinh de UI dich sang tieng Viet.
  static String _codeFor(SocketException e) {
    final errno = e.osError?.errorCode;
    final message = (e.osError?.message ?? e.message).toLowerCase();

    // EPERM: Android 16/17 chan vi chua co quyen mang noi bo.
    if (errno == 1 || message.contains('permission')) return 'NO_PERMISSION';
    // ECONNREFUSED: co may o dia chi do nhung khong ai nghe o cong nay.
    if (errno == 111 || errno == 10061 || message.contains('refused')) {
      return 'REFUSED';
    }
    // EHOSTUNREACH / ENETUNREACH: thuong la traffic dang di ra cellular thay
    // vi Wi-Fi, hoac hai may khong cung mang.
    if (errno == 113 || errno == 101 || message.contains('unreachable')) {
      return 'UNREACHABLE';
    }
    return 'UNKNOWN';
  }
}
