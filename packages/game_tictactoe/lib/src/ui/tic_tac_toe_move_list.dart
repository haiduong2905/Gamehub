import 'package:flutter/material.dart';
import 'package:game_audio/game_audio.dart';

import '../logic/tic_tac_toe.dart';

/// Mở danh sách các nước đã đánh.
Future<void> showTicTacToeMoveList(
  BuildContext context,
  TicTacToeState state,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: GameColors.page,
    showDragHandle: true,
    builder: (context) => _MoveListSheet(state: state),
  );
}

class _MoveListSheet extends StatelessWidget {
  const _MoveListSheet({required this.state});

  final TicTacToeState state;

  @override
  Widget build(BuildContext context) {
    final moves = state.moveLog;
    // X luôn đi trước, nên nước thứ n (đếm từ 0) là của X khi n chẵn.
    Mark markAt(int index) => index.isEven ? Mark.x : Mark.o;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Các nước đã đánh',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: GameColors.ink,
                ),
              ),
            ),
            if (moves.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Text(
                  'Chưa có nước nào.',
                  style: TextStyle(color: GameColors.muted),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                  // Nước mới nhất lên đầu: đó là nước người ta mở danh sách
                  // này để xem lại.
                  reverse: true,
                  itemCount: moves.length,
                  itemBuilder: (context, index) => _MoveRow(
                    number: index + 1,
                    mark: markAt(index),
                    cell: moves[index],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MoveRow extends StatelessWidget {
  const _MoveRow({
    required this.number,
    required this.mark,
    required this.cell,
  });

  final int number;
  final Mark mark;
  final int cell;

  @override
  Widget build(BuildContext context) {
    final row = cell ~/ TicTacToeGame.boardSize + 1;
    final column = cell % TicTacToeGame.boardSize + 1;
    final color = mark == Mark.x ? GameColors.accent : GameColors.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: GameColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GameColors.cardBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '$number.',
              style: const TextStyle(
                color: GameColors.muted,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            mark == Mark.x ? 'X' : 'O',
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'hàng $row · cột $column',
              style: const TextStyle(color: GameColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
