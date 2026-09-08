import 'dart:async';

import '../protocol/ids.dart';

/// Mot duong truyen hai chieu toi DUNG MOT doi tac.
///
/// Chi lam viec voi chuoi da serialize. Core khong biet ben duoi la WebSocket,
/// bo nho, hay thu gi khac - do la toan bo diem cua abstraction nay.
abstract class PeerLink {
  /// Dinh danh o tang van chuyen, KHONG phai [PlayerId].
  /// Mot nguoi choi mat ket noi roi vao lai se co [linkId] moi nhung
  /// giu nguyen [PlayerId].
  String get linkId;

  /// Cac ban tin nhan duoc, da la chuoi JSON.
  Stream<String> get incoming;

  /// Gui di. Goi khi da dong thi bo qua trong im lang, khong nem loi:
  /// mat ket noi la chuyen binh thuong, khong phai loi lap trinh.
  void send(String data);

  bool get isClosed;

  /// Hoan tat khi duong truyen dong han.
  Future<void> get done;

  Future<void> close([String? reason]);
}

/// Thong tin mot phong dang duoc quang ba tren mang.
///
/// Chi chua du lieu BAT BIEN trong suot doi phong. Khong dat so nguoi choi
/// vao day: tren Android, NsdManager truoc API 34 khong sua duoc TXT record,
/// muon doi phai huy dang ky roi dang ky lai, khien phong nhap nhay tren may
/// nguoi khac ma so lieu van sai vai giay vi mDNS cache theo TTL.
class RoomAdvertisement {
  const RoomAdvertisement({
    required this.roomId,
    required this.gameId,
    required this.displayName,
    required this.protocolVersion,
    this.hasPassword = false,
  });

  final RoomId roomId;
  final GameId gameId;
  final String displayName;
  final int protocolVersion;
  final bool hasPassword;
}

/// Dia chi de ket noi toi mot host.
class RoomAddress {
  const RoomAddress({required this.host, required this.port});

  /// Bat buoc la dia chi IP dang so.
  ///
  /// Tuyet doi khong dua hostname `.local` vao day: `InternetAddress.lookup`
  /// cua dart:io khong di qua resolver mDNS tren Android, nen ket noi se chet.
  final String host;
  final int port;

  @override
  String toString() => '$host:$port';
}

/// Mot phong tim thay tren mang.
class DiscoveredRoom {
  const DiscoveredRoom({
    required this.advertisement,
    required this.address,
  });

  final RoomAdvertisement advertisement;
  final RoomAddress address;

  RoomId get roomId => advertisement.roomId;
}

/// Phia host: lang nghe va nhan ket noi den.
abstract class HostTransport {
  /// Bat dau lang nghe. Tra ve cong that su da chiem duoc.
  Future<int> start();

  /// Moi ket noi moi tu mot client.
  Stream<PeerLink> get connections;

  Future<void> stop();
}

/// Phia client: mo ket noi toi mot host.
abstract class ClientTransport {
  Future<PeerLink> connect(
    RoomAddress address, {
    Duration timeout = const Duration(seconds: 5),
  });
}

/// Tim va quang ba phong tren mang noi bo.
abstract class DiscoveryService {
  /// Quang ba phong cua minh.
  Future<void> advertise(RoomAdvertisement ad, {required int port});

  Future<void> stopAdvertising();

  /// Danh sach phong dang thay, phat lai moi khi co thay doi.
  ///
  /// La danh sach day du chu khong phai su kien them/bot le, de UI chi can
  /// thay the ca danh sach - khong the troi trang thai.
  Stream<List<DiscoveredRoom>> get rooms;

  /// [gameId] khac null thi chi tra ve phong cua game do.
  Future<void> startDiscovery({GameId? gameId});

  Future<void> stopDiscovery();

  /// Dung han: giai phong moi tai nguyen. Sau khi goi thi khong dung lai duoc.
  Future<void> dispose();
}

/// Loi khong ket noi duoc, kem ma on dinh de UI dich sang tieng Viet.
class TransportException implements Exception {
  const TransportException(this.code, [this.message]);

  /// TIMEOUT, REFUSED, NO_PERMISSION, UNREACHABLE, UNKNOWN.
  final String code;
  final String? message;

  @override
  String toString() => 'TransportException($code): ${message ?? ''}';
}
