import 'package:platform_core/platform_core.dart';

/// Ky hieu cua mot o tren ban co.
enum Mark { x, o }

/// Mot nuoc di: danh vao o so [cell], dem tu 0 den 8 theo hang.
class TicTacToeMove {
  const TicTacToeMove(this.cell);

  final int cell;

  @override
  String toString() => 'TicTacToeMove($cell)';
}

/// State cua mot van co caro 3x3.
///
/// Bat bien: khong co ham nao sua doi state tai cho. [TicTacToeGame.apply]
/// luon tra ve mot state moi.
class TicTacToeState {
  const TicTacToeState({
    required this.board,
    required this.players,
    required this.turnIndex,
    this.winningLine,
  });

  /// 9 o. `null` la o trong.
  final List<Mark?> board;

  /// Thu tu di. players[0] danh X, players[1] danh O.
  final List<PlayerId> players;

  /// Vi tri trong [players] cua nguoi dang den luot.
  final int turnIndex;

  /// Ba o tao thanh duong thang thang cuoc, de UI to sang.
  final List<int>? winningLine;

  PlayerId get currentPlayer => players[turnIndex];

  Mark get currentMark => turnIndex == 0 ? Mark.x : Mark.o;

  Mark markOf(PlayerId player) {
    final index = players.indexOf(player);
    return index == 0 ? Mark.x : Mark.o;
  }

  bool get isBoardFull => board.every((cell) => cell != null);

  bool get hasWinner => winningLine != null;

  /// Nguoi thang, hoac null neu chua ai thang.
  PlayerId? get winner {
    final line = winningLine;
    if (line == null) return null;
    final mark = board[line.first]!;
    return players[mark == Mark.x ? 0 : 1];
  }
}

/// Co caro 3x3 - game dau tien, dung de kiem chung ca platform.
///
/// Toan bo file nay la pure Dart va khong biet gi ve socket, IP, phong hay
/// giao dien. Do la toan bo dieu kien de mot game duoc cam vao platform.
class TicTacToeGame extends GameDefinition<TicTacToeState, TicTacToeMove> {
  const TicTacToeGame();

  static const List<List<int>> _lines = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6],
  ];

  @override
  GameId get id => 'tic-tac-toe';

  @override
  String get name => 'Co caro 3x3';

  @override
  int get minPlayers => 2;

  @override
  int get maxPlayers => 2;

  @override
  TicTacToeState createInitialState(
    List<PlayerId> players, {
    required int seed,
  }) =>
      TicTacToeState(
        board: List<Mark?>.filled(9, null),
        players: List<PlayerId>.unmodifiable(players.take(2)),
        turnIndex: 0,
      );

  @override
  List<PlayerId> currentActors(TicTacToeState state) =>
      isFinished(state) ? const [] : [state.currentPlayer];

  @override
  ValidationResult validate(
    TicTacToeState state,
    PlayerId actor,
    TicTacToeMove action,
  ) {
    if (isFinished(state)) {
      return const ValidationResult.invalid('GAME_FINISHED');
    }
    if (actor != state.currentPlayer) {
      return const ValidationResult.invalid('NOT_YOUR_TURN');
    }
    if (action.cell < 0 || action.cell > 8) {
      return const ValidationResult.invalid('OUT_OF_BOARD');
    }
    if (state.board[action.cell] != null) {
      return const ValidationResult.invalid(
        'CELL_TAKEN',
        'O nay da co nguoi danh',
      );
    }
    return const ValidationResult.valid();
  }

  @override
  TicTacToeState apply(
    TicTacToeState state,
    PlayerId actor,
    TicTacToeMove action,
  ) {
    final board = List<Mark?>.of(state.board);
    board[action.cell] = state.currentMark;

    return TicTacToeState(
      board: board,
      players: state.players,
      turnIndex: (state.turnIndex + 1) % state.players.length,
      winningLine: _findWinningLine(board),
    );
  }

  static List<int>? _findWinningLine(List<Mark?> board) {
    for (final line in _lines) {
      final first = board[line[0]];
      if (first != null &&
          board[line[1]] == first &&
          board[line[2]] == first) {
        return line;
      }
    }
    return null;
  }

  @override
  bool isFinished(TicTacToeState state) =>
      state.hasWinner || state.isBoardFull;

  @override
  GameResult getResult(TicTacToeState state) {
    final winner = state.winner;
    if (winner != null) return GameResult.win(winner);
    return const GameResult.draw();
  }

  @override
  Map<String, dynamic> encodeState(TicTacToeState state) => {
        'board': state.board.map((m) => m?.name).toList(),
        'players': state.players,
        'turnIndex': state.turnIndex,
        if (state.winningLine != null) 'winningLine': state.winningLine,
      };

  @override
  TicTacToeState decodeState(Map<String, dynamic> json) => TicTacToeState(
        board: (json['board'] as List<dynamic>)
            .map(
              (dynamic e) => e == null
                  ? null
                  : Mark.values.firstWhere((m) => m.name == e),
            )
            .toList(growable: false),
        players: (json['players'] as List<dynamic>)
            .map((dynamic e) => e as String)
            .toList(growable: false),
        turnIndex: json['turnIndex'] as int,
        winningLine: (json['winningLine'] as List<dynamic>?)
            ?.map((dynamic e) => e as int)
            .toList(growable: false),
      );

  @override
  Map<String, dynamic> encodeAction(TicTacToeMove action) =>
      {'cell': action.cell};

  @override
  TicTacToeMove decodeAction(Map<String, dynamic> json) =>
      TicTacToeMove(json['cell'] as int);
}
