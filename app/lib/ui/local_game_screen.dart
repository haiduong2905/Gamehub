import 'dart:async';

import 'package:flutter/material.dart';
import 'package:game_tictactoe/game_tictactoe.dart';
import 'package:platform_core/platform_core.dart';

/// Van caro offline voi may. Khong di qua RoomHost hay transport.
class LocalGameScreen extends StatefulWidget {
  const LocalGameScreen({required this.gameId, super.key});

  final GameId gameId;

  @override
  State<LocalGameScreen> createState() => _LocalGameScreenState();
}

class _LocalGameScreenState extends State<LocalGameScreen> {
  static const _game = TicTacToeGame();
  static const _human = 'human';
  static const _computer = 'computer';

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
    if (_computerThinking || _result != null || _state.currentPlayer != _human) {
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

  Future<void> _playComputer() async {
    setState(() => _computerThinking = true);
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted || _result != null) return;

    final cell = _chooseComputerCell();
    final next = _game.apply(_state, _computer, TicTacToeMove(cell));
    setState(() {
      _state = next;
      _result = _game.isFinished(next) ? _game.getResult(next) : null;
      _computerThinking = false;
    });
  }

  int _chooseComputerCell() {
    final empty = [
      for (var index = 0; index < _state.board.length; index++)
        if (_state.board[index] == null) index,
    ];

    for (final cell in empty) {
      final next = _game.apply(_state, _computer, TicTacToeMove(cell));
      if (next.winner == _computer) return cell;
    }

    final humanTurnState = TicTacToeState(
      board: _state.board,
      players: _state.players,
      xPlayerIndex: _state.xPlayerIndex,
      turnIndex: 0,
      winningLine: _state.winningLine,
    );
    for (final cell in empty) {
      final next = _game.apply(humanTurnState, _human, TicTacToeMove(cell));
      if (next.winner == _human) return cell;
    }

    final center = (TicTacToeGame.boardSize ~/ 2) * TicTacToeGame.boardSize +
        TicTacToeGame.boardSize ~/ 2;
    if (_state.board[center] == null) return center;
    return empty.first;
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chơi với máy'),
        actions: [
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
            child: Text(
              _result == null
                  ? (_computerThinking ? 'Máy đang nghĩ...' : 'Lượt của bạn - X')
                  : (_result!.winners.contains(_human)
                      ? 'Bạn thắng!'
                      : _result!.isDraw
                          ? 'Ván hòa'
                          : 'Máy thắng'),
              style: Theme.of(context).textTheme.titleMedium,
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
    );
  }
}
