import 'package:game_hub/state/identity.dart';
import 'package:game_hub/transport/lan/local_network_permission.dart';

/// Danh tinh co dinh cho test, khong cham vao SharedPreferences that.
class FakeIdentity extends IdentityController {
  FakeIdentity({required this.playerId, required this.nickname});

  final String playerId;
  final String nickname;

  @override
  Future<Identity> build() async =>
      Identity(playerId: playerId, nickname: nickname);
}

class AlwaysGrantedPermission implements LocalNetworkPermission {
  const AlwaysGrantedPermission();

  @override
  Future<LocalNetworkAccess> request() async => LocalNetworkAccess.granted;

  @override
  Future<LocalNetworkAccess> check() async => LocalNetworkAccess.granted;

  @override
  Future<bool> openSettings() async => true;
}

class DeniedPermission implements LocalNetworkPermission {
  const DeniedPermission();

  @override
  Future<LocalNetworkAccess> request() async => LocalNetworkAccess.denied;

  @override
  Future<LocalNetworkAccess> check() async => LocalNetworkAccess.denied;

  @override
  Future<bool> openSettings() async => true;
}
