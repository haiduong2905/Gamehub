import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Danh tinh cua nguoi choi tren may nay.
class Identity {
  const Identity({required this.playerId, required this.nickname});

  /// On dinh theo thiet bi. Day la thu cho phep quay lai dung cho ngoi cu sau
  /// khi mat ket noi, nen tuyet doi khong sinh moi moi lan mo app.
  final String playerId;

  final String nickname;

  Identity copyWith({String? nickname}) =>
      Identity(playerId: playerId, nickname: nickname ?? this.nickname);
}

const _kPlayerIdKey = 'player_id';
const _kNicknameKey = 'nickname';

class IdentityController extends AsyncNotifier<Identity> {
  @override
  Future<Identity> build() async {
    final prefs = await SharedPreferences.getInstance();

    var playerId = prefs.getString(_kPlayerIdKey);
    if (playerId == null || playerId.isEmpty) {
      playerId = _newPlayerId();
      await prefs.setString(_kPlayerIdKey, playerId);
    }

    return Identity(
      playerId: playerId,
      nickname: prefs.getString(_kNicknameKey) ?? _defaultNickname(playerId),
    );
  }

  Future<void> setNickname(String nickname) async {
    final trimmed = nickname.trim();
    if (trimmed.isEmpty) return;

    final current = state.valueOrNull;
    if (current == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNicknameKey, trimmed);
    state = AsyncData(current.copyWith(nickname: trimmed));
  }

  static String _newPlayerId() {
    final random = Random.secure();
    final bytes = List<int>.generate(8, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _defaultNickname(String playerId) =>
      'Nguoi choi ${playerId.substring(0, 4).toUpperCase()}';
}

final identityProvider =
    AsyncNotifierProvider<IdentityController, Identity>(IdentityController.new);
