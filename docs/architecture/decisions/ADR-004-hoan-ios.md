# ADR-004 — Hoãn iOS nhưng giữ nguyên mọi ràng buộc của nó

## Context

Bản spec (mục 1) yêu cầu hỗ trợ cả Android và iOS, và mục 15 bắt Tech Spike
phải test đủ ma trận Android↔Android, iOS↔iOS, Android↔iOS.

Hiện chưa có máy Mac và chưa có tài khoản Apple Developer, nên không build
được iOS.

## Decision

MVP thu hẹp còn **Android**, cộng thêm bản Windows desktop để chạy thử nhanh
khi phát triển.

Nhưng **mọi ràng buộc của iOS được áp vào thiết kế ngay từ đầu**, để lúc có
Mac chỉ còn việc cấu hình chứ không phải viết lại tầng mạng:

| Ràng buộc | Đã áp ở đâu |
|---|---|
| Không UDP broadcast/multicast tự chế ở bất kỳ đâu | [ADR-002](ADR-002-discovery.md) |
| Đúng một Bonjour service type cố định `_gamehub._tcp` | `lan_discovery.dart` |
| `NSBonjourServices` + `NSLocalNetworkUsageDescription` | `ios/Runner/Info.plist` — đã viết sẵn |
| Không giả định app chạy được ở nền | Wakelock khi chơi; không tự rời phòng khi `paused` |
| Quyền mạng nội bộ nằm sau interface | `LocalNetworkPermission` |
| Chỉ dùng package có hỗ trợ iOS | `bonsoir`, `permission_handler`, `wakelock_plus` đều có |

## Alternatives

**Chờ có Mac rồi mới làm.** Chặn toàn bộ tiến độ vì một thứ chưa có.

**Làm Android trước, iOS tính sau.** Dễ nhất, nhưng gần như chắc chắn sẽ chọn
UDP broadcast (đơn giản hơn trên Android) rồi phát hiện iOS không đi được —
lúc đó phải viết lại tầng mạng.

## Reason

Chi phí áp ràng buộc iOS **ngay bây giờ** gần bằng không: viết mấy khoá vào
`Info.plist`, và chọn mDNS thay vì UDP broadcast. Chi phí sửa **sau** là viết
lại toàn bộ discovery, có thể kèm chờ Apple duyệt entitlement.

## Consequences

- Ma trận Tech Spike thu hẹp còn Android↔Android. Ghi rõ trong `decision.md`
  rằng iOS **chưa test**, chứ không phải "đã hỗ trợ".
- Rủi ro iOS còn lại chủ yếu là chuyện cấu hình, không phải kiến trúc.
- Quyền mạng nội bộ trên iOS **không test được trên Simulator** — bắt buộc máy
  thật. Và nếu người dùng bấm Từ chối thì iOS không hỏi lại lần nào nữa; app
  phải phát hiện và dẫn họ vào Settings.
- Nếu Tech Spike xác nhận Android cần platform channel `bindProcessToNetwork`
  thì channel đó là **Android-only**, phải có nhánh không-làm-gì cho iOS
  (iOS chọn interface theo cơ chế khác).
