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

/// Mot hanh dong nguoi choi gui len host.
///
/// `sealed` de compiler bat duoc moi cho quen xu ly mot loai hanh dong moi.
sealed class TicTacToeAction {
  const TicTacToeAction();
}

/// Mot nuoc di: danh vao o so [cell], dem tu 0 den 399 theo hang.
class TicTacToeMove extends TicTacToeAction {
  const TicTacToeMove(this.cell);

  final int cell;

  @override
  String toString() => 'TicTacToeMove($cell)';
}

/// Xin hoa. Doi thu tra loi bang [TicTacToeDrawAccept] hoac
/// [TicTacToeDrawReject].
///
/// Co caro tu do la the thang cua ben di truoc, nen ben di sau can duong ra
/// khi the co da hoa ro rang - keo dai them chi la go het ban co.
class TicTacToeDrawOffer extends TicTacToeAction {
  const TicTacToeDrawOffer();
}

class TicTacToeDrawAccept extends TicTacToeAction {
  const TicTacToeDrawAccept();
}

class TicTacToeDrawReject extends TicTacToeAction {
  const TicTacToeDrawReject();
}

class TicTacToeResign extends TicTacToeAction {
  const TicTacToeResign();
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
    this.moveLog = const [],
    this.drawOfferBy,
    this.drawRejections = const [0, 0],
    this.terminalResult,
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

  /// Cac o da danh, theo thu tu thoi gian.
  final List<int> moveLog;

  /// Ai dang treo loi cau hoa. Null la khong co.
  final PlayerId? drawOfferBy;

  /// So lan loi cau hoa cua tung nguoi bi tu choi, theo thu tu [players].
  final List<int> drawRejections;

  /// Ket qua do platform quyet dinh chu khong phai luat co: xin thua, hoa
  /// theo thoa thuan, bi tu choi cau hoa ba lan.
  final GameResult? terminalResult;

  int drawRejectionsOf(PlayerId player) =>
      drawRejections[players.indexOf(player)];

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
class TicTacToeGame extends GameDefinition<TicTacToeState, TicTacToeAction> {
  const TicTacToeGame();

  static const boardSize = 20;
  static const winLength = 5;

  @override
  GameId get id => 'tic-tac-toe';

  @override
  String get name => 'Cờ caro';

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
    TicTacToeAction action,
  ) {
    if (isFinished(state)) {
      return const ValidationResult.invalid('GAME_FINISHED');
    }
    // Dang co loi cau hoa treo thi khong ai duoc danh tiep: nguoi duoc hoi
    // phai tra loi truoc, con nguoi hoi thi phai cho.
    if (state.drawOfferBy != null) {
      if (actor == state.drawOfferBy) {
        return const ValidationResult.invalid('WAITING_FOR_DRAW_RESPONSE');
      }
      return switch (action) {
        TicTacToeDrawAccept() ||
        TicTacToeDrawReject() ||
        TicTacToeResign() =>
          const ValidationResult.valid(),
        _ => const ValidationResult.invalid('DRAW_RESPONSE_REQUIRED'),
      };
    }
    if (actor != state.currentPlayer) {
      return const ValidationResult.invalid('NOT_YOUR_TURN');
    }
    if (action is TicTacToeDrawOffer) {
      return state.drawRejectionsOf(actor) < 3
          ? const ValidationResult.valid()
          : const ValidationResult.invalid('DRAW_LIMIT_REACHED');
    }
    if (action is TicTacToeResign) return const ValidationResult.valid();
    if (action is! TicTacToeMove) {
      return const ValidationResult.invalid('NO_DRAW_OFFER');
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
    TicTacToeAction action,
  ) {
    switch (action) {
      case TicTacToeDrawOffer():
        return _withDecision(state, drawOfferBy: actor);
      case TicTacToeDrawAccept():
        return _withDecision(
          state,
          result: const GameResult.draw(reason: 'DRAW_AGREED'),
        );
      case TicTacToeDrawReject():
        // Bi tu choi ba lan thi nguoi hoi thua. Neu khong, mot ben co the cau
        // hoa lien tuc de doi thu khong con luot nao de danh.
        final counts = List<int>.of(state.drawRejections);
        final offerer = state.drawOfferBy!;
        counts[state.players.indexOf(offerer)]++;
        return _withDecision(
          state,
          drawRejections: counts,
          result: counts[state.players.indexOf(offerer)] == 3
              ? GameResult.win(actor, reason: 'DRAW_REJECTED_THREE_TIMES')
              : null,
        );
      case TicTacToeResign():
        final winner = otherPlayer(state.players, actor);
        return _withDecision(
          state,
          result: winner == null
              ? const GameResult.abandoned(reason: 'RESIGN')
              : GameResult.win(winner, reason: 'RESIGN'),
        );
      case TicTacToeMove():
        break;
    }

    final board = List<Mark?>.of(state.board);
    board[action.cell] = state.currentMark;

    return TicTacToeState(
      board: board,
      players: state.players,
      xPlayerIndex: state.xPlayerIndex,
      turnIndex: (state.turnIndex + 1) % state.players.length,
      winningLine: _findWinningLine(board),
      moveLog: [...state.moveLog, action.cell],
      drawRejections: state.drawRejections,
    );
  }

  /// Giu nguyen ban co, chi doi phan cau hoa / ket qua.
  TicTacToeState _withDecision(
    TicTacToeState state, {
    PlayerId? drawOfferBy,
    List<int>? drawRejections,
    GameResult? result,
  }) =>
      TicTacToeState(
        board: state.board,
        players: state.players,
        xPlayerIndex: state.xPlayerIndex,
        turnIndex: state.turnIndex,
        winningLine: state.winningLine,
        moveLog: state.moveLog,
        drawOfferBy: drawOfferBy,
        drawRejections: drawRejections ?? state.drawRejections,
        terminalResult: result,
      );

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
            if (nextRow < 0 ||
                nextRow >= boardSize ||
                nextColumn < 0 ||
                nextColumn >= boardSize) {
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
      state.terminalResult != null || state.hasWinner || state.isBoardFull;

  @override
  GameResult getResult(TicTacToeState state) {
    final terminal = state.terminalResult;
    if (terminal != null) return terminal;
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
        if (state.moveLog.isNotEmpty) 'moveLog': state.moveLog,
        if (state.drawOfferBy != null) 'drawOfferBy': state.drawOfferBy,
        'drawRejections': state.drawRejections,
        if (state.terminalResult != null)
          'terminalResult': state.terminalResult!.toJson(),
      };

  @override
  TicTacToeState decodeState(Map<String, dynamic> json) => TicTacToeState(
        board: (json['board'] as List<dynamic>)
            .map(
              (dynamic e) =>
                  e == null ? null : Mark.values.firstWhere((m) => m.name == e),
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
        moveLog: (json['moveLog'] as List<dynamic>? ?? const []).cast<int>(),
        drawOfferBy: json['drawOfferBy'] as String?,
        drawRejections:
            (json['drawRejections'] as List<dynamic>? ?? const [0, 0])
                .cast<int>(),
        terminalResult: json['terminalResult'] is Map<String, dynamic>
            ? GameResult.fromJson(json['terminalResult'] as Map<String, dynamic>)
            : null,
      );

  @override
  Map<String, dynamic> encodeAction(TicTacToeAction action) => switch (action) {
        TicTacToeMove() => {'cell': action.cell},
        TicTacToeDrawOffer() => const {'type': 'offerDraw'},
        TicTacToeDrawAccept() => const {'type': 'acceptDraw'},
        TicTacToeDrawReject() => const {'type': 'rejectDraw'},
        TicTacToeResign() => const {'type': 'resign'},
      };

  @override
  TicTacToeAction decodeAction(Map<String, dynamic> json) =>
      switch (json['type']) {
        'offerDraw' => const TicTacToeDrawOffer(),
        'acceptDraw' => const TicTacToeDrawAccept(),
        'rejectDraw' => const TicTacToeDrawReject(),
        'resign' => const TicTacToeResign(),
        _ => TicTacToeMove(json['cell'] as int),
      };
}
