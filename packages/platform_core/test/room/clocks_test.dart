import 'package:platform_core/platform_core.dart';
import 'package:test/test.dart';

import '../support/harness.dart';
import '../support/race_game.dart';

GameRegistry _registry() => GameRegistry()..register(const RaceGame());

int _now() => DateTime.now().millisecondsSinceEpoch;

/// Dong ho kieu co vua: moi nguoi mot cap.
///
/// * Dong ho NUOC DI dat lai tron ven moi khi den luot nguoi do.
/// * Dong ho CA VAN la ngan sach cua rieng ho, chi tru di trong luc chinh ho
///   dang suy nghi.
///
/// Tren day host gui SO MILI GIAY CON LAI chu khong phai moc thoi gian, va
/// may nhan dong dau theo dong ho cua chinh no. Hai dien thoai lech gio he
/// thong bao nhieu cung khong anh huong.
void main() {
  group('dong ho tung nguoi', () {
    late RoomHarness h;

    tearDown(() => h.dispose());

    Future<(RoomClient host, RoomClient guest)> start(
      RoomSettings settings,
    ) async {
      h = RoomHarness(
        registry: _registry(),
        gameId: 'race',
        settings: settings,
      );
      final host = await h.open();
      final guest = await h.joinViaDiscovery(playerId: 'p2', nickname: 'Nam');
      host.setReady(ready: true);
      guest.setReady(ready: true);
      await h.settle();
      host.startGame();
      await h.settle();
      return (host, guest);
    }

    test('khong dat gioi han thi khong co dong ho nao', () async {
      final (host, _) = await start(const RoomSettings());

      expect(host.state.playerClocks, isEmpty);
    });

    test('moi nguoi mot ngan sach, chi dong ho nguoi dang di moi chay',
        () async {
      final (host, guest) = await start(
        const RoomSettings(
          matchTimeLimit: Duration(minutes: 3),
          moveTimeLimit: Duration(seconds: 30),
        ),
      );

      expect(host.state.playerClocks.keys.toSet(), {'host', 'p2'});
      expect(host.state.playerClocks['host']!.running, isTrue,
          reason: 'host di truoc nen dong ho cua host chay');
      expect(host.state.playerClocks['p2']!.running, isFalse);
      // Ca hai may phai thay cung mot su that.
      expect(guest.state.playerClocks['host']!.running, isTrue);
      expect(guest.state.playerClocks['p2']!.running, isFalse);
    });

    test('nghi lau chi an vao phan cua minh, khong an vao phan doi thu',
        () async {
      const match = Duration(minutes: 3);
      final (host, _) = await start(const RoomSettings(matchTimeLimit: match));

      await Future<void>.delayed(const Duration(milliseconds: 120));
      host.sendAction({'step': 2});
      await h.settle();

      final clocks = host.state.playerClocks;
      expect(
        clocks['host']!.matchRemainingAt(_now()),
        lessThan(match.inMilliseconds - 100),
        reason: 'host nghi 120ms thi host phai bi tru',
      );
      expect(
        clocks['p2']!.matchRemainingAt(_now()),
        greaterThan(match.inMilliseconds - 60),
        reason: 'doi thu ngoi khong thi khong bi tru 120ms host vua nghi - '
            'day chinh la cho khac nhau giua dong ho co vua va mot dong ho '
            'dem chung cho ca ban co',
      );
    });

    test('dong ho nuoc di dat lai tron ven moi luot', () async {
      const move = Duration(seconds: 30);
      final (host, _) = await start(const RoomSettings(moveTimeLimit: move));

      await Future<void>.delayed(const Duration(milliseconds: 80));
      host.sendAction({'step': 2});
      await h.settle();

      expect(
        host.state.playerClocks['p2']!.moveRemainingAt(_now()),
        closeTo(move.inMilliseconds, 1000),
        reason: 'nguoi sap di duoc tron 30 giay cua rieng minh',
      );
    });

    test('gui lai state giua luot khong lam dong ho nhay ve dau', () async {
      // Day la ly do day chi mang SO CON LAI, khong mang gioi han da thiet
      // lap. Host gui lai GAME_STATE ngay giua luot moi khi mot nuoc di bi tu
      // choi - neu may nhan cu thay ban tin la dem lai tu dau thi cham bay vao
      // o khong hop le se duoc tang them thoi gian.
      final (host, guest) = await start(
        const RoomSettings(moveTimeLimit: Duration(seconds: 30)),
      );

      host.sendAction({'step': 2});
      await h.settle();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final before = guest.state.playerClocks['p2']!.moveRemainingAt(_now())!;
      guest.sendAction({'step': 9}); // BAD_STEP -> host gui lai state
      await h.settle();

      expect(guest.state.errorCode, 'BAD_STEP');
      expect(
        guest.state.playerClocks['p2']!.moveRemainingAt(_now()),
        lessThanOrEqualTo(before),
        reason: 'nuoc di bi tu choi khong duoc lam dong ho dai ra',
      );
    });

    test('het gio nuoc di thi nguoi dang phai di bi xu thua', () async {
      final (host, guest) = await start(
        const RoomSettings(moveTimeLimit: Duration(milliseconds: 60)),
      );

      await Future<void>.delayed(const Duration(milliseconds: 140));
      await h.settle();

      expect(host.state.result?.reason, 'MOVE_TIMEOUT');
      expect(host.state.result?.winners, ['p2'],
          reason: 'host la nguoi dang phai di, nen host thua');
      expect(guest.state.result?.winners, ['p2']);
    });

    test('tieu het ngan sach ca van thi chinh nguoi do thua', () async {
      // Khac han cach cu: het gio khong con la "ca van bi bo do" ma la mot
      // nguoi cu the het gio, va nguoi do thua.
      final (host, guest) = await start(
        const RoomSettings(matchTimeLimit: Duration(milliseconds: 60)),
      );

      await Future<void>.delayed(const Duration(milliseconds: 140));
      await h.settle();

      expect(host.state.result?.reason, 'MATCH_TIMEOUT');
      expect(host.state.result?.winners, ['p2']);
      expect(guest.state.result?.isAbandoned, isFalse,
          reason: 'co nguoi thang thuc su, khong phai van bo do');
    });

    test('van xong thi dong ho tat', () async {
      final (host, guest) = await start(
        const RoomSettings(
          matchTimeLimit: Duration(minutes: 3),
          moveTimeLimit: Duration(seconds: 30),
        ),
      );

      // Race toi 5 diem: host 2, guest 2, host 2, guest 2, host 2 -> host thang.
      for (var i = 0; i < 5; i++) {
        (i.isEven ? host : guest).sendAction({'step': 2});
        await h.settle();
      }

      expect(host.state.result?.winners, ['host']);
      expect(host.state.result?.isAbandoned, isFalse,
          reason: 'van choi den cung khong duoc bi dong ho cat ngang');
      expect(host.state.playerClocks, isEmpty,
          reason: 'van xong thi khong con gi de dem nguoc');
      expect(guest.state.playerClocks, isEmpty);
    });
  });
}
