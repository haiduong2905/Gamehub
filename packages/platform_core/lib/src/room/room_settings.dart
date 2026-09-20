import '../protocol/ids.dart';

/// Cau hinh mot van do chu phong chot truoc khi bat dau.
///
/// Day la du lieu thuần Dart. Core khong hieu y nghia cua [gameOptions];
/// game tu doc cac tuy chon cua rieng minh khi tao state ban dau.
class RoomSettings {
  const RoomSettings({
    this.gameOptions = const <String, dynamic>{},
    this.gameTimeLimit,
    this.turnTimeLimit,
  });

  final Map<String, dynamic> gameOptions;
  final Duration? gameTimeLimit;
  final Duration? turnTimeLimit;

  int? get gameTimeLimitMs => gameTimeLimit?.inMilliseconds;
  int? get turnTimeLimitMs => turnTimeLimit?.inMilliseconds;
}

/// Gioi han thoi gian ma host gui cho client theo cung mot don vi.
class GameDeadlines {
  const GameDeadlines({this.gameDeadlineMillis, this.turnDeadlineMillis});

  final int? gameDeadlineMillis;
  final int? turnDeadlineMillis;
}

GameDeadlines? deadlinesFrom({
  required RoomSettings settings,
  required int startedAtMillis,
  required int turnStartedAtMillis,
}) {
  final gameLimit = settings.gameTimeLimitMs;
  final turnLimit = settings.turnTimeLimitMs;
  if (gameLimit == null && turnLimit == null) return null;
  return GameDeadlines(
    gameDeadlineMillis:
        gameLimit == null ? null : startedAtMillis + gameLimit,
    turnDeadlineMillis:
        turnLimit == null ? null : turnStartedAtMillis + turnLimit,
  );
}

PlayerId? otherPlayer(List<PlayerId> players, PlayerId player) {
  for (final candidate in players) {
    if (candidate != player) return candidate;
  }
  return null;
}