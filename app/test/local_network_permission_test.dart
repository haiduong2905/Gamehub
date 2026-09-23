import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_hub/transport/lan/local_network_permission.dart';

/// Kênh của `permission_handler`.
const _permissionChannel =
    MethodChannel('flutter.baseflow.com/permissions/methods');

/// Mã trạng thái mà phía Android trả về. Thứ tự lấy từ
/// `PermissionStatusValue.statusByValue` của `permission_handler`.
const _denied = 0;
const _granted = 1;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  var stubbedStatus = _denied;

  setUp(() {
    calls.clear();
    stubbedStatus = _denied;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionChannel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'checkPermissionStatus':
          return stubbedStatus;
        case 'requestPermissions':
          final requested = (call.arguments as List).cast<int>();
          return <int, int>{for (final id in requested) id: stubbedStatus};
      }
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    LocalNetworkPermission.debugSetAndroidSdkInt(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionChannel, null);
  });

  group('LocalNetworkPermission', () {
    test('chỉ Android 13 trở lên mới có quyền runtime để mà xin', () {
      // NEARBY_WIFI_DEVICES xuất hiện từ API 33. Dưới mốc đó nó không tồn
      // tại, và `permission_handler` trả về "denied" chứ không phải
      // "granted" — tin vào con số đó là máy Android 12 tự chặn chính mình.
      for (final sdk in [21, 29, 31, 32]) {
        expect(
          LocalNetworkPermission.needsRuntimePermission(androidSdkInt: sdk),
          isFalse,
          reason: 'API $sdk không có NEARBY_WIFI_DEVICES để xin',
        );
      }
      for (final sdk in [33, 34, 35, 36]) {
        expect(
          LocalNetworkPermission.needsRuntimePermission(androidSdkInt: sdk),
          isTrue,
          reason: 'API $sdk bắt buộc xin NEARBY_WIFI_DEVICES cho NsdManager',
        );
      }
    });

    test('Android 12 được phép ngay, và không hỏi permission_handler', () async {
      LocalNetworkPermission.debugSetAndroidSdkInt(32);

      expect(
        await const LocalNetworkPermission().request(),
        LocalNetworkAccess.granted,
      );
      expect(
        await const LocalNetworkPermission().check(),
        LocalNetworkAccess.granted,
      );
      expect(
        calls,
        isEmpty,
        reason: 'hỏi một quyền chưa tồn tại thì luôn bị trả lời là từ chối',
      );
    });

    test('Android 13 vẫn xin quyền như cũ', () async {
      LocalNetworkPermission.debugSetAndroidSdkInt(33);

      expect(
        await const LocalNetworkPermission().request(),
        LocalNetworkAccess.denied,
      );
      expect(calls.single.method, 'requestPermissions');

      calls.clear();
      stubbedStatus = _granted;
      expect(
        await const LocalNetworkPermission().check(),
        LocalNetworkAccess.granted,
      );
      expect(calls.single.method, 'checkPermissionStatus');
    });

    test('nền tảng không phải Android thì không đụng tới quyền', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      expect(
        await const LocalNetworkPermission().request(),
        LocalNetworkAccess.granted,
      );
      expect(calls, isEmpty);
    });
  });
}
