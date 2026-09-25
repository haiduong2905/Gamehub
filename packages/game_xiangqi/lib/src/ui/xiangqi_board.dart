import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_audio/game_audio.dart';
import 'package:platform_core/platform_core.dart';

import '../logic/xiangqi.dart';
import 'xiangqi_move_list.dart';
import 'xiangqi_player_card.dart';
import 'xiangqi_theme.dart';

/// Toàn bộ màn ván đấu cờ tướng, trừ thanh tiêu đề.
///
/// Thẻ đối thủ ở trên, bàn cờ ở giữa, thẻ mình ở dưới, hàng nút ở đáy — đúng
/// thứ tự mắt đi khi đang chơi. Đồng hồ nằm trong thẻ của từng người chứ
/// không gom vào một thanh: đồng hồ là của một người cụ thể, đặt cạnh tên
/// người đó thì không phải đọc nhãn mới biết của ai.
class XiangqiBoard extends StatefulWidget {
  const XiangqiBoard({
    required this.view,
    this.onUndo,
    this.opponentSubtitle,
    super.key,
  });

  /// Dựng bàn cờ cho ván qua mạng. `app` gọi hàm này qua `CatalogEntry` mà
  /// không biết bên trong là game gì.
  static Widget build(GameView view) => XiangqiBoard(view: view);

  final GameView view;

  /// Khác null thì hiện nút **Hoàn tác** thay cho nút **Nước đi**.
  ///
  /// Đi lại một nước chỉ có nghĩa khi đối thủ là máy: qua mạng thì nước đã đi
  /// là nước đã gửi cho người khác, đòi lại được là một lỗ hổng chứ không
  /// phải một tiện ích.
  final VoidCallback? onUndo;

  /// Dòng nhỏ dưới tên đối thủ, ví dụ mức độ của máy.
  final String? opponentSubtitle;

  @override
  State<XiangqiBoard> createState() => _XiangqiBoardState();
}

class _XiangqiBoardState extends State<XiangqiBoard>
    with SingleTickerProviderStateMixin {
  static const _game = XiangqiGame();
  int? _selected;
  int _checkmateSoundPly = -1;

  /// Quân vừa đi chạy từ điểm xuất phát tới đích.
  ///
  /// Chỉ một quân duy nhất nên không cần theo dõi danh tính từng quân — thứ
  /// mà `XiangqiState` không có, vì hai con Xe cùng màu là hai giá trị bằng
  /// nhau. Ở đây chỉ cần biết `lastMove.from` và `lastMove.to`.
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: GameMotion.normal,
  );
  int? _slideFrom;
  int? _slideTo;

  /// Nhịp đập mỗi giây để đồng hồ chạy. Chỉ bật khi ván có tính giờ.
  Timer? _ticker;

  /// Phát tiếng quân cờ, tôn trọng cài đặt âm thanh của app.
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
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant XiangqiBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = _game.decodeState(oldWidget.view.state);
    final after = _game.decodeState(widget.view.state);
    if (after.ply > before.ply) {
      _selected = null;
      final move = after.lastMove;
      if (move != null) {
        _slideFrom = move.from;
        _slideTo = move.to;
        _slide.forward(from: 0);
      }
      final isMate = _game.isFinished(after) &&
          {'CHECKMATE', 'KING_CAPTURED'}
              .contains(_game.getResult(after).reason);
      if (isMate) {
        _checkmateSoundPly = after.ply;
        unawaited(_play('checkmate.wav'));
      } else {
        unawaited(_play(
          after.lastMoveWasCapture ? 'capture.mp3' : 'move.mp3',
        ));
      }
    }
    if (after.drawOfferBy != before.drawOfferBy) _selected = null;
    final reason = widget.view.result?.reason;
    if (_checkmateSoundPly != after.ply &&
        oldWidget.view.result == null &&
        (reason == 'CHECKMATE' || reason == 'KING_CAPTURED')) {
      _checkmateSoundPly = after.ply;
      unawaited(_play('checkmate.wav'));
    }
    _syncTicker();
  }

  /// Chỉ chạy nhịp khi thật sự có đồng hồ đang đếm.
  ///
  /// Vẽ lại mỗi giây một bàn cờ 90 điểm khi không có gì thay đổi là phí pin
  /// một cách lặng lẽ, đúng loại lãng phí không ai phát hiện ra.
  void _syncTicker() {
    final needed = widget.view.clocks.values.any((clock) => clock.running) &&
        !widget.view.isFinished;
    if (needed && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!needed) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Future<void> _play(String name) async {
    await _sound?.play('packages/game_xiangqi/assets/sounds/$name');
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _slide.dispose();
    _sound?.dispose();
    super.dispose();
  }

  void _send(XiangqiState state, XiangqiAction action) {
    if (!widget.view.canAct ||
        !_game.validate(state, widget.view.me, action).isValid) return;
    widget.view.onAction(_game.encodeAction(action));
  }

  Future<void> _confirmResign(XiangqiState state) async {
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
      _send(_game.decodeState(widget.view.state), const XiangqiResign());
    }
  }

  void _tap(XiangqiState state, int index) {
    if (!widget.view.canAct || state.currentPlayer != widget.view.me) return;
    final piece = state.board[index];
    if (piece?.color == state.pieceColorOf(widget.view.me)) {
      setState(() => _selected = _selected == index ? null : index);
      return;
    }
    if (_selected == null) return;
    final move = XiangqiMove(from: _selected!, to: index);
    if (_game.validate(state, widget.view.me, move).isValid) {
      widget.view.onAction(_game.encodeAction(move));
      setState(() => _selected = null);
    }
  }

  PlayerId? get _opponent =>
      otherPlayer(widget.view.seatOrder, widget.view.me);

  /// Tỉ số nhìn từ phía [who]. Null khi chưa biết đối thủ là ai — lúc đó một
  /// con số đứng lẻ không nói lên điều gì.
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
    final state = _game.decodeState(widget.view.state);
    final me = widget.view.me;
    final opponent = _opponent;
    final myColor = state.pieceColorOf(me);

    final targets = _selected != null &&
            widget.view.canAct &&
            state.drawOfferBy == null &&
            state.currentPlayer == me
        ? XiangqiGame.legalMovesFor(state, me)
            .where((move) => move.from == _selected)
            .map((move) => move.to)
            .toSet()
        : <int>{};

    // Quân của phe nào bị bắt thì thuộc về phe kia: thẻ của một người liệt kê
    // chiến lợi phẩm của người đó, không phải tổn thất.
    List<XiangqiPiece> capturedBy(XiangqiPieceColor color) => state
        .capturedPieces
        .where((piece) => piece.color != color)
        .toList(growable: false);

    final opponentCard = XiangqiPlayerCard(
      name: opponent == null ? 'Đối thủ' : widget.view.nicknameOf(opponent),
      subtitle: widget.opponentSubtitle ?? _subtitleFor(opponent, state),
      color: myColor == XiangqiPieceColor.red
          ? XiangqiPieceColor.black
          : XiangqiPieceColor.red,
      captured: capturedBy(
        myColor == XiangqiPieceColor.red
            ? XiangqiPieceColor.black
            : XiangqiPieceColor.red,
      ),
      clock: opponent == null ? null : widget.view.clocks[opponent],
      score: _scoreOf(opponent, me),
      isTheirTurn: opponent != null &&
          widget.view.currentActors.contains(opponent) &&
          !widget.view.isFinished,
    );

    final myCard = XiangqiPlayerCard(
      name: widget.view.nicknameOf(me),
      subtitle: _subtitleFor(me, state),
      color: myColor,
      captured: capturedBy(myColor),
      clock: widget.view.clocks[me],
      score: _scoreOf(me, opponent),
      isTheirTurn: widget.view.isMyTurn && !widget.view.isFinished,
    );

    return ColoredBox(
      color: XiangqiColors.page,
      child: LayoutBuilder(builder: (context, constraints) {
        // Hai thẻ + dải trạng thái + hàng nút + lề. Đo bằng hằng số thay vì
        // đo thật vì bàn cờ phải biết bề rộng của mình TRƯỚC khi những thứ
        // kia được dựng — và vì mọi thành phần ở đây đều cao cố định, đúng để
        // bàn cờ không đổi kích thước giữa ván.
        final chromeHeight = XiangqiPlayerCard.height * 2 +
            GameStatusLine.height +
            GameActionButton.barHeight +
            38;
        // Trừ lề hai bên: bàn cờ phải biết bề rộng của mình trước khi nó nằm
        // vào trong lớp padding bên dưới.
        final width = math.min(
          math.min(constraints.maxWidth - 28, 520.0),
          math.max(120, constraints.maxHeight - chromeHeight) / 1.135,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              opponentCard,
              _statusLine(state),
              Center(child: _board(state, width, targets)),
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

  String _subtitleFor(PlayerId? player, XiangqiState state) {
    if (player == null) return 'Chưa có ai';
    if (widget.view.isFinished) return 'Ván đã xong';
    if (state.drawOfferBy == player) return 'Đang cầu hòa';
    return widget.view.currentActors.contains(player)
        ? 'Đang đến lượt'
        : 'Đang chờ';
  }

  /// Kéo quân vừa đi lùi về điểm xuất phát rồi thả cho nó trượt tới đích.
  ///
  /// Dịch chuyển bằng [Transform] chứ không đổi `Positioned`: quân vẫn nằm
  /// đúng ô của nó trong cây widget nên chạm vào đâu vẫn ra ô đó, kể cả giữa
  /// lúc đang trượt.
  Widget _slidingDisc({
    required int index,
    required double step,
    required Widget child,
  }) {
    if (index != _slideTo || _slideFrom == null) return child;
    final delta = Offset(
      (_slideFrom! % 9 - index % 9) * step,
      (_slideFrom! ~/ 9 - index ~/ 9) * step,
    );
    return AnimatedBuilder(
      animation: _slide,
      builder: (context, child) => Transform.translate(
        offset: delta * (1 - GameMotion.curve.transform(_slide.value)),
        child: child,
      ),
      child: child,
    );
  }

  Widget _board(XiangqiState state, double width, Set<int> targets) {
    final step = width / 10;
    return SizedBox(
      width: width,
      height: step * 11.35,
      child: Stack(children: [
        const Positioned.fill(child: CustomPaint(painter: _BoardPainter())),
        for (var index = 0; index < XiangqiGame.totalCells; index++)
          Positioned(
            left: step * (1 + index % 9) - step / 2,
            top: step * (1 + index ~/ 9) - step / 2,
            width: step,
            height: step,
            child: Semantics(
              label: 'Giao điểm hàng ${index ~/ 9 + 1}, cột ${index % 9 + 1}',
              button: true,
              child: GestureDetector(
                key: ValueKey('cell-$index'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _tap(state, index),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      if (state.lastMove?.from == index)
                        Container(
                          key: ValueKey('last-from-$index'),
                          width: step * 0.20,
                          height: step * 0.20,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDE7229),
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (state.board[index] != null)
                        _slidingDisc(
                          index: index,
                          step: step,
                          child: XiangqiDisc(
                            key: state.lastMove?.to == index
                                ? ValueKey('last-to-$index')
                                : null,
                            piece: state.board[index]!,
                            size: step * 0.86,
                            selected: _selected == index,
                            lastMoved: state.lastMove?.to == index,
                          ),
                        ),
                      if (targets.contains(index))
                        _TargetDot(index: index, size: step * 0.18),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  /// Dải "• LƯỢT CỦA BẠN" giữa thẻ đối thủ và bàn cờ.
  Widget _statusLine(XiangqiState state) {
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
      return GameStatusLine(text: message, color: XiangqiColors.muted);
    }
    if (view.hasPendingAction) {
      return const GameStatusLine(
        text: 'ĐANG GỬI NƯỚC ĐI…',
        color: XiangqiColors.muted,
      );
    }
    final side = state.pieceColorOf(view.me) == XiangqiPieceColor.red
        ? 'ĐỎ'
        : 'ĐEN';
    return view.isMyTurn
        ? GameStatusLine(
            text: '• LƯỢT CỦA BẠN · $side',
            color: XiangqiColors.red,
          )
        : const GameStatusLine(
            text: '• LƯỢT ĐỐI THỦ',
            color: XiangqiColors.muted,
          );
  }

  // ---------------------------------------------------------------------------
  // Hàng nút
  // ---------------------------------------------------------------------------

  Widget _actions(XiangqiState state) => SizedBox(
        height: GameActionButton.barHeight,
        child: AnimatedSwitcher(
          duration: GameMotion.quick,
          switchInCurve: GameMotion.curve,
          switchOutCurve: GameMotion.curveIn,
          child: _actionsContent(state),
        ),
      );

  Widget _actionsContent(XiangqiState state) {
    if (widget.view.isFinished || state.terminalResult != null) {
      return const SizedBox.shrink(key: ValueKey('done'));
    }

    // Đang có lời cầu hòa treo thì hàng nút đổi thành câu trả lời: để nguyên
    // ba nút cũ và nhét thêm hai nút nữa là bắt người chơi tìm.
    if (state.drawOfferBy == widget.view.me) {
      return const Center(
        key: ValueKey('waiting-draw'),
        child: Text(
          'Đang chờ đối thủ trả lời cầu hòa…',
          style: TextStyle(color: XiangqiColors.muted),
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
            style: TextStyle(fontSize: 13, color: XiangqiColors.ink),
          ),
        ),
        TextButton(
          onPressed:
              canRespond ? () => _send(state, const XiangqiDrawReject()) : null,
          child: const Text('Từ chối'),
        ),
        const SizedBox(width: 6),
        FilledButton(
          onPressed:
              canRespond ? () => _send(state, const XiangqiDrawAccept()) : null,
          child: const Text('Đồng ý'),
        ),
      ]);
    }

    final canDecide = widget.view.canAct && state.currentPlayer == widget.view.me;
    final rejected = state.drawRejectionsOf(widget.view.me);

    return Row(key: const ValueKey('actions'), children: [
      Expanded(
        child: widget.onUndo == null
            ? GameActionButton(
                icon: Icons.list_rounded,
                label: 'Nước đi',
                onPressed: () => showXiangqiMoveList(context, state),
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
              ? () => _send(state, const XiangqiDrawOffer())
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

/// Dải "• LƯỢT CỦA BẠN" giữa thẻ đối thủ và bàn cờ.
///
/// Nằm ngay trên bàn cờ chứ không phải trên cùng màn hình: mắt đang ở bàn cờ,
/// và đây là câu duy nhất người chơi cần đọc lại sau mỗi nước.
class _TargetDot extends StatelessWidget {
  const _TargetDot({required this.index, required this.size});

  final int index;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        key: ValueKey('target-$index'),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: XiangqiColors.red,
          shape: BoxShape.circle,
          border: Border.all(
            color: XiangqiColors.paper,
            width: math.max(1, size * 0.12),
          ),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 3)],
        ),
      );
}

class _BoardPainter extends CustomPainter {
  const _BoardPainter();

  static const _ink = Color(0xFFB96B2C);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 10;
    final background = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFF4E1C8), XiangqiColors.paper, Color(0xFFEFD9BA)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.35)),
      background,
    );

    final grain = Paint()
      ..color = const Color(0x129B5D2D)
      ..strokeWidth = 0.7;
    for (var i = 0; i < 34; i++) {
      final x = (i * 37 % 101) / 101 * size.width;
      canvas.drawLine(Offset(x, s * 0.2),
          Offset(x + s * 0.08, size.height - s * 0.2), grain);
    }

    final frame = Paint()
      ..color = const Color(0xFFD1A677)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(s * 0.18),
        Radius.circular(s * 0.35),
      ),
      frame,
    );

    final line = Paint()
      ..color = _ink
      ..strokeWidth = math.max(0.8, s * 0.018);
    final edge = Paint()
      ..color = const Color(0xFF95501C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.06;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(s * 0.83, s * 0.83, s * 9.17, s * 10.17),
        Radius.circular(s * 0.22),
      ),
      edge,
    );

    for (var row = 1; row <= 10; row++) {
      canvas.drawLine(Offset(s, row * s), Offset(9 * s, row * s), line);
    }
    for (var col = 1; col <= 9; col++) {
      final x = col * s;
      canvas.drawLine(Offset(x, s), Offset(x, 5 * s), line);
      canvas.drawLine(Offset(x, 6 * s), Offset(x, 10 * s), line);
      if (col == 1 || col == 9) {
        canvas.drawLine(Offset(x, 5 * s), Offset(x, 6 * s), line);
      }
    }
    for (final top in [1.0, 8.0]) {
      canvas.drawLine(
          Offset(4 * s, top * s), Offset(6 * s, (top + 2) * s), line);
      canvas.drawLine(
          Offset(6 * s, top * s), Offset(4 * s, (top + 2) * s), line);
    }
    _text(canvas, '楚 河', Offset(2.7 * s, 5.5 * s), 0.43 * s);
    _text(canvas, '漢 界', Offset(7.3 * s, 5.5 * s), 0.43 * s);
    for (var col = 0; col < 9; col++) {
      _text(canvas, '${col + 1}', Offset((col + 1) * s, 0.45 * s), 0.27 * s);
      _text(canvas, '${9 - col}', Offset((col + 1) * s, 10.75 * s), 0.27 * s);
    }
  }

  void _text(Canvas canvas, String text, Offset center, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFFA6501A),
          fontSize: size,
          fontFamily: 'XiangqiBrush',
          package: 'game_xiangqi',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
        canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _BoardPainter oldDelegate) => false;
}
