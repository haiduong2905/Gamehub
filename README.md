# Game Hub

Nền tảng chơi game đối kháng qua Wi-Fi/LAN, **không cần Internet**.
Game đầu tiên: cờ caro 3x3 (X-O).

Xây theo [.claude/GAME_PLATFORM_WORKFLOW.md](.claude/GAME_PLATFORM_WORKFLOW.md).

---

## Trước khi bắt tay vào sửa gì

Đọc [CLAUDE.md](CLAUDE.md) — tóm tắt các ràng buộc kiến trúc **đã thống nhất**
và không được vi phạm. Kế hoạch đầy đủ kèm trạng thái từng phase nằm ở
[docs/plan/roadmap.md](docs/plan/roadmap.md).

---

## Cấu trúc

```
packages/platform_core/     PURE DART — không Flutter, không dart:io
  protocol/                 sealed Message + codec viết tay + golden test
  room/                     RoomHost (trọng tài) + RoomClient (phía người chơi)
  session/                  GameSession — state của một ván
  game/                     GameDefinition, GameRegistry, GameView
  transport/                Transport/Discovery trừu tượng + LoopbackTransport

packages/game_tictactoe/    Cờ caro: src/logic/ (pure Dart) + src/ui/ (Flutter)

app/                        Flutter app
  lib/transport/lan/        WebSocket + bonsoir + chọn IP + quyền mạng
  lib/state/                Riverpod
  lib/ui/                   Màn hình
```

Chiều phụ thuộc — **có test tự động canh giữ**:

```
platform_core  →  (không phụ thuộc gì)
game_tictactoe →  platform_core
app            →  cả hai
```

---

## Chạy

Flutter SDK đặt tại `D:\flutter`. Thêm vào PATH trước khi chạy:

```powershell
$env:PATH = "D:\flutter\bin;$env:PATH"
```

### Test (không cần thiết bị)

```bash
cd packages/platform_core && dart test        # 52 test, chạy dưới 1 giây
cd packages/game_tictactoe && flutter test    # luật chơi + 1 ván trọn vẹn
cd app && flutter test                        # cả app trên LoopbackTransport
```

Toàn bộ luồng tạo phòng → vào phòng → sẵn sàng → chơi → thắng thua → mất kết
nối → quay lại đều test được **không cần điện thoại, không cần Wi-Fi**, nhờ
`LoopbackTransport`.

### Chạy trên Android

```bash
cd app
flutter devices
flutter run -d <device-id>
```

Cần **2 máy Android thật cùng một Wi-Fi**. Máy ảo (emulator) không dùng được:
hai emulator không thấy nhau qua mDNS và nằm sau NAT riêng.

#### Build APK để cài lên máy

Mặc định **chỉ build cho arm64-v8a** — đủ cho hầu hết điện thoại Android từ
2017 trở lại đây, file ~17MB thay vì ~50MB của bản gộp cả 3 kiến trúc:

```bash
flutter build apk --release --target-platform android-arm64
```

File ra ở `build/app/outputs/flutter-apk/`. Cài bằng `adb install -r <file>`,
hoặc copy sang điện thoại rồi mở để cài.

Chỉ build thêm `armeabi-v7a` (máy 32-bit đời cũ) hoặc `x86_64` (máy ảo) khi
thật sự cần — thêm `--split-per-abi` để ra cả ba.

#### Hai chỗ đã phải vá để build được Android

Stack Flutter 3.47 dùng Gradle 9.3 + Kotlin 2.4 + AGP 9, còn khá mới nên có
hai chỗ gãy. Cả hai đã sửa sẵn trong repo, ghi lại đây để sau này biết vì sao:

**1. `Could not close incremental caches ... class-fq-name-to-source.tab`**

Lỗi incremental compilation của Kotlin 2.4 trên Windows — xảy ra cả khi build
sạch và không có tiến trình nào chạy song song. Đã tắt trong
[android/gradle.properties](app/android/gradle.properties):

```properties
kotlin.incremental=false
```

**2. `:bonsoir_android is currently compiled against android-33`**

`bonsoir_android 5.1.6` hard-code `compileSdkVersion 33`, trong khi AGP 9 đòi
tối thiểu 34. Đây là bản mới nhất nằm trong ràng buộc của `bonsoir` nên không
nâng dependency để tránh được. Đã thêm khối `subprojects` nâng compileSdk trong
[android/build.gradle.kts](app/android/build.gradle.kts).

Việc này **chỉ đổi phiên bản SDK dùng để biên dịch** — không đụng `targetSdk`
(hành vi lúc chạy) hay `minSdk` (phạm vi thiết bị).

⚠️ **Còn một cảnh báo chưa xử lý được**: `bonsoir_android` tự áp dụng Kotlin
Gradle Plugin, và **các bản Flutter sau sẽ không build được** nếu plugin còn
làm vậy. Khi tới lúc đó: hoặc chờ bonsoir cập nhật, hoặc đổi sang `nsd` —
interface `DiscoveryService` đã tách sẵn nên phần còn lại không phải sửa.

**Nếu JAVA_HOME trỏ vào JDK cũ**, chỉ Flutter sang JDK của Android Studio:

```bash
flutter config --jdk-dir="C:\Program Files\Android\Android Studio\jbr"
```


### Chạy trên Windows (để test nhanh)

```bash
cd app
flutter run -d windows
```

⚠️ Windows cần bật **Developer Mode** mới build được app có plugin:

```powershell
start ms-settings:developers
```

`bonsoir` có gói `bonsoir_windows` nên bản desktop cũng tự tìm được phòng.
Nếu vì lý do gì đó không thấy, vẫn vào được bằng nút **"Nhập địa chỉ phòng"**.

Cách lặp nhanh nhất khi phát triển: chạy **một bản Windows làm chủ phòng** và
**một máy Android làm khách** — thay vì phải cắm hai máy thật mỗi lần.

---

## Cách chơi

1. Cả hai máy nối chung một Wi-Fi (mạng **không cần** có Internet).
2. Máy A: chọn game → **Tạo phòng mới**.
3. Máy B: chọn game → phòng của A hiện trong danh sách → chạm để vào.
   Nếu không thấy: máy A đọc địa chỉ ở màn hình chờ, máy B bấm
   **Nhập địa chỉ phòng**.
4. Cả hai bấm **Sẵn sàng**, chủ phòng bấm **Bắt đầu ván**.

---

## Vài quyết định đáng biết

| Quyết định | Lý do |
|---|---|
| mDNS/Bonjour, **không** UDP broadcast | UDP broadcast tự chế trên iOS bắt buộc có entitlement phải xin Apple duyệt. Bonjour với service type cố định thì không cần. |
| Một service type `_gamehub._tcp` cho **mọi** game | `NSBonjourServices` của iOS không hỗ trợ wildcard. Lọc game bằng TXT record. |
| Host là trọng tài duy nhất | Client gửi ý định, host validate rồi phát state. Client không bao giờ tự kết luận. |
| Host cũng chơi qua chính protocol đó | Host tự nối một ống trong bộ nhớ tới chính nó. Nhờ vậy UI chỉ có một đường code, bug không thể chỉ lộ ở một phía. |
| Broadcast **full state** mỗi lượt | Turn-based nên chi phí không đáng kể, đổi lại loại bỏ hoàn toàn khả năng desync. |
| Phát hiện mất kết nối bằng `WebSocket.pingInterval` | `dart:io` đã tự ping/pong và đóng socket khi không có phản hồi — đúng thứ bắt được half-open lúc ai đó rớt Wi-Fi. Timer tự viết 3 giây vừa tốn pin vừa bị Doze xử lý. |
| `AppLifecycleState.paused` **không** rời phòng | `paused` bắn ra cả khi kéo thanh thông báo hay có cuộc gọi đến. Đá người chơi ra vì việc đó là sai. |
| TXT record chỉ chứa dữ liệu bất biến | `NsdManager` trước API 34 không sửa được TXT; muốn đổi phải huỷ rồi đăng ký lại, phòng sẽ nhấp nháy mà số liệu vẫn sai vì mDNS cache theo TTL. |

Chi tiết ở [docs/architecture/decisions/](docs/architecture/decisions/).

---

## Thêm game mới

1. Tạo package `packages/game_<tên>/`.
2. `lib/src/logic/` implement `GameDefinition` — **pure Dart, không import Flutter**.
3. `lib/src/ui/` vẽ bàn cờ từ `GameView`.
4. Thêm một `CatalogEntry` vào [app/lib/state/catalog.dart](app/lib/state/catalog.dart).

**Không được sửa `platform_core` hay `app/lib/transport/`.** Nếu phải sửa thì
kiến trúc đã sai — xem mục 35 của bản spec.
