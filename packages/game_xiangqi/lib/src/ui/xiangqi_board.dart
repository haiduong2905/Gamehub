import 'package:flutter/material.dart';
import 'package:platform_core/platform_core.dart';

import '../logic/xiangqi.dart';

class XiangqiBoard extends StatefulWidget {
  const XiangqiBoard({required this.view, super.key});

  static Widget build(GameView view) => XiangqiBoard(view: view);

  final GameView view;

  @override
  State<XiangqiBoard> createState() => _XiangqiBoardState();
}

class _XiangqiBoardState extends State<XiangqiBoard> {
  int? _selected;

  void _onCellTap(int index) {
    final state = XiangqiGame().decodeState(widget.view.state);
    final current = state.currentPlayer;
    if (!widget.view.canAct || current != widget.view.me) return;

    final piece = state.board[index];
    if (_selected == null) {
      if (piece == null || piece.color != XiangqiGame.colorOfPlayer(widget.view.me)) return;
      setState(() => _selected = index);
      return;
    }

    final move = XiangqiMove(from: _selected!, to: index);
    final validation = XiangqiGame().validate(state, widget.view.me, move);
    if (validation.isValid) {
      widget.view.onAction(XiangqiGame().encodeAction(move));
    }
    setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final state = XiangqiGame().decodeState(widget.view.state);
    final isMyTurn = widget.view.isMyTurn;

    final board = Container(
      width: 420,
      height: 520,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFE7D3A5),
        border: Border.all(color: const Color(0xFF8B5A2B), width: 4),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cell = constraints.maxWidth / XiangqiGame.boardColumns;
          return Stack(
            children: [
              Positioned.fill(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: XiangqiGame.totalCells,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: XiangqiGame.boardColumns,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final row = index ~/ XiangqiGame.boardColumns;
                    final col = index % XiangqiGame.boardColumns;
                    final selected = _selected == index;
                    final isPalace = (row >= 7 && row <= 9 && col >= 3 && col <= 5) ||
                        (row >= 0 && row <= 2 && col >= 3 && col <= 5);
                    final isRiverLine = row == 4 || row == 5;
                    final piece = state.board[index];

                    return GestureDetector(
                      onTap: () => _onCellTap(index),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF7A4A17), width: 1.5),
                          color: selected ? const Color(0xFFF7D27B) : const Color(0xFFF3E3BB),
                        ),
                        child: Stack(
                          children: [
                            if (isRiverLine)
                              Positioned(
                                left: 0,
                                right: 0,
                                top: cell / 2 - 2,
                                child: Divider(color: const Color(0xFF8B5A2B), thickness: 2),
                              ),
                            if (isPalace)
                              Positioned.fill(
                                child: Align(
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: cell * 0.56,
                                    height: cell * 0.56,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFFB57B3D), width: 1.2),
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.transparent,
                                    ),
                                  ),
                                ),
                              ),
                            if (piece != null)
                              Center(
                                child: Container(
                                  width: cell * 0.72,
                                  height: cell * 0.72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: piece.isRed ? const Color(0xFFE75B39) : const Color(0xFF1B1B1B),
                                    border: Border.all(
                                      color: piece.isRed ? const Color(0xFF8E2A1E) : const Color(0xFF383838),
                                      width: 3,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x22000000),
                                        blurRadius: 2,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      piece.glyph,
                                      style: TextStyle(
                                        fontSize: cell * 0.42,
                                        color: piece.isRed ? Colors.white : const Color(0xFFF6E7C5),
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'serif',
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    9,
                    (index) => Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7B4B1D),
                        fontSize: 16,
                        fontFamily: 'serif',
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    9,
                    (index) => Text(
                      '${9 - index}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7B4B1D),
                        fontSize: 16,
                        fontFamily: 'serif',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return Center(
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            isMyTurn ? 'Lượt của bạn' : 'Lượt đối thủ',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          board,
        ],
      ),
    );
  }
}
