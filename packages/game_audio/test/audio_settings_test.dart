import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_audio/game_audio.dart';

void main() {
  group('AudioSettings', () {
    test('mac dinh la bat ca hai va am luong bang am luong media cua may', () {
      const settings = AudioSettings();

      expect(settings.effectsEnabled, isTrue);
      expect(settings.musicEnabled, isTrue);
      expect(settings.volume, 1.0,
          reason: 'he so 1.0 = dung bang muc nguoi dung dat tren thiet bi');
      expect(settings.silent, isFalse);
    });

    test('nhac nen luon nho hon hieu ung', () {
      const settings = AudioSettings();

      expect(settings.musicVolume, lessThan(settings.effectsVolume),
          reason: 'nhac nen to bang hieu ung thi tieng dat quan bi chim');
    });

    test('di qua json van nguyen ven', () {
      const settings = AudioSettings(
        effectsEnabled: false,
        musicEnabled: true,
        volume: 0.4,
      );

      expect(AudioSettings.fromJson(settings.toJson()), settings);
    });

    test('json thieu khoa thi dung mac dinh cua khoa do', () {
      // Ban cu da luu chi co mot khoa: them tuy chon moi khong duoc lam hong
      // cai dat da luu cua nguoi dung.
      final restored = AudioSettings.fromJson({'music': false});

      expect(restored.musicEnabled, isFalse);
      expect(restored.effectsEnabled, isTrue);
      expect(restored.volume, 1.0);
    });

    test('am luong ngoai khoang bi keo ve 0..1', () {
      expect(AudioSettings.fromJson({'volume': 5}).volume, 1.0);
      expect(AudioSettings.fromJson({'volume': -2}).volume, 0.0);
      expect((GameAudioController()..setVolume(9)).settings.volume, 1.0);
    });
  });

  group('GameAudioController', () {
    test('bao khi cai dat doi, va im khi gan lai dung gia tri cu', () {
      final controller = GameAudioController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setMusicEnabled(enabled: false);
      expect(notifications, 1);

      controller.setMusicEnabled(enabled: false);
      expect(notifications, 1, reason: 'gan lai gia tri cu thi khong bao');
    });

    test('cong tac tong tat het roi bat lai ca hai', () {
      final controller = GameAudioController();

      controller.toggleAll();
      expect(controller.settings.silent, isTrue);

      controller.toggleAll();
      expect(controller.settings.effectsEnabled, isTrue);
      expect(controller.settings.musicEnabled, isTrue);
    });
  });

  group('GameAudioScope', () {
    testWidgets('khong co scope thi tra ve null va mac dinh', (tester) async {
      late BuildContext inner;
      await tester.pumpWidget(Builder(builder: (context) {
        inner = context;
        return const SizedBox();
      }));

      expect(GameAudioScope.maybeOf(inner), isNull);
      expect(GameAudioScope.settingsOf(inner), const AudioSettings());
    });

    testWidgets('nut loa tu an khi khong co scope', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GameAudioButton())),
      );

      expect(find.byType(IconButton), findsNothing,
          reason: 'tha an con hon hien mot nut bam khong co tac dung');
    });

    testWidgets('nut loa doi bieu tuong theo cai dat', (tester) async {
      final controller = GameAudioController();

      await tester.pumpWidget(
        GameAudioScope(
          controller: controller,
          child: const MaterialApp(home: Scaffold(body: GameAudioButton())),
        ),
      );

      expect(find.byIcon(Icons.volume_up), findsOneWidget);

      controller
        ..setEffectsEnabled(enabled: false)
        ..setMusicEnabled(enabled: false);
      await tester.pump();

      expect(find.byIcon(Icons.volume_off), findsOneWidget);
    });

    testWidgets('bam vao muc trong nut loa thi tat dung thu do',
        (tester) async {
      final controller = GameAudioController();

      await tester.pumpWidget(
        GameAudioScope(
          controller: controller,
          child: const MaterialApp(home: Scaffold(body: GameAudioButton())),
        ),
      );

      await tester.tap(find.byType(GameAudioButton));
      await tester.pumpAndSettle();
      // warnIfMissed: chữ trong menu nằm dưới lớp phủ của chính menu, nên
      // hit-test không chạm đúng widget Text. Cú chạm vẫn tới được mục menu —
      // hai expect bên dưới là bằng chứng.
      await tester.tap(find.text('Nhạc nền'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(controller.settings.musicEnabled, isFalse);
      expect(controller.settings.effectsEnabled, isTrue,
          reason: 'tat nhac nen khong duoc tat luon hieu ung');
    });
  });
}
