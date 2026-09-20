import 'package:platform_core/platform_core.dart';

/// Ky hieu cua mot o tren ban co.
enum Mark { x, o }

/// Mot nuoc di: danh vao o so [cell], dem tu 0 den 399 theo hang.
class TicTacToeMove {
  const TicTacToeMove(this.cell);

  final int cell;

  @override
  String toString() => 'TicTacToeMove($cell)';
}

/// State cua mot van co caro 20x20, thang khi co 5 quan lien tiep.
///
/// Bat bien: khong co ham nao sua doi state tai cho. [TicTacToeGame.apply]
/// luon tra ve mot state moi.
class TicTacToeState {
  const TicTacToeState({
    required this.board,
    required this.players,
    required this.xPlayerIndex,
    required this.turnIndex,
    this.winningLine,
  });

  /// 400 o. `null` la o trong.
  final List<Mark?> board;

  /// Thu tu ngoi. Ky hieu duoc luu trong [xPlayerIndex].
  final List<PlayerId> players;

  /// Vi tri cua nguoi choi X trong [players].
  final int xPlayerIndex;

  /// Vi tri trong [players] cua nguoi dang den luot.
  final int turnIndex;

  /// Cac o tao thanh duong 5 quan thang cuoc, de UI to sang.
  final List<int>? winningLine;

  PlayerId get currentPlayer => players[turnIndex];

  Mark get currentMark => turnIndex == xPlayerIndex ? Mark.x : Mark.o;

  Mark markOf(PlayerId player) {
    final index = players.indexOf(player);
    return index == xPlayerIndex ? Mark.x : Mark.o;
  }

  bool get isBoardFull => board.every((cell) => cell != null);

  bool get hasWinner => winningLine != null;

  /// Nguoi thang, hoac null neu chua ai thang.
  PlayerId? get winner {
    final line = winningLine;
    if (line == null) return null;
    final mark = board[line.first]!;
    final playerIndex = mark == Mark.x ? xPlayerIndex : 1 - xPlayerIndex;
    return players[playerIndex];
  }
}

/// Co caro 20x20, thang khi co 5 quan lien tiep.
///
/// Toan bo file nay la pure Dart va khong biet gi ve socket, IP, phong hay
/// giao dien. Do la toan bo dieu kien de mot game duoc cam vao platform.
class TicTacToeGame extends GameDefinition<TicTacToeState, TicTacToeMove> {
  const TicTacToeGame();

  static const boardSize = 20;
  static const winLength = 5;

  @override
  GameId get id => 'tic-tac-toe';

  @override
  String get name => 'Co caro 20x20';

  @override
  int get minPlayers => 2;

  @override
  int get maxPlayers => 2;

  @override
  TicTacToeState createInitialState(
    List<PlayerId> players, {
    required int seed,
    Map<String, dynamic> options = const {},
  }) {
    final selectedHostMark = options['hostMark'] == 'o' ? Mark.o : Mark.x;
    final xPlayerIndex = selectedHostMark == Mark.x ? 0 : 1;
    return TicTacToeState(
      board: List<Mark?>.filled(boardSize * boardSize, null),
      players: List<PlayerId>.unmodifiable(players.take(2)),
      xPlayerIndex: xPlayerIndex,
      turnIndex: xPlayerIndex,
    );
  }

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
    if (action.cell < 0 || action.cell >= boardSize * boardSize) {
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
      xPlayerIndex: state.xPlayerIndex,
      turnIndex: (state.turnIndex + 1) % state.players.length,
      winningLine: _findWinningLine(board),
    );
  }

  static List<int>? _findWinningLine(List<Mark?> board) {
    const directions = [(0, 1), (1, 0), (1, 1), (1, -1)];
    for (var row = 0; row < boardSize; row++) {
      for (var column = 0; column < boardSize; column++) {
        final mark = board[row * boardSize + column];
        if (mark == null) continue;
        for (final (rowStep, columnStep) in directions) {
          final line = <int>[];
          for (var offset = 0; offset < winLength; offset++) {
            final nextRow = row + rowStep * offset;
            final nextColumn = column + columnStep * offset;
            if (nextRow < 0 || nextRow >= boardSize ||
                nextColumn < 0 || nextColumn >= boardSize) {
              break;
            }
            final index = nextRow * boardSize + nextColumn;
            if (board[index] != mark) break;
            line.add(index);
          }
          if (line.length == winLength) return line;
        }
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
        'xPlayerIndex': state.xPlayerIndex,
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
        xPlayerIndex: json['xPlayerIndex'] as int? ?? 0,
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
