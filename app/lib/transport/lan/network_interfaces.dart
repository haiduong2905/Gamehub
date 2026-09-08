import 'dart:io';

/// Mot dia chi IPv4 co the dung de nguoi khac ket noi toi.
class LocalAddress {
  const LocalAddress({
    required this.address,
    required this.interfaceName,
    required this.score,
  });

  final String address;
  final String interfaceName;

  /// Cang cao cang dang tin. Xem [pickLocalAddresses].
  final int score;

  @override
  String toString() => '$address ($interfaceName)';
}

/// Chon dia chi IPv4 de quang ba cho nguoi khac ket noi toi.
///
/// Khong duoc quang ba bua moi dia chi may co:
///
/// * IPv6 link-local (`fe80::...%wlan0`) - dart:io xu ly scope-id rat te,
///   nen bo han IPv6 trong MVP.
/// * Interface cellular (`rmnet`, `ccmni`) - client trong cung Wi-Fi khong
///   the toi duoc.
/// * VPN (`tun`, `utun`, `ppp`) va cac interface ao cua Docker/VMware.
///
/// Neu quang ba nham mot trong nhung dia chi tren, client se thay phong
/// nhung join that bai - trieu chung rat kho chan doan.
///
/// Tra ve danh sach da sap theo do tin cay giam dan. Goi noi nen thu LAN
/// LUOT tu tren xuong, hoac thu song song va lay cai thanh cong dau tien.
Future<List<LocalAddress>> pickLocalAddresses() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
    includeLinkLocal: false,
  );

  final candidates = <LocalAddress>[];

  for (final interface in interfaces) {
    final name = interface.name.toLowerCase();
    if (_isExcluded(name)) continue;

    for (final address in interface.addresses) {
      final ip = address.address;
      if (!_isPrivateIPv4(ip)) continue;

      candidates.add(
        LocalAddress(
          address: ip,
          interfaceName: interface.name,
          score: _scoreOf(name, ip),
        ),
      );
    }
  }

  candidates.sort((a, b) => b.score.compareTo(a.score));
  return candidates;
}

/// Dia chi tot nhat de hien cho nguoi dung nhap tay, hoac `null` neu khong
/// tim thay - thuong la chua bat Wi-Fi.
Future<LocalAddress?> bestLocalAddress() async {
  final all = await pickLocalAddresses();
  return all.isEmpty ? null : all.first;
}

const _excludedPrefixes = <String>[
  'rmnet', // cellular tren Android
  'ccmni', // cellular tren mot so may MediaTek
  'pdp_ip', // cellular tren iOS
  'tun', // VPN
  'utun', // VPN tren macOS/iOS
  'ppp',
  'docker',
  'veth',
  'vethernet',
  'vmnet',
  'virbr',
  'vboxnet',
  'dummy',
];

bool _isExcluded(String lowerName) =>
    _excludedPrefixes.any(lowerName.startsWith) ||
    lowerName.contains('vmware') ||
    lowerName.contains('virtualbox') ||
    lowerName.contains('hyper-v') ||
    lowerName.contains('loopback');

/// Chi chap nhan dai IP noi bo. Dia chi public tren dien thoai gan nhu chac
/// chan la cellular.
bool _isPrivateIPv4(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) return false;
  final a = int.tryParse(parts[0]);
  final b = int.tryParse(parts[1]);
  if (a == null || b == null) return false;

  if (a == 10) return true;
  if (a == 192 && b == 168) return true;
  if (a == 172 && b >= 16 && b <= 31) return true;
  return false;
}

int _scoreOf(String lowerName, String ip) {
  var score = 0;

  // Wi-Fi la thu ta thuc su muon.
  if (lowerName.startsWith('wlan') ||
      lowerName.startsWith('wlp') ||
      lowerName.contains('wi-fi') ||
      lowerName.contains('wifi') ||
      lowerName.startsWith('en')) {
    score += 100;
  }

  // Ethernet van dung duoc khi test tren may ban.
  if (lowerName.startsWith('eth') || lowerName.contains('ethernet')) {
    score += 60;
  }

  // Wi-Fi Direct tao ra mang rieng, thuong khong phai cai ta muon.
  if (lowerName.startsWith('p2p') || lowerName.contains('ap0')) score -= 40;

  // 192.168.x.x la dai pho bien nhat cua router gia dinh.
  if (ip.startsWith('192.168.')) score += 20;

  return score;
}
