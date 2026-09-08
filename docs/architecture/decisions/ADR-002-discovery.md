# ADR-002 — Discovery bằng mDNS/Bonjour, không dùng UDP broadcast

## Context

Người chơi cần thấy phòng của nhau mà không phải nhập địa chỉ. Cách phổ biến
nhất là gửi UDP broadcast lên subnet — dễ viết, chạy tốt trên Android.

## Decision

Dùng **mDNS/Bonjour** với **đúng một** service type cố định: `_gamehub._tcp`,
qua package `bonsoir` (bọc Android NSD và iOS Bonjour).

**Cấm** UDP broadcast/multicast tự chế ở mọi nơi trong dự án.
**Cấm** tách service type theo game (`_gamehub-chess._tcp`).

Kèm theo: **nhập địa chỉ `IP:cổng` bằng tay là tính năng hạng nhất**, không
phải phương án chữa cháy.

## Alternatives

**UDP broadcast.** Dễ hơn, không cần thư viện, kiểm soát hoàn toàn.

**Google Nearby Connections / Apple MultipeerConnectivity.** Mỗi cái chỉ chạy
một nền tảng → không dùng được cho mục tiêu Android ↔ iOS.

## Reason

Tài liệu Apple, đã kiểm chứng:

- **UDP broadcast/multicast tự chế trên iOS bắt buộc có entitlement
  `com.apple.developer.networking.multicast`** — phải nộp đơn xin Apple duyệt
  thủ công, cấp theo từng App ID, và không chắc được cấp.
- **Bonjour với service type khai báo sẵn trong `NSBonjourServices` thì
  KHÔNG cần entitlement đó** — chỉ cần quyền mạng nội bộ thông thường.

Apple chỉ đòi entitlement khi (a) dùng service type **không** khai báo trong
plist, hoặc (b) browse meta-query liệt kê mọi service type
(`_services._dns-sd._udp`). Cả hai đều tránh được bằng một service type cố định.

Chọn UDP broadcast bây giờ sẽ chạy tốt trên Android nhưng **chặn hẳn đường lên
iOS** — mà iOS là mục tiêu đã ghi trong spec, chỉ hoãn chứ không bỏ.

Service type dùng chung cho mọi game vì `NSBonjourServices` **không hỗ trợ
wildcard**: mỗi type phải khai báo cứng trong Info.plist. Lọc theo game làm
bằng TXT record.

## Consequences

- Phụ thuộc `bonsoir`. Rủi ro này được hấp thụ bởi interface `DiscoveryService`
  — đổi sang `nsd` không ảnh hưởng phần còn lại. (`multicast_dns` **không**
  quảng bá được, chỉ resolve, nên không phải phương án B.)
- **TXT record chỉ được chứa dữ liệu bất biến.** `NsdManager` trước API 34
  không sửa được TXT; muốn đổi phải huỷ đăng ký rồi đăng ký lại, khiến phòng
  nhấp nháy trên máy người khác mà số liệu vẫn sai vài giây vì mDNS cache theo
  TTL. Vì vậy số người chơi **không** nằm trong TXT — client biết sau khi vào
  phòng, phòng đầy thì host trả `ROOM_FULL`.
- Instance name mDNS giới hạn 63 byte và phải ASCII. Dùng `gh-<roomId>`; tên
  phòng tiếng Việt đẩy vào TXT dạng percent-encode và cắt ở 120 ký tự.
- Host tắt máy đột ngột thì entry mDNS còn sống theo TTL → danh sách có thể
  hiện "phòng ma". Phải nghe cả sự kiện `serviceLost` và xử lý join-fail êm ái.
- **AP isolation chặn cả unicast**, nên nhập địa chỉ tay *không* cứu được
  trường hợp đó — chỉ báo lỗi rõ ràng. Nhập tay cứu được mạng lọc mDNS nhưng
  vẫn cho hai máy nói chuyện trực tiếp.
