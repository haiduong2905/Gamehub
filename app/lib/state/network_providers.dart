import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_core/platform_core.dart';

import '../transport/lan/lan_discovery.dart';
import '../transport/lan/lan_transport.dart';
import '../transport/lan/local_network_permission.dart';

/// Tang mang duoc lay qua provider chu khong tao thang trong controller.
///
/// Nho vay:
///
/// * Cau hoi review "Network co the thay transport khong?" tra loi duoc bang
///   code chu khong bang loi hua - chi can override ba provider nay la ca app
///   chay tren mot transport khac.
/// * Test cua app chay duoc tren LoopbackTransport: toan bo luong tao phong,
///   vao phong, choi, thang thua kiem tra duoc bang `flutter test` ma khong
///   can thiet bi, khong can quyen, khong can Wi-Fi.

final hostTransportFactoryProvider = Provider<HostTransport Function()>(
  (ref) => LanHostTransport.new,
);

final clientTransportProvider = Provider<ClientTransport>(
  (ref) => LanClientTransport(),
);

final discoveryFactoryProvider = Provider<DiscoveryService Function()>(
  (ref) => LanDiscovery.new,
);

final localNetworkPermissionProvider = Provider<LocalNetworkPermission>(
  (ref) => const LocalNetworkPermission(),
);
