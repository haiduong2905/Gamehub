import 'dart:async';
import 'dart:math' as math;

import 'package:game_audio/game_audio.dart';
import 'package:flutter/material.dart';
import 'package:platform_core/platform_core.dart';

import '../logic/tic_tac_toe.dart';

/// Ban co caro 20x20, thang khi co 5 quan lien tiep.
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

  /// Phát tiếng bút, tôn trọng cài đặt âm thanh của app.
  ///
  /// Dựng ở [didChangeDependencies] vì nó cần [GameAudioScope] phía trên.
  /// Không có scope — như trong widget test — thì nó chạy im lặng.
  GameSoundPlayer? _sound;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = GameAudioScope.readOf(context);
    if (_sound == null || _sound!.controller != controller) {
      _sound?.dispose();
      _sound = GameSoundPlayer(controller: controller);
    }
  }

  @override
  void dispose() {
    _sound?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TicTacToeBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Host da tra loi (chap nhan hoac tu choi) thi thoi ve o mo.
    if (widget.view.pendingActionId == null && _tappedCell != null) {
      _tappedCell = null;
    }

    final before = _game.decodeState(oldWidget.view.state).board;
    final after = _game.decodeState(widget.view.state).board;
    if (before.length != after.length) return;

    // Tìm quân vừa được đặt. Kêu tiếng bút cho cả nước của mình lẫn nước của
    // đối thủ — trên bàn 20x20, tiếng động là thứ cho biết đối thủ vừa đánh ở
    // đâu đó ngoài tầm nhìn hiện tại.
    for (var cell = 0; cell < after.length; cell++) {
      if (before[cell] == null && after[cell] != null) {
        unawaited(_playPen(after[cell]!));
        break;
      }
    }
  }

  Future<void> _playPen(Mark mark) async {
    final name = mark == Mark.x ? 'pen_x.wav' : 'pen_o.wav';
    await _sound?.play('packages/game_tictactoe/assets/sounds/$name');
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
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 3,
        boundaryMargin: const EdgeInsets.all(80),
        constrained: false,
        child: SizedBox.square(
          dimension: 720,
          child: GridView.builder(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: TicTacToeGame.boardSize * TicTacToeGame.boardSize,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: TicTacToeGame.boardSize,
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
          ),
        ),
      ),
    );
  }
}

/// Bao lâu để viết xong một ký hiệu. X có hai nét nên lâu hơn O một chút.
const _writeDurationX = Duration(milliseconds: 300);
const _writeDurationO = Duration(milliseconds: 340);

class _Cell extends StatefulWidget {
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
  State<_Cell> createState() => _CellState();
}

/// Ô nhớ được nó đã có quân từ trước hay quân vừa mới rơi xuống.
///
/// Phân biệt này là cả ý nghĩa của animation: chỉ quân **vừa đánh** mới được
/// vẽ dần ra như đang viết. Quân có sẵn — lúc mở lại ván, lúc vào phòng giữa
/// chừng — phải hiện ngay, nếu không cả bàn cờ sẽ tự viết lại từ đầu.
class _CellState extends State<_Cell> with SingleTickerProviderStateMixin {
  /// Tạo muộn, và chỉ tạo cho ô thật sự có animation. Bàn cờ có 400 ô; dựng
  /// sẵn 400 Ticker cho một ván chỉ dùng tới vài chục ô là phí.
  AnimationController? _controller;

  /// 1 nghĩa là đã viết xong.
  double _progress = 1;

  @override
  void initState() {
    super.initState();
    // Ô dựng ra mà đã có quân: quân cũ, hiện ngay.
    _progress = 1;
  }

  @override
  void didUpdateWidget(_Cell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mark == null && widget.mark != null) {
      _startWriting(widget.mark!);
    } else if (widget.mark == null && oldWidget.mark != null) {
      _controller?.stop();
      _progress = 1;
    }
  }

  void _startWriting(Mark mark) {
    final controller = _controller ??= AnimationController(vsync: this)
      ..addListener(() {
        if (mounted) setState(() => _progress = _controller!.value);
      });
    controller.duration =
        mark == Mark.x ? _writeDurationX : _writeDurationO;
    controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: widget.highlighted ? const Color(0xFFFFF1A8) : Colors.white,
        border: Border.all(
          color: const Color(0xFFB8BDC2),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.enabled ? widget.onTap : null,
          child: Center(
            child: switch ((widget.mark, widget.pending)) {
              (final Mark m, _) => _MarkGlyph(
                  mark: m,
                  opacity: widget.dimmed ? 0.35 : 1,
                  progress: _progress,
                ),
              // Ô vừa chạm: vẽ mờ, vẽ đủ nét. Đây là phản hồi cho cái chạm,
              // không phải một quân đang được viết.
              (null, true) => _MarkGlyph(mark: widget.myMark, opacity: 0.3),
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
  const _MarkGlyph({
    required this.mark,
    this.opacity = 1,
    this.progress = 1,
  });

  final Mark mark;
  final double opacity;

  /// 0 la chua dat but, 1 la da viet xong.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final color = mark == Mark.x
        ? const Color(0xFF1729D9)
        : const Color(0xFFF01818);

    return Opacity(
      opacity: opacity,
      child: LayoutBuilder(
        builder: (context, constraints) => CustomPaint(
          size: Size.square(constraints.biggest.shortestSide * 0.44),
          painter: _MarkPainter(
            mark: mark,
            color: color,
            progress: progress,
          ),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.mark,
    required this.color,
    required this.progress,
  });

  final Mark mark;
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.15;
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final tip = mark == Mark.x
        ? _paintCross(canvas, size, paint)
        : _paintCircle(canvas, size, paint);

    // Đầu ngòi bút: một chấm đậm ở chỗ nét đang chạy tới. Chi tiết nhỏ này
    // mới làm cái nét trông như *đang được viết* chứ không phải đang dài ra.
    if (tip != null && progress > 0 && progress < 1) {
      canvas.drawCircle(
        tip,
        stroke * 0.58,
        Paint()..color = color,
      );
    }
  }

  /// Hai nét chéo, nét sau bắt đầu khi nét trước gần xong — đúng nhịp tay
  /// nhấc bút sang nét thứ hai.
  Offset? _paintCross(Canvas canvas, Size size, Paint paint) {
    const firstEnd = 0.54;
    const secondBegin = 0.46;

    final first = (progress / firstEnd).clamp(0.0, 1.0);
    final second =
        ((progress - secondBegin) / (1 - secondBegin)).clamp(0.0, 1.0);

    Offset? tip;

    if (first > 0) {
      final from = Offset.zero;
      final to = Offset(size.width, size.height);
      final head = Offset.lerp(from, to, first)!;
      canvas.drawLine(from, to == head ? to : head, paint);
      if (first < 1) tip = head;
    }

    if (second > 0) {
      final from = Offset(size.width, 0);
      final to = Offset(0, size.height);
      final head = Offset.lerp(from, to, second)!;
      canvas.drawLine(from, head, paint);
      if (second < 1) tip = head;
    }

    return tip;
  }

  /// Một nét vòng liền, bắt đầu từ phía trên bên trái như khi viết tay.
  Offset? _paintCircle(Canvas canvas, Size size, Paint paint) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - paint.strokeWidth / 2;
    const start = -math.pi * 0.7;
    final sweep = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      paint,
    );

    if (progress >= 1) return null;
    return center + Offset.fromDirection(start + sweep, radius);
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.mark != mark || old.color != color || old.progress != progress;
}
