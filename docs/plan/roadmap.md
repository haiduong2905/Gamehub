# Lộ trình Game Hub

> **Đây là bản kế hoạch đã được thống nhất ngày 08/09/2026.** Mọi phiên làm việc
> sau phải dựa trên các quyết định trong file này. Muốn đi chệch thì phải nêu rõ
> lý do và cập nhật lại file, không tự ý làm khác.
>
> Phần ràng buộc bắt buộc tuân thủ được tóm tắt ở [CLAUDE.md](../../CLAUDE.md).

## Context

Xuất phát điểm: dự án trống, chỉ có [GAME_PLATFORM_WORKFLOW.md](../../.claude/GAME_PLATFORM_WORKFLOW.md) — bản spec quy trình mô tả nền tảng game đối kháng: Game Hub → Room Manager → Network Layer → Game Session → các game cắm vào.

Nguyên tắc cốt lõi của spec: **Core Platform xây một lần, game cắm vào**. Thêm game #2 mà phải sửa Room/Network/Discovery thì kiến trúc đã sai (§35). Spec cũng bắt buộc **TECH SPIKE PASS** trước khi implement (§15).

Kế hoạch này biến spec thành lộ trình thực thi được, và trả lời câu hỏi trọng tâm: **dùng công nghệ nào**.

Ràng buộc đã chốt:

| Yếu tố | Quyết định |
|---|---|
| Framework | Flutter (Dart) |
| Loại game | **Chỉ turn-based** |
| Số người/room | Theo từng game (`minPlayers`/`maxPlayers`); core hiện hỗ trợ 2–4 |
| iOS | **Chưa có Mac / Apple Developer account** → MVP Android-only |
| Internet | Không có trong MVP |

---

## 1. Phân tích công nghệ

### 1.1. Vì sao Flutter phù hợp bài toán này

| Yêu cầu | Flutter đáp ứng |
|---|---|
| Host phải **mở server socket** trên điện thoại | `dart:io` có `HttpServer`/`WebSocket` **native, không cần plugin bên thứ ba** — khác biệt lớn nhất so với React Native (phụ thuộc `react-native-tcp-socket` ở đúng tầng quan trọng nhất) |
| Game logic **độc lập networking** (§2.1) | Viết pure Dart → cưỡng chế ranh giới bằng chính hệ thống package, kiểm tra được tự động |
| Test không cần thiết bị | `dart test` cho logic, `HttpServer` trên `127.0.0.1` cho I/O |
| Vòng lặp dev nhanh | Chạy được **Flutter Windows desktop** làm peer thứ hai (xem 1.6 — điều này quan trọng hơn vẻ ngoài của nó) |
| Một codebase Android + iOS | Có sẵn |

Không chọn: **Unity** (mạnh cho realtime — thứ ta không dùng tới, đổi lại binary lớn + LAN discovery vẫn phải tự làm); **React Native** (TCP server phụ thuộc thư viện cộng đồng); **KMP+Compose** (sạch nhưng tốn công hơn nhiều, không có lợi thế bù lại).

### 1.2. Quyết định then chốt: Discovery bằng mDNS/Bonjour, KHÔNG dùng UDP broadcast

Đã kiểm chứng từ tài liệu Apple:

- **UDP broadcast/multicast tự chế trên iOS bắt buộc có entitlement `com.apple.developer.networking.multicast`** — phải nộp đơn xin Apple duyệt thủ công, không chắc được cấp.
- **Bonjour với service type cố định khai báo trong `NSBonjourServices` thì KHÔNG cần entitlement** — chỉ cần local network permission.

Apple chỉ đòi entitlement khi dùng service type **không** khai báo trong plist, hoặc **browse meta-query liệt kê mọi service type**. Cả hai tránh được bằng đúng một service type cố định: `_gamehub._tcp`.

→ **Cấm UDP broadcast làm discovery chính**, kể cả khi dễ hơn trên Android. Chọn sai ở đây là chặn đường lên iOS.
→ **Cấm tách service type theo game** (`_gamehub-chess._tcp`): `NSBonjourServices` của iOS không hỗ trợ wildcard, mỗi type phải khai báo cứng. Một type dùng chung, lọc game bằng TXT record.

### 1.3. Rủi ro nền tảng lớn nhất: Android đẩy traffic sang 4G

**Đây là item số 1 của Tech Spike.** Khi Wi-Fi **không có Internet** — chính xác kịch bản "LAN không Internet" của dự án — Android đánh dấu mạng đó *unvalidated* và đặt default network sang cellular. Socket không bind sẽ dùng routing table của cellular, vốn không có route tới subnet Wi-Fi → `WebSocket.connect('ws://192.168.1.x')` trả `EHOSTUNREACH` hoặc treo tới khi timeout.

Khắc phục: `ConnectivityManager.requestNetwork(TRANSPORT_WIFI)` + `bindProcessToNetwork`. **Dart thuần không làm được** → cần một platform channel Kotlin nhỏ (~30 dòng), Android-only (iOS xử lý interface theo cơ chế khác).

Spike phải trả lời: có thật sự bị không, trên Android version nào, và channel có khắc phục được không. Nếu bỏ qua, triệu chứng sẽ là "app tự nhiên không kết nối được" xuất hiện ngẫu nhiên tuỳ mạng — cực khó chẩn đoán về sau.

### 1.4. Quyền truy cập mạng nội bộ

Cả hai nền tảng đều đã siết. Không xử lý = app "im lặng không tìm thấy phòng":

**Android** — `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, cộng:

| Phiên bản | Yêu cầu |
|---|---|
| 13+ (API 33) | `NEARBY_WIFI_DEVICES` — **runtime permission**, kèm `android:usesPermissionFlags="neverForLocation"` để khỏi phải xin location |
| 16 (API 36) | `ACCESS_LOCAL_NETWORK` — opt-in |
| **17 (API 37)+** | **`ACCESS_LOCAL_NETWORK` bắt buộc.** Thiếu: TCP tới LAN **timeout**, UDP trả **EPERM** |

**iOS (khai báo sẵn ngay hôm nay, tốn 0 công)**: `NSLocalNetworkUsageDescription` + `NSBonjourServices = ["_gamehub._tcp"]`. UX: user bấm Từ chối thì iOS **không hỏi lại** → phải deep-link sang Settings.

→ Module `LocalNetworkPermission` riêng, xin quyền **trước cả discovery lẫn connect**, có màn hình hướng dẫn khi bị từ chối.

### 1.5. Transport: WebSocket trên TCP

Host: `HttpServer.bind(InternetAddress.anyIPv4, 0)` (port 0 = xin port trống, đọc lại port thật) → `WebSocketTransformer.upgrade()`. Client: `WebSocket.connect('ws://<ip>:<port>')`.

Vì sao WebSocket thay vì raw TCP + length-prefix:
- **Framing miễn phí** — nơi sinh bug âm thầm nhất trong networking, khỏi tự viết.
- **`pingInterval` có sẵn**: `dart:io` tự ping/pong ở tầng protocol và tự đóng socket khi không nhận pong. Đây chính là thứ phát hiện **half-open connection** khi ai đó rớt Wi-Fi đột ngột (TCP keepalive mặc định 2 tiếng — vô dụng). Đặt `pingInterval = 5s` ở cả hai đầu.
- **Debug bằng bất kỳ ws client nào** trên desktop, không cần thiết bị thứ hai.

Bắt buộc: `WebSocket.connect` **không có tham số timeout** → luôn bọc `.timeout(Duration(seconds: 5))`. Thiếu cái này, khi quyền LAN chưa được cấp bạn sẽ ngồi chờ TCP timeout của hệ thống.

### 1.6. Stack

```
Flutter (stable)              UI + runtime, target Android + Windows desktop
dart:io HttpServer/WebSocket  transport LAN (không cần plugin)
bonsoir                       mDNS/Bonjour: quảng bá + tìm phòng (Android NSD + iOS Bonjour)
platform channel Kotlin nhỏ   bindProcessToNetwork (chỉ nếu spike xác nhận cần)
Riverpod                      state management — CHỈ ở tầng app
wakelock_plus                 giữ màn hình sáng khi đang chơi
Dart pub workspaces           monorepo (không cần melos)
KHÔNG build_runner            sealed class + codec tay + golden test
```

**Build cho Windows desktop ngay từ đầu.** Hai Android emulator không thấy nhau qua mDNS và nằm sau NAT riêng → vô dụng cho việc này. Chạy được trên desktop nghĩa là test host-trên-Windows ↔ client-trên-điện-thoại với vòng lặp vài giây thay vì cắm 2 máy thật mỗi lần.

Dự phòng `bonsoir`: nếu spike phát hiện vấn đề, đổi sang `nsd` — interface `DiscoveryService` không đổi. (Lưu ý: `multicast_dns` **không quảng bá được**, chỉ resolve → không phải phương án B.)

---

## 2. Kiến trúc code

### 2.1. Monorepo

```
d:\Game\
├─ pubspec.yaml                    # pub workspace (chung 1 lockfile, chung SDK constraint)
├─ packages\
│  ├─ platform_core\               # PURE DART — không Flutter, không dart:io
│  │  ├─ protocol\                 # sealed Envelope, message types, codec, golden fixtures
│  │  ├─ room\                     # RoomManager, RoomState, RoomInfo
│  │  ├─ session\                  # GameSession, PlayerSlot, lifecycle, disconnect policy
│  │  ├─ game\                     # GameDefinition, GameRegistry, GameResult
│  │  └─ transport\                # abstract Transport, DiscoveryService + LoopbackTransport
│  ├─ game_tictactoe\              # Flutter package: lib/src/logic/ (pure) + lib/src/ui/
│  └─ game_xiangqi\                # cờ tướng, 2 người
└─ app\
   ├─ lib\transport\lan\           # LanTransport: ws + bonsoir + chọn interface + permission
   └─ lib\...                      # UI, Riverpod, composition root
```

**Chỉ tách package ở ranh giới có giá trị thật:**
- `platform_core` **phải** là package pure Dart riêng — đó là thứ cưỡng chế "core không biết gì về socket", và chạy được bằng `dart test` không cần Flutter binding.
- Mỗi game một package — đó là đơn vị "cắm vào" mà toàn bộ spec hướng tới.
- `LanTransport` **không** tách package: nó vẫn phải là Flutter code (bonsoir là plugin), chỉ có đúng 1 consumer, tách ra chỉ tốn thêm một pubspec. Để ở `app/lib/transport/lan/`. Chiều phụ thuộc vẫn đảm bảo vì `platform_core` không thể import ngược lên app. Tách ra khi nào xuất hiện consumer thứ hai (ví dụ transport Internet).

Chiều phụ thuộc — **là tiêu chí review §24 của spec, và ở đây kiểm tra được tự động**:

```
platform_core   ──►  (không phụ thuộc gì)
game_*          ──►  platform_core
app             ──►  tất cả
```

CI test đọc `packages/platform_core/pubspec.yaml`, fail nếu có `flutter` hoặc package mạng; và grep `packages/game_*/lib/src/logic/` fail nếu có `import 'package:flutter'`. Câu hỏi review "Game có phụ thuộc Network không?" trở thành bài test thay vì cuộc tranh luận.

### 2.2. Game interface

```dart
abstract class GameDefinition<S, A> {
  String get id;
  String get name;
  int get minPlayers;
  int get maxPlayers;

  S createInitialState(List<PlayerId> players, {required int seed});
  ValidationResult validate(S state, PlayerId actor, A action);
  S apply(S state, PlayerId actor, A action);
  bool isFinished(S state);
  GameResult getResult(S state);

  /// Mặc định trả nguyên state. Game có thông tin ẩn (bài) override để
  /// mỗi người chơi chỉ nhận phần mình được thấy.
  S viewFor(PlayerId viewer, S state) => state;

  Map<String, dynamic> encodeState(S state);
  S decodeState(Map<String, dynamic> json);
  Map<String, dynamic> encodeAction(A action);
  A decodeAction(Map<String, dynamic> json);
}
```

`viewFor` tốn 1 dòng hôm nay. Thiếu nó, ngày thêm game có bài phải sửa cả protocol + session + mọi game đã viết.

`seed` do host sinh và phát → game cần ngẫu nhiên vẫn tất định.

**Generic đụng biên**: `GameSession` không thể cầm `GameDefinition<S,A>` generic mà không lây `dynamic` khắp nơi. Giải pháp: definition generic **bên trong**, nhưng expose ra session qua một facade **không generic** nhận/trả JSON đã encode. Encode/decode xảy ra đúng một chỗ, ở biên.

### 2.3. Registry hai nửa

`GameDefinition` là pure Dart nên không chứa `Widget`. Do đó:
- **`GameRegistry`** (core): `gameId → GameDefinition`.
- **Renderer registry** (app): chỉ là `Map<String, Widget Function(GameViewModel)>` — không cần class hay interface.

Đăng ký **chỉ ở một composition root** (`main.dart`), mỗi game 2 dòng. Không dùng static initializer tự-đăng-ký: Dart không đảm bảo chạy và tree-shaking sẽ ăn mất.

Room Manager chỉ biết `gameId` (§9), không bao giờ có `if game == 'tic-tac-toe'`.

### 2.4. Protocol

Envelope chung, dùng **`sealed class` + subclass của Dart 3**: compiler sẽ bắt lỗi khi thêm message type mà quên xử lý ở đâu đó — đúng thứ freezed cung cấp, nhưng miễn phí.

```json
{ "v": 1, "type": "GAME_ACTION", "roomId": "r-8f2a", "seq": 12, "payload": { } }
```

| Client → Host | Host → Client |
|---|---|
| `HELLO` (protocolVersion, nickname, playerId) | `HELLO_ACK` / `ERROR` |
| `JOIN_REQUEST` | `JOIN_ACCEPTED` (kèm roomSecret) / `JOIN_REJECTED` |
| `PLAYER_READY` | `PLAYER_JOINED` / `PLAYER_LEFT` |
| `GAME_ACTION` (ý định) | `GAME_START`, `GAME_STATE`, `GAME_RESULT` |
| `LEAVE_ROOM` | `ROOM_CLOSED` |

**Client không bao giờ gửi state hay kết quả.** Client gửi ý định → host `validate` → `apply` → broadcast `GAME_STATE` (per-player view qua `viewFor`).

Turn-based → **broadcast full state mỗi lượt**, không delta, không optimistic prediction, không rollback. LAN ~5–20ms nên không cảm nhận được độ trễ, đổi lại **loại bỏ hoàn toàn khả năng desync**.

Hai chi tiết dễ bỏ sót:
- `stateVersion` **không** cần để loại state cũ (TCP trên một socket đã ordered). Nó cần cho **resync sau rejoin** và cho **idempotency**.
- `GAME_ACTION` phải mang `actionId` + `expectedStateVersion` → double-tap hoặc gửi lại sau reconnect không apply hai lần. Đây là chỗ thiếu sót thật, không phải chi tiết thừa.
- UI vẫn hiển thị "pending" (ô mờ + spinner) khi chờ host xác nhận — đó là phản hồi tức thì, không phải dự đoán.

`fromJson` gặp `type` lạ phải trả `UnknownMessage` chứ **không throw** (forward compatibility). Codec khoá bằng **golden test**: fixture JSON cố định + round-trip cho mọi message type.

### 2.5. Discovery và tham gia phòng

Host quảng bá `_gamehub._tcp`. **TXT record chỉ chứa dữ liệu bất biến**:

```
rid=r-8f2a  gid=tic-tac-toe  pv=1  pw=0  dn=Ph%C3%B2ng%20c%E1%BB%A7a%20V%C5%A9
```

⚠️ **Không nhét `players/maxPlayers` vào TXT.** `NsdManager` của Android không có API update TXT trước API 34 — muốn đổi phải unregister + register lại, phòng sẽ nhấp nháy biến mất/hiện lại trên máy client, mà số liệu vẫn sai vài giây vì mDNS cache theo TTL. Số người chơi để client biết **sau khi JOIN**; phòng đầy thì host trả `ROOM_FULL`.

Ràng buộc kỹ thuật của mDNS:
- **Instance name ≤ 63 byte, dùng ASCII** kiểu `gh-<roomId8>`. Tên phòng tiếng Việt có dấu bị Android/iOS xử lý khác nhau (tự đổi tên khi trùng) → tên hiển thị nhét vào TXT dạng percent-encode, và **phải cap độ dài** (ký tự có dấu tốn 3 byte UTF-8).
- Mỗi TXT string ≤ 255 byte, giữ tổng record < ~400 byte để nằm gọn một packet.
- **Service "ma"**: host crash thì entry mDNS còn sống theo TTL → Room Browser vẫn liệt kê phòng đã chết. Phải xử lý join-fail êm ái và lắng nghe cả event `serviceLost`.

**Chọn IP để quảng bá — không dùng bừa kết quả trả về:**
`bind(anyIPv4)` thì ổn, nhưng mDNS sẽ quảng bá *mọi* địa chỉ, kể cả IPv6 link-local (`fe80::...%wlan0`) và interface cellular (`rmnet`) nếu 4G đang bật. Client vớ phải cái sai là join fail. Phải lọc `NetworkInterface.list()`: loại loopback / VPN (`tun`) / cellular, ưu tiên private IPv4 (`192.168.`, `10.`, `172.16-31.`), thử **song song** các candidate và lấy cái thắng. **Chỉ IPv4 trong MVP** — `dart:io` xử lý scope-id của IPv6 link-local rất tệ.

**`.local` hostname không resolve được từ Dart**: `InternetAddress.lookup` của `dart:io` **không** đi qua resolver mDNS trên Android. Nếu bonsoir trả `host` dạng `Ten-May.local` thay vì IP số thì `WebSocket.connect` sẽ chết. Phải lấy IP số từ kết quả resolve — **đây là blocker cần xác minh trong spike**.

**Manual join `IP:port` là tính năng hạng nhất, không phải fallback.**
Host hiển thị `192.168.1.57:47821` to rõ trên màn Waiting Room; client nhập tay để vào thẳng, bỏ qua discovery. Lý do:
- Đó là đường **duy nhất** test được khi mDNS trục trặc, và đường chạy được trên Flutter Windows desktop nếu bonsoir không hỗ trợ Windows.
- Nó cứu được mạng doanh nghiệp lọc mDNS nhưng vẫn cho unicast.

Nói rõ giới hạn: **AP isolation chặn cả unicast client-to-client**, nên manual join *không* cứu được trường hợp đó — chỉ có thể báo lỗi rõ ràng cho user. (Đây là điểm bản nháp đầu của tôi hiểu sai. Cũng vì vậy không mã hoá "room code" từ octet cuối IP: giả định `/24` sai với subnet `/16` của doanh nghiệp, với VPN, hoặc khi hai máy ở VLAN khác nhau.)

### 2.6. Disconnect và lifecycle — nơi tập trung bug hại nhất

- **Phát hiện mất kết nối bằng `WebSocket.pingInterval = 5s`**, không tự viết heartbeat app-level 3s. Timer 3 giây đánh thức CPU liên tục sẽ bị Doze/App Standby của Android xử lý, và tốn pin vô ích.
- **`AppLifecycleState.paused` → KHÔNG gửi DISCONNECT.** `paused`/`inactive` bắn ra khi kéo notification shade, mở Control Center, hiện dialog xin quyền, split-screen, có cuộc gọi đến. Gửi DISCONNECT ở đây nghĩa là **người chơi liếc thông báo một cái là mất phòng**. Chỉ gửi `LEAVE_ROOM` khi user chủ động bấm rời. Cơ chế thật là **timeout phía host** (`detached` trên Android không đáng tin vì process bị kill thẳng).
- **Host mất** → phòng chết, client về Room Browser kèm thông báo rõ ràng.
- **Client mất** → host giữ chỗ 30s, **hiển thị đếm ngược trên UI của người còn lại**; rejoin bằng `playerId` (UUID trong SharedPreferences) + `roomSecret` host cấp lúc join. Đây là chống nhầm lẫn giữa 4 người quen trong cùng phòng, **không phải chống tấn công** — không làm crypto.
- **Policy hết 30s (phải quyết ngay, không để mở)**: đóng phòng với kết quả `ABANDONED`. Không xử thua, không chơi tiếp thiếu người trong MVP.
- **Màn hình tắt = ván cờ chết**: `wakelock_plus` giữ màn hình sáng trong lúc `PLAYING` ở cả host lẫn client.
- **Chừa chỗ cho turn timer** trong `GameSession` (chưa cần cho MVP, nhưng thiếu nó thì một người treo máy làm ván cờ đứng vĩnh viễn).
- **Hot restart làm rò `HttpServer`**: server bound trong provider không tự đóng → tích tụ server zombie, mDNS quảng bá trùng. Với Riverpod phải `ref.onDispose` đóng server, và cẩn thận `autoDispose` giết server khi navigate khỏi Waiting Room.

### 2.7. LoopbackTransport — quyết định quan trọng nhất về tốc độ phát triển

Implement đúng interface `Transport` nhưng chuyển message trong bộ nhớ. Nhờ nó, **toàn bộ** room + session + game + UI build và test được **không cần networking gì cả**.

Hai điều kiện để nó không thành cái bẫy:
1. **Phải serialize thật** (encode ra String rồi decode lại). Truyền thẳng object reference sẽ sinh aliasing bug ẩn và codec không hề được test.
2. **Phải bất đồng bộ** (`Timer(Duration.zero)`). Delivery đồng bộ sẽ khiến code vô tình phụ thuộc vào thứ tự đó, rồi vỡ khi lên mạng thật.

Bổ sung tầng thứ hai: integration test dựng `HttpServer` thật trên `127.0.0.1` trong `dart test` — bắt được lỗi framing/handshake mà loopback giấu.

---

## 3. Lộ trình

### Phase 0 — Brief tối thiểu (0.5 ngày)
Chỉ 2 trang: `docs/product/product-brief.md` + phác thảo envelope protocol.

⚠️ **Cố ý hoãn phần lớn docs của §28.** Spec đòi ~15 file markdown trước khi code, nhưng docs về protocol/transport/networking sẽ sai trước khi spike xong — viết rồi vứt là lãng phí. Docs kiến trúc + ADR viết **sau spike**, ngược từ hiện thực đã chạy. ADR ghi lại *quyết định đã được kiểm chứng*; không thể ghi một quyết định chưa biết đúng hay sai.

### Phase 1 — TECH SPIKE (gate cứng, 1–2 ngày)
Code một file, vứt đi sau, không tái sử dụng. Cần **2 máy Android thật cùng Wi-Fi**.

Phải trả lời đủ 6 câu — không chỉ PING/PONG:

| # | Kiểm chứng | Vì sao |
|---|---|---|
| a | **Wi-Fi không có Internet có bị đẩy sang cellular không**, `bindProcessToNetwork` có cứu được không | Rủi ro nền tảng số 1 (1.3) |
| b | Advertise + browse + resolve **ra IP số**, không phải `.local` | Blocker tiềm tàng (2.5) |
| c | `WebSocket.connect` + `pingInterval` + rớt Wi-Fi đột ngột | Xác minh cơ chế phát hiện disconnect |
| d | Runtime permission trên đúng Android version của máy test | `NEARBY_WIFI_DEVICES` / `ACCESS_LOCAL_NETWORK` |
| e | Background / foreground / khoá màn hình | Xác định thời gian sống thật của socket |
| f | Hành vi khi update TXT record | Xác nhận quyết định "TXT bất biến" |

**Tiêu chí PASS** (ghi số đo vào `docs/tech-spike/decision.md`):

| Chỉ số | Ngưỡng |
|---|---|
| Thời gian tìm thấy phòng | ≤ 3s |
| Thời gian kết nối | ≤ 1s |
| RTT p95 | ≤ 50ms |
| Phát hiện mất kết nối | ≤ 10s |
| Chạy liên tục 30 phút | không rò socket/bộ nhớ |

Không PASS thì **không sang Phase 2** (§15).

### Phase 2 — `platform_core` + LoopbackTransport (2–3 ngày)
Sealed envelope + codec + golden test, RoomManager, GameSession, GameDefinition, GameRegistry, interface Transport. Chạy bằng `dart test`, không cần Flutter, không cần thiết bị.

### Phase 3 — `game_tictactoe` (0.5 ngày)
Thuần logic + widget bàn cờ. Test nhanh, không chạm networking.

### Phase 4 — UI đầy đủ chạy trên Loopback (3–4 ngày)
Splash · Home · Game List · Create Room · Room Browser · Waiting Room · Game · Result · Settings.
Dựng **harness 2 pane cạnh nhau trên desktop**, mỗi pane là một người chơi → hot reload vài giây cho toàn bộ luồng.
Room là **generic + game metadata** (§8) — cấm tạo `TicTacToeRoom`.

⚠️ **Cố ý đảo thứ tự so với §17** (spec đặt Network Layer trước UI). Điểm mấu chốt là: **abstraction `Transport` được định nghĩa từ Phase 2**, chỉ có *implementation* LAN là làm sau. Game và UI vẫn không hề biết đến socket — đúng tinh thần §2.1. Đổi lại, mọi bug ở Phase 5 chắc chắn là bug I/O, không lẫn với bug game logic hay UI. Rủi ro "phát hiện sự thật nền tảng quá muộn" đã được Phase 1 khử.

### Phase 5 — `LanTransport` (2–3 ngày)
WebSocket + bonsoir + lọc network interface + manual join `IP:port` + `LocalNetworkPermission` + platform channel bind network (nếu spike xác nhận cần).

**Multi-device test bắt đầu từ đây và chạy liên tục đến hết** — không phải một phase ở cuối.

### Phase 6 — Disconnect / rejoin / lifecycle (2 ngày)
Tách riêng vì đây là nơi bug hại nhất và khó tái hiện nhất. Chạy đủ checklist §23.

### Phase 7 — Game #2 = **Cờ tướng** (2 người)
Số người trong phòng lấy từ `minPlayers`/`maxPlayers` của game. Cờ tướng có
package và mục trong `GameCatalog`; cần hoàn thiện luật, UI và kiểm thử trước
khi nghiệm thu. Game mới không được yêu cầu sửa `platform_core` hoặc tầng mạng
chỉ để đăng ký game (§35).

Nhánh 3–4 người vẫn cần kiểm chứng riêng trên thiết bị thật khi có game hỗ trợ
số người đó; không gắn mục tiêu này với cờ tướng.

### Phase 8 — Docs kiến trúc + ADR (0.5 ngày)
Viết ngược từ code đã chạy: `architecture/*`, và ADR-001 transport · ADR-002 host-authoritative · ADR-003 discovery (kèm lý do loại UDP broadcast vì entitlement iOS) · ADR-004 game interface · ADR-005 hoãn iOS.

---

## 4. Ràng buộc iOS giữ sẵn (dù chưa build được)

- Chỉ **một** service type cố định `_gamehub._tcp`.
- **Không** UDP broadcast/multicast tự chế ở bất kỳ đâu.
- Không giả định app chạy được ở background.
- `LocalNetworkPermission` nằm sau interface → thêm nhánh iOS không lan ra chỗ khác.
- Viết sẵn `NSBonjourServices` + `NSLocalNetworkUsageDescription` vào `Info.plist` **ngay hôm nay** — tốn 0 công, quên thì sau này debug mù.
- Luật: **không tự viết platform channel trừ khi bắt buộc**; nếu viết (bind network) thì phải Android-only và có nhánh no-op cho iOS.
- ADR-005 ghi rõ: local network permission **không test được trên iOS Simulator**, bắt buộc máy thật.

---

## 5. Rủi ro chính

| Rủi ro | Giảm thiểu |
|---|---|
| **Android đẩy traffic sang cellular khi Wi-Fi không Internet** | Spike item #1; platform channel `bindProcessToNetwork` |
| `.local` hostname không resolve được từ Dart | Spike item #2; bắt buộc lấy IP số |
| mDNS bị chặn trên router/Wi-Fi công ty | Manual join `IP:port` là tính năng hạng nhất |
| AP isolation (chặn cả unicast) | Không cứu được — phải báo lỗi rõ ràng, không treo im lặng |
| Quyền LAN bị từ chối → app "im lặng không chạy" | `LocalNetworkPermission` + màn hướng dẫn, test trong spike |
| `bonsoir` lỗi trên thiết bị thật hoặc thiếu Windows | Interface `DiscoveryService` cho phép đổi `nsd`; desktop vẫn join tay được |
| Nhánh 3–4 người chưa chạy thật | Kiểm chứng khi thêm game hỗ trợ 3–4 người |

---

## 6. Kiểm chứng

1. `dart test` trên `platform_core` — vòng đời phòng + luật game qua LoopbackTransport, không cần Flutter.
2. Golden test protocol: fixture JSON cố định + round-trip mọi message type.
3. Integration test `HttpServer` thật trên `127.0.0.1` trong một process.
4. Harness 2 pane trên desktop — chơi hết một ván qua Loopback.
5. Spike trên 2 máy Android thật, số đo ghi vào `docs/tech-spike/decision.md` (PASS/FAIL).
6. Multi-device test theo §23 (Room · Game · Network), chạy liên tục từ Phase 5.
7. **Nghiệm thu kiến trúc**: hoàn thiện cờ tướng mà không phải sửa `platform_core` và `app/lib/transport/` chỉ vì game mới.
8. CI: test chặn `platform_core` phụ thuộc Flutter/mạng, và chặn `game_*/lib/src/logic/` import Flutter.

---

## Trạng thái thực hiện (08/09/2026)

| Phase | Trạng thái |
|---|---|
| 0 — Brief tối thiểu | ✅ docs/product/product-brief.md + room-lifecycle.md |
| 1 — TECH SPIKE | 🟡 Đã thử kết nối tốt trên 2 máy Android 13; còn thiếu điều kiện test và số đo để kết luận PASS. Xem docs/tech-spike/decision.md |
| 2 — platform_core + Loopback | ✅ 50 test pass, analyze sạch |
| 3 — game_tictactoe | ✅ 24 test pass (17 luật + 7 widget) |
| 4 — UI trên Loopback | ✅ 5 test pass, cả app chạy trên LoopbackTransport |
| 5 — LanTransport | ✅ Code xong (WebSocket + bonsoir + lọc IP + quyền). Đã thử kết nối tốt trên 2 máy Android 13; chưa ghi đủ phạm vi kiểm chứng |
| 6 — Disconnect/rejoin | ✅ Logic xong + test; chưa kiểm chứng trên mạng thật |
| 7 — Game #2 Cờ tướng | 🟡 Đã có package và đăng ký trong catalog; cần rà luật, UI và kiểm thử |
| 8 — Docs kiến trúc + ADR | ✅ overview, game-protocol, ADR-001..005 |

Phase 1 được bắt đầu **sau** code thay vì trước vì ban đầu chưa có thiết bị
thật. Kết quả thử trên 2 máy Android 13 là tín hiệu tốt, nhưng Tech Spike chỉ
PASS khi các điều kiện bắt buộc và số đo được ghi nhận theo checklist.
