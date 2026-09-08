# Game Hub — ràng buộc dự án

Nền tảng chơi game đối kháng qua Wi-Fi/LAN, không cần Internet. Flutter.
Game đầu tiên: cờ caro 3x3.

**Đây là dự án dài hạn. Các quyết định dưới đây đã được thống nhất — không tự ý
làm khác.** Muốn đổi thì nêu lý do trước, rồi cập nhật cả file này lẫn ADR liên
quan.

| Tài liệu | Nội dung |
|---|---|
| [.claude/GAME_PLATFORM_WORKFLOW.md](.claude/GAME_PLATFORM_WORKFLOW.md) | Spec gốc của chủ dự án — nguồn ràng buộc cao nhất |
| [docs/plan/roadmap.md](docs/plan/roadmap.md) | Kế hoạch đã thống nhất + trạng thái từng phase |
| [docs/architecture/](docs/architecture/) | Kiến trúc, giao thức, và 5 ADR |
| [docs/tech-spike/checklist.md](docs/tech-spike/checklist.md) | Việc phải đo trên 2 máy Android thật |
| [README.md](README.md) | Cách chạy, cách build, các chỗ đã phải vá |

---

## Bối cảnh đã chốt với chủ dự án

| Yếu tố | Quyết định |
|---|---|
| Framework | Flutter — chủ dự án quen nhất |
| Loại game | **Chỉ turn-based** (caro, cờ vua, connect-four, dots and boxes) |
| Số người/phòng | 2–4 |
| iOS | **Hoãn** (chưa có Mac / Apple Developer account) — không phải bỏ |
| Internet | Không có trong MVP |
| Ngôn ngữ | Tài liệu và giao diện viết tiếng Việt |
| Build APK | **Chỉ `arm64-v8a`**, trừ khi được yêu cầu khác |

### Quy ước build APK

Mặc định chỉ build cho `arm64-v8a` — đủ cho hầu hết điện thoại Android từ 2017
trở lại đây, và cho ra file ~17MB thay vì ~50MB của bản gộp cả 3 kiến trúc:

```bash
cd app && flutter build apk --release --target-platform android-arm64
```

Chỉ build thêm `armeabi-v7a` (máy 32-bit đời cũ) hoặc `x86_64` (máy ảo) khi
được yêu cầu rõ.

---

## Chín ràng buộc không được vi phạm

**1. Game không được biết gì về mạng.**
`GameDefinition` là pure Dart: không socket, không IP, không discovery, không
`Widget`. Có test tự động canh.

**2. Phòng và tầng mạng không được biết game nào tồn tại.**
Tra cứu qua `GameRegistry` bằng `gameId`. Không bao giờ viết
`if (gameId == 'tic-tac-toe')` ở `platform_core` hay `app/lib/transport/`.

**3. `platform_core` phải là pure Dart.**
Không `flutter`, không `dart:io`, không thư viện mạng. Đây là thứ cưỡng chế
ràng buộc 1 và 2 ở mức hệ thống package. Có test tự động canh.

**4. Host là trọng tài duy nhất.**
Client gửi **ý định** (`GAME_ACTION`), host `validate` → `apply` → phát
`GAME_STATE` đầy đủ. Client không bao giờ tự áp dụng nước đi hay tự kết luận
thắng thua. Bảng bản tin trong [game-protocol.md](docs/architecture/game-protocol.md)
chính là quy tắc này.

**5. Chủ phòng cũng chơi qua đúng protocol đó.**
Host tự nối một `LocalLinkPair` trong bộ nhớ tới chính mình. Không được gọi
thẳng vào logic — làm vậy thì đường code của host và client khác nhau, và bug
sẽ chỉ lộ ra ở một phía.

**6. Discovery bằng mDNS/Bonjour, cấm UDP broadcast.**
UDP broadcast tự chế trên iOS bắt buộc entitlement phải xin Apple duyệt. Dùng
**đúng một** service type `_gamehub._tcp` cho **mọi** game — `NSBonjourServices`
không hỗ trợ wildcard. Lọc game bằng TXT record. Xem
[ADR-002](docs/architecture/decisions/ADR-002-discovery.md).

**7. TXT record chỉ chứa dữ liệu bất biến.**
Không đặt số người chơi vào đó: `NsdManager` trước API 34 không sửa được TXT.

**8. `AppLifecycleState.paused` không được rời phòng.**
`paused` bắn ra cả khi kéo thanh thông báo, có cuộc gọi đến, hiện hộp thoại xin
quyền. Cơ chế thật là timeout phía host.

**9. Phát hiện mất kết nối bằng `WebSocket.pingInterval`.**
`dart:io` đã làm sẵn. Không tự viết heartbeat ở tầng ứng dụng — tốn pin và bị
Doze của Android xử lý.

---

## Thêm game mới

1. Tạo package `packages/game_<tên>/`.
2. `lib/src/logic/` implement `GameDefinition` — **pure Dart**.
3. `lib/src/ui/` vẽ bàn cờ từ `GameView`.
4. Thêm một `CatalogEntry` vào [app/lib/state/catalog.dart](app/lib/state/catalog.dart).

**Chỉ được chạm 4 chỗ trên.** Nếu phải sửa `platform_core` hay
`app/lib/transport/` thì kiến trúc đã sai (spec §35) — dừng lại, báo cáo, sửa
kiến trúc trước.

Tên game hiện chỉ xuất hiện ở **đúng một file**: `catalog.dart`. Có test canh giữ.

---

## Chạy và kiểm thử

```powershell
$env:PATH = "D:\flutter\bin;$env:PATH"
```

```bash
cd packages/platform_core && dart test      # 52 test, dưới 1 giây
cd packages/game_tictactoe && flutter test  # 24 test
cd app && flutter test                      # 7 test
```

Toàn bộ luồng phòng + ván đấu test được **không cần thiết bị**, nhờ
`LoopbackTransport`. Viết tính năng mới thì test bằng nó trước, đừng cắm máy thật.

Hai điều kiện của `LoopbackTransport` không được phá: **serialize thật** (truyền
chuỗi JSON, không đưa tham chiếu object) và **giao tin bất đồng bộ**.

**Khi viết widget test**: `LocalLink` giao tin qua `Timer`, mà trong
`testWidgets` Timer chạy trên đồng hồ giả. Mọi thao tác điều khiển mạng phải nằm
trong `tester.runAsync`, nếu không test sẽ treo.

---

## Đang mở

**Tech Spike chưa chạy** — cần 2 máy Android thật. Đây là gate mà spec §15 bắt
buộc. Rủi ro số 1: Wi-Fi không có Internet khiến Android đẩy traffic sang 4G,
làm TCP tới LAN không tới nơi. Nếu đúng vậy thì cần platform channel Kotlin gọi
`bindProcessToNetwork`. Chi tiết ở [checklist](docs/tech-spike/checklist.md).

**Nhánh 3–4 người chưa từng chạy thật** — cờ caro luôn 2 người. Code đã viết cho
N người và có test ở `platform_core`, nhưng game thật đầu tiên dùng tới nó phải
là game thứ hai. Vì vậy game #2 đã chốt là **Dots and Boxes (2–4 người)**, không
phải cờ vua: mục đích của nó là đo chi phí cắm thêm game và chạy nhánh N>2, chứ
không phải để có game hay.

**`bonsoir_android` tự áp dụng Kotlin Gradle Plugin** — các bản Flutter sau sẽ
không build được. Khi tới lúc đó: chờ bonsoir cập nhật, hoặc đổi sang `nsd`
(interface `DiscoveryService` đã tách sẵn).

---

## Môi trường trên máy này

- Flutter SDK: `D:\flutter` (không nằm trong PATH mặc định)
- JDK: đã trỏ Flutter sang JDK 17 của Android Studio, vì `JAVA_HOME` của hệ
  thống trỏ vào một JDK 8 không tồn tại
- Hai chỗ đã phải vá trong cấu hình Gradle — lý do ghi trong [README.md](README.md)
- Chưa có Mac, chưa có tài khoản Apple Developer
