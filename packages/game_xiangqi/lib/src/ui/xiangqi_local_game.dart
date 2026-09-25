import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:game_audio/game_audio.dart';
import 'package:platform_core/platform_core.dart';

import '../logic/xiangqi.dart';
import '../logic/xiangqi_ai.dart';
import 'xiangqi_board.dart';
import 'xiangqi_theme.dart';

/// Chơi cờ tướng với máy, ngay trên một thiết bị.
///
/// Nằm trong package của game chứ không nằm ở `app`, cùng lý do như các game
/// khác: `app` không được biết trong hub có những game nào.
class XiangqiLocalGameScreen extends StatefulWidget {
  const XiangqiLocalGameScreen({super.key});

  @override
  State<XiangqiLocalGameScreen> createState() => _XiangqiLocalGameScreenState();
}

enum _Menu { sideRed, sideBlack, newGame }

class _XiangqiLocalGameScreenState extends State<XiangqiLocalGameScreen> {
  static const _game = XiangqiGame();

  String _humanSide = 'red';

  String get _computerSide => _humanSide == 'red' ? 'black' : 'red';

  XiangqiDifficulty _difficulty = XiangqiDifficulty.hard;
  late XiangqiState _state;

  /// Các thế cờ trước đó, để hoàn tác.
  ///
  /// Giữ nguyên thế cờ thay vì tính ngược nước đi: cờ tướng có bắt quân, có
  /// cầu hòa, có kết thúc — tính ngược tất cả những thứ đó là một hàm mới phải
  /// tự kiểm chứng, còn giữ lại thì đúng theo định nghĩa.
  final List<XiangqiState> _history = <XiangqiState>[];

  GameResult? _result;

  /// Ti so tinh tu luc mo man hinh, cong don qua cac van.
  ///
  /// Dung chinh kieu ma host dung cho van qua mang, nen ban co ve ti so chi
  /// co mot duong code — khong co chuyen hai che do hien hai kieu khac nhau.
  SeriesScore _series = SeriesScore.empty;

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
      _history.clear();
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

  /// Lùi lại tới lượt gần nhất của người chơi.
  ///
  /// Lùi một nước là trả về lượt của máy, và máy sẽ đi lại ngay — nhìn như
  /// nút không có tác dụng. Nên lùi cho tới khi đến lượt người.
  void _undo() {
    if (_history.isEmpty || _computerThinking) return;
    _round++; // Huỷ nước máy đang tính dở, nếu có.
    setState(() {
      while (_history.isNotEmpty) {
        _state = _history.removeLast();
        if (_state.currentPlayer == _humanSide) break;
      }
      _result = null;
      _computerThinking = false;
    });
  }

  /// Dat ket qua va cong diem cung mot cho.
  ///
  /// Moi duong van co the ket thuc deu di qua day, nen khong nhanh nao cong
  /// diem hai lan hay quen cong.
  void _settle(XiangqiState next) {
    _result = _game.isFinished(next) ? _game.getResult(next) : null;
    if (_result != null) _series = _series.after(_result!);
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
      _history.add(_state);
      _state = _game.apply(_state, _humanSide, move);
      _settle(_state);
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
      _history.add(_state);
      _state = _game.apply(_state, _computerSide, decision);
      _settle(_state);
      _computerThinking = false;
    });
  }

  /// Thời gian tối thiểu của một lượt máy.
  ///
  /// Dài hơn đường trượt của một quân, để quân người chơi đi xong hẳn rồi quân
  /// máy mới cất bước. Là chờ *bù*, không cộng thêm vào thời gian máy đã nghĩ:
  /// ở mức Chuyên gia máy nghĩ lâu hơn chừng này thì không phải chờ thêm.
  static const _minimumTurn = Duration(milliseconds: 320);

  Future<void> _playComputer() async {
    final round = _round;
    setState(() => _computerThinking = true);

    // Đợi khung hình chứa nước người chơi vừa đi được dựng xong hẳn, trước khi
    // giao việc cho isolate nền.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _result != null || round != _round) return;

    final clock = Stopwatch()..start();
    // Máy nghĩ ở isolate nền. Xem [pickXiangqiMove] để biết vì sao.
    final encoded = await compute(
      pickXiangqiMove,
      XiangqiAiRequest(
        state: _game.encodeState(_state),
        actor: _computerSide,
        difficulty: _difficulty,
      ),
    );
    clock.stop();
    if (!mounted || _result != null || round != _round) return;

    if (encoded == null) {
      setState(() => _computerThinking = false);
      return;
    }
    final move = _game.decodeAction(encoded);

    final remaining = _minimumTurn - clock.elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
      if (!mounted || _result != null || round != _round) return;
    }

    final next = _game.apply(_state, _computerSide, move);
    setState(() {
      _history.add(_state);
      _state = next;
      _settle(next);
      _computerThinking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final view = GameView(
      state: _game.encodeState(_state),
      me: _humanSide,
      seatOrder: const ['red', 'black'],
      // Tên chứ không phải màu: màu đã nằm sẵn ở huy hiệu bên cạnh, để "Đỏ"
      // ở cả hai chỗ thì thẻ đọc ra "Đỏ · Đỏ".
      nicknames: {_humanSide: 'Bạn', _computerSide: 'Máy'},
      currentActors: _result == null ? _game.currentActors(_state) : const [],
      result: _result,
      series: _series,
      onAction: _playHuman,
    );

    // Nhạc nền chạy suốt màn này và tắt khi rời đi. Ván qua mạng đã có nhạc
    // do màn phòng của app lo; màn chơi với máy là của game nên tự bọc lấy.
    return GameMusic(
      child: Scaffold(
        backgroundColor: XiangqiColors.page,
        appBar: gameAppBar(
          context: context,
          title: 'Cờ tướng',
          background: XiangqiColors.page,
          foreground: XiangqiColors.ink,
          actions: [
            const GameAudioButton(),
            PopupMenuButton<Object>(
              tooltip: 'Tuỳ chọn ván đấu',
              icon: const Icon(Icons.more_vert_rounded,
                  size: 20, color: XiangqiColors.ink),
              iconSize: 20,
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFEFEDE8),
                fixedSize: const Size(GameBarButton.size, GameBarButton.size),
                minimumSize: const Size(GameBarButton.size, GameBarButton.size),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSelected: (value) {
                switch (value) {
                  case _Menu.sideRed:
                    _setHumanSide('red');
                  case _Menu.sideBlack:
                    _setHumanSide('black');
                  case _Menu.newGame:
                    _reset();
                  case final XiangqiDifficulty level:
                    setState(() => _difficulty = level);
                    if (_state.currentPlayer == _computerSide &&
                        !_computerThinking &&
                        _result == null) {
                      unawaited(_playComputer());
                    }
                }
              },
              itemBuilder: (context) => [
                CheckedPopupMenuItem(
                  value: _Menu.sideRed,
                  checked: _humanSide == 'red',
                  child: const Text('Cầm Đỏ - đi trước'),
                ),
                CheckedPopupMenuItem(
                  value: _Menu.sideBlack,
                  checked: _humanSide == 'black',
                  child: const Text('Cầm Đen - đi sau'),
                ),
                const PopupMenuDivider(),
                for (final level in XiangqiDifficulty.values)
                  CheckedPopupMenuItem(
                    value: level,
                    checked: _difficulty == level,
                    child: Text(labelForXiangqiDifficulty(level)),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: _Menu.newGame,
                  child: Text('Ván mới'),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: XiangqiBoard(
                view: view,
                onUndo: _undo,
                opponentSubtitle: _computerThinking
                    ? 'Đang nghĩ…'
                    : labelForXiangqiDifficulty(_difficulty),
              ),
            ),
            if (_result != null)
              Container(
                width: double.infinity,
                color: XiangqiColors.page,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: FilledButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Chơi ván mới'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String labelForXiangqiDifficulty(XiangqiDifficulty level) {
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
