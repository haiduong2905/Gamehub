import 'dart:async';
import 'dart:math';

import '../game/game_registry.dart';
import '../protocol/ids.dart';
import '../protocol/message_codec.dart';
import '../protocol/messages.dart';
import '../session/game_session.dart';
import '../transport/local_link.dart';
import '../transport/transport.dart';
import 'player_clock.dart';
import 'room_models.dart';
import 'room_settings.dart';
import 'series_score.dart';

/// Phia host cua mot phong: trong tai duy nhat.
///
/// Moi quyet dinh - ai duoc vao, den luot ai, nuoc di co hop le khong, ai
/// thang - deu xay ra o day. Client khong bao gio tu ket luan.
///
/// Lop nay KHONG biet luat cua bat ky game nao. No tra cuu [GameRegistry]
/// bang [GameId] va goi qua [GameAdapter]. Them game moi khong phai sua file
/// nay - do la phep thu kien truc quan trong nhat cua ca du an.
class RoomHost {
  RoomHost({
    required GameRegistry registry,
    required HostTransport transport,
    required DiscoveryService discovery,
    required this.roomId,
    required this.gameId,
    required this.displayName,
    required this.hostPlayerId,
    this.settings = const RoomSettings(),
    int? maxPlayers,
    this.rejoinGrace = const Duration(seconds: 30),
    Random? random,
  })  : _registry = registry,
        _transport = transport,
        _discovery = discovery,
        _random = random ?? Random.secure(),
        maxPlayers = _clampMaxPlayers(registry, gameId, maxPlayers);

  static int _clampMaxPlayers(
    GameRegistry registry,
    GameId gameId,
    int? requested,
  ) {
    final adapter = registry.require(gameId);
    if (requested == null) return adapter.maxPlayers;
    return requested.clamp(adapter.minPlayers, adapter.maxPlayers);
  }

  final GameRegistry _registry;
  final HostTransport _transport;
  final DiscoveryService _discovery;
  final Random _random;

  final RoomId roomId;
  final GameId gameId;
  final String displayName;
  final PlayerId hostPlayerId;
  final int maxPlayers;
  final RoomSettings settings;

  /// Thoi gian giu cho cho nguoi choi mat ket noi quay lai.
  final Duration rejoinGrace;

  final List<PlayerSlot> _slots = <PlayerSlot>[];
  final Map<PlayerId, PeerLink> _links = <PlayerId, PeerLink>{};
  final Map<PlayerId, String> _secrets = <PlayerId, String>{};
  final Map<PlayerId, Timer> _graceTimers = <PlayerId, Timer>{};
  final Set<PeerLink> _unjoinedLinks = <PeerLink>{};
  final List<StreamSubscription<void>> _subscriptions =
      <StreamSubscription<void>>[];

  RoomStatus _status = RoomStatus.waiting;
  GameSession? _session;
  Timer? _clockTimer;

  /// Ngan sach ca van cua tung nguoi, va thoi gian con lai cho nuoc di dang
  /// cho. Vang mat trong map = nguoi do khong bi gioi han dong ho do.
  final Map<PlayerId, int> _matchRemaining = <PlayerId, int>{};
  final Map<PlayerId, int> _moveRemaining = <PlayerId, int>{};

  /// Luot hien tai bat dau luc nao, de biet nguoi dang di da tieu bao nhieu.
  int _turnStartedAtMillis = 0;

  /// Ti so thang - thua tinh tu luc mo phong, cong don qua cac van.
  ///
  /// Song theo phong chu khong theo van: bam "Choi lai" la sang van moi nhung
  /// van cung mot loat dau. Ghi theo `playerId` nen ai mat ket noi roi vao
  /// lai van giu nguyen diem cua minh.
  SeriesScore _series = SeriesScore.empty;
  int? _port;
  bool _closed = false;

  final StreamController<RoomSnapshot> _snapshots =
      StreamController<RoomSnapshot>.broadcast();

  /// Snapshot phat ra moi khi phong thay doi. Chu yeu de log va debug;
  /// UI cua host van di qua [RoomClient] nhu moi nguoi khac.
  Stream<RoomSnapshot> get snapshots => _snapshots.stream;

  RoomStatus get status => _status;

  int get port => _port ?? (throw StateError('Phong chua mo'));

  GameSession? get session => _session;

  /// Mo phong: lang nghe ket noi va bat dau quang ba.
  ///
  /// Tra ve dau ong danh cho NGUOI CHOI LA HOST. Host phai noi chuyen qua
  /// dung protocol nhu moi client khac - neu goi thang vao logic ben trong,
  /// duong code cua host va cua client se khac nhau va bug se chi lo ra o
  /// mot phia.
  Future<PeerLink> open() async {
    final port = await _transport.start();
    _port = port;

    _subscriptions.add(_transport.connections.listen(_onConnection));

    await _discovery.advertise(
      RoomAdvertisement(
        roomId: roomId,
        gameId: gameId,
        displayName: displayName,
        protocolVersion: kProtocolVersion,
      ),
      port: port,
    );

    final pair = LocalLinkPair.create(linkId: 'host-local-$roomId');
    _onConnection(pair.a);
    return pair.b;
  }

  Future<void> close({String code = 'HOST_CLOSED', String? message}) async {
    if (_closed) return;
    _closed = true;
    _status = RoomStatus.closed;

    _broadcast((_) => RoomClosed(code: code, message: message));

    for (final timer in _graceTimers.values) {
      timer.cancel();
    }
    _graceTimers.clear();
    _clockTimer?.cancel();

    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    await _discovery.stopAdvertising();
    await _transport.stop();

    // Cho ban tin ROOM_CLOSED kip di truoc khi cat ket noi.
    await Future<void>.delayed(Duration.zero);
    for (final link in _links.values) {
      await link.close('room closed');
    }
    for (final link in _unjoinedLinks) {
      await link.close('room closed');
    }
    _links.clear();
    _unjoinedLinks.clear();

    if (!_snapshots.isClosed) await _snapshots.close();
  }

  // -------------------------------------------------------------------------
  // Ket noi
  // -------------------------------------------------------------------------

  void _onConnection(PeerLink link) {
    if (_closed) {
      unawaited(link.close('room closed'));
      return;
    }
    _unjoinedLinks.add(link);

    _subscriptions.add(
      link.incoming.listen(
        (raw) => _onRawMessage(link, raw),
        onError: (Object _) {},
      ),
    );

    unawaited(link.done.then((_) => _onLinkClosed(link)));
  }

  void _onRawMessage(PeerLink link, String raw) {
    if (_closed) return;
    final Message message;
    try {
      message = MessageCodec.decode(raw);
    } on FormatException {
      _sendTo(link, const ErrorMessage(code: 'MALFORMED_MESSAGE'));
      return;
    }

    final playerId = _playerIdOf(link);

    // Chua vao phong thi chi duoc phep xin vao.
    if (playerId == null) {
      if (message is JoinRequest) {
        _handleJoin(link, message);
      } else if (message is! UnknownMessage) {
        _sendTo(link, const ErrorMessage(code: 'NOT_JOINED'));
      }
      return;
    }

    switch (message) {
      case PlayerReady():
        _handleReady(playerId, message);
      case StartGame():
        _handleStartGame(playerId);
      case GameActionMessage():
        _handleGameAction(playerId, message);
      case LeaveRoom():
        _removePlayer(playerId, RoomUpdateReason.playerLeft);
      case Ping():
        _sendTo(
          link,
          Pong(nonce: message.nonce, sentAtMillis: message.sentAtMillis),
        );
      case JoinRequest():
        _sendTo(link, const ErrorMessage(code: 'ALREADY_JOINED'));
      // Nhung ban tin sau chi di theo chieu host -> client. Client gui len la
      // sai protocol, bo qua.
      case RoomJoined():
      case JoinRejected():
      case RoomUpdate():
      case GameStart():
      case GameStateMessage():
      case GameResultMessage():
      case RoomClosed():
      case ErrorMessage():
      case Pong():
        _sendTo(link, const ErrorMessage(code: 'UNEXPECTED_MESSAGE'));
      case UnknownMessage():
        break; // Ban tin cua phien ban khac: lang le bo qua.
    }
  }

  void _handleJoin(PeerLink link, JoinRequest request) {
    if (request.protocolVersion != kProtocolVersion) {
      _sendTo(
        link,
        JoinRejected(
          code: 'PROTOCOL_MISMATCH',
          message: 'Hai may dang chay hai phien ban khac nhau',
        ),
      );
      unawaited(link.close('protocol mismatch'));
      return;
    }

    final existing = _slotOf(request.playerId);
    if (existing != null) {
      final expected = _secrets[request.playerId];
      if (expected == null || request.roomSecret != expected) {
        _sendTo(
          link,
          const JoinRejected(
            code: 'ID_TAKEN',
            message: 'Da co nguoi khac dung dinh danh nay trong phong',
          ),
        );
        unawaited(link.close('id taken'));
        return;
      }
      _rebindPlayer(link, request.playerId);
      return;
    }

    if (_status == RoomStatus.closed) {
      _sendTo(link, const JoinRejected(code: 'ROOM_CLOSED'));
      unawaited(link.close('room closed'));
      return;
    }
    if (_status == RoomStatus.playing) {
      _sendTo(
        link,
        const JoinRejected(
          code: 'GAME_IN_PROGRESS',
          message: 'Van dau da bat dau',
        ),
      );
      unawaited(link.close('game in progress'));
      return;
    }
    if (_slots.length >= maxPlayers) {
      _sendTo(link, const JoinRejected(code: 'ROOM_FULL'));
      unawaited(link.close('room full'));
      return;
    }

    final secret = _newSecret();
    final slot = PlayerSlot(
      playerId: request.playerId,
      nickname: request.nickname,
      seat: _slots.length,
      isHost: request.playerId == hostPlayerId,
    );
    _slots.add(slot);
    _secrets[request.playerId] = secret;
    _links[request.playerId] = link;
    _unjoinedLinks.remove(link);

    _recomputeStatus();
    _sendTo(
      link,
      RoomJoined(you: request.playerId, roomSecret: secret, snapshot: snapshot),
    );
    _broadcast(
      (_) => RoomUpdate(
        snapshot: snapshot,
        reason: RoomUpdateReason.playerJoined,
        actorPlayerId: request.playerId,
      ),
      except: request.playerId,
    );
    _emitSnapshot();
  }

  /// Nguoi choi cu quay lai sau khi mat ket noi.
  void _rebindPlayer(PeerLink link, PlayerId playerId) {
    _graceTimers.remove(playerId)?.cancel();

    final old = _links[playerId];
    if (old != null && old != link) {
      unawaited(old.close('replaced by rejoin'));
    }
    _links[playerId] = link;
    _unjoinedLinks.remove(link);
    _updateSlot(
      playerId,
      (s) => s.copyWith(connection: PlayerConnectionState.connected),
    );

    _sendTo(
      link,
      RoomJoined(
        you: playerId,
        roomSecret: _secrets[playerId]!,
        snapshot: snapshot,
      ),
    );

    // Dang giua van thi phai dung lai toan bo van cho nguoi vua quay lai.
    final session = _session;
    if (session != null && _status == RoomStatus.playing) {
      _sendTo(
        link,
        GameStart(
          gameId: gameId,
          stateVersion: session.stateVersion,
          state: session.viewFor(playerId),
          currentActors: session.currentActors,
          seatOrder: session.seatOrder,
          playerClocks: _clocksNow(),
          series: _series,
        ),
      );
    }

    _broadcast(
      (_) => RoomUpdate(
        snapshot: snapshot,
        reason: RoomUpdateReason.playerReconnected,
        actorPlayerId: playerId,
      ),
      except: playerId,
    );
    _emitSnapshot();
  }

  void _handleReady(PlayerId playerId, PlayerReady message) {
    if (_status == RoomStatus.playing) return;
    _updateSlot(playerId, (s) => s.copyWith(isReady: message.ready));
    _recomputeStatus();
    _broadcast(
      (_) => RoomUpdate(
        snapshot: snapshot,
        reason: RoomUpdateReason.readyChanged,
        actorPlayerId: playerId,
      ),
    );
    _emitSnapshot();
  }

  void _handleStartGame(PlayerId playerId) {
    if (playerId != hostPlayerId) {
      _sendToPlayer(
        playerId,
        const ErrorMessage(
          code: 'NOT_HOST',
          message: 'Chi nguoi tao phong moi bat dau duoc van dau',
        ),
      );
      return;
    }
    if (_status == RoomStatus.playing) {
      _sendToPlayer(playerId, const ErrorMessage(code: 'ALREADY_PLAYING'));
      return;
    }
    if (_slots.length < _minPlayers) {
      _sendToPlayer(
        playerId,
        ErrorMessage(
          code: 'NOT_ENOUGH_PLAYERS',
          message: 'Can it nhat $_minPlayers nguoi choi',
        ),
      );
      return;
    }
    if (!_allReady) {
      _sendToPlayer(playerId, const ErrorMessage(code: 'NOT_ALL_READY'));
      return;
    }

    final seatOrder = _seatOrder;
    final session = GameSession(
      adapter: _registry.require(gameId),
      seatOrder: seatOrder,
      seed: _random.nextInt(1 << 32),
      options: settings.gameOptions,
    );
    _session = session;
    _status = RoomStatus.playing;
    _startClocks(seatOrder, session.currentActors);

    for (final slot in _slots) {
      _sendToPlayer(
        slot.playerId,
        GameStart(
          gameId: gameId,
          stateVersion: session.stateVersion,
          state: session.viewFor(slot.playerId),
          currentActors: session.currentActors,
          seatOrder: seatOrder,
          playerClocks: _clocksNow(),
          series: _series,
        ),
      );
    }
    _emitSnapshot();
  }

  void _handleGameAction(PlayerId playerId, GameActionMessage message) {
    final session = _session;
    if (session == null || _status != RoomStatus.playing) {
      _sendToPlayer(
        playerId,
        ErrorMessage(code: 'NO_ACTIVE_GAME', actionId: message.actionId),
      );
      return;
    }

    final outcome = session.applyAction(
      actor: playerId,
      actionId: message.actionId,
      expectedStateVersion: message.expectedStateVersion,
      action: message.action,
    );

    switch (outcome) {
      case ActionRejected():
        _sendToPlayer(
          playerId,
          ErrorMessage(
            code: outcome.code,
            message: outcome.message,
            actionId: message.actionId,
          ),
        );
        // Gui lai state hien tai de client bo trang thai "dang cho".
        _sendState(playerId, session, lastActionId: message.actionId);
      case ActionDuplicate():
        _sendState(playerId, session, lastActionId: message.actionId);
      case ActionApplied(:final finished):
        if (!finished) {
          _passTurn(from: playerId, to: session.currentActors);
        }
        for (final slot in _slots) {
          _sendState(slot.playerId, session, lastActionId: message.actionId);
        }
        if (finished) _finishGame(session);
    }
  }

  void _sendState(
    PlayerId playerId,
    GameSession session, {
    String? lastActionId,
  }) {
    _sendToPlayer(
      playerId,
      GameStateMessage(
        stateVersion: session.stateVersion,
        state: session.viewFor(playerId),
        currentActors: session.currentActors,
        lastActionId: lastActionId,
        playerClocks: _clocksNow(),
        series: _series,
      ),
    );
  }

  void _finishGame(GameSession session) {
    _status = RoomStatus.finished;
    _clockTimer?.cancel();
    _matchRemaining.clear();
    _moveRemaining.clear();
    // Cong diem TRUOC khi gui ket qua, de ban tin bao van xong mang luon ti so
    // da tinh ca van vua roi - neu khong, ti so tang len o ban tin sau va nguoi
    // choi thay con so nhay mot nhip sau khi doc xong ket qua.
    _series = _series.after(session.result!);
    // Van moi thi ai cung phai bam san sang lai.
    for (var i = 0; i < _slots.length; i++) {
      _slots[i] = _slots[i].copyWith(isReady: false);
    }
    for (final slot in _slots) {
      _sendToPlayer(
        slot.playerId,
        GameResultMessage(
          stateVersion: session.stateVersion,
          state: session.viewFor(slot.playerId),
          result: session.result!,
          series: _series,
        ),
      );
    }
    _clockTimer?.cancel();
    // Ket qua khong mang theo snapshot phong, nen phai gui rieng: neu khong,
    // client van thay trang thai san sang cu cua van truoc.
    _broadcast(
      (_) => RoomUpdate(
        snapshot: snapshot,
        reason: RoomUpdateReason.statusChanged,
      ),
    );
    _emitSnapshot();
  }

  // -------------------------------------------------------------------------
  // Mat ket noi
  // -------------------------------------------------------------------------

  void _onLinkClosed(PeerLink link) {
    if (_closed) return;
    _unjoinedLinks.remove(link);

    final playerId = _playerIdOf(link);
    if (playerId == null) return;
    // Ket noi da bi thay the boi mot lan rejoin: bo qua.
    if (_links[playerId] != link) return;

    _links.remove(playerId);

    // Host bien mat thi phong khong con trong tai nua.
    if (playerId == hostPlayerId) {
      unawaited(
        close(code: 'HOST_LEFT', message: 'Nguoi tao phong da thoat'),
      );
      return;
    }

    _updateSlot(
      playerId,
      (s) => s.copyWith(connection: PlayerConnectionState.disconnected),
    );
    _broadcast(
      (_) => RoomUpdate(
        snapshot: snapshot,
        reason: RoomUpdateReason.playerDisconnected,
        actorPlayerId: playerId,
      ),
    );
    _emitSnapshot();

    _graceTimers[playerId] = Timer(rejoinGrace, () {
      _graceTimers.remove(playerId);
      _removePlayer(playerId, RoomUpdateReason.playerLeft);
    });
  }

  void _removePlayer(PlayerId playerId, RoomUpdateReason reason) {
    if (_closed) return;
    _graceTimers.remove(playerId)?.cancel();

    if (playerId == hostPlayerId) {
      unawaited(close(code: 'HOST_LEFT', message: 'Nguoi tao phong da thoat'));
      return;
    }

    final existed = _slots.any((s) => s.playerId == playerId);
    if (!existed) return;

    _slots.removeWhere((s) => s.playerId == playerId);
    _secrets.remove(playerId);
    final link = _links.remove(playerId);
    unawaited(link?.close('left room') ?? Future<void>.value());

    // Khong con giua van thi don lai cho ngoi cho lien tuc.
    if (_status != RoomStatus.playing) _compactSeats();

    final session = _session;
    if (_status == RoomStatus.playing &&
        session != null &&
        _slots.length < _minPlayers) {
      session.abandon(reason: 'OPPONENT_LEFT');
      _finishGame(session);
    } else {
      _recomputeStatus();
    }

    _broadcast(
      (_) => RoomUpdate(
        snapshot: snapshot,
        reason: reason,
        actorPlayerId: playerId,
      ),
    );
    _emitSnapshot();
  }

  // -------------------------------------------------------------------------
  // Tien ich
  // -------------------------------------------------------------------------

  int get _minPlayers => _registry.require(gameId).minPlayers;

  bool get _allReady =>
      _slots.isNotEmpty && _slots.every((s) => s.isReady && s.isConnected);

  List<PlayerId> get _seatOrder {
    final sorted = [..._slots]..sort((a, b) => a.seat.compareTo(b.seat));
    return sorted.map((s) => s.playerId).toList(growable: false);
  }

  RoomSnapshot get snapshot => RoomSnapshot(
        roomId: roomId,
        gameId: gameId,
        displayName: displayName,
        status: _status,
        players: List<PlayerSlot>.unmodifiable(_slots),
        maxPlayers: maxPlayers,
        hostPlayerId: hostPlayerId,
      );

  void _recomputeStatus() {
    // Giu nguyen finished cho toi khi host bat dau van moi. Neu khong, nguoi
    // dau tien bam "choi lai" se lam man ket qua cua ca hai nhay ve phong cho.
    if (_status == RoomStatus.playing ||
        _status == RoomStatus.closed ||
        _status == RoomStatus.finished) {
      return;
    }
    final enough = _slots.length >= _minPlayers;
    _status = enough && _allReady ? RoomStatus.ready : RoomStatus.waiting;
  }

  void _compactSeats() {
    for (var i = 0; i < _slots.length; i++) {
      _slots[i] = _slots[i].copyWith(seat: i);
    }
  }

  PlayerSlot? _slotOf(PlayerId id) {
    for (final slot in _slots) {
      if (slot.playerId == id) return slot;
    }
    return null;
  }

  void _updateSlot(PlayerId id, PlayerSlot Function(PlayerSlot) update) {
    for (var i = 0; i < _slots.length; i++) {
      if (_slots[i].playerId == id) {
        _slots[i] = update(_slots[i]);
        return;
      }
    }
  }

  PlayerId? _playerIdOf(PeerLink link) {
    for (final entry in _links.entries) {
      if (entry.value == link) return entry.key;
    }
    return null;
  }

  String _newSecret() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(
      12,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }

  void _sendTo(PeerLink link, Message message) {
    if (link.isClosed) return;
    link.send(MessageCodec.encode(message));
  }

  void _sendToPlayer(PlayerId playerId, Message message) {
    final link = _links[playerId];
    if (link != null) _sendTo(link, message);
  }

  void _broadcast(Message Function(PlayerId) build, {PlayerId? except}) {
    for (final entry in _links.entries) {
      if (entry.key == except) continue;
      _sendTo(entry.value, build(entry.key));
    }
  }

  void _emitSnapshot() {
    if (!_snapshots.isClosed) _snapshots.add(snapshot);
  }

  /// Doi mot han chot cua host thanh so mili giay con lai.
  // -------------------------------------------------------------------------
  // Dong ho
  //
  // Moi nguoi mot cap dong ho, kieu co vua: mot cho nuoc di dang cho, mot la
  // ngan sach cua rieng ho cho ca van. Dong ho chi chay trong luc chinh chu
  // dang suy nghi - nghi lau la tu an vao phan cua minh, khong an vao phan
  // cua doi thu.
  // -------------------------------------------------------------------------

  /// Dat dong ho cho mot van moi.
  void _startClocks(List<PlayerId> seatOrder, List<PlayerId> actors) {
    _matchRemaining.clear();
    _moveRemaining.clear();
    final matchLimit = settings.matchTimeLimitMs;
    final moveLimit = settings.moveTimeLimitMs;
    for (final player in seatOrder) {
      if (matchLimit != null) _matchRemaining[player] = matchLimit;
      if (moveLimit != null) _moveRemaining[player] = moveLimit;
    }
    _turnStartedAtMillis = DateTime.now().millisecondsSinceEpoch;
    _scheduleClockTimer(actors);
  }

  /// Ket thuc luot cua [from] va bat dau luot cua [to].
  void _passTurn({required PlayerId from, required List<PlayerId> to}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final spent = now - _turnStartedAtMillis;

    // Nguoi vua di bi tru dung phan ho da nghi. Dong ho nuoc di cua ho giu
    // lai cho con thua, de man hinh con cho thay ho vua di nhanh hay cham.
    final match = _matchRemaining[from];
    if (match != null) _matchRemaining[from] = _floor(match - spent);
    final move = _moveRemaining[from];
    if (move != null) _moveRemaining[from] = _floor(move - spent);

    // Nguoi sap di duoc dong ho nuoc di moi tinh.
    final moveLimit = settings.moveTimeLimitMs;
    if (moveLimit != null) {
      for (final player in to) {
        _moveRemaining[player] = moveLimit;
      }
    }

    _turnStartedAtMillis = now;
    _scheduleClockTimer(to);
  }

  static int _floor(int value) => value < 0 ? 0 : value;

  /// Anh chup dong ho de gui di, tinh tai thoi diem goi.
  ///
  /// Trong nay host giu SO CON LAI cua tung nguoi cong voi moc bat dau luot,
  /// vi no chi so voi dong ho cua chinh no. Ra ngoai day thi chi con KHOANG
  /// THOI GIAN, de may nhan khong phai so gio cua minh voi gio cua host.
  /// Xem [GameStart.playerClocks].
  Map<PlayerId, PlayerClock> _clocksNow() {
    if (_matchRemaining.isEmpty && _moveRemaining.isEmpty) return const {};
    final session = _session;
    final actors = session?.currentActors ?? const <PlayerId>[];
    final spent = DateTime.now().millisecondsSinceEpoch - _turnStartedAtMillis;

    return {
      for (final slot in _slots)
        slot.playerId: () {
          final running = actors.contains(slot.playerId);
          final match = _matchRemaining[slot.playerId];
          final move = _moveRemaining[slot.playerId];
          // Nguoi dang di thi so trong map la so luc luot bat dau, phai tru
          // phan da nghi. Nguoi khac thi so do dung yen tu luc ho di xong.
          return PlayerClock(
            matchMillis:
                match == null ? null : _floor(running ? match - spent : match),
            moveMillis:
                move == null ? null : _floor(running ? move - spent : move),
            running: running,
          );
        }(),
    };
  }

  /// Hen gio cho ben dang di het gio - cai nao can truoc thi tinh cai do.
  void _scheduleClockTimer(List<PlayerId> actors) {
    _clockTimer?.cancel();
    final actor = actors.firstOrNull;
    if (actor == null) return;

    final match = _matchRemaining[actor];
    final move = _moveRemaining[actor];
    final int limit;
    final String reason;
    if (match != null && (move == null || match <= move)) {
      limit = match;
      reason = 'MATCH_TIMEOUT';
    } else if (move != null) {
      limit = move;
      reason = 'MOVE_TIMEOUT';
    } else {
      return; // Van nay khong tinh gio.
    }

    _clockTimer = Timer(Duration(milliseconds: _floor(limit)), () {
      final session = _session;
      if (session == null || _status != RoomStatus.playing) return;
      if (_matchRemaining.containsKey(actor)) _matchRemaining[actor] = 0;
      if (_moveRemaining.containsKey(actor)) _moveRemaining[actor] = 0;
      session.timeout(reason: reason);
      _finishGame(session);
    });
  }
}
