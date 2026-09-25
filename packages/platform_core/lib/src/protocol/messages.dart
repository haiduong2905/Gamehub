import '../game/game_result.dart';
import '../room/player_clock.dart';
import '../room/series_score.dart';
import '../room/room_models.dart';
import 'ids.dart';

/// Phien ban protocol. Tang len khi thay doi khong tuong thich nguoc.
/// Host va client khac phien ban se bi tu choi ngay o buoc JOIN.
const int kProtocolVersion = 3;

/// Ly do host gui lai snapshot phong, dung cho UI hien thong bao.
enum RoomUpdateReason {
  playerJoined,
  playerLeft,
  playerDisconnected,
  playerReconnected,
  readyChanged,
  statusChanged,
}

/// Mot ban tin trong protocol.
///
/// Day la `sealed class`: moi `switch` tren [Message] deu duoc compiler kiem
/// tra day du nhanh. Them mot loai ban tin moi ma quen xu ly o dau do se la
/// loi bien dich, khong phai bug luc chay.
sealed class Message {
  const Message();

  String get type;

  Map<String, dynamic> toPayload();
}

// ---------------------------------------------------------------------------
// Client -> Host
// ---------------------------------------------------------------------------

/// Xin vao phong. Ban tin dau tien client gui sau khi ket noi.
///
/// [roomSecret] chi co khi dang quay lai phong sau khi mat ket noi.
class JoinRequest extends Message {
  const JoinRequest({
    required this.playerId,
    required this.nickname,
    this.protocolVersion = kProtocolVersion,
    this.roomSecret,
  });

  final PlayerId playerId;
  final String nickname;
  final int protocolVersion;
  final String? roomSecret;

  @override
  String get type => 'JOIN_REQUEST';

  @override
  Map<String, dynamic> toPayload() => {
        'playerId': playerId,
        'nickname': nickname,
        'protocolVersion': protocolVersion,
        if (roomSecret != null) 'roomSecret': roomSecret,
      };

  static JoinRequest fromPayload(Map<String, dynamic> p) => JoinRequest(
        playerId: p['playerId'] as String,
        nickname: p['nickname'] as String,
        protocolVersion: p['protocolVersion'] as int? ?? 0,
        roomSecret: p['roomSecret'] as String?,
      );
}

/// Bao san sang / huy san sang trong phong cho.
class PlayerReady extends Message {
  const PlayerReady({required this.ready});

  final bool ready;

  @override
  String get type => 'PLAYER_READY';

  @override
  Map<String, dynamic> toPayload() => {'ready': ready};

  static PlayerReady fromPayload(Map<String, dynamic> p) =>
      PlayerReady(ready: p['ready'] as bool? ?? false);
}

/// Mot nuoc di. Day la Y DINH, khong phai ket qua.
///
/// [actionId] va [expectedStateVersion] lam cho ban tin nay idempotent:
/// bam hai lan hoac gui lai sau khi reconnect deu khong ap dung hai lan.
class GameActionMessage extends Message {
  const GameActionMessage({
    required this.actionId,
    required this.expectedStateVersion,
    required this.action,
  });

  final String actionId;
  final int expectedStateVersion;
  final Map<String, dynamic> action;

  @override
  String get type => 'GAME_ACTION';

  @override
  Map<String, dynamic> toPayload() => {
        'actionId': actionId,
        'expectedStateVersion': expectedStateVersion,
        'action': action,
      };

  static GameActionMessage fromPayload(Map<String, dynamic> p) =>
      GameActionMessage(
        actionId: p['actionId'] as String,
        expectedStateVersion: p['expectedStateVersion'] as int,
        action: (p['action'] as Map).cast<String, dynamic>(),
      );
}

/// Bat dau van dau. CHI nguoi tao phong duoc phep gui.
///
/// Cung dung de choi lai khi van truoc da ket thuc: host gui lai ban tin nay
/// thi phong reset ve van moi.
class StartGame extends Message {
  const StartGame();

  @override
  String get type => 'START_GAME';

  @override
  Map<String, dynamic> toPayload() => const {};

  static StartGame fromPayload(Map<String, dynamic> p) => const StartGame();
}

/// Chu dong roi phong. Chi gui khi nguoi dung THAT SU bam roi phong,
/// tuyet doi khong gui khi app chi tam thoi xuong nen.
class LeaveRoom extends Message {
  const LeaveRoom();

  @override
  String get type => 'LEAVE_ROOM';

  @override
  Map<String, dynamic> toPayload() => const {};

  static LeaveRoom fromPayload(Map<String, dynamic> p) => const LeaveRoom();
}

/// Do RTT de hien thi. Viec phat hien mat ket noi KHONG dua vao ban tin nay
/// ma dua vao ping/pong san co cua tang WebSocket.
class Ping extends Message {
  const Ping({required this.nonce, required this.sentAtMillis});

  final String nonce;
  final int sentAtMillis;

  @override
  String get type => 'PING';

  @override
  Map<String, dynamic> toPayload() =>
      {'nonce': nonce, 'sentAtMillis': sentAtMillis};

  static Ping fromPayload(Map<String, dynamic> p) => Ping(
        nonce: p['nonce'] as String,
        sentAtMillis: p['sentAtMillis'] as int,
      );
}

// ---------------------------------------------------------------------------
// Host -> Client
// ---------------------------------------------------------------------------

/// Da vao phong. [roomSecret] duoc client luu lai de quay vao dung cho ngoi cu
/// neu chang may mat ket noi.
class RoomJoined extends Message {
  const RoomJoined({
    required this.you,
    required this.roomSecret,
    required this.snapshot,
  });

  final PlayerId you;
  final String roomSecret;
  final RoomSnapshot snapshot;

  @override
  String get type => 'ROOM_JOINED';

  @override
  Map<String, dynamic> toPayload() => {
        'you': you,
        'roomSecret': roomSecret,
        'snapshot': snapshot.toJson(),
      };

  static RoomJoined fromPayload(Map<String, dynamic> p) => RoomJoined(
        you: p['you'] as String,
        roomSecret: p['roomSecret'] as String,
        snapshot: RoomSnapshot.fromJson(
          (p['snapshot'] as Map).cast<String, dynamic>(),
        ),
      );
}

class JoinRejected extends Message {
  const JoinRejected({required this.code, this.message});

  /// Ma on dinh: ROOM_FULL, GAME_IN_PROGRESS, PROTOCOL_MISMATCH, ROOM_CLOSED.
  final String code;
  final String? message;

  @override
  String get type => 'JOIN_REJECTED';

  @override
  Map<String, dynamic> toPayload() =>
      {'code': code, if (message != null) 'message': message};

  static JoinRejected fromPayload(Map<String, dynamic> p) => JoinRejected(
        code: p['code'] as String,
        message: p['message'] as String?,
      );
}

/// Snapshot phong moi nhat.
///
/// Thay cho ca PLAYER_JOINED lan PLAYER_LEFT: host luon gui nguyen snapshot
/// kem [reason] de UI biet vua xay ra chuyen gi. Mot duong code duy nhat ap
/// dung snapshot, nen client khong the troi trang thai so voi host.
class RoomUpdate extends Message {
  const RoomUpdate({
    required this.snapshot,
    required this.reason,
    this.actorPlayerId,
  });

  final RoomSnapshot snapshot;
  final RoomUpdateReason reason;

  /// Nguoi choi lien quan den [reason], de UI hien "X da vao phong".
  final PlayerId? actorPlayerId;

  @override
  String get type => 'ROOM_UPDATE';

  @override
  Map<String, dynamic> toPayload() => {
        'snapshot': snapshot.toJson(),
        'reason': reason.name,
        if (actorPlayerId != null) 'actorPlayerId': actorPlayerId,
      };

  static RoomUpdate fromPayload(Map<String, dynamic> p) => RoomUpdate(
        snapshot: RoomSnapshot.fromJson(
          (p['snapshot'] as Map).cast<String, dynamic>(),
        ),
        reason: RoomUpdateReason.values.firstWhere(
          (r) => r.name == p['reason'],
          orElse: () => RoomUpdateReason.statusChanged,
        ),
        actorPlayerId: p['actorPlayerId'] as String?,
      );
}

/// Van dau bat dau. [state] la phan state ma rieng nguoi nhan duoc thay.
class GameStart extends Message {
  const GameStart({
    required this.gameId,
    required this.stateVersion,
    required this.state,
    required this.currentActors,
    required this.seatOrder,
    this.playerClocks = const {},
    this.series = SeriesScore.empty,
  });

  final GameId gameId;
  final int stateVersion;
  final Map<String, dynamic> state;

  /// Nhung nguoi dang den luot. Game tu khai bao, platform khong suy ra.
  final List<PlayerId> currentActors;

  /// Thu tu di, da chot luc bat dau van.
  final List<PlayerId> seatOrder;

  /// Dong ho cua TUNG nguoi choi. Rong = van nay khong tinh gio.
  ///
  /// Mang SO MILI GIAY CON LAI tinh tu luc host gui, khong phai moc thoi
  /// gian: gui moc tuyet doi thi nguoi nhan buoc phai tru theo dong ho cua
  /// may minh, ma hai dien thoai lech gio bao nhieu thi so dem nguoc lech bay
  /// nhieu, va khong co cach nao biet ai dung. Gui khoang thoi gian thi moi
  /// may tu neo vao dong ho cua chinh no.
  ///
  /// Va la SO CON LAI chu khong phai gioi han da thiet lap: host gui lai
  /// GAME_STATE ngay giua luot (nuoc di bi tu choi, gui trung, vao lai phong),
  /// va luc do luot da troi di mot phan roi.
  final Map<PlayerId, PlayerClock> playerClocks;

  /// Ti so thang - thua cua ca loat van trong phong nay.
  final SeriesScore series;

  @override
  String get type => 'GAME_START';

  @override
  Map<String, dynamic> toPayload() => {
        'gameId': gameId,
        'stateVersion': stateVersion,
        'state': state,
        'currentActors': currentActors,
        'seatOrder': seatOrder,
        if (playerClocks.isNotEmpty) 'playerClocks': encodeClocks(playerClocks),
        if (!series.isEmpty) 'series': series.toJson(),
      };

  static GameStart fromPayload(Map<String, dynamic> p) => GameStart(
        gameId: p['gameId'] as String,
        stateVersion: p['stateVersion'] as int,
        state: (p['state'] as Map).cast<String, dynamic>(),
        currentActors: (p['currentActors'] as List<dynamic>)
            .map((dynamic e) => e as String)
            .toList(growable: false),
        seatOrder: (p['seatOrder'] as List<dynamic>)
            .map((dynamic e) => e as String)
            .toList(growable: false),
        playerClocks: decodeClocks(p['playerClocks']),
        series: SeriesScore.fromJson(p['series']),
      );
}

/// State moi sau mot nuoc di. Host la nguon su that duy nhat.
class GameStateMessage extends Message {
  const GameStateMessage({
    required this.stateVersion,
    required this.state,
    required this.currentActors,
    this.lastActionId,
    this.playerClocks = const {},
    this.series = SeriesScore.empty,
  });

  final int stateVersion;
  final Map<String, dynamic> state;
  final List<PlayerId> currentActors;

  /// Nuoc di vua duoc ap dung, de client bo trang thai "dang cho".
  final String? lastActionId;

  /// Dong ho tung nguoi. Xem [GameStart.playerClocks].
  final Map<PlayerId, PlayerClock> playerClocks;

  /// Ti so thang - thua cua ca loat van trong phong nay.
  final SeriesScore series;

  @override
  String get type => 'GAME_STATE';

  @override
  Map<String, dynamic> toPayload() => {
        'stateVersion': stateVersion,
        'state': state,
        'currentActors': currentActors,
        if (lastActionId != null) 'lastActionId': lastActionId,
        if (playerClocks.isNotEmpty) 'playerClocks': encodeClocks(playerClocks),
        if (!series.isEmpty) 'series': series.toJson(),
      };

  static GameStateMessage fromPayload(Map<String, dynamic> p) =>
      GameStateMessage(
        stateVersion: p['stateVersion'] as int,
        state: (p['state'] as Map).cast<String, dynamic>(),
        currentActors: (p['currentActors'] as List<dynamic>)
            .map((dynamic e) => e as String)
            .toList(growable: false),
        lastActionId: p['lastActionId'] as String?,
        playerClocks: decodeClocks(p['playerClocks']),
        series: SeriesScore.fromJson(p['series']),
      );
}

/// Ket qua van dau. Chi host duoc phep gui ban tin nay.
class GameResultMessage extends Message {
  const GameResultMessage({
    required this.stateVersion,
    required this.state,
    required this.result,
    this.playerClocks = const {},
    this.series = SeriesScore.empty,
  });

  final int stateVersion;
  final Map<String, dynamic> state;
  final GameResult result;

  /// Dong ho tung nguoi. Xem [GameStart.playerClocks].
  final Map<PlayerId, PlayerClock> playerClocks;

  /// Ti so thang - thua cua ca loat van trong phong nay.
  final SeriesScore series;

  @override
  String get type => 'GAME_RESULT';

  @override
  Map<String, dynamic> toPayload() => {
        'stateVersion': stateVersion,
        'state': state,
        'result': result.toJson(),
        if (playerClocks.isNotEmpty) 'playerClocks': encodeClocks(playerClocks),
        if (!series.isEmpty) 'series': series.toJson(),
      };

  static GameResultMessage fromPayload(Map<String, dynamic> p) =>
      GameResultMessage(
        stateVersion: p['stateVersion'] as int,
        state: (p['state'] as Map).cast<String, dynamic>(),
        result:
            GameResult.fromJson((p['result'] as Map).cast<String, dynamic>()),
        playerClocks: decodeClocks(p['playerClocks']),
        series: SeriesScore.fromJson(p['series']),
      );
}

class RoomClosed extends Message {
  const RoomClosed({required this.code, this.message});

  /// HOST_LEFT, GAME_FINISHED, HOST_CLOSED.
  final String code;
  final String? message;

  @override
  String get type => 'ROOM_CLOSED';

  @override
  Map<String, dynamic> toPayload() =>
      {'code': code, if (message != null) 'message': message};

  static RoomClosed fromPayload(Map<String, dynamic> p) => RoomClosed(
        code: p['code'] as String,
        message: p['message'] as String?,
      );
}

/// Loi khong lam dong ket noi, vi du nuoc di khong hop le.
class ErrorMessage extends Message {
  const ErrorMessage({required this.code, this.message, this.actionId});

  final String code;
  final String? message;

  /// Neu loi nay tu choi mot nuoc di cu the thi day la actionId cua no.
  final String? actionId;

  @override
  String get type => 'ERROR';

  @override
  Map<String, dynamic> toPayload() => {
        'code': code,
        if (message != null) 'message': message,
        if (actionId != null) 'actionId': actionId,
      };

  static ErrorMessage fromPayload(Map<String, dynamic> p) => ErrorMessage(
        code: p['code'] as String,
        message: p['message'] as String?,
        actionId: p['actionId'] as String?,
      );
}

class Pong extends Message {
  const Pong({required this.nonce, required this.sentAtMillis});

  final String nonce;
  final int sentAtMillis;

  @override
  String get type => 'PONG';

  @override
  Map<String, dynamic> toPayload() =>
      {'nonce': nonce, 'sentAtMillis': sentAtMillis};

  static Pong fromPayload(Map<String, dynamic> p) => Pong(
        nonce: p['nonce'] as String,
        sentAtMillis: p['sentAtMillis'] as int,
      );
}

/// Ban tin khong hieu duoc: type la, hoac protocol version khac.
///
/// Decoder tra ve gia tri nay thay vi nem loi, de mot ban cu khong chet khi
/// gap ban tin cua ban moi hon. Ben nhan chi viec bo qua.
class UnknownMessage extends Message {
  const UnknownMessage({
    required this.rawType,
    required this.payload,
    this.protocolVersion,
  });

  final String rawType;
  final Map<String, dynamic> payload;
  final int? protocolVersion;

  @override
  String get type => rawType;

  @override
  Map<String, dynamic> toPayload() => payload;
}

/// Dong ho tung nguoi, dang gui di duoc.
Map<String, dynamic> encodeClocks(Map<PlayerId, PlayerClock> clocks) => {
      for (final entry in clocks.entries) entry.key: entry.value.toJson(),
    };

/// Doc dong ho tu ban tin, dong dau bang gio CUA MAY DANG GIAI MA.
///
/// Dong dau o day chu khong phai o cho goi la co chu dich: moi ban tin chi
/// giai ma dung mot lan, ngay khi vua toi, nen day la thoi diem sat nhat voi
/// luc host gui ma may nay biet duoc.
Map<PlayerId, PlayerClock> decodeClocks(Object? raw) {
  if (raw is! Map) return const {};
  final now = DateTime.now().millisecondsSinceEpoch;
  return {
    for (final entry in raw.entries)
      entry.key as PlayerId: PlayerClock.fromJson(
        (entry.value as Map).cast<String, dynamic>(),
        asOfMillis: now,
      ),
  };
}
