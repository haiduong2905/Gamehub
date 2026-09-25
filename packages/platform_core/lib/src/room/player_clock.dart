/// Dong ho cua MOT nguoi choi, do tai mot thoi diem.
///
/// Moi nguoi co hai dong ho, giong dong ho co vua:
///
/// * [moveMillis] - con lai bao nhieu cho NUOC DI hien tai. Dat lai tron ven
///   moi khi den luot nguoi do.
/// * [matchMillis] - ngan sach cua rieng nguoi do cho CA VAN. Chi tru di
///   trong luc ho dang suy nghi, khong tru trong luc doi thu nghi.
///
/// `null` nghia la khong dat gioi han, khong phai la het gio.
///
/// Chi dong ho cua nguoi dang den luot moi [running]. Nho vay may nhan ve
/// duoc dung nhu anh chup trong [GameView]: so cua doi thu dung yen, so cua
/// nguoi dang di thi chay.
class PlayerClock {
  const PlayerClock({
    this.moveMillis,
    this.matchMillis,
    this.running = false,
    this.asOfMillis = 0,
  });

  final int? moveMillis;
  final int? matchMillis;
  final bool running;

  /// Luc [moveMillis] va [matchMillis] duoc do, theo dong ho CUA MAY DANG GIU
  /// con so nay.
  ///
  /// Host do theo gio cua host; may nhan dong dau lai theo gio cua chinh no
  /// ngay khi giai ma ban tin. Vi vay truong nay khong bao gio di tren day -
  /// neu di thi lai thanh so sanh hai dong ho khac nhau, dung thu vua bo.
  final int asOfMillis;

  bool get isUnlimited => moveMillis == null && matchMillis == null;

  /// Con lai bao nhieu cho nuoc di hien tai, tinh tai [nowMillis].
  int? moveRemainingAt(int nowMillis) => _at(moveMillis, nowMillis);

  /// Con lai bao nhieu cho ca van, tinh tai [nowMillis].
  int? matchRemainingAt(int nowMillis) => _at(matchMillis, nowMillis);

  int? _at(int? value, int nowMillis) {
    if (value == null || !running) return value;
    final left = value - (nowMillis - asOfMillis);
    return left < 0 ? 0 : left;
  }

  PlayerClock stampedAt(int millis) => PlayerClock(
        moveMillis: moveMillis,
        matchMillis: matchMillis,
        running: running,
        asOfMillis: millis,
      );

  Map<String, dynamic> toJson() => {
        if (moveMillis != null) 'move': moveMillis,
        if (matchMillis != null) 'match': matchMillis,
        if (running) 'running': true,
      };

  /// [asOfMillis] do nguoi GIAI MA dong dau, khong doc tu json.
  static PlayerClock fromJson(
    Map<String, dynamic> json, {
    required int asOfMillis,
  }) =>
      PlayerClock(
        moveMillis: json['move'] as int?,
        matchMillis: json['match'] as int?,
        running: json['running'] as bool? ?? false,
        asOfMillis: asOfMillis,
      );

  @override
  bool operator ==(Object other) =>
      other is PlayerClock &&
      other.moveMillis == moveMillis &&
      other.matchMillis == matchMillis &&
      other.running == running;

  @override
  int get hashCode => Object.hash(moveMillis, matchMillis, running);

  @override
  String toString() =>
      'PlayerClock(move: $moveMillis, match: $matchMillis, running: $running)';
}
