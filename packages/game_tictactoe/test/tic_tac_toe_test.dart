import 'package:flutter_test/flutter_test.dart';
import 'package:game_tictactoe/game_tictactoe.dart';
import 'package:platform_core/platform_core.dart';

const game = TicTacToeGame();

/// Suy ra toa do tu kich thuoc ban co thay vi viet so cung: ban co da doi tu
/// 3x3 sang 10x10 roi 20x20, va moi lan doi lai co mot nhom test chet vi cac
/// so 0, 10, 20 duoc go tay theo be rong cu.
const size = TicTacToeGame.boardSize;

int at(int row, int column) => row * size + column;

List<Mark?> _emptyBoard() => List<Mark?>.filled(size * size, null);

TicTacToeState newGame({Map<String, dynamic> options = const {}}) => game
    .createInitialState(['x-player', 'o-player'], seed: 0, options: options);

TicTacToeState playAll(TicTacToeState state, List<int> cells) {
  var current = state;
  for (final cell in cells) {
    current = game.apply(current, current.currentPlayer, TicTacToeMove(cell));
  }
  return current;
}

void main() {
  group('luat choi', () {
    test('van moi thi ban co trong va X di truoc', () {
      final state = newGame();

      expect(state.board.every((c) => c == null), isTrue);
      expect(state.currentPlayer, 'x-player');
      expect(state.currentMark, Mark.x);
      expect(game.currentActors(state), ['x-player']);
      expect(game.isFinished(state), isFalse);
    });

    test('danh xong thi doi luot', () {
      final state = playAll(newGame(), [4]);

      expect(state.board[4], Mark.x);
      expect(state.currentPlayer, 'o-player');
      expect(game.currentActors(state), ['o-player']);
    });

    test('khong duoc danh vao o da co nguoi', () {
      final state = playAll(newGame(), [4]);
      final result = game.validate(state, 'o-player', const TicTacToeMove(4));

      expect(result.isValid, isFalse);
      expect(result.code, 'CELL_TAKEN');
    });

    test('khong duoc danh khi chua den luot', () {
      final state = newGame();
      final result = game.validate(state, 'o-player', const TicTacToeMove(0));

      expect(result.isValid, isFalse);
      expect(result.code, 'NOT_YOUR_TURN');
    });

    test('khong duoc danh ra ngoai ban co', () {
      expect(
        game.validate(newGame(), 'x-player', TicTacToeMove(size * size)).code,
        'OUT_OF_BOARD',
      );
      expect(
        game.validate(newGame(), 'x-player', const TicTacToeMove(-1)).code,
        'OUT_OF_BOARD',
      );
    });

    test('chu phong chon O thi O di sau va X cua doi thu di truoc', () {
      final state = newGame(options: {'hostMark': 'o'});

      expect(state.currentMark, Mark.x);
      expect(state.currentPlayer, 'o-player');
      expect(state.markOf('x-player'), Mark.o);
      expect(state.markOf('o-player'), Mark.x);
    });

    test('apply khong duoc sua state cu', () {
      final before = newGame();
      game.apply(before, 'x-player', const TicTacToeMove(0));

      expect(before.board.every((c) => c == null), isTrue);
    });
  });

  group('thang thua', () {
    test('thang theo hang ngang', () {
      // X: 0,1,2,3,4   O: 10,11,12,13
      final state = playAll(newGame(), [0, 10, 1, 11, 2, 12, 3, 13, 4]);

      expect(game.isFinished(state), isTrue);
      expect(state.winningLine, [0, 1, 2, 3, 4]);
      expect(game.getResult(state).winners, ['x-player']);
      expect(game.currentActors(state), isEmpty);
    });

    test('thang theo cot doc', () {
      // X doc theo cot 0; O danh lung tung o hang 0 cho du luot.
      final column = [for (var row = 0; row < 5; row++) at(row, 0)];
      final filler = [for (var i = 1; i <= 4; i++) at(0, i + 4)];
      final state = playAll(newGame(), [
        for (var i = 0; i < 5; i++) ...[
          column[i],
          if (i < 4) filler[i],
        ],
      ]);

      expect(state.winningLine, column);
      expect(game.getResult(state).winners, ['x-player']);
    });

    test('thang theo duong cheo', () {
      final diagonal = [for (var i = 0; i < 5; i++) at(i, i)];
      final filler = [for (var i = 1; i <= 4; i++) at(0, i + 4)];
      final state = playAll(newGame(), [
        for (var i = 0; i < 5; i++) ...[
          diagonal[i],
          if (i < 4) filler[i],
        ],
      ]);

      expect(state.winningLine, diagonal);
      expect(game.getResult(state).isWin, isTrue);
    });

    test('nguoi danh O cung thang duoc', () {
      // X: 0,1,2,3,9  O: 10,11,12,13,14
      final state = playAll(newGame(), [0, 10, 1, 11, 2, 12, 3, 13, 9, 14]);

      expect(state.winningLine, [10, 11, 12, 13, 14]);
      expect(game.getResult(state).winners, ['o-player']);
    });

    test('chua du 5 quan thi van chua ket thuc', () {
      final state = playAll(newGame(), [0, 10, 1, 11, 2, 12, 3]);

      expect(game.isFinished(state), isFalse);
      expect(state.hasWinner, isFalse);
    });

    test('da ket thuc thi khong danh tiep duoc', () {
      final state = playAll(newGame(), [0, 10, 1, 11, 2, 12, 3, 13, 4]);

      expect(
        game.validate(state, 'o-player', const TicTacToeMove(6)).code,
        'GAME_FINISHED',
      );
    });
  });

  group('ai', () {
    test('cap do kho cao can nuoc thang ngay neu co the', () {
      final board = List<Mark?>.filled(
          TicTacToeGame.boardSize * TicTacToeGame.boardSize, null);
      for (final cell in [0, 1, 2, 3]) {
        board[cell] = Mark.o;
      }
      final state = TicTacToeState(
        board: board,
        players: ['human', 'computer'],
        xPlayerIndex: 0,
        turnIndex: 1,
      );

      expect(
        TicTacToeAi.pickMove(state, 'computer', TicTacToeDifficulty.hard),
        4,
      );
      expect(
        TicTacToeAi.pickMove(state, 'computer', TicTacToeDifficulty.expert),
        4,
      );
    });

    test('cap do trung va cao phai chan nuoc thang cua nguoi choi', () {
      final board = List<Mark?>.filled(
          TicTacToeGame.boardSize * TicTacToeGame.boardSize, null);
      for (final cell in [0, 1, 2, 3]) {
        board[cell] = Mark.x;
      }
      final state = TicTacToeState(
        board: board,
        players: ['human', 'computer'],
        xPlayerIndex: 0,
        turnIndex: 1,
      );

      expect(
        TicTacToeAi.pickMove(state, 'computer', TicTacToeDifficulty.medium),
        4,
      );
      expect(
        TicTacToeAi.pickMove(state, 'computer', TicTacToeDifficulty.hard),
        4,
      );
    });

    test('cap do de chi chon o trong hop le', () {
      final board = List<Mark?>.filled(
          TicTacToeGame.boardSize * TicTacToeGame.boardSize, null);
      for (final cell in [0, 1, 2, 3]) {
        board[cell] = Mark.x;
      }
      final state = TicTacToeState(
        board: board,
        players: ['human', 'computer'],
        xPlayerIndex: 0,
        turnIndex: 1,
      );

      final move =
          TicTacToeAi.pickMove(state, 'computer', TicTacToeDifficulty.easy);
      expect(move, isNotNull);
      expect(move, isA<int>());
      expect(board[move!], isNull);
    });

    test('cap do kho phai chan ba mo, khong doi den luc bi bon quan', () {
      // X co _XXX_ o giua ban. De den luot X danh tiep thi thanh bon mo va
      // khong con chan duoc, nen day la thoi diem bat buoc phai chan.
      final board = _emptyBoard();
      for (final column in [8, 9, 10]) {
        board[at(10, column)] = Mark.x;
      }
      // Hai quan O de o goc, khong tao de doa gi.
      board[at(0, 0)] = Mark.o;
      board[at(0, 2)] = Mark.o;

      final state = TicTacToeState(
        board: board,
        players: ['human', 'computer'],
        xPlayerIndex: 0,
        turnIndex: 1,
      );

      for (final difficulty in [
        TicTacToeDifficulty.hard,
        TicTacToeDifficulty.expert,
      ]) {
        expect(
          TicTacToeAi.pickMove(state, 'computer', difficulty),
          anyOf(at(10, 7), at(10, 11)),
          reason: 'muc ${difficulty.label} phai bit mot dau cua ba mo',
        );
      }
    });

    test('moi cap do deu tra loi trong han gio cua no', () {
      // The co giua van, day de doa cho ca hai ben - truong hop nang nhat cho
      // thuat toan tim kiem.
      final board = _emptyBoard();
      for (final (row, column) in const [(9, 9), (9, 10), (10, 11), (11, 9)]) {
        board[at(row, column)] = Mark.x;
      }
      for (final (row, column) in const [(10, 9), (10, 10), (9, 11), (11, 11)]) {
        board[at(row, column)] = Mark.o;
      }
      final state = TicTacToeState(
        board: board,
        players: ['human', 'computer'],
        xPlayerIndex: 0,
        turnIndex: 1,
      );

      // Nguong rong gap doi ngan sach: day la canh cho truong hop may nghi
      // mai khong dung, khong phai bai do hieu nang chinh xac.
      const ceiling = {
        TicTacToeDifficulty.easy: 200,
        TicTacToeDifficulty.medium: 400,
        TicTacToeDifficulty.hard: 900,
        TicTacToeDifficulty.expert: 1400,
      };

      for (final difficulty in TicTacToeDifficulty.values) {
        final clock = Stopwatch()..start();
        final move = TicTacToeAi.pickMove(state, 'computer', difficulty);
        clock.stop();

        expect(move, isNotNull);
        expect(board[move!], isNull, reason: 'khong duoc danh de o da co quan');
        expect(
          clock.elapsedMilliseconds,
          lessThan(ceiling[difficulty]!),
          reason: 'muc ${difficulty.label} nghi qua lau',
        );
      }
    });
  });

  group('codec', () {
    test('state di qua encode/decode van nguyen ven', () {
      final state = playAll(newGame(), [0, 10, 1, 11, 2, 12, 3, 13, 4]);
      final restored = game.decodeState(game.encodeState(state));

      expect(restored.board, state.board);
      expect(restored.players, state.players);
      expect(restored.turnIndex, state.turnIndex);
      expect(restored.winningLine, state.winningLine);
    });

    test('nuoc di di qua encode/decode van nguyen ven', () {
      final restored =
          game.decodeAction(game.encodeAction(const TicTacToeMove(7)));

      expect(restored, isA<TicTacToeMove>());
      expect((restored as TicTacToeMove).cell, 7);
    });

    test('cau hoa va xin thua cung di qua encode/decode', () {
      for (final action in const [
        TicTacToeDrawOffer(),
        TicTacToeDrawAccept(),
        TicTacToeDrawReject(),
        TicTacToeResign(),
      ]) {
        expect(
          game.decodeAction(game.encodeAction(action)).runtimeType,
          action.runtimeType,
        );
      }
    });

    test('co caro khong co thong tin an nen viewFor tra ve nguyen state', () {
      final state = playAll(newGame(), [4]);

      expect(game.viewFor('o-player', state).board, state.board);
    });
  });

  group('cam vao platform', () {
    test('choi tron mot van qua RoomHost va Loopback, khong can thiet bi',
        () async {
      final registry = GameRegistry()..register(const TicTacToeGame());
      final network = LoopbackNetwork();
      final discovery = LoopbackDiscovery(network);

      final host = RoomHost(
        registry: registry,
        transport: LoopbackHostTransport(network),
        discovery: discovery,
        roomId: 'r1',
        gameId: 'tic-tac-toe',
        displayName: 'Phong caro',
        hostPlayerId: 'host',
      );

      Future<void> settle() async {
        for (var i = 0; i < 8; i++) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      final hostClient = RoomClient(
        link: await host.open(),
        playerId: 'host',
        nickname: 'Vu',
      )..join();
      await settle();

      final guestLink = await LoopbackClientTransport(network)
          .connect(RoomAddress(host: '127.0.0.1', port: host.port));
      final guest = RoomClient(
        link: guestLink,
        playerId: 'guest',
        nickname: 'Nam',
      )..join();
      await settle();

      hostClient.setReady(ready: true);
      guest.setReady(ready: true);
      await settle();
      hostClient.startGame();
      await settle();

      expect(hostClient.state.phase, ClientPhase.playing);
      expect(hostClient.state.isMyTurn, isTrue);

      // Host la X va thang bang hang tren cung.
      for (final move in [
        (hostClient, 0),
        (guest, 10),
        (hostClient, 1),
        (guest, 11),
        (hostClient, 2),
        (guest, 12),
        (hostClient, 3),
        (guest, 13),
        (hostClient, 4),
      ]) {
        move.$1.sendAction({'cell': move.$2});
        await settle();
      }

      expect(hostClient.state.phase, ClientPhase.finished);
      expect(hostClient.state.result!.winners, ['host']);
      expect(guest.state.result!.winners, ['host'],
          reason: 'ca hai may phai nhan cung ket qua tu host');

      final finalState = game.decodeState(guest.state.gameState!);
      expect(finalState.winningLine, [0, 1, 2, 3, 4]);

      await hostClient.dispose();
      await guest.dispose();
      await host.close();
      await discovery.dispose();
    });

    test('them game moi khong phai sua platform_core', () {
      // Registry nhan game qua interface chung, khong biet game nao ton tai.
      final registry = GameRegistry()..register(const TicTacToeGame());

      expect(registry.contains('tic-tac-toe'), isTrue);
      expect(registry.require('tic-tac-toe').name, 'Cờ caro');
      expect(registry.all, hasLength(1));
    });
  });
}
