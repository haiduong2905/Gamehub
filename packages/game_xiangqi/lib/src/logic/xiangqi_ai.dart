import 'dart:math';

import 'package:platform_core/platform_core.dart';

import 'xiangqi.dart';

/// May choi co tuong: alpha-beta, sap xep nuoc an va danh gia vi tri.
///
/// Cac nhom Elo tren UI la muc tham chieu de nguoi choi chon do kho.
/// Chua co ket qua dau thu de hieu chuan thanh Elo thi dau thuc te.
class XiangqiAi {
  static const _game = XiangqiGame();
  static const _mate = 1000000;
  static const _infinity = 1 << 30;

  static XiangqiMove? pickMove(
    XiangqiState state,
    PlayerId actor,
    XiangqiDifficulty difficulty, {
    Random? random,
  }) {
    if (actor != state.currentPlayer || _game.isFinished(state)) return null;
    final legal = _ordered(state, XiangqiGame.legalMovesFor(state, actor));
    if (legal.isEmpty) return null;

    final (maxDepth, maxNodes) = switch (difficulty) {
      XiangqiDifficulty.easy => (1, 200),
      XiangqiDifficulty.medium => (2, 1800),
      XiangqiDifficulty.hard => (3, 6500),
      XiangqiDifficulty.expert => (4, 18000),
    };

    var best = legal.first;
    var ordering = legal;
    final search = _SearchBudget(maxNodes);
    for (var depth = 1; depth <= maxDepth; depth++) {
      final scored = <(XiangqiMove, int)>[];
      var alpha = -_infinity;
      try {
        for (final move in ordering) {
          final next = _game.apply(state, actor, move);
          final opponent = _opponent(state, actor);
          final score = -_negamax(
            next,
            opponent,
            depth - 1,
            -_infinity,
            -alpha,
            1,
            search,
          );
          scored.add((move, score));
          alpha = max(alpha, score);
        }
      } on _SearchLimit {
        break; // Giu nuoc tot nhat cua do sau da tim xong.
      }
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      best = scored.first.$1;
      ordering = scored.map((entry) => entry.$1).toList();

      if (difficulty == XiangqiDifficulty.easy) {
        // Tap su co the bo lo nuoc tot, nhung luon chon nuoc hop le.
        final choices = min(4, scored.length);
        return scored[(random ?? Random()).nextInt(choices)].$1;
      }
      if (scored.first.$2 >= _mate - 20) break;
    }
    return best;
  }

  static int _negamax(
    XiangqiState state,
    PlayerId actor,
    int depth,
    int alpha,
    int beta,
    int ply,
    _SearchBudget budget,
  ) {
    budget.visit();
    final myColor = state.pieceColorOf(actor);
    if (!_hasKing(state, myColor)) return -_mate + ply;
    if (!_hasKing(state, _otherColor(myColor))) return _mate - ply;

    if (depth == 0) {
      // Phat hien chieu bi o la tim kiem, tranh xem the bi la vi tri tot.
      if (XiangqiGame.isInCheck(state, actor) &&
          XiangqiGame.legalMovesFor(state, actor).isEmpty) {
        return -_mate + ply;
      }
      return _evaluate(state, actor);
    }

    final legal = _ordered(state, XiangqiGame.legalMovesFor(state, actor));
    if (legal.isEmpty) {
      return XiangqiGame.isInCheck(state, actor) ? -_mate + ply : 0;
    }

    var best = -_infinity;
    for (final move in legal) {
      final next = _game.apply(state, actor, move);
      final score = -_negamax(
        next,
        _opponent(state, actor),
        depth - 1,
        -beta,
        -alpha,
        ply + 1,
        budget,
      );
      best = max(best, score);
      alpha = max(alpha, score);
      if (alpha >= beta) break;
    }
    return best;
  }

  static List<XiangqiMove> _ordered(
      XiangqiState state, List<XiangqiMove> moves) {
    final sorted = [...moves];
    sorted.sort((a, b) => _priority(state, b).compareTo(_priority(state, a)));
    return sorted;
  }

  static int _priority(XiangqiState state, XiangqiMove move) {
    final target = state.board[move.to];
    if (target == null) return 0;
    final attacker = state.board[move.from]!;
    return XiangqiGame.pieceValue(target) * 10 -
        XiangqiGame.pieceValue(attacker);
  }

  static int _evaluate(XiangqiState state, PlayerId actor) {
    final myColor = state.pieceColorOf(actor);
    var score = 0;
    for (var index = 0; index < state.board.length; index++) {
      final piece = state.board[index];
      if (piece == null) continue;
      final row = index ~/ XiangqiGame.boardColumns;
      final col = index % XiangqiGame.boardColumns;
      var value = XiangqiGame.pieceValue(piece);
      switch (piece.type) {
        case XiangqiPieceType.pawn:
          final progress = piece.isRed ? 9 - row : row;
          value += progress * 14;
          if (progress >= 5) value += 35;
        case XiangqiPieceType.knight:
          value += (4 - (col - 4).abs()) * 8;
        case XiangqiPieceType.rook:
        case XiangqiPieceType.cannon:
          value += (4 - (col - 4).abs()) * 3;
        case XiangqiPieceType.king:
        case XiangqiPieceType.advisor:
        case XiangqiPieceType.bishop:
          break;
      }
      score += piece.color == myColor ? value : -value;
    }
    return score;
  }

  static bool _hasKing(XiangqiState state, XiangqiPieceColor color) =>
      state.board.any((piece) =>
          piece?.type == XiangqiPieceType.king && piece?.color == color);

  static XiangqiPieceColor _otherColor(XiangqiPieceColor color) =>
      color == XiangqiPieceColor.red
          ? XiangqiPieceColor.black
          : XiangqiPieceColor.red;

  static PlayerId _opponent(XiangqiState state, PlayerId actor) =>
      state.players.firstWhere((player) => player != actor);
}

class _SearchBudget {
  _SearchBudget(this.limit);

  final int limit;
  int visited = 0;

  void visit() {
    visited++;
    if (visited > limit) throw const _SearchLimit();
  }
}

class _SearchLimit implements Exception {
  const _SearchLimit();
}

/// Dữ liệu đủ cho một lượt nghĩ của máy, ở dạng gửi được sang isolate khác.
///
/// Thế cờ đi ở dạng JSON đã mã hóa — đúng dạng giao thức vẫn dùng để truyền
/// thế cờ qua mạng, nên chắc chắn gửi được và đã có golden test canh.
class XiangqiAiRequest {
  const XiangqiAiRequest({
    required this.state,
    required this.actor,
    required this.difficulty,
  });

  final Map<String, dynamic> state;
  final PlayerId actor;
  final XiangqiDifficulty difficulty;
}

/// Chọn nước cho máy — hàm top-level để chạy được ở isolate nền qua `compute`.
///
/// Trả về nước đã mã hóa, hoặc `null` khi không còn nước nào.
///
/// Vì sao ra isolate nền: alpha-beta chạy đồng bộ, và ngân sách của nó tính
/// bằng **số nút duyệt** chứ không bằng thời gian — máy càng chậm thì lượt máy
/// càng dài. Chạy trên luồng giao diện thì suốt lượt đó không khung hình nào
/// được vẽ: quân người chơi vừa đi đứng im giữa đường trượt, và nếu khung hình
/// chưa kịp dựng thì nước vừa đánh còn chưa hiện ra.
Map<String, dynamic>? pickXiangqiMove(XiangqiAiRequest request) {
  const game = XiangqiGame();
  final move = XiangqiAi.pickMove(
    game.decodeState(request.state),
    request.actor,
    request.difficulty,
  );
  return move == null ? null : game.encodeAction(move);
}
