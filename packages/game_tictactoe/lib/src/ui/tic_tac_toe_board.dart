import 'dart:async';
import 'dart:math' as math;

import 'package:game_audio/game_audio.dart';
import 'package:flutter/material.dart';
import 'package:platform_core/platform_core.dart';

import '../logic/tic_tac_toe.dart';
import 'tic_tac_toe_move_list.dart';

/// Ban co caro 20x20, thang khi co 5 quan lien tiep.
///
/// Chi ve lai [GameView.state] ma host gui xuong va gui nuoc di di. Khong tu
/// suy ra luat, khong tu danh dau o, khong tu ket luan thang thua.
///
/// Rieng o vua cham thi ve mo cho toi khi host xac nhan. Do khong phai du
/// doan lac quan - o do van chua thuoc ve ai - ma chi la phan hoi tuc thi de
/// nguoi choi biet cai cham da duoc ghi nhan.
class TicTacToeBoard extends StatefulWidget {
  const TicTacToeBoard({
    required this.view,
    this.onUndo,
    this.opponentSubtitle,
    super.key,
  });

  /// Dung ham nay khi dang ky vao renderer registry cua app.
  static Widget build(GameView view) => TicTacToeBoard(view: view);

  final GameView view;

  /// Khác null thì hiện nút **Hoàn tác** thay cho nút **Nước đi**.
  ///
  /// Đi lại một nước chỉ có nghĩa khi đối thủ là máy: qua mạng thì nước đã đi
  /// là nước đã gửi cho người khác, đòi lại được là một lỗ hổng chứ không
  /// phải một tiện ích.
  final VoidCallback? onUndo;

  /// Dòng nhỏ dưới tên đối thủ, ví dụ `Độ khó: Khó`.
  final String? opponentSubtitle;

  @override
  State<TicTacToeBoard> createState() => _TicTacToeBoardState();
}

class _TicTacToeBoardState extends State<TicTacToeBoard> {
  static const _game = TicTacToeGame();

  /// Cạnh của bàn cờ bên trong khung nhìn, tính bằng pixel logic.
  static const _fullBoard = 720.0;
  static const _cell = _fullBoard / TicTacToeGame.boardSize;

  int? _tappedCell;

  /// Vị trí khung nhìn đang nhìn vào chỗ nào của bàn cờ.
  ///
  /// Bàn 20x20 rộng gấp mấy lần khung nhìn, nên nếu để mặc định thì ván mở ra
  /// ở góc trên bên trái — chỗ thường không có quân nào. Phải tự đưa khung
  /// nhìn về nơi đang có cờ.
  final _viewer = TransformationController();
  bool _centered = false;

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
    _viewer.dispose();
    _sound?.dispose();
    super.dispose();
  }

  /// Đưa ô [cell] vào giữa khung nhìn cạnh [side].
  void _centerOn(int cell, double side) {
    final scale = _viewer.value.getMaxScaleOnAxis();
    final x = (cell % TicTacToeGame.boardSize + 0.5) * _cell * scale;
    final y = (cell ~/ TicTacToeGame.boardSize + 0.5) * _cell * scale;
    _viewer.value = Matrix4.identity()
      ..scaleByDouble(scale, scale, scale, 1)
      ..setTranslationRaw(side / 2 - x, side / 2 - y, 0);
  }

  bool _isVisible(int cell, double side) {
    final translation = _viewer.value.getTranslation();
    final scale = _viewer.value.getMaxScaleOnAxis();
    final x =
        (cell % TicTacToeGame.boardSize + 0.5) * _cell * scale + translation.x;
    final y =
        (cell ~/ TicTacToeGame.boardSize + 0.5) * _cell * scale + translation.y;
    // Chừa một ô ở mép: quân nằm sát viền coi như chưa thấy rõ.
    return x > _cell && x < side - _cell && y > _cell && y < side - _cell;
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

  void _send(TicTacToeState state, TicTacToeAction action) {
    if (!widget.view.canAct ||
        !_game.validate(state, widget.view.me, action).isValid) {
      return;
    }
    widget.view.onAction(_game.encodeAction(action));
  }

  Future<void> _confirmResign(TicTacToeState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xin thua ván này?'),
        content: const Text('Đối thủ sẽ được xử thắng ngay.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xin thua'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) {
      _send(_game.decodeState(widget.view.state), const TicTacToeResign());
    }
  }

  PlayerId? get _opponent => otherPlayer(widget.view.seatOrder, widget.view.me);

  /// Tỉ số nhìn từ phía [who]. Null khi không biết đối thủ là ai — lúc đó
  /// một con số đứng lẻ không nói lên điều gì.
  GameScore? _scoreOf(PlayerId? who, PlayerId? against) {
    if (who == null || against == null) return null;
    final series = widget.view.series;
    return GameScore(
      wins: series.winsOf(who),
      opponentWins: series.winsOf(against),
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final state = _game.decodeState(view.state);
    final me = view.me;
    final opponent = _opponent;
    final myMark = state.markOf(me);
    final theirMark = myMark == Mark.x ? Mark.o : Mark.x;

    final opponentCard = GamePlayerCard(
      name: opponent == null ? 'Đối thủ' : view.nicknameOf(opponent),
      sideLabel: _markLabel(theirMark),
      avatarLabel: _markLabel(theirMark),
      subtitle: widget.opponentSubtitle ?? _subtitleFor(opponent, state),
      sideColor: _markColor(theirMark),
      clock: opponent == null ? null : view.clocks[opponent],
      score: _scoreOf(opponent, me),
      isTheirTurn: opponent != null &&
          view.currentActors.contains(opponent) &&
          !view.isFinished,
    );

    final myCard = GamePlayerCard(
      name: view.nicknameOf(me),
      sideLabel: _markLabel(myMark),
      avatarLabel: _markLabel(myMark),
      subtitle: _subtitleFor(me, state),
      sideColor: _markColor(myMark),
      clock: view.clocks[me],
      score: _scoreOf(me, opponent),
      isTheirTurn: view.isMyTurn && !view.isFinished,
    );

    final (statusText, statusColor) = _status(state);

    return ColoredBox(
      color: GameColors.page,
      child: LayoutBuilder(builder: (context, constraints) {
        // Hai thẻ + dải trạng thái + hàng nút + lề. Mọi thứ ở đây cao cố
        // định, nên khung nhìn bàn cờ không đổi kích thước giữa ván.
        final chromeHeight = GamePlayerCard.heightOf(withFooter: false) * 2 +
            GameStatusLine.height +
            GameActionButton.barHeight +
            38;
        final side = math.min(
          constraints.maxWidth - 28,
          math.max(160.0, constraints.maxHeight - chromeHeight),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              opponentCard,
              GameStatusLine(text: statusText, color: statusColor),
              Center(child: _boardBox(state, side)),
              const SizedBox(height: 10),
              myCard,
              const SizedBox(height: 10),
              _actions(state),
            ],
          ),
        );
      }),
    );
  }

  String _subtitleFor(PlayerId? player, TicTacToeState state) {
    if (player == null) return 'Chưa có ai';
    if (widget.view.isFinished) return 'Ván đã xong';
    if (state.drawOfferBy == player) return 'Đang cầu hòa';
    if (!widget.view.currentActors.contains(player)) return 'Đang chờ';
    return player == widget.view.me ? 'Lượt của bạn' : 'Đang đến lượt';
  }

  (String, Color) _status(TicTacToeState state) {
    final view = widget.view;
    final result = view.result ?? state.terminalResult;
    if (result != null) {
      final message = switch (result.reason) {
        'DRAW_AGREED' => 'HAI BÊN ĐÃ ĐỒNG Ý HÒA',
        'DRAW_REJECTED_THREE_TIMES' => result.winners.contains(view.me)
            ? 'ĐỐI THỦ THUA VÌ BỊ TỪ CHỐI CẦU HÒA 3 LẦN'
            : 'BẠN THUA VÌ BỊ TỪ CHỐI CẦU HÒA 3 LẦN',
        'RESIGN' => result.winners.contains(view.me)
            ? 'ĐỐI THỦ ĐÃ XIN THUA'
            : 'BẠN ĐÃ XIN THUA',
        'MOVE_TIMEOUT' || 'MATCH_TIMEOUT' => result.winners.contains(view.me)
            ? 'ĐỐI THỦ HẾT GIỜ'
            : 'BẠN ĐÃ HẾT GIỜ',
        _ => result.isDraw
            ? 'VÁN HÒA'
            : (result.winners.contains(view.me) ? 'BẠN THẮNG' : 'BẠN THUA'),
      };
      return (message, GameColors.muted);
    }
    if (view.hasPendingAction) return ('ĐANG GỬI NƯỚC ĐI…', GameColors.muted);
    return view.isMyTurn
        ? ('• LƯỢT CỦA BẠN · ${_markLabel(state.markOf(view.me))}',
            GameColors.accent)
        : ('• LƯỢT ĐỐI THỦ', GameColors.muted);
  }

  /// Khung nhìn vuông; bàn cờ 20x20 nằm bên trong và kéo được.
  ///
  /// Bàn 20x20 rộng gấp mấy lần màn điện thoại: thu vừa màn hình thì ô nhỏ
  /// tới mức không bấm trúng. Thay vào đó là một cửa sổ cố định để kéo, và
  /// dòng nhắc ở góc nói ra điều đó — không có nó thì người chơi không biết
  /// bàn cờ còn kéo được.
  Widget _boardBox(TicTacToeState state, double side) {
    final winningLine = state.winningLine ?? const <int>[];
    final pendingCell = widget.view.hasPendingAction ? _tappedCell : null;

    // Lần đầu: nhìn vào nước mới nhất, hoặc giữa bàn nếu ván chưa bắt đầu.
    // Sau đó chỉ can thiệp khi nước vừa đánh rơi ra ngoài khung — kéo khung
    // nhìn về mỗi nước sẽ giằng tay người đang tự kéo bàn cờ.
    final latest = state.moveLog.isEmpty
        ? (TicTacToeGame.boardSize * TicTacToeGame.boardSize) ~/ 2 +
            TicTacToeGame.boardSize ~/ 2
        : state.moveLog.last;
    if (!_centered) {
      _centered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _centerOn(latest, side);
      });
    } else if (state.moveLog.isNotEmpty && !_isVisible(latest, side)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _centerOn(latest, side);
      });
    }

    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        color: GameColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8C9B0), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        InteractiveViewer(
          transformationController: _viewer,
          minScale: 0.5,
          maxScale: 3,
          boundaryMargin: const EdgeInsets.all(80),
          constrained: false,
          child: SizedBox.square(
            dimension: _fullBoard,
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: TicTacToeGame.boardSize * TicTacToeGame.boardSize,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: TicTacToeGame.boardSize,
              ),
              itemBuilder: (context, index) => _Cell(
                key: ValueKey('cell-$index'),
                mark: state.board[index],
                highlighted: winningLine.contains(index),
                lastMove: state.moveLog.isNotEmpty &&
                    index == state.moveLog.last &&
                    winningLine.isEmpty,
                pending: pendingCell == index,
                myMark: state.markOf(widget.view.me),
                enabled: widget.view.canAct && state.board[index] == null,
                dimmed: winningLine.isNotEmpty &&
                    !winningLine.contains(index) &&
                    state.board[index] != null,
                onTap: () => _tap(index),
              ),
            ),
          ),
        ),
        Positioned(
          right: 8,
          bottom: 6,
          child: IgnorePointer(
            child: Text(
              'Kéo để xem bàn cờ',
              style: TextStyle(
                fontSize: 10,
                color: GameColors.muted.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _actions(TicTacToeState state) => SizedBox(
        height: GameActionButton.barHeight,
        child: AnimatedSwitcher(
          duration: GameMotion.quick,
          switchInCurve: GameMotion.curve,
          switchOutCurve: GameMotion.curveIn,
          child: _actionsContent(state),
        ),
      );

  Widget _actionsContent(TicTacToeState state) {
    if (widget.view.isFinished || state.terminalResult != null) {
      return const SizedBox.shrink(key: ValueKey('done'));
    }
    if (state.drawOfferBy == widget.view.me) {
      return const Center(
        key: ValueKey('waiting-draw'),
        child: Text(
          'Đang chờ đối thủ trả lời cầu hòa…',
          style: TextStyle(color: GameColors.muted),
        ),
      );
    }
    if (state.drawOfferBy != null) {
      final canRespond = widget.view.canAct;
      return Row(key: const ValueKey('answer-draw'), children: [
        const Expanded(
          child: Text(
            'Đối thủ cầu hòa',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: GameColors.ink),
          ),
        ),
        TextButton(
          onPressed:
              canRespond ? () => _send(state, const TicTacToeDrawReject()) : null,
          child: const Text('Từ chối'),
        ),
        const SizedBox(width: 6),
        FilledButton(
          onPressed:
              canRespond ? () => _send(state, const TicTacToeDrawAccept()) : null,
          child: const Text('Đồng ý'),
        ),
      ]);
    }

    final canDecide = widget.view.canAct;
    final rejected = state.drawRejectionsOf(widget.view.me);

    return Row(key: const ValueKey('actions'), children: [
      Expanded(
        child: widget.onUndo == null
            ? GameActionButton(
                icon: Icons.list_rounded,
                label: 'Nước đi',
                onPressed: () => showTicTacToeMoveList(context, state),
              )
            : GameActionButton(
                icon: Icons.undo_rounded,
                label: 'Hoàn tác',
                onPressed: state.moveLog.isEmpty ? null : widget.onUndo,
              ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: GameActionButton(
          icon: Icons.handshake_outlined,
          // Số lần bị từ chối chỉ hiện khi đã có: bị từ chối 3 lần là thua,
          // nên khi nó bắt đầu đếm thì người chơi phải thấy.
          label: rejected == 0 ? 'Cầu hòa' : 'Cầu hòa ($rejected/3)',
          onPressed: canDecide && rejected < 3
              ? () => _send(state, const TicTacToeDrawOffer())
              : null,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: GameActionButton(
          icon: Icons.flag_outlined,
          label: 'Xin thua',
          danger: true,
          onPressed: canDecide ? () => _confirmResign(state) : null,
        ),
      ),
    ]);
  }
}

String _markLabel(Mark mark) => mark == Mark.x ? 'X' : 'O';

Color _markColor(Mark mark) =>
    mark == Mark.x ? GameColors.accent : GameColors.dark;

/// Bao lâu để viết xong một ký hiệu. X có hai nét nên lâu hơn O một chút.
///
/// Phải khớp với độ dài hai file trong `bin/generate_sounds.dart`: tiếng bút
/// kêu xong trước lúc quân vẽ xong, hay ngược lại, đều nghe như âm thanh lệch
/// khỏi hình.
///
/// Ngắn hơn tốc độ một nét bút thật, có chủ ý. Cờ caro là gõ liên tiếp; chờ
/// gần một phần ba giây mỗi lần đặt quân thì cả ván nặng nề, dù từng nét
/// riêng lẻ nhìn đẹp hơn.
abstract final class TicTacToePenMotion {
  static const x = Duration(milliseconds: 190);
  static const o = Duration(milliseconds: 210);
}

class _Cell extends StatefulWidget {
  const _Cell({
    required this.mark,
    required this.highlighted,
    required this.lastMove,
    super.key,
    required this.pending,
    required this.myMark,
    required this.enabled,
    required this.dimmed,
    required this.onTap,
  });

  final Mark? mark;
  final bool highlighted;

  /// Ô vừa được đánh. Trên bàn 20x20 đây là thứ cho biết đối thủ vừa đi đâu.
  final bool lastMove;
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
        mark == Mark.x ? TicTacToePenMotion.x : TicTacToePenMotion.o;
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
      duration: GameMotion.quick,
      decoration: BoxDecoration(
        color: widget.highlighted
            ? const Color(0xFFF8E7B0)
            : (widget.lastMove ? const Color(0xFFFBF0D3) : GameColors.paper),
        border: Border.all(
          color: widget.lastMove
              ? const Color(0xFFE2B45C)
              : const Color(0xFFE0D2B8),
          width: widget.lastMove ? 1.4 : 1,
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
    // X đỏ, O mực đen — cùng cặp màu với quân Đỏ và quân Đen của cờ tướng,
    // để hai game trong cùng một app không nói hai thứ tiếng màu.
    final color = _markColor(mark);

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
