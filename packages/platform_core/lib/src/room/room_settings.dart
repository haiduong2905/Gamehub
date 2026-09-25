import '../protocol/ids.dart';

/// Cau hinh mot van do chu phong chot truoc khi bat dau.
///
/// Day la du lieu thuần Dart. Core khong hieu y nghia cua [gameOptions];
/// game tu doc cac tuy chon cua rieng minh khi tao state ban dau.
class RoomSettings {
  const RoomSettings({
    this.gameOptions = const <String, dynamic>{},
    this.matchTimeLimit,
    this.moveTimeLimit,
  });

  final Map<String, dynamic> gameOptions;

  /// Ngan sach thoi gian cua MOI nguoi cho ca van, kieu dong ho co vua.
  ///
  /// Khong phai tong thoi gian cua ca ban co: dong ho cua mot nguoi chi chay
  /// trong luc ho dang suy nghi. Ai tieu het phan cua minh thi nguoi do thua.
  final Duration? matchTimeLimit;

  /// Thoi gian toi da cho MOT nuoc di. Dat lai tron ven moi luot.
  final Duration? moveTimeLimit;

  int? get matchTimeLimitMs => matchTimeLimit?.inMilliseconds;
  int? get moveTimeLimitMs => moveTimeLimit?.inMilliseconds;

  bool get hasClocks => matchTimeLimit != null || moveTimeLimit != null;
}

PlayerId? otherPlayer(List<PlayerId> players, PlayerId player) {
  for (final candidate in players) {
    if (candidate != player) return candidate;
  }
  return null;
}
