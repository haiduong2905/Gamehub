import '../protocol/ids.dart';
import 'game_adapter.dart';
import 'game_definition.dart';

/// So dang ky game cua platform.
///
/// Room Manager chi biet [GameId] va tra cuu qua day. Khong o dau trong core
/// duoc phep viet `if (gameId == 'tic-tac-toe')`. Them game moi = them mot
/// dong dang ky o composition root, khong sua core.
class GameRegistry {
  GameRegistry();

  final Map<GameId, GameAdapter> _adapters = <GameId, GameAdapter>{};

  /// Dang ky mot game. Generic o day de suy ra `<S, A>` tu [definition].
  void register<S, A>(GameDefinition<S, A> definition) {
    if (_adapters.containsKey(definition.id)) {
      throw StateError('Game "${definition.id}" da duoc dang ky roi.');
    }
    if (definition.minPlayers < 2) {
      throw ArgumentError(
        'Game "${definition.id}" phai co it nhat 2 nguoi choi.',
      );
    }
    if (definition.maxPlayers < definition.minPlayers) {
      throw ArgumentError(
        'Game "${definition.id}" co maxPlayers < minPlayers.',
      );
    }
    _adapters[definition.id] = GameAdapter.of(definition);
  }

  bool contains(GameId id) => _adapters.containsKey(id);

  GameAdapter? lookup(GameId id) => _adapters[id];

  /// Nem [StateError] neu chua dang ky. Dung o duong code da chac chan co game.
  GameAdapter require(GameId id) {
    final adapter = _adapters[id];
    if (adapter == null) {
      throw StateError('Game "$id" chua duoc dang ky trong GameRegistry.');
    }
    return adapter;
  }

  /// Danh sach game cho man Game List, sap theo ten.
  List<GameAdapter> get all {
    final list = _adapters.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(list);
  }
}
