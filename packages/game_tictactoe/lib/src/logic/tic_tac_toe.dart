import 'dart:math';

import 'package:platform_core/platform_core.dart';

/// Ky hieu cua mot o tren ban co.
enum Mark { x, o }

/// Cac cap do cho may. Cac muc kho danh theo on dinh cua thuat toan.
enum TicTacToeDifficulty {
  easy,
  medium,
  hard,
  expert,
}

extension TicTacToeDifficultyLabel on TicTacToeDifficulty {
  String get label {
    switch (this) {
      case TicTacToeDifficulty.easy:
        return 'Dễ';
      case TicTacToeDifficulty.medium:
        return 'Trung bình';
      case TicTacToeDifficulty.hard:
        return 'Khó';
      case TicTacToeDifficulty.expert:
        return 'Chuyên gia';
    }
  }
}

/// Mot nuoc di: danh vao o so [cell], dem tu 0 den 399 theo hang.
class TicTacToeMove {
  const TicTacToeMove(this.cell);

  final int cell;

  @override
  String toString() => 'TicTacToeMove($cell)';
}

/// May danh trong van choi offline.
class TicTacToeAi {
  static const _inf = 1 << 30;
  static final Random _random = Random();

  static int? pickMove(
    TicTacToeState state,
    PlayerId actor,
    TicTacToeDifficulty difficulty,
  ) {
    final empty = <int>[];
    for (var cell = 0; cell < state.board.length; cell++) {
      if (state.board[cell] == null) empty.add(cell);
    }
    if (empty.isEmpty) return null;

    switch (difficulty) {
      case TicTacToeDifficulty.easy:
        return empty[_random.nextInt(empty.length)];
      case TicTacToeDifficulty.medium:
        return _pickByStrategy(state, actor, empty, maxDepth: 1);
      case TicTacToeDifficulty.hard:
        return _pickByMinimax(state, actor, empty, depth: 2, candidateLimit: 10);
      case TicTacToeDifficulty.expert:
        return _pickByMinimax(state, actor, empty, depth: 3, candidateLimit: 14);
    }
  }

  static int _pickByStrategy(
    TicTacToeState state,
    PlayerId actor,
    List<int> empty, {
    required int maxDepth,
  }) {
    final immediateWin = _findImmediateWinningMove(state, actor, empty);
    if (immediateWin != null) return immediateWin;

    final opponent = _opponent(state, actor);
    final immediateBlock = _findImmediateWinningMove(state, opponent, empty);
    if (immediateBlock != null) return immediateBlock;

    final ordered = _rankMoves(state, actor, empty);
    return ordered.first;
  }

  static int _pickByMinimax(
    TicTacToeState state,
    PlayerId actor,
    List<int> empty, {
    required int depth,
    required int candidateLimit,
  }) {
    final ordered = _rankMoves(state, actor, empty, limit: candidateLimit);
    var bestMove = ordered.first;
    var bestScore = -_inf;

    for (final cell in ordered) {
      final next = const TicTacToeGame().apply(
        state,
        actor,
        TicTacToeMove(cell),
      );
      final score = _minimax(
        next,
        _opponent(state, actor),
        depth - 1,
        -_inf,
        _inf,
        false,
        actor,
      );
      if (score > bestScore) {
        bestScore = score;
        bestMove = cell;
      }
    }

    return bestMove;
  }

  static int _minimax(
    TicTacToeState state,
    PlayerId actor,
    int depth,
    int alpha,
    int beta,
    bool maximizing,
    PlayerId rootActor,
  ) {
    if (state.hasWinner) {
      final winner = state.winner;
      if (winner == rootActor) return 100000 + depth;
      if (winner != null) return -100000 - depth;
    }
    if (state.isBoardFull || depth <= 0) {
      return _evaluateBoard(state, rootActor);
    }

    final empty = <int>[];
    for (var cell = 0; cell < state.board.length; cell++) {
      if (state.board[cell] == null) empty.add(cell);
    }

    final ordered = _rankMoves(state, actor, empty, limit: 12);
    var currentAlpha = alpha;
    var currentBeta = beta;

    if (maximizing) {
      var best = -_inf;
      for (final cell in ordered) {
        final next = const TicTacToeGame().apply(
          state,
          actor,
          TicTacToeMove(cell),
        );
        final score = _minimax(
          next,
          _opponent(state, actor),
          depth - 1,
          currentAlpha,
          currentBeta,
          false,
          rootActor,
        );
        best = best > score ? best : score;
        currentAlpha = currentAlpha > best ? currentAlpha : best;
        if (currentBeta <= currentAlpha) break;
      }
      return best;
    }

    var best = _inf;
    for (final cell in ordered) {
      final next = const TicTacToeGame().apply(
        state,
        actor,
        TicTacToeMove(cell),
      );
      final score = _minimax(
        next,
        _opponent(state, actor),
        depth - 1,
        currentAlpha,
        currentBeta,
        true,
        rootActor,
      );
      best = best < score ? best : score;
      currentBeta = currentBeta < best ? currentBeta : best;
      if (currentBeta <= currentAlpha) break;
    }
    return best;
  }

  static int? _findImmediateWinningMove(
    TicTacToeState state,
    PlayerId actor,
    List<int> empty,
  ) {
    for (final cell in empty) {
      final next = const TicTacToeGame().apply(
        state,
        actor,
        TicTacToeMove(cell),
      );
      if (next.winner == actor) return cell;
    }
    return null;
  }

  static List<int> _rankMoves(
    TicTacToeState state,
    PlayerId actor,
    List<int> empty, {
    int limit = 12,
  }) {
    final scored = <MapEntry<int, int>>[];
    for (final cell in empty) {
      final score = _moveScore(state, actor, cell);
      scored.add(MapEntry(cell, score));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(limit).map((entry) => entry.key).toList(growable: false);
  }

  static int _moveScore(TicTacToeState state, PlayerId actor, int cell) {
    final board = List<Mark?>.of(state.board);
    board[cell] = state.markOf(actor);

    final immediate = _isWinningMove(state, actor, cell)
        ? 100000
        : 0;
    final center = _isCenter(cell) ? 160 : 0;
    final adjacency = _adjacencyBonus(cell);
    final safety = _evaluateBoard(
      TicTacToeState(
        board: board,
        players: state.players,
        xPlayerIndex: state.xPlayerIndex,
        turnIndex: state.turnIndex,
        winningLine: state.winningLine,
      ),
      actor,
    );

    return immediate + center + adjacency + safety;
  }

  static int _evaluateBoard(TicTacToeState state, PlayerId actor) {
    final opponent = _opponent(state, actor);
    final actorMark = state.markOf(actor);
    final opponentMark = state.markOf(opponent);
    var score = 0;

    for (var row = 0; row < TicTacToeGame.boardSize; row++) {
      for (var column = 0; column < TicTacToeGame.boardSize; column++) {
        final start = row * TicTacToeGame.boardSize + column;
        for (final (rowStep, columnStep) in const [(0, 1), (1, 0), (1, 1), (1, -1)]) {
          final cells = <int>[];
          for (var offset = 0; offset < TicTacToeGame.winLength; offset++) {
            final nextRow = row + rowStep * offset;
            final nextColumn = column + columnStep * offset;
            if (nextRow < 0 ||
                nextRow >= TicTacToeGame.boardSize ||
                nextColumn < 0 ||
                nextColumn >= TicTacToeGame.boardSize) {
              break;
            }
            cells.add(nextRow * TicTacToeGame.boardSize + nextColumn);
          }
          if (cells.length < TicTacToeGame.winLength) continue;

          final actorCount = cells.fold<int>(0, (sum, cell) {
            return sum + (state.board[cell] == actorMark ? 1 : 0);
          });
          final opponentCount = cells.fold<int>(0, (sum, cell) {
            return sum + (state.board[cell] == opponentMark ? 1 : 0);
          });
          final emptyCount = cells.fold<int>(0, (sum, cell) {
            return sum + (state.board[cell] == null ? 1 : 0);
          });

          if (actorCount > 0 && opponentCount == 0) {
            score += switch (actorCount) {
              1 => 2,
              2 => 30,
              3 => 200,
              4 => 8000,
              _ => 100000,
            };
            if (emptyCount == 1 && actorCount == 4) score += 5000;
          }
          if (opponentCount > 0 && actorCount == 0) {
            score -= switch (opponentCount) {
              1 => 2,
              2 => 35,
              3 => 220,
              4 => 9000,
              _ => 120000,
            };
            if (emptyCount == 1 && opponentCount == 4) score -= 6000;
          }
        }
      }
    }

    return score;
  }

  static bool _isCenter(int cell) {
    final center = TicTacToeGame.boardSize ~/ 2;
    final row = cell ~/ TicTacToeGame.boardSize;
    final column = cell % TicTacToeGame.boardSize;
    return (row - center).abs() <= 1 && (column - center).abs() <= 1;
  }

  static int _adjacencyBonus(int cell) {
    final row = cell ~/ TicTacToeGame.boardSize;
    final column = cell % TicTacToeGame.boardSize;
    final center = TicTacToeGame.boardSize ~/ 2;
    final distance = ((row - center).abs() + (column - center).abs());
    return switch (distance) {
      0 => 30,
      1 => 12,
      2 => 4,
      _ => 0,
    };
  }

  static bool _isWinningMove(TicTacToeState state, PlayerId actor, int cell) {
    final next = const TicTacToeGame().apply(
      state,
      actor,
      TicTacToeMove(cell),
    );
    return next.winner == actor;
  }

  static PlayerId _opponent(TicTacToeState state, PlayerId actor) {
    return state.players.firstWhere((player) => player != actor);
  }
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
