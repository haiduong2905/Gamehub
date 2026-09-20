import '../game/game_adapter.dart';
import '../game/game_result.dart';
import '../protocol/ids.dart';

/// Ket qua cua mot lan host xu ly nuoc di.
sealed class ApplyOutcome {
  const ApplyOutcome();
}

/// Nuoc di hop le va da duoc ap dung.
class ActionApplied extends ApplyOutcome {
  const ActionApplied({required this.stateVersion, required this.finished});

  final int stateVersion;
  final bool finished;
}

/// Nuoc di bi tu choi. [code] la ma on dinh de UI dich sang tieng Viet.
class ActionRejected extends ApplyOutcome {
  const ActionRejected(this.code, [this.message]);

  final String code;
  final String? message;
}

/// Nuoc di nay da duoc ap dung tu truoc.
///
/// Xay ra khi nguoi choi bam hai lan, hoac client gui lai sau khi ket noi lai.
/// Khong phai loi: host chi lang le gui lai state hien tai.
class ActionDuplicate extends ApplyOutcome {
  const ActionDuplicate(this.stateVersion);

  final int stateVersion;
}

/// Mot van dau dang dien ra. CHI ton tai o phia host.
///
/// Day la nguon su that duy nhat ve state. Client khong bao gio tu tinh state
/// hay tu ket luan thang thua - no chi ve lai nhung gi host gui xuong.
class GameSession {
  GameSession({
    required this.adapter,
    required this.seatOrder,
    required int seed,
    Map<String, dynamic> options = const {},
  })  : _state = adapter.createInitialState(
          seatOrder,
          seed: seed,
          options: options,
        ),
        _stateVersion = 1;

  final GameAdapter adapter;

  /// Thu tu di, chot luc bat dau van.
  final List<PlayerId> seatOrder;

  Map<String, dynamic> _state;
  int _stateVersion;
  GameResult? _result;

  /// Nhung nuoc di da ap dung, de khong ap dung hai lan.
  final Set<String> _appliedActionIds = <String>{};

  int get stateVersion => _stateVersion;

  GameResult? get result => _result;

  bool get isFinished => _result != null;

  List<PlayerId> get currentActors =>
      isFinished ? const [] : adapter.currentActors(_state);

  /// Phan state ma rieng [viewer] duoc phep nhin thay.
  Map<String, dynamic> viewFor(PlayerId viewer) => adapter.viewFor(viewer, _state);

  /// Xu ly mot nuoc di. Day la cho duy nhat state duoc phep thay doi.
  ApplyOutcome applyAction({
    required PlayerId actor,
    required String actionId,
    required int expectedStateVersion,
    required Map<String, dynamic> action,
  }) {
    if (_appliedActionIds.contains(actionId)) {
      return ActionDuplicate(_stateVersion);
    }
    if (isFinished) {
      return const ActionRejected('GAME_FINISHED', 'Van dau da ket thuc');
    }
    if (expectedStateVersion != _stateVersion) {
      // Client dang nhin mot state cu. Thuong la do bam khi nuoc di cua doi
      // thu vua toi. Tu choi va de client ve lai theo state moi nhat.
      return const ActionRejected('STALE_STATE', 'State da thay doi');
    }
    if (!currentActors.contains(actor)) {
      return const ActionRejected('NOT_YOUR_TURN', 'Chua den luot ban');
    }

    final validation = adapter.validate(_state, actor, action);
    if (!validation.isValid) {
      return ActionRejected(
        validation.code ?? 'INVALID_ACTION',
        validation.message,
      );
    }

    _state = adapter.apply(_state, actor, action);
    _stateVersion++;
    _appliedActionIds.add(actionId);

    if (adapter.isFinished(_state)) {
      _result = adapter.getResult(_state);
    }

    return ActionApplied(stateVersion: _stateVersion, finished: isFinished);
  }

  /// Ket thuc van dau khong theo luat game, vi du doi thu roi phong qua lau.
  ///
  /// Ket qua nay do platform quyet dinh chu khong phai game, nen no khong di
  /// qua [GameAdapter].
  void abandon({String? reason}) {
    if (isFinished) return;
    _result = GameResult.abandoned(reason: reason);
    _stateVersion++;
  }

  /// Het thoi gian luot: nguoi dang choi thua, neu game co doi thu.
  void timeout() {
    if (isFinished) return;
    final actor = currentActors.firstOrNull;
    if (actor == null) return;
    final winner = seatOrder.where((player) => player != actor).toList();
    _result = winner.isEmpty
        ? const GameResult.abandoned(reason: 'TURN_TIMEOUT')
        : GameResult.winners(winner, reason: 'TURN_TIMEOUT');
    _stateVersion++;
  }
}
