import '../protocol/ids.dart';
import 'game_result.dart';

/// Moi thu mot man hinh game can de ve, va cach no gui nuoc di di.
///
/// Day la du lieu thuan, khong co kieu nao cua Flutter, nen no o duoc trong
/// core. Nho vay package cua tung game co the vua chua luat choi vua chua
/// widget ban co ma khong sinh ra phu thuoc vong:
///
///     game_tictactoe  ->  platform_core   (lay [GameView])
///     app             ->  game_tictactoe  (lay widget)
///
/// Neu de contract nay o tang app thi game phai phu thuoc nguoc len app.
class GameView {
  const GameView({
    required this.state,
    required this.me,
    required this.seatOrder,
    required this.nicknames,
    required this.currentActors,
    required this.onAction,
    this.pendingActionId,
    this.result,
  });

  /// State da encode, dung phan ma rieng nguoi nay duoc thay.
  final Map<String, dynamic> state;

  final PlayerId me;

  /// Thu tu di, chot tu luc bat dau van.
  final List<PlayerId> seatOrder;

  final Map<PlayerId, String> nicknames;

  final List<PlayerId> currentActors;

  /// Nuoc di dang cho host xac nhan. Man hinh game dung de ve trang thai mo.
  final String? pendingActionId;

  /// Khac null khi van da ket thuc.
  final GameResult? result;

  /// Gui mot nuoc di len host. Man hinh game KHONG duoc tu doi [state].
  final void Function(Map<String, dynamic> action) onAction;

  bool get isMyTurn => currentActors.contains(me);

  bool get isFinished => result != null;

  bool get hasPendingAction => pendingActionId != null;

  /// Cham vao ban co co an khong. Sai khi chua den luot, dang cho host xac
  /// nhan, hoac van da xong.
  bool get canAct => isMyTurn && !hasPendingAction && !isFinished;

  String nicknameOf(PlayerId id) => nicknames[id] ?? 'Nguoi choi';
}
