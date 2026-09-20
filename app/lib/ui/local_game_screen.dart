import 'dart:async';

import 'package:flutter/material.dart';
import 'package:game_tictactoe/game_tictactoe.dart';
import 'package:game_xiangqi/game_xiangqi.dart';
import 'package:platform_core/platform_core.dart';

/// Màn hình local game theo gameId, không còn bị hardcode luôn là cờ caro.
class LocalGameScreen extends StatelessWidget {
  const LocalGameScreen({required this.gameId, super.key});

  final GameId gameId;

  @override
  Widget build(BuildContext context) {
    switch (gameId) {
      case 'xiangqi':
        return const XiangqiLocalGameScreen();
      case 'tic-tac-toe':
      default:
        return const TicTacToeLocalGameScreen();
    }
  }
}

class TicTacToeLocalGameScreen extends StatefulWidget {
  const TicTacToeLocalGameScreen({super.key});

  @override
  State<TicTacToeLocalGameScreen> createState() => _TicTacToeLocalGameScreenState();
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
    final delayMs = switch (_difficulty) {
      TicTacToeDifficulty.easy => 180,
      TicTacToeDifficulty.medium => 240,
      TicTacToeDifficulty.hard => 320,
      TicTacToeDifficulty.expert => 420,
    };
    await Future<void>.delayed(Duration(milliseconds: delayMs));
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chơi với máy'),
        actions: [
          PopupMenuButton<TicTacToeDifficulty>(
            tooltip: 'Chọn mức độ máy',
            initialValue: _difficulty,
            onSelected: (value) {
              setState(() => _difficulty = value);
              if (_state.currentPlayer == _computer && !_computerThinking && _result == null) {
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
                      ? (_computerThinking ? 'Máy đang nghĩ...' : 'Lượt của bạn - X')
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
    );
  }
}

class XiangqiLocalGameScreen extends StatefulWidget {
  const XiangqiLocalGameScreen({super.key});

  @override
  State<XiangqiLocalGameScreen> createState() => _XiangqiLocalGameScreenState();
}

class _XiangqiLocalGameScreenState extends State<XiangqiLocalGameScreen> {
  static const _game = XiangqiGame();

  String _humanSide = 'red';

  String get _computerSide => _humanSide == 'red' ? 'black' : 'red';

  XiangqiDifficulty _difficulty = XiangqiDifficulty.hard;
  late XiangqiState _state;
  GameResult? _result;
  bool _computerThinking = false;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    setState(() {
      _state = _game.createInitialState(const ['red', 'black'], seed: 0);
      _result = null;
      _computerThinking = false;
    });
  }

  void _setHumanSide(String side) {
    if (side == _humanSide) return;
    setState(() {
      _humanSide = side;
      _result = null;
      _computerThinking = false;
      _state = _game.createInitialState(const ['red', 'black'], seed: 0);
    });
  }

  void _playHuman(Map<String, dynamic> action) {
    if (_computerThinking || _result != null || _state.currentPlayer != _humanSide) {
      return;
    }
    final move = _game.decodeAction(action);
    if (!_game.validate(_state, _humanSide, move).isValid) return;

    setState(() {
      _state = _game.apply(_state, _humanSide, move);
      if (_game.isFinished(_state)) _result = _game.getResult(_state);
    });
    if (_result == null) unawaited(_playComputer());
  }

  Future<void> _playComputer() async {
    setState(() => _computerThinking = true);
    final delayMs = switch (_difficulty) {
      XiangqiDifficulty.easy => 180,
      XiangqiDifficulty.medium => 240,
      XiangqiDifficulty.hard => 320,
      XiangqiDifficulty.expert => 420,
    };
    await Future<void>.delayed(Duration(milliseconds: delayMs));
    if (!mounted || _result != null) return;

    final move = _chooseComputerMove();
    if (move == null) {
      setState(() => _computerThinking = false);
      return;
    }

    final next = _game.apply(_state, _computerSide, move);
    setState(() {
      _state = next;
      _result = _game.isFinished(next) ? _game.getResult(next) : null;
      _computerThinking = false;
    });
  }

  XiangqiMove? _chooseComputerMove() {
    final legal = XiangqiGame.legalMovesFor(_state, _computerSide);
    final dest = XiangqiAi.pickMove(_state, _computerSide, _difficulty);
    if (dest == null) return legal.isEmpty ? null : legal.first;

    for (final move in legal) {
      if (move.to == dest) return move;
    }
    return legal.isEmpty ? null : legal.first;
  }

  @override
  Widget build(BuildContext context) {
    final view = GameView(
      state: _game.encodeState(_state),
      me: _humanSide,
      seatOrder: const ['red', 'black'],
      nicknames: const {'red': 'Đỏ', 'black': 'Đen'},
      currentActors: _result == null ? _game.currentActors(_state) : const [],
      result: _result,
      onAction: _playHuman,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cờ tướng - Chơi với máy'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Chọn quân của bạn',
            initialValue: _humanSide,
            onSelected: (value) => _setHumanSide(value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'red', child: Text('Đỏ - đi trước')),
              PopupMenuItem(value: 'black', child: Text('Đen - đi sau')),
            ],
          ),
          PopupMenuButton<XiangqiDifficulty>(
            tooltip: 'Chọn mức độ máy',
            initialValue: _difficulty,
            onSelected: (value) {
              setState(() => _difficulty = value);
              if (_state.currentPlayer == _computerSide && !_computerThinking && _result == null) {
                unawaited(_playComputer());
              }
            },
            itemBuilder: (context) => XiangqiDifficulty.values
                .map(
                  (level) => PopupMenuItem(
                    value: level,
                    child: Text(_labelForXiangqiDifficulty(level)),
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
                          : (_state.currentPlayer == _humanSide ? 'Lượt của bạn' : 'Lượt máy'))
                      : (_result!.winners.contains(_humanSide)
                          ? 'Bạn thắng!'
                          : _result!.isDraw
                              ? 'Ván hòa'
                              : 'Máy thắng'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Mức máy: ${_labelForXiangqiDifficulty(_difficulty)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Expanded(child: XiangqiBoard(view: view)),
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

String _labelForXiangqiDifficulty(XiangqiDifficulty level) {
  switch (level) {
    case XiangqiDifficulty.easy:
      return 'Dễ';
    case XiangqiDifficulty.medium:
      return 'Trung bình';
    case XiangqiDifficulty.hard:
      return 'Khó';
    case XiangqiDifficulty.expert:
      return 'Chuyên gia';
  }
}
