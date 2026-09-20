import 'dart:async';
import 'dart:math';

import '../game/game_result.dart';
import '../protocol/ids.dart';
import '../protocol/message_codec.dart';
import '../protocol/messages.dart';
import '../transport/transport.dart';
import 'room_models.dart';

/// Giai doan cua client trong mot phong.
enum ClientPhase {
  /// Da co duong truyen, dang xin vao phong.
  joining,

  /// Bi tu choi vao phong.
  rejected,

  /// Dang o trong phong cho.
  inRoom,

  /// Dang choi.
  playing,

  /// Van dau da xong, van con trong phong.
  finished,

  /// Phong da dong hoac mat ket noi.
  closed,
}

/// Toan bo nhung gi client biet. Tat ca deu do host gui xuong.
class RoomClientState {
  const RoomClientState({
    required this.phase,
    required this.me,
    this.room,
    this.gameState,
    this.stateVersion = 0,
    this.currentActors = const [],
    this.seatOrder = const [],
    this.result,
    this.pendingActionId,
    this.gameDeadlineMillis,
    this.turnDeadlineMillis,
    this.errorCode,
    this.errorMessage,
    this.closeCode,
  });

  final ClientPhase phase;
  final PlayerId me;
  final RoomSnapshot? room;

  /// State cua game, da la phan ma rieng nguoi nay duoc thay.
  final Map<String, dynamic>? gameState;
  final int stateVersion;
  final List<PlayerId> currentActors;
  final List<PlayerId> seatOrder;
  final GameResult? result;

  /// Nuoc di dang cho host xac nhan. UI dung de ve o mo + spinner.
  ///
  /// Day KHONG phai du doan lac quan: client khong he tu ve ket qua nuoc di,
  /// no chi bao cho nguoi dung biet cham vua duoc ghi nhan.
  final String? pendingActionId;
  final int? gameDeadlineMillis;
  final int? turnDeadlineMillis;

  final String? errorCode;
  final String? errorMessage;

  /// Ly do phong dong: HOST_LEFT, HOST_CLOSED, CONNECTION_LOST...
  final String? closeCode;

  bool get isMyTurn => currentActors.contains(me);

  bool get hasPendingAction => pendingActionId != null;

  PlayerSlot? get mySlot => room?.slotOf(me);

  bool get amHost => room?.hostPlayerId == me;

  RoomClientState copyWith({
    ClientPhase? phase,
    RoomSnapshot? room,
    Map<String, dynamic>? gameState,
    int? stateVersion,
    List<PlayerId>? currentActors,
    List<PlayerId>? seatOrder,
    GameResult? result,
    String? pendingActionId,
    int? gameDeadlineMillis,
    int? turnDeadlineMillis,
    String? errorCode,
    String? errorMessage,
    String? closeCode,
    bool clearPendingAction = false,
    bool clearError = false,
    bool clearResult = false,
  }) =>
      RoomClientState(
        phase: phase ?? this.phase,
        me: me,
        room: room ?? this.room,
        gameState: gameState ?? this.gameState,
        stateVersion: stateVersion ?? this.stateVersion,
        currentActors: currentActors ?? this.currentActors,
        seatOrder: seatOrder ?? this.seatOrder,
        result: clearResult ? null : (result ?? this.result),
        pendingActionId:
            clearPendingAction ? null : (pendingActionId ?? this.pendingActionId),
        gameDeadlineMillis: gameDeadlineMillis ?? this.gameDeadlineMillis,
        turnDeadlineMillis: turnDeadlineMillis ?? this.turnDeadlineMillis,
        errorCode: clearError ? null : (errorCode ?? this.errorCode),
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        closeCode: closeCode ?? this.closeCode,
      );
}

/// Phia client cua mot phong.
///
/// Ca nguoi tao phong lan nguoi vao phong deu dung lop nay - host chi khac o
/// cho no dong thoi chay them mot [RoomHost] ben canh. Nho vay UI chi co mot
/// duong code duy nhat, va bug khong the chi xuat hien o mot phia.
class RoomClient {
  RoomClient({
    required PeerLink link,
    required this.playerId,
    required this.nickname,
    String? roomSecret,
    Random? random,
  })  : _link = link,
        _roomSecret = roomSecret,
        _random = random ?? Random(),
        _state = RoomClientState(phase: ClientPhase.joining, me: playerId) {
    _subscription = _link.incoming.listen(_onRaw, onError: (Object _) {});
    unawaited(_link.done.then((_) => _onLinkClosed()));
  }

  final PeerLink _link;
  final PlayerId playerId;
  final String nickname;
  final Random _random;

  String? _roomSecret;
  late final StreamSubscription<String> _subscription;
  int _actionCounter = 0;

  RoomClientState _state;

  final StreamController<RoomClientState> _states =
      StreamController<RoomClientState>.broadcast();

  /// Bi mat de quay lai dung cho ngoi cu sau khi mat ket noi.
  /// App nen luu lai cung voi roomId.
  String? get roomSecret => _roomSecret;

  RoomClientState get state => _state;

  Stream<RoomClientState> get states => _states.stream;

  /// Gui yeu cau vao phong. Phai goi ngay sau khi tao.
  void join() {
    _send(
      JoinRequest(
        playerId: playerId,
        nickname: nickname,
        roomSecret: _roomSecret,
      ),
    );
  }

  void setReady({required bool ready}) => _send(PlayerReady(ready: ready));

  /// Chi co tac dung khi minh la host.
  void startGame() => _send(const StartGame());

  void leave() {
    _send(const LeaveRoom());
    unawaited(dispose());
  }

  /// Gui mot nuoc di. Tra ve actionId de UI theo doi trang thai cho.
  ///
  /// Khong tu ap dung nuoc di vao [state]: client khong bao gio tu quyet dinh.
  /// State chi doi khi host gui GAME_STATE ve.
  String sendAction(Map<String, dynamic> action) {
    final actionId = '$playerId-${_actionCounter++}-${_random.nextInt(1 << 20)}';
    _emit(_state.copyWith(pendingActionId: actionId, clearError: true));
    _send(
      GameActionMessage(
        actionId: actionId,
        expectedStateVersion: _state.stateVersion,
        action: action,
      ),
    );
    return actionId;
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _link.close();
    if (!_states.isClosed) await _states.close();
  }

  // -------------------------------------------------------------------------

  void _onRaw(String raw) {
    final Message message;
    try {
      message = MessageCodec.decode(raw);
    } on FormatException {
      return;
    }

    switch (message) {
      case RoomJoined():
        _roomSecret = message.roomSecret;
        _emit(
          _state.copyWith(
            phase: _phaseFor(message.snapshot.status),
            room: message.snapshot,
            clearError: true,
          ),
        );

      case JoinRejected():
        _emit(
          _state.copyWith(
            phase: ClientPhase.rejected,
            errorCode: message.code,
            errorMessage: message.message,
          ),
        );

      case RoomUpdate():
        _emit(
          _state.copyWith(
            phase: _phaseFor(message.snapshot.status),
            room: message.snapshot,
          ),
        );

      case GameStart():
        _emit(
          _state.copyWith(
            phase: ClientPhase.playing,
            gameState: message.state,
            stateVersion: message.stateVersion,
            currentActors: message.currentActors,
            seatOrder: message.seatOrder,
            gameDeadlineMillis: message.gameDeadlineMillis,
            turnDeadlineMillis: message.turnDeadlineMillis,
            clearPendingAction: true,
            clearError: true,
            clearResult: true,
          ),
        );

      case GameStateMessage():
        // Bo trang thai "dang cho" khi nuoc di cua chinh minh da duoc ghi nhan.
        final clearPending = message.lastActionId != null &&
            message.lastActionId == _state.pendingActionId;
        _emit(
          _state.copyWith(
            gameState: message.state,
            stateVersion: message.stateVersion,
            currentActors: message.currentActors,
            gameDeadlineMillis: message.gameDeadlineMillis,
            turnDeadlineMillis: message.turnDeadlineMillis,
            clearPendingAction: clearPending,
          ),
        );

      case GameResultMessage():
        _emit(
          _state.copyWith(
            phase: ClientPhase.finished,
            gameState: message.state,
            stateVersion: message.stateVersion,
            currentActors: const [],
            gameDeadlineMillis: message.gameDeadlineMillis,
            turnDeadlineMillis: message.turnDeadlineMillis,
            result: message.result,
            clearPendingAction: true,
          ),
        );

      case ErrorMessage():
        final clearPending = message.actionId != null &&
            message.actionId == _state.pendingActionId;
        _emit(
          _state.copyWith(
            errorCode: message.code,
            errorMessage: message.message,
            clearPendingAction: clearPending,
          ),
        );

      case RoomClosed():
        _emit(
          _state.copyWith(
            phase: ClientPhase.closed,
            closeCode: message.code,
            errorMessage: message.message,
            clearPendingAction: true,
          ),
        );

      case Pong():
        break;

      // Nhung ban tin sau chi di theo chieu client -> host. Nhan duoc o day
      // la sai protocol.
      case JoinRequest():
      case PlayerReady():
      case StartGame():
      case GameActionMessage():
      case LeaveRoom():
      case Ping():
      case UnknownMessage():
        break;
    }
  }

  ClientPhase _phaseFor(RoomStatus status) {
    // Phong dang choi hoac vua xong mot van, nhung minh chua he nhan state game
    // nao: minh khong o trong van do (vua vao phong sau khi van ket thuc).
    // Dua vao man van dau luc nay se ve mot ban co rong va lam do renderer.
    final khongCoVan = _state.gameState == null;

    return switch (status) {
      RoomStatus.waiting => ClientPhase.inRoom,
      RoomStatus.ready => ClientPhase.inRoom,
      RoomStatus.playing =>
        khongCoVan ? ClientPhase.inRoom : ClientPhase.playing,
      RoomStatus.finished =>
        khongCoVan ? ClientPhase.inRoom : ClientPhase.finished,
      RoomStatus.closed => ClientPhase.closed,
    };
  }

  void _onLinkClosed() {
    if (_state.phase == ClientPhase.closed) return;
    // Bi tu choi vao phong thi host dong link ngay sau do. Giu nguyen ly do
    // tu choi - noi "phong day" huu ich hon nhieu so voi "mat ket noi".
    if (_state.phase == ClientPhase.rejected) return;
    _emit(
      _state.copyWith(
        phase: ClientPhase.closed,
        closeCode: _state.closeCode ?? 'CONNECTION_LOST',
      ),
    );
  }

  void _send(Message message) {
    if (_link.isClosed) return;
    _link.send(MessageCodec.encode(message));
  }

  void _emit(RoomClientState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }
}
