import 'dart:async';

import 'package:flutter/foundation.dart';
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

enum _Menu { newGame }

class _TicTacToeLocalGameScreenState extends State<TicTacToeLocalGameScreen> {
  static const _game = TicTacToeGame();
  static const _human = 'human';
  static const _computer = 'computer';

  TicTacToeDifficulty _difficulty = TicTacToeDifficulty.hard;
  late TicTacToeState _state;

  /// Các thế cờ trước đó, để hoàn tác.
  ///
  /// Giữ nguyên thế cờ thay vì tính ngược nước đi: ván cờ còn có cầu hòa, xin
  /// thua, đường thắng — tính ngược tất cả những thứ đó là một hàm mới phải tự
  /// kiểm chứng, còn giữ lại thì đúng theo định nghĩa.
  final List<TicTacToeState> _history = <TicTacToeState>[];

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
      _state = _game.createInitialState([_human, _computer], seed: 0);
      _history.clear();
      _result = null;
      _computerThinking = false;
    });
  }

  /// Lùi lại tới lượt gần nhất của người chơi.
  ///
  /// Lùi một nước là trả về lượt của máy, và máy sẽ đánh lại ngay — nhìn như
  /// nút không có tác dụng. Nên lùi cho tới khi đến lượt người.
  void _undo() {
    if (_history.isEmpty || _computerThinking) return;
    _round++; // Huỷ nước máy đang tính dở, nếu có.
    setState(() {
      while (_history.isNotEmpty) {
        _state = _history.removeLast();
        if (_state.currentPlayer == _human) break;
      }
      _result = null;
      _computerThinking = false;
    });
  }

  /// Dat ket qua va cong diem cung mot cho.
  ///
  /// Moi duong van co the ket thuc deu di qua day, nen khong nhanh nao cong
  /// diem hai lan hay quen cong.
  void _settle(TicTacToeState next) {
    _result = _game.isFinished(next) ? _game.getResult(next) : null;
    if (_result != null) _series = _series.after(_result!);
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
      _history.add(_state);
      _state = _game.apply(_state, _human, move);
      _settle(_state);
    });
    if (_result != null) return;
    if (move is TicTacToeDrawOffer) {
      unawaited(_respondToDrawOffer());
    } else if (move is TicTacToeMove) {
      unawaited(_playComputer());
    }
  }

  Future<void> _respondToDrawOffer() async {
    final round = _round;
    setState(() => _computerThinking = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted || round != _round || _state.drawOfferBy != _human) return;

    // Máy đồng ý hòa khi bàn đã gần kín mà chưa ai có đường; còn sớm thì từ
    // chối, vì cờ caro tự do vốn còn rất nhiều đất để chơi.
    final filled = _state.board.where((cell) => cell != null).length;
    final decision = filled > _state.board.length * 0.7
        ? const TicTacToeDrawAccept()
        : const TicTacToeDrawReject();
    setState(() {
      _history.add(_state);
      _state = _game.apply(_state, _computer, decision);
      _settle(_state);
      _computerThinking = false;
    });
  }

  /// Thời gian tối thiểu của một lượt máy.
  ///
  /// Dài hơn nét viết của một quân: quân người chơi phải viết xong rồi quân
  /// máy mới bắt đầu rơi xuống, hai nét chồng lên nhau thì mắt không theo kịp
  /// bên nào. Là chờ *bù*, không cộng thêm vào thời gian máy đã nghĩ.
  ///
  /// Đi cùng `_writeDurationO` bên bàn cờ — rút nét viết mà quên rút chỗ này
  /// thì mỗi lượt vẫn hụt một nhịp trống không ai giải thích được.
  static const _minimumTurn = Duration(milliseconds: 230);

  Future<void> _playComputer() async {
    final round = _round;
    setState(() => _computerThinking = true);

    // Đợi cho khung hình chứa nước người chơi vừa đánh được dựng xong hẳn.
    // `Future.delayed` một nhịp thì không bảo đảm điều đó — timer và vsync là
    // hai đồng hồ rời nhau, lúc cái này về trước lúc cái kia.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _result != null || round != _round) return;

    final clock = Stopwatch()..start();
    // Máy nghĩ ở isolate nền. Xem [pickTicTacToeMove] để biết vì sao không
    // được tính ngay tại đây.
    final picked = await compute(
      pickTicTacToeMove,
      TicTacToeAiRequest(
        state: _game.encodeState(_state),
        actor: _computer,
        difficulty: _difficulty,
      ),
    );
    clock.stop();
    if (!mounted || _result != null || round != _round) return;

    final cell = picked ?? _firstEmptyCell();
    if (cell == null) {
      setState(() => _computerThinking = false);
      return;
    }

    final remaining = _minimumTurn - clock.elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
      if (!mounted || _result != null || round != _round) return;
    }

    final next = _game.apply(_state, _computer, TicTacToeMove(cell));
    setState(() {
      _history.add(_state);
      _state = next;
      _settle(next);
      _computerThinking = false;
    });
  }

  int? _firstEmptyCell() {
    for (var index = 0; index < _state.board.length; index++) {
      if (_state.board[index] == null) return index;
    }
    return null;
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
      series: _series,
      onAction: _playHuman,
    );

    // Nhạc nền chạy suốt màn này và tắt khi rời đi. Ván qua mạng đã có nhạc
    // do màn phòng của app lo; màn chơi với máy là của game nên tự bọc lấy.
    return GameMusic(
      child: Scaffold(
        backgroundColor: GameColors.page,
        appBar: gameAppBar(
          context: context,
          title: 'Cờ caro',
          background: GameColors.page,
          foreground: GameColors.ink,
          actions: [
            const GameAudioButton(),
            PopupMenuButton<Object>(
              tooltip: 'Tuỳ chọn ván đấu',
              icon: const Icon(Icons.more_vert_rounded,
                  size: 20, color: GameColors.ink),
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
                  case _Menu.newGame:
                    _reset();
                  case final TicTacToeDifficulty level:
                    setState(() => _difficulty = level);
                    if (_state.currentPlayer == _computer &&
                        !_computerThinking &&
                        _result == null) {
                      unawaited(_playComputer());
                    }
                }
              },
              itemBuilder: (context) => [
                for (final level in TicTacToeDifficulty.values)
                  CheckedPopupMenuItem(
                    value: level,
                    checked: _difficulty == level,
                    child: Text(level.label),
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
              child: TicTacToeBoard(
                view: view,
                onUndo: _undo,
                opponentSubtitle: _computerThinking
                    ? 'Đang nghĩ…'
                    : 'Độ khó: ${_difficulty.label}',
              ),
            ),
            if (_result != null)
              Container(
                width: double.infinity,
                color: GameColors.page,
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
