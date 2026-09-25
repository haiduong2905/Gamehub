import 'package:platform_core/platform_core.dart';
import 'package:test/test.dart';

import '../support/harness.dart';
import '../support/race_game.dart';

GameRegistry _registry() => GameRegistry()..register(const RaceGame());

/// Ti so thang - thua cua ca loat van trong mot phong.
///
/// Do host cong va phat xuong, khong phai moi may tu dem: ai vao phong giua
/// chung hoac mat ket noi roi quay lai deu se dem thieu, va hai may hien hai
/// con so khac nhau thi khong co cach nao biet cai nao dung.
void main() {
  group('cong diem', () {
    const a = 'p1';
    const b = 'p2';

    test('thang thi cong cho dung nguoi', () {
      final score = SeriesScore.empty.after(GameResult.win(a));

      expect(score.winsOf(a), 1);
      expect(score.winsOf(b), 0);
      expect(score.draws, 0);
    });

    test('hoa khong cong cho ai, nhung van tinh la mot van da choi', () {
      final score = SeriesScore.empty.after(const GameResult.draw());

      expect(score.winsOf(a), 0);
      expect(score.winsOf(b), 0);
      expect(score.draws, 1);
      expect(score.played, 1);
    });

    test('van bo do khong tinh vao ti so', () {
      final before = SeriesScore.empty.after(GameResult.win(a));
      final after = before.after(const GameResult.abandoned(reason: 'PLAYER_LEFT'));

      expect(after.winsOf(a), 1, reason: 'khong cong them cho ai');
      expect(after.draws, 0);
      expect(
        after.played,
        1,
        reason: 'rut day mang khong duoc bien thanh mot cach ghi diem',
      );
    });

    test('doc lai duoc nguyen ven sau khi ma hoa', () {
      final score = SeriesScore.empty
          .after(GameResult.win(a))
          .after(const GameResult.draw())
          .after(GameResult.win(b))
          .after(GameResult.win(a));

      final decoded = SeriesScore.fromJson(score.toJson());

      expect(decoded.winsOf(a), 2);
      expect(decoded.winsOf(b), 1);
      expect(decoded.draws, 1);
      expect(decoded.played, 4);
    });

    test('ban tin cu khong co truong ti so thi doc ra ti so rong', () {
      expect(SeriesScore.fromJson(null).isEmpty, isTrue);
    });
  });

  group('trong mot phong', () {
    late RoomHarness h;

    tearDown(() => h.dispose());

    /// Mot van Race tron ven, ket thuc bang viec host thang.
    Future<void> hostWins(RoomClient host, RoomClient guest) async {
      host.setReady(ready: true);
      guest.setReady(ready: true);
      await h.settle();
      host.startGame();
      await h.settle();

      // Race toi 5 diem: host cong 2 moi luot, guest cong 1.
      for (var i = 0; i < 3; i++) {
        host.sendAction({'step': 2});
        await h.settle();
        guest.sendAction({'step': 1});
        await h.settle();
      }
    }

    test('ti so cong don qua cac van, va hai may thay cung mot con so',
        () async {
      h = RoomHarness(registry: _registry(), gameId: 'race');
      final host = await h.open();
      final guest = await h.joinViaDiscovery(playerId: 'p2', nickname: 'Nam');

      expect(host.state.series.isEmpty, isTrue, reason: 'chua choi van nao');

      await hostWins(host, guest);
      expect(host.state.series.winsOf('host'), 1);
      expect(host.state.series.winsOf('p2'), 0);

      // Bam "Choi lai": van moi, nhung van cung mot loat dau.
      await hostWins(host, guest);
      expect(host.state.series.winsOf('host'), 2);

      expect(
        guest.state.series.winsOf('host'),
        2,
        reason: 'ti so do host phat xuong nen hai may khong the lech nhau',
      );
      expect(guest.state.series.winsOf('p2'), 0);
    });

    test('ti so den cung ban tin bao van xong, khong den cham mot nhip',
        () async {
      h = RoomHarness(registry: _registry(), gameId: 'race');
      final host = await h.open();
      final guest = await h.joinViaDiscovery(playerId: 'p2', nickname: 'Nam');

      final seen = <int>[];
      guest.states.listen((state) {
        if (state.result != null) seen.add(state.series.winsOf('host'));
      });

      await hostWins(host, guest);
      await h.settle();

      expect(
        seen.first,
        1,
        reason: 'ngay khung hinh dau tien co ket qua da phai co diem cua van do',
      );
    });

    test('nguoi vao phong giua loat dau van thay dung ti so', () async {
      h = RoomHarness(registry: _registry(), gameId: 'race');
      final host = await h.open();
      final guest = await h.joinViaDiscovery(playerId: 'p2', nickname: 'Nam');
      await hostWins(host, guest);

      // Mat ket noi roi quay lai bang chinh playerId cu.
      final secret = guest.roomSecret;
      await guest.dispose();
      await h.settle();
      final again = await h.joinViaDiscovery(
        playerId: 'p2',
        nickname: 'Nam',
        roomSecret: secret,
      );
      await hostWins(host, again);

      expect(again.state.series.winsOf('host'), 2);
    });
  });
}
