import '../protocol/ids.dart';
import 'game_definition.dart';
import 'game_result.dart';

/// Mat na khong generic boc quanh mot [GameDefinition].
///
/// Ly do ton tai: [GameSession] va [RoomHost] khong the cam
/// `GameDefinition<S, A>` generic ma khong lam `dynamic` lan ra khap noi.
/// Adapter nay chi noi chuyen bang JSON da encode, nen viec encode/decode
/// xay ra dung MOT cho: tai bien nay.
abstract class GameAdapter {
  /// Bat buoc dung ham nay de suy ra dung `<S, A>` tu [definition].
  /// Khong dung constructor nhan `GameDefinition<Object?, Object?>`: Dart cho phep
  /// ep kieu do vi generic la covariant, nhung se no kieu luc chay.
  static GameAdapter of<S, A>(GameDefinition<S, A> definition) =>
      _TypedGameAdapter<S, A>(definition);

  GameId get id;
  String get name;
  int get minPlayers;
  int get maxPlayers;

  Map<String, dynamic> createInitialState(
    List<PlayerId> players, {
    required int seed,
    Map<String, dynamic> options = const {},
  });

  ValidationResult validate(
    Map<String, dynamic> state,
    PlayerId actor,
    Map<String, dynamic> action,
  );

  Map<String, dynamic> apply(
    Map<String, dynamic> state,
    PlayerId actor,
    Map<String, dynamic> action,
  );

  List<PlayerId> currentActors(Map<String, dynamic> state);

  bool isFinished(Map<String, dynamic> state);

  GameResult getResult(Map<String, dynamic> state);

  Map<String, dynamic> viewFor(PlayerId viewer, Map<String, dynamic> state);
}

class _TypedGameAdapter<S, A> implements GameAdapter {
  _TypedGameAdapter(this._definition);

  final GameDefinition<S, A> _definition;

  @override
  GameId get id => _definition.id;

  @override
  String get name => _definition.name;

  @override
  int get minPlayers => _definition.minPlayers;

  @override
  int get maxPlayers => _definition.maxPlayers;

  @override
  Map<String, dynamic> createInitialState(
    List<PlayerId> players, {
    required int seed,
    Map<String, dynamic> options = const {},
  }) =>
      _definition.encodeState(
        _definition.createInitialState(players, seed: seed, options: options),
      );

  @override
  ValidationResult validate(
    Map<String, dynamic> state,
    PlayerId actor,
    Map<String, dynamic> action,
  ) {
    final A decodedAction;
    try {
      decodedAction = _definition.decodeAction(action);
    } on Object catch (e) {
      return ValidationResult.invalid('MALFORMED_ACTION', '$e');
    }
    return _definition.validate(
      _definition.decodeState(state),
      actor,
      decodedAction,
    );
  }

  @override
  Map<String, dynamic> apply(
    Map<String, dynamic> state,
    PlayerId actor,
    Map<String, dynamic> action,
  ) =>
      _definition.encodeState(
        _definition.apply(
          _definition.decodeState(state),
          actor,
          _definition.decodeAction(action),
        ),
      );

  @override
  List<PlayerId> currentActors(Map<String, dynamic> state) =>
      _definition.currentActors(_definition.decodeState(state));

  @override
  bool isFinished(Map<String, dynamic> state) =>
      _definition.isFinished(_definition.decodeState(state));

  @override
  GameResult getResult(Map<String, dynamic> state) =>
      _definition.getResult(_definition.decodeState(state));

  @override
  Map<String, dynamic> viewFor(PlayerId viewer, Map<String, dynamic> state) =>
      _definition.encodeState(
        _definition.viewFor(viewer, _definition.decodeState(state)),
      );
}
