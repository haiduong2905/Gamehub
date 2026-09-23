import 'dart:math';

import 'package:platform_core/platform_core.dart';

import 'tic_tac_toe.dart';

/// Máy đánh cờ caro 20x20.
///
/// Ba thứ quyết định cả tốc độ lẫn trình độ, và bản đầu tiên sai cả ba:
///
/// **1. Chỉ xét ô gần quân đã có.** Bàn 400 ô nhưng nước đáng đánh luôn nằm
/// sát đám quân hiện tại. Xét bán kính 2 quanh các quân đã đặt thường chỉ còn
/// 20-40 ô, tức nhánh nhỏ đi hơn 10 lần ở *mỗi* tầng.
///
/// **2. Điểm thế cờ tính tăng dần.** Điểm toàn bàn là tổng điểm của mọi cửa sổ
/// 5 ô. Đặt một quân chỉ đổi những cửa sổ chứa ô đó — nhiều nhất 4 hướng x 5
/// cửa sổ. Nên thay vì quét lại cả bàn (1600 cửa sổ) sau mỗi nước, chỉ cần
/// cộng trừ 20 cửa sổ. Kết quả giống hệt, nhanh hơn khoảng 80 lần.
///
/// **3. Có hạn giờ.** Tìm kiếm sâu dần (2, 4, 6, 8...) và dừng khi hết giờ,
/// giữ kết quả của tầng sâu nhất đã xong. Nhờ vậy máy *không bao giờ* nghĩ lâu
/// hơn ngân sách, dù thế cờ rối tới đâu.
///
/// Pure Dart: `Stopwatch` và `Random` đều nằm trong `dart:core`/`dart:math`,
/// không đụng tới Flutter hay `dart:io`.
class TicTacToeAi {
  const TicTacToeAi._();

  /// Tìm ô cho [actor] đánh, hoặc `null` nếu bàn đã đầy.
  static int? pickMove(
    TicTacToeState state,
    PlayerId actor,
    TicTacToeDifficulty difficulty, {
    Random? random,
  }) {
    final engine = _Engine(
      board: List<Mark?>.of(state.board),
      me: state.markOf(actor),
      profile: _Profile.of(difficulty),
      random: random ?? Random(),
    );
    return engine.pick();
  }
}

/// Thông số của một mức độ. Bốn mức khác nhau ở **độ sâu nhìn trước**, chứ
/// không phải ở việc cố tình đánh dở.
class _Profile {
  const _Profile({
    required this.maxDepth,
    required this.rootCandidates,
    required this.innerCandidates,
    required this.budget,
    required this.defenceWeight,
    required this.noise,
  });

  /// Tầng sâu nhất được thử. 0 nghĩa là không tìm kiếm, chỉ chấm điểm nước đi.
  final int maxDepth;

  final int rootCandidates;
  final int innerCandidates;
  final Duration budget;

  /// Nhân vào điểm chặn đối thủ. Dưới 1 thì máy ham tấn công và hay quên đỡ —
  /// đó chính là cái làm nên mức Dễ.
  final int defenceWeight;

  /// Số nước đầu bảng được bốc ngẫu nhiên. 1 là luôn chọn nước tốt nhất.
  final int noise;

  static _Profile of(TicTacToeDifficulty difficulty) => switch (difficulty) {
        // Nhìn đúng một nước: cướp thắng nếu có, chặn thua ngay trước mắt,
        // còn lại đánh theo cảm tính và không thấy đòn đôi.
        TicTacToeDifficulty.easy => const _Profile(
            maxDepth: 0,
            rootCandidates: 8,
            innerCandidates: 0,
            budget: Duration(milliseconds: 40),
            defenceWeight: 4,
            noise: 4,
          ),
        // Nhìn trước hai nước: đã biết chặn ba mở.
        TicTacToeDifficulty.medium => const _Profile(
            maxDepth: 2,
            rootCandidates: 12,
            innerCandidates: 8,
            budget: Duration(milliseconds: 150),
            defenceWeight: 8,
            noise: 2,
          ),
        // Nhìn trước sáu nước: thấy được đòn đôi và chuỗi ép ngắn.
        TicTacToeDifficulty.hard => const _Profile(
            maxDepth: 6,
            rootCandidates: 14,
            innerCandidates: 8,
            budget: Duration(milliseconds: 450),
            defenceWeight: 9,
            noise: 1,
          ),
        // Sâu dần tới 8 tầng trong 0,7 giây: thấy được chuỗi ép bằng nước bốn.
        TicTacToeDifficulty.expert => const _Profile(
            maxDepth: 8,
            rootCandidates: 16,
            innerCandidates: 10,
            budget: Duration(milliseconds: 700),
            defenceWeight: 10,
            noise: 1,
          ),
      };
}

/// Mức nguy hiểm của một nước, đọc từ các cửa sổ 5 ô đi qua nó.
class _Threat {
  const _Threat({
    required this.five,
    required this.fours,
    required this.openThrees,
    required this.threes,
    required this.twos,
  });

  /// Đánh vào đây là thành 5 quân: thắng ngay.
  final bool five;

  /// Số hướng tạo ra nước bốn. Hai trở lên là đối thủ không đỡ xuể.
  final int fours;

  /// Số hướng tạo ra ba mở (hai đầu thoáng).
  final int openThrees;

  final int threes;
  final int twos;

  /// Điểm để xếp thứ tự nước đi. Các mốc cách nhau rất xa để một đòn đôi luôn
  /// được xét trước mọi nước bình thường, bất kể nước đó đẹp tới đâu.
  int get score {
    if (five) return 10000000;
    if (fours >= 2) return 500000;
    if (fours >= 1 && openThrees >= 1) return 300000;
    if (openThrees >= 2) return 200000;
    if (fours >= 1) return 20000;
    if (openThrees >= 1) return 8000;
    return threes * 400 + twos * 40;
  }
}

const _size = TicTacToeGame.boardSize;
const _win = TicTacToeGame.winLength;
const _cells = _size * _size;

/// Bốn hướng của một đường: ngang, dọc, chéo xuôi, chéo ngược.
const _directions = [(0, 1), (1, 0), (1, 1), (1, -1)];

/// Điểm của một cửa sổ 5 ô chỉ chứa quân mình.
const _attackWeight = [0, 1, 14, 130, 1600, 1000000];

/// Điểm của một cửa sổ 5 ô chỉ chứa quân đối thủ. Cao hơn bảng tấn công một
/// chút: trong cờ caro, ai chỉ mải tấn công thì thua trước nửa nhịp.
const _defenceWeight = [0, 1, 17, 160, 2100, 1200000];

const _winScore = 100000000;

class _Engine {
  _Engine({
    required this.board,
    required this.me,
    required this.profile,
    required this.random,
  }) : them = me == Mark.x ? Mark.o : Mark.x {
    for (var cell = 0; cell < _cells; cell++) {
      if (board[cell] != null) _stones++;
    }
    _score = _fullScore();
  }

  final List<Mark?> board;
  final Mark me;
  final Mark them;
  final _Profile profile;
  final Random random;

  final _clock = Stopwatch();
  int _stones = 0;
  int _score = 0;
  bool _outOfTime = false;

  int? pick() {
    if (_stones == _cells) return null;
    _clock.start();

    // Bàn trống: đánh giữa. Không cần thuật toán nào để biết điều đó.
    if (_stones == 0) return (_size ~/ 2) * _size + _size ~/ 2;

    final candidates = _candidates(profile.rootCandidates);
    if (candidates.isEmpty) return _anyEmptyCell();

    // Hai nước bắt buộc, kiểm tra trước khi tìm kiếm vì chúng vừa rẻ vừa
    // tuyệt đối: thắng được thì thắng, sắp thua thì chặn.
    for (final cell in candidates) {
      if (_threatOf(cell, me).five) return cell;
    }
    for (final cell in candidates) {
      if (_threatOf(cell, them).five) return cell;
    }

    if (profile.maxDepth == 0) return _pickGreedy(candidates);

    return _pickBySearch(candidates);
  }

  /// Mức Dễ: chọn trong vài nước đầu bảng, có pha ngẫu nhiên.
  int _pickGreedy(List<int> candidates) {
    final take = min(profile.noise, candidates.length);
    return candidates[random.nextInt(take)];
  }

  /// Tìm kiếm sâu dần, giữ kết quả của tầng cuối cùng chạy xong.
  ///
  /// Sâu dần chứ không nhảy thẳng vào tầng sâu nhất vì hai lẽ: luôn có sẵn một
  /// nước hợp lệ để trả về khi hết giờ, và thứ tự nước của tầng trước giúp
  /// cắt nhánh ở tầng sau.
  int _pickBySearch(List<int> candidates) {
    var best = candidates.first;
    var ordered = candidates;

    for (var depth = 2; depth <= profile.maxDepth; depth += 2) {
      final scored = <int, int>{};
      var bestScore = -_winScore * 2;
      int? bestOfDepth;

      for (final cell in ordered) {
        _place(cell, me);
        final value = _makesFive(cell)
            ? _winScore + depth
            : _search(depth - 1, -_winScore * 2, _winScore * 2, false);
        _undo(cell);

        if (_outOfTime) break;

        scored[cell] = value;
        if (bestOfDepth == null || value > bestScore) {
          bestScore = value;
          bestOfDepth = cell;
        }
      }

      if (bestOfDepth == null) break;
      best = bestOfDepth;

      // Thắng ép được rồi thì đào sâu thêm cũng không đổi kết quả.
      if (bestScore >= _winScore) break;
      if (_outOfTime || _expired) break;

      ordered = scored.keys.toList(growable: false)
        ..sort((a, b) => scored[b]!.compareTo(scored[a]!));
    }

    return best;
  }

  int _search(int depth, int alpha, int beta, bool maximizing) {
    if (_expired) {
      _outOfTime = true;
      return _score;
    }
    if (depth <= 0 || _stones == _cells) return _score;

    final mark = maximizing ? me : them;
    final candidates = _candidates(profile.innerCandidates);
    if (candidates.isEmpty) return _score;

    var currentAlpha = alpha;
    var currentBeta = beta;
    var best = maximizing ? -_winScore * 2 : _winScore * 2;

    for (final cell in candidates) {
      _place(cell, mark);
      final int value;
      if (_makesFive(cell)) {
        value = maximizing ? _winScore + depth : -_winScore - depth;
      } else {
        value = _search(depth - 1, currentAlpha, currentBeta, !maximizing);
      }
      _undo(cell);

      if (_outOfTime) return best;

      if (maximizing) {
        if (value > best) best = value;
        if (best > currentAlpha) currentAlpha = best;
      } else {
        if (value < best) best = value;
        if (best < currentBeta) currentBeta = best;
      }
      if (currentBeta <= currentAlpha) break;
    }

    return best;
  }

  bool get _expired => _clock.elapsed >= profile.budget;

  /// Các ô trống nằm trong bán kính 2 quanh một quân đã đặt, xếp theo điểm đe
  /// doạ giảm dần, cắt còn [limit] ô.
  List<int> _candidates(int limit) {
    final scored = <MapEntry<int, int>>[];

    for (var cell = 0; cell < _cells; cell++) {
      if (board[cell] != null) continue;
      if (!_hasNeighbour(cell)) continue;

      final attack = _threatOf(cell, me).score;
      final defence = _threatOf(cell, them).score;
      scored.add(MapEntry(cell, attack + defence * profile.defenceWeight ~/ 10));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final entry in scored.take(limit)) entry.key,
    ];
  }

  bool _hasNeighbour(int cell) {
    final row = cell ~/ _size;
    final column = cell % _size;
    for (var dr = -2; dr <= 2; dr++) {
      final r = row + dr;
      if (r < 0 || r >= _size) continue;
      for (var dc = -2; dc <= 2; dc++) {
        final c = column + dc;
        if (c < 0 || c >= _size) continue;
        if (board[r * _size + c] != null) return true;
      }
    }
    return false;
  }

  /// Đọc mức đe doạ nếu [mark] đánh vào [cell], bằng cách đặt thử rồi trả lại.
  _Threat _threatOf(int cell, Mark mark) {
    final saved = board[cell];
    board[cell] = mark;

    var five = false;
    var fours = 0;
    var openThrees = 0;
    var threes = 0;
    var twos = 0;

    final row = cell ~/ _size;
    final column = cell % _size;

    for (final (dr, dc) in _directions) {
      var fourWindows = 0;
      var threeWindows = 0;
      var twoWindows = 0;

      for (var back = 0; back < _win; back++) {
        final startRow = row - dr * back;
        final startColumn = column - dc * back;
        if (!_windowInBoard(startRow, startColumn, dr, dc)) continue;

        var mine = 0;
        var blocked = false;
        for (var i = 0; i < _win; i++) {
          final value =
              board[(startRow + dr * i) * _size + startColumn + dc * i];
          if (value == mark) {
            mine++;
          } else if (value != null) {
            blocked = true;
            break;
          }
        }
        if (blocked) continue;

        if (mine >= _win) {
          five = true;
        } else if (mine == 4) {
          fourWindows++;
        } else if (mine == 3) {
          threeWindows++;
        } else if (mine == 2) {
          twoWindows++;
        }
      }

      // Hai cửa sổ cùng thiếu một quân nghĩa là có hai cách hoàn thành năm
      // quân — đối thủ chỉ chặn được một. Đó chính là "bốn mở".
      if (fourWindows >= 2) {
        fours += 2;
      } else if (fourWindows == 1) {
        fours += 1;
      }
      if (threeWindows >= 2) {
        openThrees++;
      } else if (threeWindows == 1) {
        threes++;
      }
      if (twoWindows > 0) twos++;
    }

    board[cell] = saved;

    return _Threat(
      five: five,
      fours: fours,
      openThrees: openThrees,
      threes: threes,
      twos: twos,
    );
  }

  bool _makesFive(int cell) {
    final mark = board[cell];
    if (mark == null) return false;

    final row = cell ~/ _size;
    final column = cell % _size;

    for (final (dr, dc) in _directions) {
      var count = 1;
      for (final sign in const [1, -1]) {
        var r = row + dr * sign;
        var c = column + dc * sign;
        while (r >= 0 &&
            c >= 0 &&
            r < _size &&
            c < _size &&
            board[r * _size + c] == mark) {
          count++;
          r += dr * sign;
          c += dc * sign;
        }
      }
      if (count >= _win) return true;
    }
    return false;
  }

  void _place(int cell, Mark mark) {
    _score -= _scoreAround(cell);
    board[cell] = mark;
    _score += _scoreAround(cell);
    _stones++;
  }

  void _undo(int cell) {
    _score -= _scoreAround(cell);
    board[cell] = null;
    _score += _scoreAround(cell);
    _stones--;
  }

  /// Tổng điểm của mọi cửa sổ 5 ô đi qua [cell].
  ///
  /// Đây là toàn bộ phần điểm mà một quân ở ô này ảnh hưởng tới, nên hiệu số
  /// trước/sau khi đặt quân chính là thay đổi của điểm toàn bàn.
  int _scoreAround(int cell) {
    final row = cell ~/ _size;
    final column = cell % _size;
    var total = 0;

    for (final (dr, dc) in _directions) {
      for (var back = 0; back < _win; back++) {
        final startRow = row - dr * back;
        final startColumn = column - dc * back;
        if (!_windowInBoard(startRow, startColumn, dr, dc)) continue;
        total += _windowScore(startRow, startColumn, dr, dc);
      }
    }
    return total;
  }

  int _fullScore() {
    var total = 0;
    for (var row = 0; row < _size; row++) {
      for (var column = 0; column < _size; column++) {
        for (final (dr, dc) in _directions) {
          if (!_windowInBoard(row, column, dr, dc)) continue;
          total += _windowScore(row, column, dr, dc);
        }
      }
    }
    return total;
  }

  int _windowScore(int startRow, int startColumn, int dr, int dc) {
    var mine = 0;
    var theirs = 0;
    for (var i = 0; i < _win; i++) {
      final value = board[(startRow + dr * i) * _size + startColumn + dc * i];
      if (value == me) {
        mine++;
      } else if (value == them) {
        theirs++;
      }
    }
    if (mine > 0 && theirs == 0) return _attackWeight[mine];
    if (theirs > 0 && mine == 0) return -_defenceWeight[theirs];
    return 0;
  }

  bool _windowInBoard(int startRow, int startColumn, int dr, int dc) {
    if (startRow < 0 || startColumn < 0 || startRow >= _size ||
        startColumn >= _size) {
      return false;
    }
    final endRow = startRow + dr * (_win - 1);
    final endColumn = startColumn + dc * (_win - 1);
    return endRow >= 0 && endColumn >= 0 && endRow < _size && endColumn < _size;
  }

  int? _anyEmptyCell() {
    for (var cell = 0; cell < _cells; cell++) {
      if (board[cell] == null) return cell;
    }
    return null;
  }
}
