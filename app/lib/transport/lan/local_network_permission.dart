import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Ket qua xin quyen truy cap mang noi bo.
enum LocalNetworkAccess {
  /// Duoc phep, hoac he dieu hanh khong doi quyen nay.
  granted,

  /// Nguoi dung tu choi nhung van hoi lai duoc.
  denied,

  /// Bi tu choi vinh vien - phai vao Settings mo tay.
  permanentlyDenied,
}

/// Xin quyen truy cap mang noi bo.
///
/// Day la nguyen nhan so mot khien mot app LAN "khong chay" tren may nguoi
/// dung, va trieu chung lai rat kho doan: khong tim thay phong nao, hoac
/// ket noi treo den khi timeout - chu khong he co thong bao loi nao.
///
/// Trang thai hien tai cua hai nen tang:
///
/// Android
/// * 12 (API 32) tro XUONG: `NsdManager` va socket toi LAN KHONG doi runtime
///   permission nao. Ba quyen trong manifest (`INTERNET`,
///   `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`) la install-time, he thong
///   cap san luc cai dat. Xem [_kNearbyWifiDevicesSdk] ve cai bay o day.
/// * 13 (API 33): `NEARBY_WIFI_DEVICES` cho `NsdManager`.
/// * 16 (API 36): `ACCESS_LOCAL_NETWORK`, dang opt-in.
/// * 17 (API 37): `ACCESS_LOCAL_NETWORK` BAT BUOC. Thieu quyen thi TCP toi
///   dia chi LAN bi timeout va UDP tra ve EPERM. `permission_handler` chua
///   biet quyen nay; khi Android 17 toi phai them mot nhanh nua o day.
///
/// iOS (chua build duoc nhung da chuan bi san)
/// * `NSLocalNetworkUsageDescription` + `NSBonjourServices` trong Info.plist.
/// * Nguoi dung bam Tu choi thi iOS KHONG hoi lai lan nao nua - bat buoc phai
///   dan ho vao Settings.
class LocalNetworkPermission {
  const LocalNetworkPermission();

  /// Phien ban Android dau tien co `NEARBY_WIFI_DEVICES`.
  ///
  /// Duoi moc nay quyen do KHONG TON TAI, va `permission_handler` tra ve
  /// `denied` chu khong phai `granted`: no tim trong manifest cac ten quyen
  /// ung voi nhom `nearbyWifiDevices`, tren API < 33 tim ra danh sach rong,
  /// va danh sach rong bi coi la "manifest thieu khai bao" -> denied.
  ///
  /// Neu tin vao ket qua do thi may Android 12 tu chan chinh minh: khong tim
  /// duoc phong, khong tao duoc phong, khong nhap tay dia chi duoc - trong
  /// khi thuc te no khong can xin gi ca. Bam "Mo Cai dat" cung vo ich, vi
  /// trong Cai dat khong he co muc quyen nao de bat.
  static const _kNearbyWifiDevicesSdk = 33;

  /// Doc mot lan roi nho: so nay khong doi trong mot phien chay, ma moi lan
  /// hoi la mot luot qua platform channel.
  static Future<int>? _androidSdk;

  static Future<int> _androidSdkInt() =>
      _androidSdk ??= DeviceInfoPlugin()
          .androidInfo
          .then((info) => info.version.sdkInt);

  /// Chi de test: ep so phien ban Android, hoac `null` de doc lai tu may.
  @visibleForTesting
  static void debugSetAndroidSdkInt(int? sdkInt) =>
      _androidSdk = sdkInt == null ? null : Future<int>.value(sdkInt);

  /// Quy tac quyet dinh, tach rieng de test duoc ma khong can thiet bi.
  @visibleForTesting
  static bool needsRuntimePermission({required int androidSdkInt}) =>
      androidSdkInt >= _kNearbyWifiDevicesSdk;

  /// He dieu hanh nay co doi quyen gi khong.
  Future<bool> _needsRuntimePermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      // iOS khong co API xin truoc: he thong tu hien hop thoai o lan dau app
      // cham vao mang noi bo. Cac nen tang desktop khong doi quyen nay.
      return false;
    }
    return needsRuntimePermission(androidSdkInt: await _androidSdkInt());
  }

  /// Xin quyen truoc khi lam bat cu viec gi lien quan den mang.
  ///
  /// Phai goi TRUOC ca discovery lan connect, khong phai chi truoc discovery.
  Future<LocalNetworkAccess> request() async {
    if (!await _needsRuntimePermission()) return LocalNetworkAccess.granted;

    return _translate(await Permission.nearbyWifiDevices.request());
  }

  Future<LocalNetworkAccess> check() async {
    if (!await _needsRuntimePermission()) return LocalNetworkAccess.granted;

    return _translate(await Permission.nearbyWifiDevices.status);
  }

  static LocalNetworkAccess _translate(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return LocalNetworkAccess.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return LocalNetworkAccess.permanentlyDenied;
    }
    return LocalNetworkAccess.denied;
  }

  /// Mo man hinh cai dat cua app. Dung khi quyen da bi tu choi vinh vien.
  Future<bool> openSettings() => openAppSettings();
}
