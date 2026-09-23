import 'dart:async';
import 'dart:math' as math;

import 'package:game_audio/game_audio.dart';
import 'package:flutter/material.dart';
import 'package:platform_core/platform_core.dart';

import '../logic/xiangqi.dart';

const _paper = Color(0xFFFFF7EA);
const _ink = Color(0xFFB96B2C);
const _red = Color(0xFFC42C1D);
const _black = Color(0xFF292C2E);

class XiangqiBoard extends StatefulWidget {
  const XiangqiBoard({required this.view, super.key});

  static Widget build(GameView view) => XiangqiBoard(view: view);

  final GameView view;

  @override
  State<XiangqiBoard> createState() => _XiangqiBoardState();
}

class _XiangqiBoardState extends State<XiangqiBoard> {
  static const _game = XiangqiGame();
  int? _selected;
  int _checkmateSoundPly = -1;

  /// Phat tieng quan co, ton trong cai dat am thanh cua app.
  ///
  /// Dung o [didChangeDependencies] vi no can [GameAudioScope] phia tren.
  /// Khong co scope - nhu trong widget test - thi no chay im lang.
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
  void didUpdateWidget(covariant XiangqiBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = _game.decodeState(oldWidget.view.state);
    final after = _game.decodeState(widget.view.state);
    if (after.ply > before.ply) {
      _selected = null;
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
  }

  Future<void> _play(String name) async {
    await _sound?.play('packages/game_xiangqi/assets/sounds/$name');
  }

  @override
  void dispose() {
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

  Widget _actions(XiangqiState state) {
    final result = widget.view.result ?? state.terminalResult;
    if (result != null) {
      final message = switch (result.reason) {
        'DRAW_AGREED' => 'Hai bên đã đồng ý hòa',
        'DRAW_REJECTED_THREE_TIMES' => result.winners.contains(widget.view.me)
            ? 'Đối thủ thua vì bị từ chối cầu hòa 3 lần'
            : 'Bạn thua vì bị từ chối cầu hòa 3 lần',
        'RESIGN' => result.winners.contains(widget.view.me)
            ? 'Đối thủ đã xin thua'
            : 'Bạn đã xin thua',
        _ => null,
      };
      return SizedBox(
        height: 52,
        child: Center(
          child: message == null
              ? null
              : Text(message,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis),
        ),
      );
    }
    if (state.drawOfferBy == widget.view.me) {
      return const SizedBox(
        height: 52,
        child: Center(child: Text('Đang chờ đối thủ trả lời cầu hòa…')),
      );
    }
    if (state.drawOfferBy != null) {
      final canRespond = widget.view.canAct;
      return SizedBox(
        height: 52,
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Đối thủ cầu hòa',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: canRespond
                  ? () => _send(state, const XiangqiDrawReject())
                  : null,
              child: const Text('Từ chối'),
            ),
            FilledButton(
              onPressed: canRespond
                  ? () => _send(state, const XiangqiDrawAccept())
                  : null,
              child: const Text('Đồng ý'),
            ),
          ],
        ),
      );
    }
    final canDecide =
        widget.view.canAct && state.currentPlayer == widget.view.me;
    final rejected = state.drawRejectionsOf(widget.view.me);
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: canDecide && rejected < 3
                  ? () => _send(state, const XiangqiDrawOffer())
                  : null,
              child: Text('Cầu hòa ($rejected/3)'),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: canDecide ? () => _confirmResign(state) : null,
            child: const Text('Xin thua'),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final state = _game.decodeState(widget.view.state);
    final targets = _selected != null &&
            widget.view.canAct &&
            state.drawOfferBy == null &&
            state.currentPlayer == widget.view.me
        ? XiangqiGame.legalMovesFor(state, widget.view.me)
            .where((move) => move.from == _selected)
            .map((move) => move.to)
            .toSet()
        : <int>{};

    return LayoutBuilder(builder: (context, constraints) {
      const capturedRowsHeight = 60.0;
      final width = math.min(
        math.min(constraints.maxWidth, 520.0),
        math.max(0, constraints.maxHeight - 52 - capturedRowsHeight) / 1.135,
      );
      final step = width / 10;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: width,
              child: _CapturedRow(
                color: XiangqiPieceColor.black,
                pieces: state.capturedPieces
                    .where((piece) => piece.isBlack)
                    .toList(growable: false),
                discSize: math.min(24, step * 0.65),
              ),
            ),
            SizedBox(
              width: width,
              height: step * 11.35,
              child: Stack(children: [
                const Positioned.fill(
                    child: CustomPaint(painter: _BoardPainter())),
                for (var index = 0; index < XiangqiGame.totalCells; index++)
                  Positioned(
                    left: step * (1 + index % 9) - step / 2,
                    top: step * (1 + index ~/ 9) - step / 2,
                    width: step,
                    height: step,
                    child: Semantics(
                      label:
                          'Giao điểm hàng ${index ~/ 9 + 1}, cột ${index % 9 + 1}',
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
                                _Disc(
                                  key: state.lastMove?.to == index
                                      ? ValueKey('last-to-$index')
                                      : null,
                                  piece: state.board[index]!,
                                  size: step * 0.86,
                                  selected: _selected == index,
                                  lastMoved: state.lastMove?.to == index,
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
            ),
            SizedBox(
              width: width,
              child: _CapturedRow(
                color: XiangqiPieceColor.red,
                pieces: state.capturedPieces
                    .where((piece) => piece.isRed)
                    .toList(growable: false),
                discSize: math.min(24, step * 0.65),
              ),
            ),
            SizedBox(width: width, child: _actions(state)),
          ],
        ),
      );
    });
  }
}

class _CapturedRow extends StatelessWidget {
  const _CapturedRow({
    required this.color,
    required this.pieces,
    required this.discSize,
  });

  final XiangqiPieceColor color;
  final List<XiangqiPiece> pieces;
  final double discSize;

  @override
  Widget build(BuildContext context) {
    final side = color == XiangqiPieceColor.black ? 'Đen' : 'Đỏ';
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E3CE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            '$side mất (${pieces.length})',
            style: TextStyle(
              color: color == XiangqiPieceColor.black ? _black : _red,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: pieces.isEmpty
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('—'),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: pieces.length,
                    itemBuilder: (context, index) {
                      final piece = pieces[pieces.length - 1 - index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Center(
                          child: _Disc(
                            key: ValueKey('captured-${color.name}-$index'),
                            piece: piece,
                            size: discSize,
                            selected: false,
                            lastMoved: false,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc(
      {required this.piece,
      required this.size,
      required this.selected,
      required this.lastMoved,
      super.key});
  final XiangqiPiece piece;
  final double size;
  final bool selected;
  final bool lastMoved;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      foregroundDecoration: lastMoved
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFF2A23A),
                width: size * 0.075,
              ),
            )
          : null,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: piece.isRed ? _red : _black,
        border: Border.all(color: _paper, width: size * 0.045),
        boxShadow: [
          BoxShadow(
            color: const Color(0x88000000),
            blurRadius: size * 0.12,
            offset: Offset(1, size * 0.08),
          ),
          if (selected)
            BoxShadow(
              color: const Color(0xFFFFC34C),
              blurRadius: size * 0.2,
              spreadRadius: size * 0.06,
            ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.09),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white70),
          ),
          child: Center(
            child: Text(
              piece.glyph,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.57,
                height: 1,
                fontFamily: 'XiangqiBrush',
                package: 'game_xiangqi',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
          color: _red,
          shape: BoxShape.circle,
          border: Border.all(color: _paper, width: math.max(1, size * 0.12)),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 3),
          ],
        ),
      );
}

class _BoardPainter extends CustomPainter {
  const _BoardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 10;
    final background = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFF4E1C8), _paper, Color(0xFFEFD9BA)],
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
