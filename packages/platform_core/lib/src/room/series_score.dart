import '../game/game_result.dart';
import '../protocol/ids.dart';

/// Ti so thang - thua cua ca loat van trong mot phong.
///
/// Do host giu va phat xuong chu khong phai moi may tu dem lay. Client vao
/// phong giua chung, hoac mat ket noi roi quay lai, se dem thieu - va khi hai
/// may hien hai ti so khac nhau thi khong co cach nao biet cai nao dung. Day
/// van la ràng buoc "host la trong tai duy nhat", ap dung cho mot con so chu
/// khong phai cho mot nuoc di.
class SeriesScore {
  const SeriesScore({this.wins = const {}, this.draws = 0});

  /// So van tung nguoi da thang.
  final Map<PlayerId, int> wins;

  /// So van hoa. Khong thuoc ve ai nen de rieng.
  final int draws;

  static const empty = SeriesScore();

  bool get isEmpty => wins.isEmpty && draws == 0;

  int winsOf(PlayerId player) => wins[player] ?? 0;

  /// Tong so van da tinh diem.
  int get played => wins.values.fold(draws, (sum, n) => sum + n);

  /// Ti so sau khi mot van ket thuc.
  ///
  /// Van bo do khong tinh vao ti so: no khong noi len ai choi hon ai, va tinh
  /// no thanh mot thua se bien viec rut day mang thanh mot cach ghi diem.
  SeriesScore after(GameResult result) => switch (result.outcome) {
        GameOutcome.win => SeriesScore(
            wins: {
              ...wins,
              for (final winner in result.winners) winner: winsOf(winner) + 1,
            },
            draws: draws,
          ),
        GameOutcome.draw => SeriesScore(wins: wins, draws: draws + 1),
        GameOutcome.abandoned => this,
      };

  Map<String, dynamic> toJson() => {
        'wins': wins,
        if (draws > 0) 'draws': draws,
      };

  static SeriesScore fromJson(Object? raw) {
    if (raw is! Map) return empty;
    final wins = raw['wins'];
    return SeriesScore(
      wins: wins is Map
          ? {
              for (final entry in wins.entries)
                '${entry.key}': (entry.value as num?)?.toInt() ?? 0,
            }
          : const {},
      draws: (raw['draws'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  String toString() => 'SeriesScore(wins: $wins, draws: $draws)';
}
