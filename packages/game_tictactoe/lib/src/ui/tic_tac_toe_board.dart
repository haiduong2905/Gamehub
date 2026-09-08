import 'package:flutter/material.dart';
import 'package:platform_core/platform_core.dart';

import '../logic/tic_tac_toe.dart';

/// Ban co caro.
///
/// Chi ve lai [GameView.state] ma host gui xuong va gui nuoc di di. Khong tu
/// suy ra luat, khong tu danh dau o, khong tu ket luan thang thua.
///
/// Rieng o vua cham thi ve mo cho toi khi host xac nhan. Do khong phai du
/// doan lac quan - o do van chua thuoc ve ai - ma chi la phan hoi tuc thi de
/// nguoi choi biet cai cham da duoc ghi nhan.
class TicTacToeBoard extends StatefulWidget {
  const TicTacToeBoard({required this.view, super.key});

  /// Dung ham nay khi dang ky vao renderer registry cua app.
  static Widget build(GameView view) => TicTacToeBoard(view: view);

  final GameView view;

  @override
  State<TicTacToeBoard> createState() => _TicTacToeBoardState();
}

class _TicTacToeBoardState extends State<TicTacToeBoard> {
  static const _game = TicTacToeGame();

  int? _tappedCell;

  @override
  void didUpdateWidget(TicTacToeBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Host da tra loi (chap nhan hoac tu choi) thi thoi ve o mo.
    if (widget.view.pendingActionId == null && _tappedCell != null) {
      _tappedCell = null;
    }
  }

  void _tap(int index) {
    setState(() => _tappedCell = index);
    widget.view.onAction(_game.encodeAction(TicTacToeMove(index)));
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final state = _game.decodeState(view.state);
    final winningLine = state.winningLine ?? const <int>[];
    final pendingCell = view.hasPendingAction ? _tappedCell : null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gap = constraints.maxWidth * 0.022;
              return GridView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 9,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: gap,
                ),
                itemBuilder: (context, index) => _Cell(
                  mark: state.board[index],
                  highlighted: winningLine.contains(index),
                  pending: pendingCell == index,
                  myMark: state.markOf(view.me),
                  enabled: view.canAct && state.board[index] == null,
                  dimmed: winningLine.isNotEmpty &&
                      !winningLine.contains(index) &&
                      state.board[index] != null,
                  onTap: () => _tap(index),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.mark,
    required this.highlighted,
    required this.pending,
    required this.myMark,
    required this.enabled,
    required this.dimmed,
    required this.onTap,
  });

  final Mark? mark;
  final bool highlighted;
  final bool pending;
  final Mark myMark;
  final bool enabled;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: highlighted
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Center(
            child: switch ((mark, pending)) {
              (final Mark m, _) => _MarkGlyph(
                  mark: m,
                  opacity: dimmed ? 0.35 : 1,
                ),
              (null, true) => _MarkGlyph(mark: myMark, opacity: 0.3),
              (null, false) => const SizedBox.shrink(),
            },
          ),
        ),
      ),
    );
  }
}

/// Ve X va O bang net thay vi dung chu, de hai ky hieu can nhau va sac net o
/// moi kich thuoc man hinh.
class _MarkGlyph extends StatelessWidget {
  const _MarkGlyph({required this.mark, this.opacity = 1});

  final Mark mark;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = mark == Mark.x ? scheme.primary : scheme.tertiary;

    return Opacity(
      opacity: opacity,
      child: LayoutBuilder(
        builder: (context, constraints) => CustomPaint(
          size: Size.square(constraints.biggest.shortestSide * 0.44),
          painter: _MarkPainter(mark: mark, color: color),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.mark, required this.color});

  final Mark mark;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.15
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (mark == Mark.x) {
      canvas
        ..drawLine(Offset.zero, Offset(size.width, size.height), paint)
        ..drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
    } else {
      canvas.drawCircle(
        size.center(Offset.zero),
        size.width / 2 - paint.strokeWidth / 2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.mark != mark || old.color != color;
}
