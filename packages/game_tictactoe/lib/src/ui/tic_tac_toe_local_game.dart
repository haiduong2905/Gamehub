import 'dart:async';

import 'package:flutter/material.dart';
import 'package:game_audio/game_audio.dart';
import 'package:platform_core/platform_core.dart';

import '../logic/tic_tac_toe.dart';
import '../logic/tic_tac_toe_ai.dart';
import 'tic_tac_toe_board.dart';

/// Chơi cờ caro với máy, ngay trên một thiết bị.
///
/// Nằm trong package của game chứ không nằm ở `app`: nếu để `app` dựng màn
/// hình này thì `app` phải biết trong hub có những game nào và mỗi game có máy
/// đánh ra sao — đúng thứ ràng buộc số 2 cấm. `app` chỉ cầm một hàm dựng
/// widget lấy từ `CatalogEntry`, không biết bên trong là game gì.
class TicTacToeLocalGameScreen extends StatefulWidget {
  const TicTacToeLocalGameScreen({super.key});

  @override
  State<TicTacToeLocalGameScreen> createState() =>
      _TicTacToeLocalGameScreenState();
}

class _TicTacToeLocalGameScreenState extends State<TicTacToeLocalGameScreen> {
  static const _game = TicTacToeGame();
  static const _human = 'human';
  static const _computer = 'computer';

  TicTacToeDifficulty _difficulty = TicTacToeDifficulty.hard;
  late TicTacToeState _state;
  GameResult? _result;
  bool _computerThinking = false;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    setState(() {
      _state = _game.createInitialState([_human, _computer], seed: 0);
      _result = null;
      _computerThinking = false;
    });
  }

  void _playHuman(Map<String, dynamic> action) {
    if (_computerThinking ||
        _result != null ||
        _state.currentPlayer != _human) {
      return;
    }
    final move = _game.decodeAction(action);
    if (!_game.validate(_state, _human, move).isValid) return;

    setState(() {
      _state = _game.apply(_state, _human, move);
      if (_game.isFinished(_state)) _result = _game.getResult(_state);
    });
    if (_result == null) unawaited(_playComputer());
  }

  /// Thời gian tối thiểu của một lượt máy.
  ///
  /// Máy giờ tính xong trong vài mili giây ở mức thấp. Đánh trả lời tức thì
  /// nhìn giật và khó theo dõi, nên chờ cho đủ nhịp này — nhưng là chờ *bù*,
  /// không cộng thêm vào thời gian máy đã nghĩ.
  static const _minimumTurn = Duration(milliseconds: 280);

  Future<void> _playComputer() async {
    setState(() => _computerThinking = true);

    // Nhường một nhịp cho khung hình "Máy đang nghĩ" được vẽ ra trước khi bắt
    // đầu tính: thuật toán chạy đồng bộ nên sẽ chiếm luồng giao diện.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!mounted || _result != null) return;

    final clock = Stopwatch()..start();
    final cell = _chooseComputerCell();
    clock.stop();

    final remaining = _minimumTurn - clock.elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
      if (!mounted || _result != null) return;
    }

    final next = _game.apply(_state, _computer, TicTacToeMove(cell));
    setState(() {
      _state = next;
      _result = _game.isFinished(next) ? _game.getResult(next) : null;
      _computerThinking = false;
    });
  }

  int _chooseComputerCell() {
    final move = TicTacToeAi.pickMove(_state, _computer, _difficulty);
    if (move != null) return move;

    final empty = [
      for (var index = 0; index < _state.board.length; index++)
        if (_state.board[index] == null) index,
    ];
    if (empty.isNotEmpty) return empty.first;
    throw StateError('Không còn ô trống để máy đánh.');
  }

  @override
  Widget build(BuildContext context) {
    final view = GameView(
      state: _game.encodeState(_state),
      me: _human,
      seatOrder: const [_human, _computer],
      nicknames: const {_human: 'Bạn', _computer: 'Máy'},
      currentActors: _result == null ? _game.currentActors(_state) : const [],
      result: _result,
      onAction: _playHuman,
    );

    // Nhạc nền chạy suốt màn này và tắt khi rời đi. Ván qua mạng đã có nhạc
    // do màn phòng của app lo; màn chơi với máy là của game nên tự bọc lấy.
    return GameMusic(
        child: Scaffold(
      appBar: AppBar(
        title: const Text('Chơi với máy'),
        actions: [
          const GameAudioButton(),
          PopupMenuButton<TicTacToeDifficulty>(
            tooltip: 'Chọn mức độ máy',
            initialValue: _difficulty,
            onSelected: (value) {
              setState(() => _difficulty = value);
              if (_state.currentPlayer == _computer &&
                  !_computerThinking &&
                  _result == null) {
                unawaited(_playComputer());
              }
            },
            itemBuilder: (context) => TicTacToeDifficulty.values
                .map(
                  (level) => PopupMenuItem(
                    value: level,
                    child: Text(level.label),
                  ),
                )
                .toList(),
          ),
          IconButton(
            onPressed: _reset,
            tooltip: 'Ván mới',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _result == null
                      ? (_computerThinking
                          ? 'Máy đang nghĩ...'
                          : 'Lượt của bạn - X')
                      : (_result!.winners.contains(_human)
                          ? 'Bạn thắng!'
                          : _result!.isDraw
                              ? 'Ván hòa'
                              : 'Máy thắng'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Mức máy: ${_difficulty.label}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Expanded(child: TicTacToeBoard(view: view)),
          if (_result != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: FilledButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Chơi ván mới'),
              ),
            ),
        ],
      ),
    ));
  }
}
