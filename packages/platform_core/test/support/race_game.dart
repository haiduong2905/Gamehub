import 'package:platform_core/platform_core.dart';

/// Game gia lap chi dung trong test cua core.
///
/// Core khong duoc phep phu thuoc vao mot game that nao. Dung game nay de
/// chung minh dieu do, va de chay duoc nhanh 3-4 nguoi choi - nhanh ma co
/// caro (luon 2 nguoi) khong bao gio cham toi.
///
/// Luat: lan luot moi nguoi cong 1 hoac 2 diem. Ai toi [target] truoc thi thang.
class RaceState {
  const RaceState({
    required this.players,
    required this.scores,
    required this.turnIndex,
    required this.target,
  });

  final List<PlayerId> players;
  final Map<PlayerId, int> scores;
  final int turnIndex;
  final int target;

  PlayerId get currentPlayer => players[turnIndex];

  PlayerId? get winner {
    for (final p in players) {
      if ((scores[p] ?? 0) >= target) return p;
    }
    return null;
  }
}

class RaceMove {
  const RaceMove(this.step);

  final int step;
}

class RaceGame extends GameDefinition<RaceState, RaceMove> {
  const RaceGame({this.target = 5});

  final int target;

  @override
  GameId get id => 'race';

  @override
  String get name => 'Race';

  @override
  int get minPlayers => 2;

  @override
  int get maxPlayers => 4;

  @override
  RaceState createInitialState(List<PlayerId> players, {required int seed}) =>
      RaceState(
        players: List<PlayerId>.unmodifiable(players),
        scores: {for (final p in players) p: 0},
        turnIndex: 0,
        target: target,
      );

  @override
  List<PlayerId> currentActors(RaceState state) =>
      isFinished(state) ? const [] : [state.currentPlayer];

  @override
  ValidationResult validate(RaceState state, PlayerId actor, RaceMove action) {
    if (isFinished(state)) return const ValidationResult.invalid('FINISHED');
    if (actor != state.currentPlayer) {
      return const ValidationResult.invalid('NOT_YOUR_TURN');
    }
    if (action.step < 1 || action.step > 2) {
      return const ValidationResult.invalid('BAD_STEP');
    }
    return const ValidationResult.valid();
  }

  @override
  RaceState apply(RaceState state, PlayerId actor, RaceMove action) {
    final scores = Map<PlayerId, int>.of(state.scores);
    scores[actor] = (scores[actor] ?? 0) + action.step;
    return RaceState(
      players: state.players,
      scores: scores,
      turnIndex: (state.turnIndex + 1) % state.players.length,
      target: state.target,
    );
  }

  @override
  bool isFinished(RaceState state) => state.winner != null;

  @override
  GameResult getResult(RaceState state) => GameResult.win(state.winner!);

  @override
  Map<String, dynamic> encodeState(RaceState state) => {
        'players': state.players,
        'scores': state.scores,
        'turnIndex': state.turnIndex,
        'target': state.target,
      };

  @override
  RaceState decodeState(Map<String, dynamic> json) => RaceState(
        players: (json['players'] as List<dynamic>)
            .map((dynamic e) => e as String)
            .toList(growable: false),
        scores: (json['scores'] as Map).map(
          (dynamic k, dynamic v) => MapEntry(k as String, v as int),
        ),
        turnIndex: json['turnIndex'] as int,
        target: json['target'] as int,
      );

  @override
  Map<String, dynamic> encodeAction(RaceMove action) => {'step': action.step};

  @override
  RaceMove decodeAction(Map<String, dynamic> json) =>
      RaceMove(json['step'] as int);
}

/// Game co thong tin an, de kiem tra rang host khong gui bai cua nguoi nay
/// cho nguoi kia. Moi nguoi co mot con so bi mat.
class SecretNumberGame extends GameDefinition<Map<String, dynamic>, RaceMove> {
  const SecretNumberGame();

  @override
  GameId get id => 'secret';

  @override
  String get name => 'Secret';

  @override
  int get minPlayers => 2;

  @override
  int get maxPlayers => 2;

  @override
  Map<String, dynamic> createInitialState(
    List<PlayerId> players, {
    required int seed,
  }) =>
      {
        'players': players,
        'turnIndex': 0,
        'secrets': {for (final p in players) p: '${p}_secret'},
      };

  @override
  Map<String, dynamic> viewFor(PlayerId viewer, Map<String, dynamic> state) {
    final secrets = (state['secrets'] as Map).cast<String, dynamic>();
    return {
      ...state,
      'secrets': {
        for (final entry in secrets.entries)
          entry.key: entry.key == viewer ? entry.value : null,
      },
    };
  }

  @override
  List<PlayerId> currentActors(Map<String, dynamic> state) => [
        (state['players'] as List<dynamic>)[state['turnIndex'] as int]
            as PlayerId,
      ];

  @override
  ValidationResult validate(
    Map<String, dynamic> state,
    PlayerId actor,
    RaceMove action,
  ) =>
      const ValidationResult.valid();

  @override
  Map<String, dynamic> apply(
    Map<String, dynamic> state,
    PlayerId actor,
    RaceMove action,
  ) =>
      {...state, 'turnIndex': 1 - (state['turnIndex'] as int)};

  @override
  bool isFinished(Map<String, dynamic> state) => false;

  @override
  GameResult getResult(Map<String, dynamic> state) =>
      const GameResult.draw();

  @override
  Map<String, dynamic> encodeState(Map<String, dynamic> state) => state;

  @override
  Map<String, dynamic> decodeState(Map<String, dynamic> json) => json;

  @override
  Map<String, dynamic> encodeAction(RaceMove action) => {'step': action.step};

  @override
  RaceMove decodeAction(Map<String, dynamic> json) =>
      RaceMove(json['step'] as int);
}
