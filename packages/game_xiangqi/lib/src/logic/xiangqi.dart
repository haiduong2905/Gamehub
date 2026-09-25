import 'dart:math';

import 'package:platform_core/platform_core.dart';

enum XiangqiPieceType {
  king,
  advisor,
  bishop,
  rook,
  knight,
  cannon,
  pawn,
}

enum XiangqiPieceColor { red, black }

class XiangqiPiece {
  const XiangqiPiece({required this.color, required this.type});

  final XiangqiPieceColor color;
  final XiangqiPieceType type;

  String get glyph {
    switch ((color, type)) {
      case (XiangqiPieceColor.red, XiangqiPieceType.king):
        return '帥';
      case (XiangqiPieceColor.black, XiangqiPieceType.king):
        return '將';
      case (XiangqiPieceColor.red, XiangqiPieceType.advisor):
        return '仕';
      case (XiangqiPieceColor.black, XiangqiPieceType.advisor):
        return '士';
      case (XiangqiPieceColor.red, XiangqiPieceType.bishop):
        return '相';
      case (XiangqiPieceColor.black, XiangqiPieceType.bishop):
        return '象';
      case (XiangqiPieceColor.red, XiangqiPieceType.rook):
        return '車';
      case (XiangqiPieceColor.black, XiangqiPieceType.rook):
        return '車';
      case (XiangqiPieceColor.red, XiangqiPieceType.knight):
        return '馬';
      case (XiangqiPieceColor.black, XiangqiPieceType.knight):
        return '馬';
      case (XiangqiPieceColor.red, XiangqiPieceType.cannon):
        return '砲';
      case (XiangqiPieceColor.black, XiangqiPieceType.cannon):
        return '炮';
      case (XiangqiPieceColor.red, XiangqiPieceType.pawn):
        return '兵';
      case (XiangqiPieceColor.black, XiangqiPieceType.pawn):
        return '卒';
    }
  }

  bool get isRed => color == XiangqiPieceColor.red;
  bool get isBlack => color == XiangqiPieceColor.black;

  bool operator ==(Object other) =>
      other is XiangqiPiece && other.color == color && other.type == type;

  @override
  int get hashCode => Object.hash(color, type);
}

sealed class XiangqiAction {
  const XiangqiAction();
}

class XiangqiMove extends XiangqiAction {
  const XiangqiMove({required this.from, required this.to});

  final int from;
  final int to;

  @override
  String toString() => 'XiangqiMove($from -> $to)';
}

class XiangqiDrawOffer extends XiangqiAction {
  const XiangqiDrawOffer();
}

class XiangqiDrawAccept extends XiangqiAction {
  const XiangqiDrawAccept();
}

class XiangqiDrawReject extends XiangqiAction {
  const XiangqiDrawReject();
}

class XiangqiResign extends XiangqiAction {
  const XiangqiResign();
}

class XiangqiState {
  const XiangqiState({
    required this.board,
    required this.players,
    required this.turnIndex,
    this.redPlayerIndex = 0,
    this.lastMove,
    this.ply = 0,
    this.lastMoveWasCapture = false,
    this.capturedPieces = const [],
    this.moveLog = const [],
    this.drawOfferBy,
    this.drawRejections = const [0, 0],
    this.terminalResult,
  });

  final List<XiangqiPiece?> board;
  final List<PlayerId> players;
  final int turnIndex;
  final int redPlayerIndex;
  final XiangqiMove? lastMove;
  final int ply;
  final bool lastMoveWasCapture;

  /// Quân đã bị ăn, theo thứ tự thời gian; màu là phe bị mất quân.
  final List<XiangqiPiece> capturedPieces;

  /// Các nước đã đi, gói phẳng thành [from0, to0, from1, to1, ...].
  ///
  /// Gói phẳng chứ không phải danh sách đối tượng vì nó phải đi qua JSON mỗi
  /// lượt: một danh sách số nguyên rẻ hơn hẳn một danh sách bản đồ.
  final List<int> moveLog;
  final PlayerId? drawOfferBy;
  final List<int> drawRejections;
  final GameResult? terminalResult;

  int drawRejectionsOf(PlayerId player) =>
      drawRejections[players.indexOf(player)];

  PlayerId get currentPlayer => players[turnIndex];

  XiangqiPieceColor pieceColorOf(PlayerId player) {
    final index = players.indexOf(player);
    if (index == redPlayerIndex) return XiangqiPieceColor.red;
    if (index >= 0) return XiangqiPieceColor.black;
    throw StateError('Player $player khong thuoc van co');
  }

  PlayerId get oppositePlayer => players[(turnIndex + 1) % players.length];
}

enum XiangqiDifficulty { easy, medium, hard, expert }

class XiangqiGame extends GameDefinition<XiangqiState, XiangqiAction> {
  const XiangqiGame();

  static const boardRows = 10;
  static const boardColumns = 9;
  static const int totalCells = boardRows * boardColumns;

  @override
  GameId get id => 'xiangqi';

  @override
  String get name => 'Cờ tướng';

  @override
  int get minPlayers => 2;

  @override
  int get maxPlayers => 2;

  @override
  XiangqiState createInitialState(
    List<PlayerId> players, {
    required int seed,
    Map<String, dynamic> options = const {},
  }) {
    if (players.length != 2 || players[0] == players[1]) {
      throw ArgumentError.value(
          players, 'players', 'Co tuong can dung 2 nguoi khac nhau');
    }
    final board = List<XiangqiPiece?>.filled(totalCells, null, growable: false);
    _placeInitialPieces(board, XiangqiPieceColor.black, 0);
    _placeInitialPieces(board, XiangqiPieceColor.red, 9);
    final redPlayerIndex = options['hostColor'] == 'black' ? 1 : 0;
    return XiangqiState(
      board: board,
      players: List<PlayerId>.unmodifiable(players),
      turnIndex: redPlayerIndex,
      redPlayerIndex: redPlayerIndex,
    );
  }

  static void _placeInitialPieces(
      List<XiangqiPiece?> board, XiangqiPieceColor color, int rowBase) {
    final isRed = color == XiangqiPieceColor.red;
    final backRankRow = isRed ? 9 : 0;
    final cannonRow = isRed ? 7 : 2;
    final pawnRow = isRed ? 6 : 3;

    final pieces = [
      XiangqiPieceType.rook,
      XiangqiPieceType.knight,
      XiangqiPieceType.bishop,
      XiangqiPieceType.advisor,
      XiangqiPieceType.king,
      XiangqiPieceType.advisor,
      XiangqiPieceType.bishop,
      XiangqiPieceType.knight,
      XiangqiPieceType.rook,
    ];

    for (var col = 0; col < boardColumns; col++) {
      board[backRankRow * boardColumns + col] =
          XiangqiPiece(color: color, type: pieces[col]);
    }

    board[(cannonRow * boardColumns) + 1] =
        XiangqiPiece(color: color, type: XiangqiPieceType.cannon);
    board[(cannonRow * boardColumns) + 7] =
        XiangqiPiece(color: color, type: XiangqiPieceType.cannon);

    for (var col = 0; col < boardColumns; col += 2) {
      board[(pawnRow * boardColumns) + col] =
          XiangqiPiece(color: color, type: XiangqiPieceType.pawn);
    }
  }

  @override
  List<PlayerId> currentActors(XiangqiState state) => isFinished(state)
      ? const []
      : [
          state.drawOfferBy == null
              ? state.currentPlayer
              : state.players
                  .firstWhere((player) => player != state.drawOfferBy)
        ];

  @override
  ValidationResult validate(
    XiangqiState state,
    PlayerId actor,
    XiangqiAction action,
  ) {
    if (isFinished(state)) {
      return const ValidationResult.invalid('GAME_FINISHED');
    }
    if (state.drawOfferBy != null) {
      if (actor == state.drawOfferBy) {
        return const ValidationResult.invalid('WAITING_FOR_DRAW_RESPONSE');
      }
      return switch (action) {
        XiangqiDrawAccept() ||
        XiangqiDrawReject() ||
        XiangqiResign() =>
          const ValidationResult.valid(),
        _ => const ValidationResult.invalid('DRAW_RESPONSE_REQUIRED'),
      };
    }
    if (actor != state.currentPlayer) {
      return const ValidationResult.invalid('NOT_YOUR_TURN');
    }
    if (action is XiangqiDrawOffer) {
      return state.drawRejectionsOf(actor) < 3
          ? const ValidationResult.valid()
          : const ValidationResult.invalid('DRAW_LIMIT_REACHED');
    }
    if (action is XiangqiResign) return const ValidationResult.valid();
    if (action is! XiangqiMove) {
      return const ValidationResult.invalid('NO_DRAW_OFFER');
    }
    if (action.from < 0 ||
        action.to < 0 ||
        action.from >= totalCells ||
        action.to >= totalCells) {
      return const ValidationResult.invalid('OUT_OF_BOARD');
    }
    if (action.from == action.to) {
      return const ValidationResult.invalid('INVALID_MOVE');
    }

    final piece = state.board[action.from];
    if (piece == null) {
      return const ValidationResult.invalid('NO_PIECE');
    }
    if (piece.color != state.pieceColorOf(actor)) {
      return const ValidationResult.invalid('WRONG_SIDE');
    }

    final legal = legalMovesFor(state, actor)
        .where((move) => move.from == action.from && move.to == action.to)
        .toList();
    if (legal.isEmpty) {
      return const ValidationResult.invalid('ILLEGAL_MOVE');
    }

    return const ValidationResult.valid();
  }

  @override
  XiangqiState apply(
    XiangqiState state,
    PlayerId actor,
    XiangqiAction action,
  ) {
    switch (action) {
      case XiangqiDrawOffer():
        return XiangqiState(
          board: state.board,
          players: state.players,
          turnIndex: state.turnIndex,
          redPlayerIndex: state.redPlayerIndex,
          lastMove: state.lastMove,
          ply: state.ply,
          lastMoveWasCapture: state.lastMoveWasCapture,
          capturedPieces: state.capturedPieces,
          drawOfferBy: actor,
          drawRejections: state.drawRejections,
        );
      case XiangqiDrawAccept():
        return _withDecision(state,
            result: const GameResult.draw(reason: 'DRAW_AGREED'));
      case XiangqiDrawReject():
        final counts = List<int>.of(state.drawRejections);
        final offerer = state.drawOfferBy!;
        counts[state.players.indexOf(offerer)]++;
        return _withDecision(state,
            drawRejections: counts,
            result: counts[state.players.indexOf(offerer)] == 3
                ? GameResult.win(actor, reason: 'DRAW_REJECTED_THREE_TIMES')
                : null);
      case XiangqiResign():
        return _withDecision(state,
            result: GameResult.win(
                state.players.firstWhere((player) => player != actor),
                reason: 'RESIGN'));
      case XiangqiMove():
        break;
    }
    final board = List<XiangqiPiece?>.from(state.board, growable: false);
    final piece = board[action.from];
    if (piece == null) throw StateError('Khong co quan o diem bat dau');
    final captured = board[action.to];
    board[action.from] = null;
    board[action.to] = piece;
    final nextPlayers = List<PlayerId>.from(state.players, growable: false);
    final nextTurnIndex = (state.turnIndex + 1) % nextPlayers.length;
    return XiangqiState(
      board: board,
      players: nextPlayers,
      turnIndex: nextTurnIndex,
      redPlayerIndex: state.redPlayerIndex,
      lastMove: action,
      ply: state.ply + 1,
      lastMoveWasCapture: captured != null,
      capturedPieces: captured == null
          ? state.capturedPieces
          : [...state.capturedPieces, captured],
      moveLog: [...state.moveLog, action.from, action.to],
      drawRejections: state.drawRejections,
    );
  }

  XiangqiState _withDecision(
    XiangqiState state, {
    List<int>? drawRejections,
    GameResult? result,
  }) =>
      XiangqiState(
        board: state.board,
        players: state.players,
        turnIndex: state.turnIndex,
        redPlayerIndex: state.redPlayerIndex,
        lastMove: state.lastMove,
        ply: state.ply,
        lastMoveWasCapture: state.lastMoveWasCapture,
        capturedPieces: state.capturedPieces,
        moveLog: state.moveLog,
        drawRejections: drawRejections ?? state.drawRejections,
        terminalResult: result,
      );

  @override
  bool isFinished(XiangqiState state) {
    if (state.terminalResult != null) return true;
    if (_findKing(state.board, XiangqiPieceColor.red) == null ||
        _findKing(state.board, XiangqiPieceColor.black) == null) return true;
    final current = state.currentPlayer;
    final moves = legalMovesFor(state, current);
    if (moves.isEmpty && isInCheck(state, current)) return true;
    if (moves.isEmpty) return true;
    return false;
  }

  @override
  GameResult getResult(XiangqiState state) {
    if (state.terminalResult != null) return state.terminalResult!;
    if (_findKing(state.board, XiangqiPieceColor.red) == null) {
      return GameResult.win(state.players[1 - state.redPlayerIndex],
          reason: 'KING_CAPTURED');
    }
    if (_findKing(state.board, XiangqiPieceColor.black) == null) {
      return GameResult.win(state.players[state.redPlayerIndex],
          reason: 'KING_CAPTURED');
    }
    final current = state.currentPlayer;
    final opponent = state.oppositePlayer;
    if (legalMovesFor(state, current).isEmpty) {
      if (isInCheck(state, current)) {
        return GameResult.win(opponent, reason: 'CHECKMATE');
      }
      return const GameResult.draw();
    }
    return const GameResult.draw();
  }

  @override
  Map<String, dynamic> encodeState(XiangqiState state) => {
        'board': state.board
            .map((piece) => piece == null
                ? null
                : {'color': piece.color.name, 'type': piece.type.name})
            .toList(),
        'players': state.players,
        'turnIndex': state.turnIndex,
        'redPlayerIndex': state.redPlayerIndex,
        if (state.lastMove != null) 'lastMove': encodeAction(state.lastMove!),
        'ply': state.ply,
        'lastMoveWasCapture': state.lastMoveWasCapture,
        'capturedPieces': state.capturedPieces
            .map(
                (piece) => {'color': piece.color.name, 'type': piece.type.name})
            .toList(),
        if (state.moveLog.isNotEmpty) 'moveLog': state.moveLog,
        if (state.drawOfferBy != null) 'drawOfferBy': state.drawOfferBy,
        'drawRejections': state.drawRejections,
        if (state.terminalResult != null)
          'terminalResult': state.terminalResult!.toJson(),
      };

  @override
  XiangqiState decodeState(Map<String, dynamic> json) {
    final list = (json['board'] as List<dynamic>?) ?? const [];
    final board = List<XiangqiPiece?>.filled(totalCells, null, growable: false);
    for (var i = 0; i < list.length; i++) {
      final value = list[i];
      if (value == null) continue;
      final map = value as Map<String, dynamic>;
      board[i] = XiangqiPiece(
        color:
            XiangqiPieceColor.values.firstWhere((c) => c.name == map['color']),
        type: XiangqiPieceType.values.firstWhere((t) => t.name == map['type']),
      );
    }
    return XiangqiState(
      board: board,
      players: (json['players'] as List<dynamic>? ?? const ['red', 'black'])
          .map((e) => e as String)
          .toList(growable: false),
      turnIndex: json['turnIndex'] as int? ?? 0,
      redPlayerIndex: json['redPlayerIndex'] as int? ?? 0,
      lastMove: json['lastMove'] is Map<String, dynamic>
          ? decodeAction(json['lastMove'] as Map<String, dynamic>)
              as XiangqiMove
          : null,
      ply: json['ply'] as int? ?? 0,
      lastMoveWasCapture: json['lastMoveWasCapture'] as bool? ?? false,
      capturedPieces:
          (json['capturedPieces'] as List<dynamic>? ?? const []).map((value) {
        final piece = value as Map<String, dynamic>;
        return XiangqiPiece(
          color: XiangqiPieceColor.values
              .firstWhere((color) => color.name == piece['color']),
          type: XiangqiPieceType.values
              .firstWhere((type) => type.name == piece['type']),
        );
      }).toList(growable: false),
      moveLog: (json['moveLog'] as List<dynamic>? ?? const []).cast<int>(),
      drawOfferBy: json['drawOfferBy'] as String?,
      drawRejections: (json['drawRejections'] as List<dynamic>? ?? const [0, 0])
          .cast<int>(),
      terminalResult: json['terminalResult'] is Map<String, dynamic>
          ? GameResult.fromJson(json['terminalResult'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  Map<String, dynamic> encodeAction(XiangqiAction action) => switch (action) {
        XiangqiMove() => {'from': action.from, 'to': action.to},
        XiangqiDrawOffer() => {'type': 'offerDraw'},
        XiangqiDrawAccept() => {'type': 'acceptDraw'},
        XiangqiDrawReject() => {'type': 'rejectDraw'},
        XiangqiResign() => {'type': 'resign'},
      };

  @override
  XiangqiAction decodeAction(Map<String, dynamic> json) =>
      switch (json['type']) {
        'offerDraw' => const XiangqiDrawOffer(),
        'acceptDraw' => const XiangqiDrawAccept(),
        'rejectDraw' => const XiangqiDrawReject(),
        'resign' => const XiangqiResign(),
        null => XiangqiMove(from: json['from'] as int, to: json['to'] as int),
        _ => throw FormatException('Unknown Xiangqi action: ${json['type']}'),
      };

  static List<XiangqiMove> legalMovesFor(XiangqiState state, PlayerId actor) {
    final currentColor = state.pieceColorOf(actor);
    final moves = <XiangqiMove>[];
    for (var index = 0; index < state.board.length; index++) {
      final piece = state.board[index];
      if (piece == null || piece.color != currentColor) continue;
      final generated = _generateMovesForPiece(state, index, piece);
      for (final move in generated) {
        final next = const XiangqiGame().apply(state, actor, move);
        if (!kingsFaceEachOther(next) && !isInCheck(next, actor)) {
          moves.add(move);
        }
      }
    }
    return moves;
  }

  static List<XiangqiMove> _generateMovesForPiece(
    XiangqiState state,
    int from,
    XiangqiPiece piece,
  ) {
    final moves = <XiangqiMove>[];
    final row = from ~/ boardColumns;
    final col = from % boardColumns;

    switch (piece.type) {
      case XiangqiPieceType.king:
        for (final (dr, dc) in const [(0, 1), (0, -1), (1, 0), (-1, 0)]) {
          final nextRow = row + dr;
          final nextCol = col + dc;
          if (_insidePalace(nextRow, nextCol, piece.color) &&
              _isEmptyOrEnemy(state, nextRow, nextCol, piece.color)) {
            moves.add(XiangqiMove(from: from, to: _cell(nextRow, nextCol)));
          }
        }
      case XiangqiPieceType.advisor:
        for (final (dr, dc) in const [(1, 1), (1, -1), (-1, 1), (-1, -1)]) {
          final nextRow = row + dr;
          final nextCol = col + dc;
          if (_insidePalace(nextRow, nextCol, piece.color) &&
              _isEmptyOrEnemy(state, nextRow, nextCol, piece.color)) {
            moves.add(XiangqiMove(from: from, to: _cell(nextRow, nextCol)));
          }
        }
      case XiangqiPieceType.bishop:
        for (final (dr, dc) in const [(2, 2), (2, -2), (-2, 2), (-2, -2)]) {
          final nextRow = row + dr;
          final nextCol = col + dc;
          final midRow = row + dr ~/ 2;
          final midCol = col + dc ~/ 2;
          if (_crossesRiver(nextRow, piece.color)) continue;
          if (!_insideBoard(nextRow, nextCol)) continue;
          if (state.board[_cell(midRow, midCol)] != null) continue;
          if (_isEmptyOrEnemy(state, nextRow, nextCol, piece.color)) {
            moves.add(XiangqiMove(from: from, to: _cell(nextRow, nextCol)));
          }
        }
      case XiangqiPieceType.knight:
        for (final (dr, dc) in const [
          (2, 1),
          (2, -1),
          (-2, 1),
          (-2, -1),
          (1, 2),
          (1, -2),
          (-1, 2),
          (-1, -2)
        ]) {
          final nextRow = row + dr;
          final nextCol = col + dc;
          if (!_insideBoard(nextRow, nextCol)) continue;
          final midRow = row + (dr.abs() == 2 ? dr.sign : 0);
          final midCol = col + (dc.abs() == 2 ? dc.sign : 0);
          if (state.board[_cell(midRow, midCol)] != null) continue;
          if (_isEmptyOrEnemy(state, nextRow, nextCol, piece.color)) {
            moves.add(XiangqiMove(from: from, to: _cell(nextRow, nextCol)));
          }
        }
      case XiangqiPieceType.rook:
      case XiangqiPieceType.cannon:
        final directions = const [(0, 1), (0, -1), (1, 0), (-1, 0)];
        for (final (dr, dc) in directions) {
          var r = row + dr;
          var c = col + dc;
          while (_insideBoard(r, c)) {
            final idx = _cell(r, c);
            final target = state.board[idx];
            if (target == null) {
              moves.add(XiangqiMove(from: from, to: idx));
            } else {
              if (target.color != piece.color) {
                if (piece.type == XiangqiPieceType.cannon) {
                  // cannon captures only when there is exactly one piece between.
                  break;
                }
                moves.add(XiangqiMove(from: from, to: idx));
              }
              break;
            }
            r += dr;
            c += dc;
          }
        }
        if (piece.type == XiangqiPieceType.cannon) {
          for (final (dr, dc) in const [(0, 1), (0, -1), (1, 0), (-1, 0)]) {
            var r = row + dr;
            var c = col + dc;
            var jumped = false;
            while (_insideBoard(r, c)) {
              final idx = _cell(r, c);
              final target = state.board[idx];
              if (target != null) {
                if (!jumped) {
                  jumped = true;
                } else {
                  if (target.color != piece.color) {
                    moves.add(XiangqiMove(from: from, to: idx));
                  }
                  break;
                }
              }
              r += dr;
              c += dc;
            }
          }
        }
      case XiangqiPieceType.pawn:
        final dir = piece.color == XiangqiPieceColor.red ? -1 : 1;
        final nextRow = row + dir;
        if (_insideBoard(nextRow, col) &&
            _isEmptyOrEnemy(state, nextRow, col, piece.color)) {
          moves.add(XiangqiMove(from: from, to: _cell(nextRow, col)));
        }
        if (_hasCrossedRiver(piece.color, row)) {
          for (final dc in [-1, 1]) {
            final nextCol = col + dc;
            if (_insideBoard(row, nextCol) &&
                _isEmptyOrEnemy(state, row, nextCol, piece.color)) {
              moves.add(XiangqiMove(from: from, to: _cell(row, nextCol)));
            }
          }
        }
    }
    return moves;
  }

  static bool _insideBoard(int row, int col) =>
      row >= 0 && row < boardRows && col >= 0 && col < boardColumns;

  static bool _insidePalace(int row, int col, XiangqiPieceColor color) {
    final minRow = color == XiangqiPieceColor.red ? 7 : 0;
    final maxRow = color == XiangqiPieceColor.red ? 9 : 2;
    final inPalace = row >= minRow && row <= maxRow && col >= 3 && col <= 5;
    return inPalace;
  }

  static bool _crossesRiver(int row, XiangqiPieceColor color) {
    return color == XiangqiPieceColor.red ? row <= 4 : row >= 5;
  }

  static bool _hasCrossedRiver(XiangqiPieceColor color, int row) {
    return color == XiangqiPieceColor.red ? row <= 4 : row >= 5;
  }

  static bool _isEmptyOrEnemy(
      XiangqiState state, int row, int col, XiangqiPieceColor color) {
    final target = state.board[_cell(row, col)];
    if (target == null) return true;
    return target.color != color;
  }

  static int _cell(int row, int col) => row * boardColumns + col;

  static bool isInCheck(XiangqiState state, PlayerId actor) {
    final color = state.pieceColorOf(actor);
    final kingIndex = _findKing(state.board, color);
    if (kingIndex == null) return true;
    if (kingsFaceEachOther(state)) return true;
    final row = kingIndex ~/ boardColumns;
    final col = kingIndex % boardColumns;
    for (var i = 0; i < state.board.length; i++) {
      final piece = state.board[i];
      if (piece == null || piece.color == color) continue;
      final attack = _pieceAttacksSquare(state, i, piece, row, col);
      if (attack) return true;
    }
    return false;
  }

  static bool kingsFaceEachOther(XiangqiState state) {
    final redKing = _findKing(state.board, XiangqiPieceColor.red);
    final blackKing = _findKing(state.board, XiangqiPieceColor.black);
    if (redKing == null || blackKing == null) return false;

    final redRow = redKing ~/ boardColumns;
    final redCol = redKing % boardColumns;
    final blackRow = blackKing ~/ boardColumns;
    final blackCol = blackKing % boardColumns;

    if (redCol != blackCol) return false;
    if ((redRow - blackRow).abs() <= 1) return false;

    final startRow = min(redRow, blackRow) + 1;
    final endRow = max(redRow, blackRow);
    for (var row = startRow; row < endRow; row++) {
      if (state.board[_cell(row, redCol)] != null) return false;
    }
    return true;
  }

  static int? _findKing(List<XiangqiPiece?> board, XiangqiPieceColor color) {
    for (var i = 0; i < board.length; i++) {
      final piece = board[i];
      if (piece != null &&
          piece.type == XiangqiPieceType.king &&
          piece.color == color) return i;
    }
    return null;
  }

  static bool _pieceAttacksSquare(
    XiangqiState state,
    int from,
    XiangqiPiece piece,
    int targetRow,
    int targetCol,
  ) {
    final row = from ~/ boardColumns;
    final col = from % boardColumns;
    switch (piece.type) {
      case XiangqiPieceType.king:
        final dr = (targetRow - row).abs();
        final dc = (targetCol - col).abs();
        return dr + dc == 1 && _insidePalace(targetRow, targetCol, piece.color);
      case XiangqiPieceType.advisor:
        final dr = (targetRow - row).abs();
        final dc = (targetCol - col).abs();
        return dr == 1 &&
            dc == 1 &&
            _insidePalace(targetRow, targetCol, piece.color);
      case XiangqiPieceType.bishop:
        final dr = (targetRow - row).abs();
        final dc = (targetCol - col).abs();
        if (dr != 2 || dc != 2) return false;
        if (_crossesRiver(targetRow, piece.color)) return false;
        final midRow = row + (targetRow - row) ~/ 2;
        final midCol = col + (targetCol - col) ~/ 2;
        return state.board[_cell(midRow, midCol)] == null;
      case XiangqiPieceType.rook:
        return _rayToTarget(state, from, targetRow, targetCol, piece.color,
            allowCannon: false, requireEmpty: false);
      case XiangqiPieceType.knight:
        final dr = (targetRow - row).abs();
        final dc = (targetCol - col).abs();
        if (dr == 2 && dc == 1) {
          final midRow = row + (targetRow - row).sign;
          final midCol = col;
          return state.board[_cell(midRow, midCol)] == null;
        }
        if (dr == 1 && dc == 2) {
          final midRow = row;
          final midCol = col + (targetCol - col).sign;
          return state.board[_cell(midRow, midCol)] == null;
        }
        return false;
      case XiangqiPieceType.cannon:
        return _rayToTarget(state, from, targetRow, targetCol, piece.color,
            allowCannon: true, requireEmpty: true);
      case XiangqiPieceType.pawn:
        final dir = piece.color == XiangqiPieceColor.red ? -1 : 1;
        final sameColumn = col == targetCol;
        final oneForward = targetRow == row + dir;
        if (sameColumn && oneForward) return true;
        if (_hasCrossedRiver(piece.color, row) &&
            ((targetRow == row && (targetCol - col).abs() == 1))) return true;
        return false;
    }
  }

  static bool _rayToTarget(
    XiangqiState state,
    int from,
    int targetRow,
    int targetCol,
    XiangqiPieceColor color, {
    required bool allowCannon,
    required bool requireEmpty,
  }) {
    final row = from ~/ boardColumns;
    final col = from % boardColumns;
    final dr = (targetRow - row).sign;
    final dc = (targetCol - col).sign;
    if (row == targetRow && col != targetCol) {
      var blockers = 0;
      var c = col + dc;
      while (c != targetCol) {
        if (state.board[_cell(row, c)] != null) blockers++;
        c += dc;
      }
      return blockers == (allowCannon ? 1 : 0);
    }
    if (col == targetCol && row != targetRow) {
      var blockers = 0;
      var r = row + dr;
      while (r != targetRow) {
        if (state.board[_cell(r, col)] != null) blockers++;
        r += dr;
      }
      return blockers == (allowCannon ? 1 : 0);
    }
    return false;
  }

  static int evaluate(XiangqiState state, PlayerId rootActor) {
    var score = 0;
    for (var i = 0; i < state.board.length; i++) {
      final piece = state.board[i];
      if (piece == null) continue;
      final value = pieceValue(piece);
      score += piece.color == state.pieceColorOf(rootActor) ? value : -value;
    }
    if (isInCheck(state, rootActor)) score -= 2500;
    return score;
  }

  static int pieceValue(XiangqiPiece piece) {
    switch (piece.type) {
      case XiangqiPieceType.king:
        return 100000;
      case XiangqiPieceType.rook:
        return 900;
      case XiangqiPieceType.knight:
        return 450;
      case XiangqiPieceType.cannon:
        return 500;
      case XiangqiPieceType.bishop:
        return 180;
      case XiangqiPieceType.advisor:
        return 120;
      case XiangqiPieceType.pawn:
        return 100;
    }
  }
}
