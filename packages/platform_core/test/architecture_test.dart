import 'dart:io';

import 'package:test/test.dart';

/// Bien cau hoi review kien truc thanh bai test tu dong.
///
/// GAME_PLATFORM_WORKFLOW.md muc 24 hoi "Game co phu thuoc Network khong?"
/// va "Room co phu thuoc Game cu the khong?". Nhung cau hoi do khong nen phu
/// thuoc vao viec ai do nho kiem tra khi review.
void main() {
  group('ranh gioi cua core', () {
    test('platform_core khong phu thuoc Flutter hay thu vien mang nao',
        () async {
      final pubspec = await File('pubspec.yaml').readAsString();
      const banned = ['flutter', 'bonsoir', 'nsd', 'web_socket', 'http'];

      // Chi xet phan dependencies, khong xet dev_dependencies.
      final devIndex = pubspec.indexOf('dev_dependencies:');
      final deps = devIndex == -1 ? pubspec : pubspec.substring(0, devIndex);

      for (final name in banned) {
        expect(
          deps.contains('  $name:'),
          isFalse,
          reason: 'platform_core khong duoc phu thuoc "$name". '
              'Core phai chay duoc bang `dart test` thuan tuy.',
        );
      }
    });

    test('khong file nao trong core import dart:io hay Flutter', () async {
      final offenders = await _scan(
        (code) =>
            code.contains("import 'dart:io'") ||
            code.contains('package:flutter/'),
      );

      expect(
        offenders,
        isEmpty,
        reason: 'Core phai la pure Dart. Socket va UI nam o tang tren.\n'
            'Vi pham: ${offenders.join(", ")}',
      );
    });

    test('core khong nhac ten mot game cu the nao', () async {
      final offenders = await _scan(
        (code) => code.contains('tic-tac-toe') || code.contains('TicTacToe'),
      );

      expect(
        offenders,
        isEmpty,
        reason: 'Room Manager va Network khong duoc biet game nao ton tai.\n'
            'Vi pham: ${offenders.join(", ")}',
      );
    });
  });
}

/// Quet moi file Dart trong lib/, da bo comment.
///
/// Bo comment vi doc comment duoc phep neu ten game lam vi du minh hoa -
/// dieu bi cam la CODE phu thuoc vao mot game cu the.
Future<List<String>> _scan(bool Function(String code) isOffending) async {
  final offenders = <String>[];

  await for (final entity in Directory('lib').list(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;

    final code = (await entity.readAsString())
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    if (isOffending(code)) offenders.add(entity.path);
  }

  return offenders;
}
