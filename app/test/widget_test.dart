import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_hub/state/catalog.dart';
import 'package:game_hub/ui/game_rooms_screen.dart';
import 'package:game_xiangqi/game_xiangqi.dart';
import 'package:platform_core/platform_core.dart';

void main() {
  testWidgets('choi voi may: ba lan cau hoa bi tu choi thi thua',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: XiangqiLocalGameScreen()),
    );
    for (var rejected = 0; rejected < 3; rejected++) {
      await tester.tap(find.text('Cầu hòa ($rejected/3)'));
      await tester.pump();
      expect(find.text('Đang chờ đối thủ trả lời cầu hòa…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Máy thắng'), findsOneWidget);
    expect(find.text('Bạn thua vì bị từ chối cầu hòa 3 lần'), findsOneWidget);
  });

  testWidgets('choi voi may: xin thua ket thuc van', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: XiangqiLocalGameScreen()),
    );
    await tester.tap(find.text('Xin thua'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Xin thua'));
    await tester.pump();
    expect(find.text('Máy thắng'), findsOneWidget);
    expect(find.text('Bạn đã xin thua'), findsOneWidget);
  });

  testWidgets('chon Den thi may cam Do tu di nuoc dau', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: XiangqiLocalGameScreen()),
    );
    await tester.tap(find.byTooltip('Chọn quân của bạn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đen - đi sau').last);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Lượt của bạn'), findsOneWidget);
  });

  testWidgets('tao phong co tuong chon Den va luu dung game option',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final entry = container.read(gameCatalogProvider).require('xiangqi');
    RoomSettings? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await showDialog<RoomSettings>(
                  context: context,
                  builder: (_) => CreateRoomDialog(entry: entry),
                );
              },
              child: const Text('Mở thiết lập'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở thiết lập'));
    await tester.pumpAndSettle();
    expect(find.text('Đỏ - đi trước'), findsOneWidget);
    expect(find.text('X - đi trước'), findsNothing);

    await tester.tap(find.text('Đỏ - đi trước'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đen - đi sau').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo phòng'));
    await tester.pumpAndSettle();

    expect(selected?.gameOptions, {'hostColor': 'black'});
  });

  test('co caro van dung tuy chon X/O', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final option = container
        .read(gameCatalogProvider)
        .require('tic-tac-toe')
        .hostSideOption!;
    expect(option.key, 'hostMark');
    expect(option.choices.map((choice) => choice.value), ['x', 'o']);
  });
}
