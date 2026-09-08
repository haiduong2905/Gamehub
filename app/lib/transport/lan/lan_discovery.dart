import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:platform_core/platform_core.dart';

/// Kieu dich vu mDNS cua ca platform.
///
/// DUNG MOT kieu duy nhat cho moi game, khong bao gio tach thanh
/// `_gamehub-chess._tcp`. Ly do: `NSBonjourServices` cua iOS khong ho tro
/// wildcard, moi kieu phai khai bao cung trong Info.plist. Loc theo game
/// duoc lam bang TXT record thay vi bang kieu dich vu.
const String kServiceType = '_gamehub._tcp';

/// Khoa cua TXT record. RFC 6763 khuyen nghi khoa khong qua 9 ky tu.
const String _kRoomId = 'rid';
const String _kGameId = 'gid';
const String _kProtocol = 'pv';
const String _kDisplayName = 'dn';
const String _kHasPassword = 'pw';

/// Do dai toi da cua ten phong sau khi ma hoa, de ca TXT record nam gon
/// trong mot goi tin. Tieng Viet co dau ton 3 byte moi ky tu sau khi
/// percent-encode nen phai cat nguon.
const int _kMaxEncodedNameLength = 120;

/// Tim va quang ba phong bang mDNS/Bonjour.
///
/// Chon mDNS chu khong phai UDP broadcast la quyet dinh kien truc quan trong
/// nhat cua tang mang: tren iOS, UDP broadcast tu che bat buoc phai co
/// entitlement `com.apple.developer.networking.multicast` - phai nop don xin
/// Apple duyet thu cong. Bonjour voi kieu dich vu co dinh khai bao san trong
/// `NSBonjourServices` thi khong can entitlement do.
class LanDiscovery implements DiscoveryService {
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _events;

  final Map<String, DiscoveredRoom> _found = <String, DiscoveredRoom>{};
  final StreamController<List<DiscoveredRoom>> _rooms =
      StreamController<List<DiscoveredRoom>>.broadcast();

  GameId? _filterGameId;

  @override
  Stream<List<DiscoveredRoom>> get rooms => _rooms.stream;

  @override
  Future<void> advertise(RoomAdvertisement ad, {required int port}) async {
    await stopAdvertising();

    final service = BonsoirService(
      // Ten instance phai la ASCII va toi da 63 byte. Ten phong tieng Viet co
      // dau bi Android va iOS xu ly khac nhau (tu doi ten khi trung), nen ten
      // hien thi duoc day vao TXT record thay vi dat o day.
      name: 'gh-${ad.roomId}',
      type: kServiceType,
      port: port,
      attributes: {
        _kRoomId: ad.roomId,
        _kGameId: ad.gameId,
        _kProtocol: '${ad.protocolVersion}',
        _kHasPassword: ad.hasPassword ? '1' : '0',
        _kDisplayName: _encodeName(ad.displayName),
      },
    );

    final broadcast = BonsoirBroadcast(service: service);
    _broadcast = broadcast;
    await broadcast.ready;
    await broadcast.start();
  }

  @override
  Future<void> stopAdvertising() async {
    final broadcast = _broadcast;
    _broadcast = null;
    if (broadcast != null && !broadcast.isStopped) {
      await broadcast.stop();
    }
  }

  @override
  Future<void> startDiscovery({GameId? gameId}) async {
    await stopDiscovery();
    _filterGameId = gameId;
    _found.clear();

    final discovery = BonsoirDiscovery(type: kServiceType);
    _discovery = discovery;
    await discovery.ready;

    _events = discovery.eventStream?.listen(_onEvent);
    await discovery.start();
    _emit();
  }

  @override
  Future<void> stopDiscovery() async {
    await _events?.cancel();
    _events = null;

    final discovery = _discovery;
    _discovery = null;
    if (discovery != null && !discovery.isStopped) {
      await discovery.stop();
    }

    _found.clear();
  }

  @override
  Future<void> dispose() async {
    await stopDiscovery();
    await stopAdvertising();
    if (!_rooms.isClosed) await _rooms.close();
  }

  Future<void> _onEvent(BonsoirDiscoveryEvent event) async {
    switch (event.type) {
      case BonsoirDiscoveryEventType.discoveryServiceFound:
        // Tim thay moi chi biet ten; phai resolve moi co dia chi va TXT.
        final service = event.service;
        if (service != null) {
          await _discovery?.serviceResolver.resolveService(service);
        }

      case BonsoirDiscoveryEventType.discoveryServiceResolved:
        final room = await _toRoom(event.service);
        if (room != null) {
          _found[room.roomId] = room;
          _emit();
        }

      case BonsoirDiscoveryEventType.discoveryServiceLost:
        // Host tat may thi entry mDNS con song theo TTL, nen su kien nay den
        // muon. Van phai nghe: neu khong, danh sach se day phong ma.
        final roomId = event.service?.attributes[_kRoomId];
        if (roomId != null && _found.remove(roomId) != null) _emit();

      case BonsoirDiscoveryEventType.discoveryServiceResolveFailed:
      case BonsoirDiscoveryEventType.discoveryStarted:
      case BonsoirDiscoveryEventType.discoveryStopped:
      case BonsoirDiscoveryEventType.unknown:
        break;
    }
  }

  Future<DiscoveredRoom?> _toRoom(BonsoirService? service) async {
    if (service is! ResolvedBonsoirService) return null;

    final attributes = service.attributes;
    final roomId = attributes[_kRoomId];
    final gameId = attributes[_kGameId];
    if (roomId == null || gameId == null) return null;

    // Bo qua phong cua phien ban protocol khac: vao cung bi tu choi.
    if (attributes[_kProtocol] != '$kProtocolVersion') return null;

    if (_filterGameId != null && gameId != _filterGameId) return null;

    final host = await _numericHost(service.host);
    if (host == null) return null;

    return DiscoveredRoom(
      advertisement: RoomAdvertisement(
        roomId: roomId,
        gameId: gameId,
        displayName: _decodeName(attributes[_kDisplayName]) ?? 'Phong',
        protocolVersion: kProtocolVersion,
        hasPassword: attributes[_kHasPassword] == '1',
      ),
      address: RoomAddress(host: host, port: service.port),
    );
  }

  /// Bien host cua mDNS thanh dia chi IP dang so.
  ///
  /// Bat buoc phai lam: `InternetAddress.lookup` cua dart:io KHONG di qua
  /// resolver mDNS tren Android, nen neu de nguyen hostname dang
  /// `Ten-May.local` thi `WebSocket.connect` se chet. Neu khong doi duoc ra
  /// so thi bo phong do khoi danh sach con hon de nguoi dung bam vao roi
  /// nhan mot loi kho hieu.
  static Future<String?> _numericHost(String? host) async {
    if (host == null || host.isEmpty) return null;

    if (InternetAddress.tryParse(host) != null) return host;

    try {
      final addresses = await InternetAddress.lookup(
        host,
        type: InternetAddressType.IPv4,
      ).timeout(const Duration(seconds: 2));
      if (addresses.isEmpty) return null;
      return addresses.first.address;
    } on Object {
      return null;
    }
  }

  void _emit() {
    if (_rooms.isClosed) return;
    _rooms.add(List<DiscoveredRoom>.unmodifiable(_found.values));
  }

  /// TXT record chi cho phep US-ASCII in duoc, nen ten tieng Viet phai ma hoa.
  static String _encodeName(String name) {
    final encoded = Uri.encodeComponent(name);
    return encoded.length <= _kMaxEncodedNameLength
        ? encoded
        : encoded.substring(0, _kMaxEncodedNameLength);
  }

  static String? _decodeName(String? raw) {
    if (raw == null) return null;
    try {
      return Uri.decodeComponent(raw);
    } on FormatException {
      // Bi cat giua mot chuoi %XX. Hien nguyen ban con hon la hong ca danh sach.
      return raw;
    }
  }
}
