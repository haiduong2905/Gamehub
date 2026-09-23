import 'dart:async';

import 'package:flutter/material.dart';
import 'package:game_audio/game_audio.dart';
import 'package:platform_core/platform_core.dart';

import '../logic/xiangqi.dart';
import '../logic/xiangqi_ai.dart';
import 'xiangqi_board.dart';

/// Chơi cờ tướng với máy, ngay trên một thiết bị.
///
/// Nằm trong package của game chứ không nằm ở `app`, cùng lý do như các game
/// khác: `app` không được biết trong hub có những game nào.
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
  int _round = 0;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _round++;
    setState(() {
      _state = _game.createInitialState(const ['red', 'black'], seed: 0);
      _result = null;
      _computerThinking = false;
    });
    if (_humanSide == 'black') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _state.currentPlayer == _computerSide &&
            !_computerThinking &&
            _result == null) {
          unawaited(_playComputer());
        }
      });
    }
  }

  void _setHumanSide(String side) {
    if (side == _humanSide) return;
    _humanSide = side;
    _reset();
  }

  void _playHuman(Map<String, dynamic> action) {
    if (_computerThinking ||
        _result != null ||
        _state.currentPlayer != _humanSide) {
      return;
    }
    final move = _game.decodeAction(action);
    if (!_game.validate(_state, _humanSide, move).isValid) return;

    setState(() {
      _state = _game.apply(_state, _humanSide, move);
      if (_game.isFinished(_state)) _result = _game.getResult(_state);
    });
    if (_result != null) return;
    if (move is XiangqiDrawOffer) {
      unawaited(_respondToDrawOffer());
    } else if (move is XiangqiMove) {
      unawaited(_playComputer());
    }
  }

  Future<void> _respondToDrawOffer() async {
    final round = _round;
    setState(() => _computerThinking = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted || round != _round || _state.drawOfferBy != _humanSide) return;

    // Máy đồng ý khi đang thua rõ; ở thế cân bằng hoặc đang hơn thì từ chối.
    final decision = XiangqiGame.evaluate(_state, _computerSide) <= -500
        ? const XiangqiDrawAccept()
        : const XiangqiDrawReject();
    setState(() {
      _state = _game.apply(_state, _computerSide, decision);
      _result = _game.isFinished(_state) ? _game.getResult(_state) : null;
      _computerThinking = false;
    });
  }

  Future<void> _playComputer() async {
    final round = _round;
    setState(() => _computerThinking = true);
    final delayMs = switch (_difficulty) {
      XiangqiDifficulty.easy => 180,
      XiangqiDifficulty.medium => 240,
      XiangqiDifficulty.hard => 320,
      XiangqiDifficulty.expert => 420,
    };
    await Future<void>.delayed(Duration(milliseconds: delayMs));
    if (!mounted || _result != null || round != _round) return;

    final move = _chooseComputerMove();
    if (move == null) {
      setState(() => _computerThinking = false);
      return;
    }

    if (round != _round) return;
    final next = _game.apply(_state, _computerSide, move);
    setState(() {
      _state = next;
      _result = _game.isFinished(next) ? _game.getResult(next) : null;
      _computerThinking = false;
    });
  }

  XiangqiMove? _chooseComputerMove() {
    return XiangqiAi.pickMove(_state, _computerSide, _difficulty);
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

    // Nhạc nền chạy suốt màn này và tắt khi rời đi. Ván qua mạng đã có nhạc
    // do màn phòng của app lo; màn chơi với máy là của game nên tự bọc lấy.
    return GameMusic(
        child: Scaffold(
      appBar: AppBar(
        title: const Text('Cờ tướng - Chơi với máy'),
        actions: [
          const GameAudioButton(),
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
              if (_state.currentPlayer == _computerSide &&
                  !_computerThinking &&
                  _result == null) {
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
                          : (_state.currentPlayer == _humanSide
                              ? 'Lượt của bạn'
                              : 'Lượt máy'))
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
                Text(
                  'Nhóm Elo tham chiếu; sức cờ chưa được hiệu chuẩn bằng đấu thử.',
                  style: Theme.of(context).textTheme.bodySmall,
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
    ));
  }
}

String _labelForXiangqiDifficulty(XiangqiDifficulty level) {
  switch (level) {
    case XiangqiDifficulty.easy:
      return 'Tập sự';
    case XiangqiDifficulty.medium:
      return 'Kỳ thủ Phong trào';
    case XiangqiDifficulty.hard:
      return 'Nhất cấp Kỳ sĩ';
    case XiangqiDifficulty.expert:
      return 'Tượng kỳ Đại sư';
  }
}
