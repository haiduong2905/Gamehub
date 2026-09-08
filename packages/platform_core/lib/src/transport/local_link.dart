import 'dart:async';

import 'transport.dart';

/// Mot cap [PeerLink] noi thang voi nhau trong bo nho.
///
/// Dung o hai cho:
///
/// 1. Cho chinh nguoi choi la host. Host khong duoc phep goi thang vao
///    logic cua minh - neu lam vay, duong code cua host va cua client se khac
///    nhau va bug se chi xuat hien o mot phia. Thay vao do host tu noi mot
///    ong trong bo nho toi chinh no, roi noi chuyen qua dung protocol nhu
///    moi nguoi khac.
/// 2. Lam nen cho [LoopbackNetwork] khi test.
///
/// Chuyen tin LUON bat dong bo (qua [Timer]). Neu giao tin dong bo, code se
/// vo tinh phu thuoc vao thu tu do roi vo khi len mang that.
class LocalLinkPair {
  LocalLinkPair._(this.a, this.b);

  /// Tao mot cap da noi san. Gui o [a] thi [b] nhan duoc va nguoc lai.
  factory LocalLinkPair.create({
    required String linkId,
    Duration latency = Duration.zero,
    bool Function(String data)? dropIf,
  }) {
    final a = _LocalLink('$linkId/a', latency, dropIf);
    final b = _LocalLink('$linkId/b', latency, dropIf);
    a._peer = b;
    b._peer = a;
    return LocalLinkPair._(a, b);
  }

  final PeerLink a;
  final PeerLink b;

  Future<void> closeBoth([String? reason]) async {
    await a.close(reason);
    await b.close(reason);
  }
}

class _LocalLink implements PeerLink {
  _LocalLink(this.linkId, this._latency, this._dropIf);

  @override
  final String linkId;

  final Duration _latency;
  final bool Function(String data)? _dropIf;

  late final _LocalLink _peer;

  final StreamController<String> _incoming =
      StreamController<String>.broadcast();
  final Completer<void> _done = Completer<void>();

  bool _closed = false;

  @override
  Stream<String> get incoming => _incoming.stream;

  @override
  bool get isClosed => _closed;

  @override
  Future<void> get done => _done.future;

  @override
  void send(String data) {
    if (_closed || _peer._closed) return;
    if (_dropIf != null && _dropIf(data)) return;
    Timer(_latency, () {
      if (_peer._closed || _peer._incoming.isClosed) return;
      _peer._incoming.add(data);
    });
  }

  @override
  Future<void> close([String? reason]) async {
    if (_closed) return;
    _closed = true;
    if (!_incoming.isClosed) await _incoming.close();
    if (!_done.isCompleted) _done.complete();
    // Dong mot dau thi dau kia cung phai biet, giong socket that.
    Timer.run(() => _peer.close(reason));
  }
}
