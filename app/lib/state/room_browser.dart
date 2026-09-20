import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_core/platform_core.dart';

import '../transport/lan/lan_discovery.dart';
import '../transport/lan/local_network_permission.dart';

/// Nhung gi man hinh tim phong can biet.
class BrowserState {
  const BrowserState({
    this.rooms = const [],
    this.scanning = false,
    this.permission = LocalNetworkAccess.granted,
  });

  final List<DiscoveredRoom> rooms;
  final bool scanning;
  final LocalNetworkAccess permission;

  bool get blockedByPermission => permission != LocalNetworkAccess.granted;
}

/// Quet tim phong cua mot game tren mang noi bo.
///
/// `autoDispose` de viec quet dung ngay khi roi man hinh - quang ba va lang
/// nghe mDNS chay nen la mot cach ro pin rat de bo quen.
class RoomBrowser extends AutoDisposeFamilyAsyncNotifier<BrowserState, GameId> {
  LanDiscovery? _discovery;
  StreamSubscription<List<DiscoveredRoom>>? _sub;

  @override
  Future<BrowserState> build(GameId gameId) async {
    ref.onDispose(() {
      unawaited(_sub?.cancel());
      unawaited(_discovery?.dispose());
    });

    if (kIsWeb) {
      return const BrowserState(scanning: false);
    }

    const permission = LocalNetworkPermission();
    final access = await permission.request();
    if (access != LocalNetworkAccess.granted) {
      return BrowserState(permission: access);
    }

    final discovery = LanDiscovery();
    _discovery = discovery;

    _sub = discovery.rooms.listen((rooms) {
      state = AsyncData(BrowserState(rooms: rooms, scanning: true));
    });

    await discovery.startDiscovery(gameId: gameId);
    return const BrowserState(scanning: true);
  }

  /// Quet lai tu dau. Dung khi nguoi dung keo de lam moi, hoac sau khi vua
  /// cap quyen trong Cai dat.
  ///
  /// Dung invalidateSelf chu khong goi thang build(): goi tay se dang ky them
  /// mot ref.onDispose moi sau moi lan lam moi, va bo qua vong doi ma Riverpod
  /// quan ly.
  void refresh() => ref.invalidateSelf();
}

final roomBrowserProvider = AsyncNotifierProvider.autoDispose
    .family<RoomBrowser, BrowserState, GameId>(RoomBrowser.new);
