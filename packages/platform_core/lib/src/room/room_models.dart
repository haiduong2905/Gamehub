import '../protocol/ids.dart';

/// Vong doi cua mot phong, theo dung dinh nghia trong GAME_PLATFORM_WORKFLOW.md.
enum RoomStatus {
  waiting,
  ready,
  playing,
  finished,
  closed,
}

/// Trang thai ket noi cua mot nguoi choi trong phong.
enum PlayerConnectionState {
  connected,

  /// Mat ket noi nhung van con trong thoi gian cho quay lai.
  disconnected,
}

/// Mot cho ngoi trong phong.
class PlayerSlot {
  const PlayerSlot({
    required this.playerId,
    required this.nickname,
    required this.seat,
    required this.isHost,
    this.isReady = false,
    this.connection = PlayerConnectionState.connected,
  });

  final PlayerId playerId;
  final String nickname;

  /// Vi tri cho ngoi, quyet dinh thu tu di. Bat dau tu 0.
  final int seat;
  final bool isHost;
  final bool isReady;
  final PlayerConnectionState connection;

  bool get isConnected => connection == PlayerConnectionState.connected;

  PlayerSlot copyWith({
    String? nickname,
    int? seat,
    bool? isReady,
    PlayerConnectionState? connection,
  }) =>
      PlayerSlot(
        playerId: playerId,
        nickname: nickname ?? this.nickname,
        seat: seat ?? this.seat,
        isHost: isHost,
        isReady: isReady ?? this.isReady,
        connection: connection ?? this.connection,
      );

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'nickname': nickname,
        'seat': seat,
        'isHost': isHost,
        'isReady': isReady,
        'connection': connection.name,
      };

  static PlayerSlot fromJson(Map<String, dynamic> json) => PlayerSlot(
        playerId: json['playerId'] as String,
        nickname: json['nickname'] as String,
        seat: json['seat'] as int,
        isHost: json['isHost'] as bool? ?? false,
        isReady: json['isReady'] as bool? ?? false,
        connection: PlayerConnectionState.values.firstWhere(
          (s) => s.name == json['connection'],
          orElse: () => PlayerConnectionState.connected,
        ),
      );

  @override
  String toString() => 'PlayerSlot($nickname, seat $seat, $connection)';
}

/// Anh chup toan bo trang thai phong tai mot thoi diem.
///
/// Host broadcast nguyen ca snapshot moi khi co thay doi, thay vi gui tung
/// su kien nho le. Turn-based nen chi phi khong dang ke, doi lai client
/// khong the troi trang thai so voi host.
class RoomSnapshot {
  const RoomSnapshot({
    required this.roomId,
    required this.gameId,
    required this.displayName,
    required this.status,
    required this.players,
    required this.maxPlayers,
    this.hostPlayerId = '',
  });

  final RoomId roomId;
  final GameId gameId;
  final String displayName;
  final RoomStatus status;
  final List<PlayerSlot> players;
  final int maxPlayers;
  final PlayerId hostPlayerId;

  int get playerCount => players.length;
  bool get isFull => players.length >= maxPlayers;

  PlayerSlot? slotOf(PlayerId id) {
    for (final slot in players) {
      if (slot.playerId == id) return slot;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'roomId': roomId,
        'gameId': gameId,
        'displayName': displayName,
        'status': status.name,
        'maxPlayers': maxPlayers,
        'hostPlayerId': hostPlayerId,
        'players': players.map((p) => p.toJson()).toList(),
      };

  static RoomSnapshot fromJson(Map<String, dynamic> json) => RoomSnapshot(
        roomId: json['roomId'] as String,
        gameId: json['gameId'] as String,
        displayName: json['displayName'] as String,
        status: RoomStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => RoomStatus.closed,
        ),
        maxPlayers: json['maxPlayers'] as int,
        hostPlayerId: json['hostPlayerId'] as String? ?? '',
        players: (json['players'] as List<dynamic>)
            .map((dynamic e) => PlayerSlot.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );

  @override
  String toString() =>
      'RoomSnapshot($roomId, $gameId, $status, ${players.length}/$maxPlayers)';
}
