import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_tictactoe/game_tictactoe.dart';
import 'package:platform_core/platform_core.dart';

/// Mot game trong Game Hub: luat choi + cach ve + thong tin cho danh sach.
class CatalogEntry {
  const CatalogEntry({
    required this.definition,
    required this.buildBoard,
    required this.icon,
    required this.tagline,
  });

  final GameAdapter definition;

  /// Nua con lai cua registry: phan Flutter.
  ///
  /// [GameDefinition] la pure Dart nen khong the chua [Widget]. Hai nua duoc
  /// khop voi nhau qua `gameId`, nho vay core khong phai biet den Flutter.
  final Widget Function(GameView view) buildBoard;

  final IconData icon;

  /// Mot dong mo ta ngan cho man danh sach game.
  final String tagline;

  GameId get id => definition.id;
  String get name => definition.name;
  int get minPlayers => definition.minPlayers;
  int get maxPlayers => definition.maxPlayers;

  String get playersLabel => minPlayers == maxPlayers
      ? '$minPlayers nguoi'
      : '$minPlayers-$maxPlayers nguoi';
}

/// Danh muc game cua app.
class GameCatalog {
  GameCatalog({required this.registry, required this.entries})
      : _byId = {for (final e in entries) e.id: e};

  /// Registry ma [RoomHost] thuc su dung de tra cuu luat choi.
  final GameRegistry registry;

  final List<CatalogEntry> entries;
  final Map<GameId, CatalogEntry> _byId;

  CatalogEntry? operator [](GameId id) => _byId[id];

  CatalogEntry require(GameId id) {
    final entry = _byId[id];
    if (entry == null) throw StateError('Game "$id" chua duoc dang ky.');
    return entry;
  }
}

/// Composition root cua ca app.
///
/// Day la cho DUY NHAT biet nhung game nao ton tai. Them game moi = them mot
/// muc o day; khong sua platform_core, khong sua RoomHost, khong sua transport.
///
/// Dang ky tap trung o day chu khong dung static initializer tu-dang-ky:
/// Dart khong dam bao chay chung, va tree-shaking se an mat.
final gameCatalogProvider = Provider<GameCatalog>((ref) {
  final registry = GameRegistry()..register(const TicTacToeGame());

  return GameCatalog(
    registry: registry,
    entries: [
      CatalogEntry(
        definition: registry.require('tic-tac-toe'),
        buildBoard: TicTacToeBoard.build,
        icon: Icons.grid_3x3_rounded,
        tagline: 'Ba o thang hang la thang.',
      ),
    ],
  );
});
