import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_tictactoe/game_tictactoe.dart';
import 'package:game_xiangqi/game_xiangqi.dart';
import 'package:platform_core/platform_core.dart';

/// Lua chon ben choi cua chu phong. Y nghia option do game tu xu ly.
class HostSideOption {
  const HostSideOption({
    required this.key,
    required this.label,
    required this.choices,
  });

  final String key;
  final String label;
  final List<HostSideChoice> choices;

  String get defaultValue => choices.first.value;
}

class HostSideChoice {
  const HostSideChoice(this.value, this.label);

  final String value;
  final String label;
}

/// Mot game trong Game Hub: luat choi + cach ve + thong tin cho danh sach.
class CatalogEntry {
  const CatalogEntry({
    required this.definition,
    required this.buildBoard,
    required this.buildIcon,
    this.buildLocalGame,
    this.hostSideOption,
  });

  final GameAdapter definition;

  /// Nua con lai cua registry: phan Flutter.
  ///
  /// [GameDefinition] la pure Dart nen khong the chua [Widget]. Hai nua duoc
  /// khop voi nhau qua `gameId`, nho vay core khong phai biet den Flutter.
  final Widget Function(GameView view) buildBoard;

  /// Icon riêng của game, vẽ ở kích thước được yêu cầu.
  ///
  /// Là hàm dựng widget chứ không phải [IconData]: mỗi game tự vẽ icon của
  /// mình trong package của nó (bàn cờ thu nhỏ, quân cờ thật), nên `app`
  /// không phải chứa ảnh hay biết game đó trông thế nào.
  final Widget Function(double size) buildIcon;

  /// Man hinh choi voi may, do chinh game dung.
  ///
  /// `null` nghia la game chua co may danh — khi do nut "Choi voi may" khong
  /// hien ra, thay vi hien roi dan vao mot man hinh trong.
  ///
  /// Ly do day la mot ham chu khong phai mot `switch (gameId)` o tang UI:
  /// rang buoc so 2 cam `app` biet trong hub co nhung game nao. `app` chi goi
  /// ham nay, khong biet ben trong la game gi.
  final Widget Function()? buildLocalGame;

  final HostSideOption? hostSideOption;

  GameId get id => definition.id;
  String get name => definition.name;
  int get minPlayers => definition.minPlayers;
  int get maxPlayers => definition.maxPlayers;

  String get playersLabel => minPlayers == maxPlayers
      ? '$minPlayers người chơi'
      : '$minPlayers-$maxPlayers người chơi';
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
  final registry = GameRegistry()
    ..register(const TicTacToeGame())
    ..register(const XiangqiGame());

  return GameCatalog(
    registry: registry,
    entries: [
      CatalogEntry(
        definition: registry.require('tic-tac-toe'),
        buildBoard: TicTacToeBoard.build,
        buildIcon: (size) => TicTacToeIcon(size: size),
        buildLocalGame: TicTacToeLocalGameScreen.new,
        hostSideOption: const HostSideOption(
          key: 'hostMark',
          label: 'Bạn chơi',
          choices: [
            HostSideChoice('x', 'X - đi trước'),
            HostSideChoice('o', 'O - đi sau'),
          ],
        ),
      ),
      CatalogEntry(
        definition: registry.require('xiangqi'),
        buildBoard: XiangqiBoard.build,
        buildIcon: (size) => XiangqiIcon(size: size),
        buildLocalGame: XiangqiLocalGameScreen.new,
        hostSideOption: const HostSideOption(
          key: 'hostColor',
          label: 'Bạn cầm quân',
          choices: [
            HostSideChoice('red', 'Đỏ - đi trước'),
            HostSideChoice('black', 'Đen - đi sau'),
          ],
        ),
      ),
    ],
  );
});
