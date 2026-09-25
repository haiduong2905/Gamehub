import 'package:flutter/material.dart';

import '../logic/xiangqi.dart';
import 'xiangqi_theme.dart';

/// Mở danh sách các nước đã đi.
Future<void> showXiangqiMoveList(BuildContext context, XiangqiState state) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: XiangqiColors.page,
    showDragHandle: true,
    builder: (context) => _MoveListSheet(state: state),
  );
}

class _MoveListSheet extends StatelessWidget {
  const _MoveListSheet({required this.state});

  final XiangqiState state;

  @override
  Widget build(BuildContext context) {
    final moves = _rows(state);
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
                'Các nước đã đi',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: XiangqiColors.ink,
                ),
              ),
            ),
            if (moves.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Text(
                  'Chưa có nước nào.',
                  style: TextStyle(color: XiangqiColors.muted),
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
                  itemBuilder: (context, index) => _MoveRow(row: moves[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MoveRow extends StatelessWidget {
  const _MoveRow({required this.row});

  final _Row row;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: XiangqiColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: XiangqiColors.cardBorder),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '${row.number}.',
                style: const TextStyle(
                  color: XiangqiColors.muted,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: row.isRed ? XiangqiColors.red : XiangqiColors.black,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                row.text,
                style: const TextStyle(color: XiangqiColors.ink),
              ),
            ),
          ],
        ),
      );
}

class _Row {
  const _Row({required this.number, required this.isRed, required this.text});

  final int number;
  final bool isRed;
  final String text;
}

/// Đọc [XiangqiState.moveLog] thành các dòng hiển thị được.
///
/// Toạ độ ghi theo đúng số in trên bàn cờ — cột 1..9 đếm từ phải sang trái
/// với bên Đỏ, từ trái sang phải với bên Đen, và hàng đếm từ phía mình đi ra.
/// Đây không phải ký hiệu cờ tướng chính thống, nhưng nó khớp với con số
/// người chơi đang nhìn thấy, nên không phải học thêm gì.
List<_Row> _rows(XiangqiState state) {
  final rows = <_Row>[];
  // Đỏ luôn đi trước, nên nước thứ n (đếm từ 0) là của Đỏ khi n chẵn.
  for (var i = 0; i + 1 < state.moveLog.length; i += 2) {
    final index = i ~/ 2;
    final isRed = index.isEven;
    rows.add(_Row(
      number: index + 1,
      isRed: isRed,
      text: '${_point(state.moveLog[i], isRed: isRed)}'
          ' → ${_point(state.moveLog[i + 1], isRed: isRed)}',
    ));
  }
  return rows;
}

String _point(int cell, {required bool isRed}) {
  final row = cell ~/ 9;
  final column = cell % 9;
  final file = isRed ? 9 - column : column + 1;
  final rank = isRed ? 10 - row : row + 1;
  return 'cột $file hàng $rank';
}
