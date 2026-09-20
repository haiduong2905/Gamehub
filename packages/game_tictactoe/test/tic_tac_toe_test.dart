import 'package:flutter_test/flutter_test.dart';
import 'package:game_tictactoe/game_tictactoe.dart';
import 'package:platform_core/platform_core.dart';

const game = TicTacToeGame();

TicTacToeState newGame({Map<String, dynamic> options = const {}}) =>
  game.createInitialState(['x-player', 'o-player'], seed: 0, options: options);

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
      final result =
          game.validate(state, 'o-player', const TicTacToeMove(4));

      expect(result.isValid, isFalse);
      expect(result.code, 'CELL_TAKEN');
    });

    test('khong duoc danh khi chua den luot', () {
      final state = newGame();
      final result =
          game.validate(state, 'o-player', const TicTacToeMove(0));

      expect(result.isValid, isFalse);
      expect(result.code, 'NOT_YOUR_TURN');
    });

    test('khong duoc danh ra ngoai ban co', () {
      expect(
        game.validate(newGame(), 'x-player', const TicTacToeMove(100)).code,
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
      // X: 0,10,20,30,40   O: 1,2,3,4
      final state = playAll(newGame(), [0, 1, 10, 2, 20, 3, 30, 4, 40]);

      expect(state.winningLine, [0, 10, 20, 30, 40]);
      expect(game.getResult(state).winners, ['x-player']);
    });

    test('thang theo duong cheo', () {
      // X: 0,11,22,33,44   O: 1,2,3,4
      final state = playAll(newGame(), [0, 1, 11, 2, 22, 3, 33, 4, 44]);

      expect(state.winningLine, [0, 11, 22, 33, 44]);
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

      expect(restored.cell, 7);
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
      expect(registry.require('tic-tac-toe').name, 'Co caro 20x20');
      expect(registry.all, hasLength(1));
    });
  });
}
