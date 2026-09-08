import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Canh giữ lời hứa lớn nhất của kiến trúc.
///
/// Mục 35 của bản spec: thêm game thứ hai mà phải sửa phòng, mạng hay giao
/// thức thì kiến trúc đã sai. Lời hứa đó không nên phụ thuộc vào việc ai đó
/// nhớ kiểm tra khi review.
void main() {
  group('ranh giới của app', () {
    test('chỉ composition root được biết game nào tồn tại', () async {
      const compositionRoot = 'catalog.dart';
      final offenders = <String>[];

      await for (final entity in Directory('lib').list(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith(compositionRoot)) continue;

        // Bỏ comment: nhắc tên game trong ví dụ minh hoạ thì được, phụ thuộc
        // vào nó trong CODE thì không.
        final code = (await entity.readAsString())
            .split('\n')
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');

        if (code.contains('tic-tac-toe') ||
            code.contains('TicTacToe') ||
            code.contains('game_tictactoe')) {
          offenders.add(entity.path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Chỉ lib/state/$compositionRoot được nhắc tên một game cụ thể.\n'
            'Thêm game mới phải là thêm một CatalogEntry, không phải sửa '
            'phòng, mạng hay giao diện.\n'
            'Vi phạm: ${offenders.join(", ")}',
      );
    });

    test('tầng UI không gọi thẳng vào tầng mạng', () async {
      final offenders = <String>[];

      await for (final entity in Directory('lib/ui').list(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        final code = await entity.readAsString();
        // Màn hình được phép dùng LocalNetworkPermission (để dẫn người dùng
        // vào Cài đặt), nhưng không được đụng tới socket hay mDNS.
        if (code.contains('lan_transport.dart') ||
            code.contains('lan_discovery.dart') ||
            code.contains("import 'dart:io'")) {
          offenders.add(entity.path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Giao diện phải đi qua session/room_browser, không chạm thẳng '
            'vào socket hay mDNS.\nVi phạm: ${offenders.join(", ")}',
      );
    });
  });
}
