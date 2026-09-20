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
/// * 13 (API 33): `NEARBY_WIFI_DEVICES` cho `NsdManager`.
/// * 16 (API 36): `ACCESS_LOCAL_NETWORK`, dang opt-in.
/// * 17 (API 37): `ACCESS_LOCAL_NETWORK` BAT BUOC. Thieu quyen thi TCP toi
///   dia chi LAN bi timeout va UDP tra ve EPERM.
///
/// iOS (chua build duoc nhung da chuan bi san)
/// * `NSLocalNetworkUsageDescription` + `NSBonjourServices` trong Info.plist.
/// * Nguoi dung bam Tu choi thi iOS KHONG hoi lai lan nao nua - bat buoc phai
///   dan ho vao Settings.
class LocalNetworkPermission {
  const LocalNetworkPermission();

  /// Xin quyen truoc khi lam bat cu viec gi lien quan den mang.
  ///
  /// Phai goi TRUOC ca discovery lan connect, khong phai chi truoc discovery.
  Future<LocalNetworkAccess> request() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      // iOS khong co API xin truoc: he thong tu hien hop thoai o lan dau app
      // cham vao mang noi bo. Cac nen tang desktop khong doi quyen nay.
      return LocalNetworkAccess.granted;
    }

    final status = await Permission.nearbyWifiDevices.request();

    if (status.isGranted || status.isLimited) return LocalNetworkAccess.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return LocalNetworkAccess.permanentlyDenied;
    }
    return LocalNetworkAccess.denied;
  }

  Future<LocalNetworkAccess> check() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return LocalNetworkAccess.granted;
    }

    final status = await Permission.nearbyWifiDevices.status;
    if (status.isGranted || status.isLimited) return LocalNetworkAccess.granted;
    if (status.isPermanentlyDenied) return LocalNetworkAccess.permanentlyDenied;
    return LocalNetworkAccess.denied;
  }

  /// Mo man hinh cai dat cua app. Dung khi quyen da bi tu choi vinh vien.
  Future<bool> openSettings() => openAppSettings();
}
