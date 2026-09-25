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
| Số người/phòng | Theo từng game (`minPlayers`/`maxPlayers`); hiện core hỗ trợ 2–4 |
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
3. `lib/src/ui/` vẽ bàn cờ từ `GameView`, vẽ icon của game (`CustomPaint`,
   không dùng file ảnh — icon phải sắc nét từ 30px tới 90px), và nếu game có
   máy đánh thì dựng luôn màn hình chơi với máy.
4. Thêm một `CatalogEntry` vào [app/lib/state/catalog.dart](app/lib/state/catalog.dart).

**Mỗi game tự vẽ dải trạng thái của mình** ("Lượt của bạn", chiếu tướng, hết
giờ). Màn phòng của `app` không biết game nào đang chạy nên không biết chữ nào
đúng, và nó không vẽ dòng đó nữa.

**Không có gì trong màn ván đấu được đổi chiều cao giữa ván.** Mọi khối quanh
bàn cờ — dải trạng thái, thẻ người chơi, hàng nút — phải cao cố định, kể cả khi
đang trống. `if (x) Widget()` trong một `Column` là cách sinh ra lỗi này: bắt
quân đầu tiên, bấm ván mới, hay ván kết thúc đều làm cả trang nhảy. Chỗ trống
trông thừa hơn hẳn một cú nhảy. Có
[test canh](packages/game_xiangqi/test/xiangqi_board_test.dart).

**Thời lượng animation lấy từ `GameMotion`** của
[packages/game_audio](packages/game_audio), đừng viết `Duration` rời. Thứ làm
giao diện trông rời rạc không phải là thiếu animation mà là mỗi chỗ một tốc độ.

**Máy đánh phải chạy ở isolate nền.** Thuật toán tìm kiếm chạy đồng bộ; gọi
thẳng nó trong `setState` hay trong một `Future.delayed` thì suốt lượt máy nghĩ
**không khung hình nào được vẽ** — kể cả khung hình đang chờ để hiện nước mà
người chơi vừa đánh. Triệu chứng đúng là "bấm một ô, một hai giây sau mới thấy
quân của mình", và nó nặng dần theo độ khó. Cách làm: một hàm **top-level** nhận
một request chỉ chứa dữ liệu thuần (thế cờ ở dạng JSON đã mã hóa), gọi qua
`compute` — xem `pickTicTacToeMove` và `pickXiangqiMove`. Trước khi gọi thì
`await WidgetsBinding.instance.endOfFrame`, đừng `Future.delayed` một nhịp:
timer và vsync là hai đồng hồ rời nhau. Có
[test canh ranh giới isolate](packages/game_tictactoe/test/ai_isolate_test.dart)
ở mỗi game. Widget test nào chạm vào lượt máy phải bọc `tester.runAsync` —
đồng hồ giả của `testWidgets` không nhích được một isolate khác.

**Khung màn ván đấu dùng lại, không vẽ mới.** `GamePlayerCard`,
`GameStatusLine`, `GameActionButton`, `GameColors` — tất cả ở `game_audio`.
Game chỉ đưa vào phần của riêng mình (cờ tướng đưa dải "Đã bắt" vào chỗ
`footer` mà thẻ chừa sẵn). Tự vẽ một thẻ người chơi riêng là bắt đầu để hai màn
ván đấu trôi khác nhau, và người chơi đi từ game này sang game kia sẽ thấy hai
app khác nhau.

**Màn hình của `app` thì dùng lại [app_ui.dart](app/lib/ui/app_ui.dart)** —
`AppDialog`, `AppTile`, `AppButtons`, `AppField`, `AppNotice`, `AppStatusPill`,
`AppInkPage`, `AppInkHeader`, `AppInkCard`. Đó là chỗ của những mảnh chỉ `app`
cần; để chúng vào `game_audio` sẽ bắt mọi package game kéo theo thứ chúng không
bao giờ gọi.

**Hai bảng màu, mỗi bảng một chặng.** `GameColors` (ở `game_audio`) cho những
màn dẫn tới bàn cờ — tìm phòng, phòng chờ, ván đấu. `AppInk` (ở `app_ui.dart`)
cho Trang chủ và Cài đặt, ấm hơn một bậc vì hai màn đó lấy bức tranh thuỷ mặc
làm nền. Màu nhấn của cả hai là **cùng một sắc đỏ**, nên đường đi từ trang chủ
tới bàn cờ không thấy đứt đoạn. Đừng thêm bảng thứ ba.

Ảnh trong repo chỉ có **bộ icon app** và **hai file trang trí của `app`**:
`paper_landscape.png` (nền tranh thuỷ mặc) và `title_banner.png` (tấm biển
nhãn mục). **Icon game vẫn phải vẽ bằng `CustomPaint`** trong package của game
— icon phải sắc nét từ 30px tới 90px, ảnh bitmap thì không. Hai file kia thuộc
về `app` nên chúng nằm ở `app/assets`, và mọi ảnh của bộ mực nho phải có tên
trong `AppInkImages.all` để công cụ dựng ảnh nạp sẵn được.

**Tấm biển dùng nguyên một ảnh, không cắt mảnh rồi ghép lúc dựng.** Ghép mảnh
thì bề rộng tấm biển chạy theo độ dài nhãn, nên "KẾT NỐI" ra một tấm ngắn còn
"CHƠI NHANH" ra một tấm dài — ba mục trên cùng một trang thành ba tấm biển
khác nhau. Một ảnh nguyên thì ba tấm giống hệt nhau. Đổi lại lòng biển cố định
ở 34% bề ngang ảnh, nên nhãn dài hơn thế sẽ bị cắt bớt; nhãn mục vốn ngắn nên
đó là cái giá đúng.

**Một sắc vàng cho mọi khung viền.** `GameColors.frame` ở
[game_audio](packages/game_audio) là màu duy nhất của viền: nhãn mục, viền
thẻ ở `app`, và viền icon của từng game đều lấy từ đó. Để mỗi chỗ tự khai một
sắc nâu gần giống nhau thì chúng sẽ trôi khỏi nhau, và trên cùng một trang
trông như lỗi in. Nó nằm ở `game_audio` vì đó là package duy nhất mà cả `app`
lẫn mọi package game đều phụ thuộc.

**Mọi thứ tầng mạng lấy qua provider, không tự dựng.**
[network_providers.dart](app/lib/state/network_providers.dart) tồn tại để
override được. Gọi thẳng `LanDiscovery()` hay `LocalNetworkPermission()` trong
một notifier là biến màn hình đó thành màn duy nhất không test được và không
dựng ảnh được — đã xảy ra một lần ở màn tìm phòng, có
[test canh](app/test/rooms_screen_test.dart).

**Âm thanh và thanh tiêu đề không phải khai báo gì.** Ván qua mạng đã được màn
phòng của `app` bọc `GameMusic` và dựng sẵn `gameAppBar` kèm nút loa. Màn chơi
với máy thì game tự gọi `gameAppBar` của
[packages/game_audio](packages/game_audio) — đừng tự dựng `AppBar` riêng, hai
đường đó phải trông giống nhau. Ngoài ra game chỉ cần: phát tiếng riêng qua
`GameSoundPlayer` của [packages/game_audio](packages/game_audio) — **cấm gọi
thẳng `audioplayers`**, vì gọi thẳng là bỏ qua nút tắt tiếng của người dùng —
và màn chơi với máy của mình thì tự bọc `GameMusic` + thêm `GameAudioButton`.

`CatalogEntry` cầm **hàm dựng widget**, không cầm `gameId` để `app` tự phân
nhánh. Mọi màn hình riêng của game — bàn cờ, icon, chơi với máy — đều do package
của game dựng, `app` chỉ gọi hàm. Thấy `switch (gameId)` hay `if (gameId == ...)`
ở `app/lib/ui/` là đã vi phạm ràng buộc số 2; cách sửa luôn là thêm một trường
hàm vào `CatalogEntry`, không phải thêm một nhánh `case`.

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
cd packages/platform_core && dart test      # luật phòng + giao thức
cd packages/game_audio && flutter test      # cài đặt âm thanh dùng chung
cd packages/game_tictactoe && flutter test  # luật cờ caro + máy + bàn cờ
cd packages/game_xiangqi && flutter test    # luật cờ tướng + bàn cờ
cd app && flutter test                      # cả app trên LoopbackTransport
```

Hai công cụ dòng lệnh, không phải test tự động:

```bash
cd packages/game_tictactoe
dart run bin/benchmark_ai.dart       # máy nghĩ bao lâu, mức trên có thắng mức dưới
dart run bin/generate_sounds.dart    # sinh lại assets/sounds/*.wav

cd packages/game_audio
dart run bin/generate_music.dart     # sinh lại nhạc nền assets/music/ambient.mp3

cd packages/game_xiangqi
flutter test tool/render_preview_test.dart   # dựng build/*.png để soi bố cục

cd app
flutter test tool/render_preview_test.dart   # dựng build/*.png các màn của app
flutter test tool/render_app_icon_test.dart  # dựng lại 27 file icon của app
flutter build web --release && \
  dart run tool/shoot_web.dart build/shots shot:trang-chu   # chụp app chạy thật
```

Công cụ dựng ảnh nằm ở `tool/` chứ không ở `test/`: nó không khẳng định điều
gì, nó chỉ vẽ ra để mắt người nhìn. Để trong `test/` thì `flutter test` chạy
luôn nó và lẫn vào kết quả thật — riêng công cụ icon còn ghi đè file trong
repo, càng không được chạy lẫn.

**Sửa giao diện xong thì soi bằng [shoot_web.dart](app/tool/shoot_web.dart),
đừng dừng ở `render_preview_test.dart`.** Công cụ dựng widget chạy dưới
`flutter test`, mà font của `flutter_test` không có glyph Latin: mọi chữ ra ô
vuông, rộng hơn chữ thật kha khá, và không ảnh nào tự giải mã. Nó đủ để canh
khối, không đủ để kết luận "đã đúng thiết kế". `shoot_web.dart` chạy **app
thật** trong Chrome ở đúng 390x844 @3x, bấm được để sang màn khác, nên thấy
đúng thứ người dùng thấy.

Công cụ đó đi qua DevTools Protocol chứ không dùng cờ `--screenshot` của
Chrome: `--window-size` cộng `--force-device-scale-factor` cho ra viewport
không đoán trước được, và đã một lần chụp ở 390px trong khi Flutter dựng bố
cục ở 780px — loại sai lệch làm ta tin nhầm rằng giao diện đã đúng.

**Icon của app sửa ở hai chỗ, và hai chỗ phải khớp**:
[app_icon.svg](app/assets/images/app_icon.svg) là nguồn thiết kế, còn
[render_app_icon_test.dart](app/tool/render_app_icon_test.dart) là thứ thật sự
dựng ra PNG cho Android/iOS/web và `.ico` cho Windows. Đừng xuất ảnh bằng tay:
27 file ở 4 nền tảng, bỏ sót một cái là icon lệch nhau mà không ai nhận ra.

Mọi âm thanh trong repo đều **tổng hợp bằng Dart**, không tải file ngoài: không
vướng giấy phép, và muốn đổi thì sửa công thức rồi chạy lại. Nhạc nền phải lặp
không nghe thấy mối nối — cách bảo đảm điều đó ghi trong chính file generator.

Chạy `benchmark_ai` **mỗi khi đụng vào thuật toán của máy**. Hai con số phải
giữ: thời gian nghĩ nằm trong ngân sách của từng mức, và mức trên phải thắng
mức dưới **cả khi đi sau** — thắng khi đi trước không chứng minh được gì, vì cờ
caro tự do vốn là thế thắng của bên đi trước.

Toàn bộ luồng phòng + ván đấu test được **không cần thiết bị**, nhờ
`LoopbackTransport`. Viết tính năng mới thì test bằng nó trước, đừng cắm máy thật.

Hai điều kiện của `LoopbackTransport` không được phá: **serialize thật** (truyền
chuỗi JSON, không đưa tham chiếu object) và **giao tin bất đồng bộ**.

**Khi viết widget test**: `LocalLink` giao tin qua `Timer`, mà trong
`testWidgets` Timer chạy trên đồng hồ giả. Mọi thao tác điều khiển mạng phải nằm
trong `tester.runAsync`, nếu không test sẽ treo.

---

## Đang mở

**Đã thử kết nối trên 2 máy Android 13** — chủ dự án xác nhận kết nối rất tốt.
Các điều kiện và số đo của Tech Spike chưa được ghi lại đầy đủ, nên chưa kết
luận PASS cho toàn bộ checklist §15. Đặc biệt cần xác nhận kịch bản Wi-Fi không
có Internet khi 4G bật, mất kết nối và khôi phục. Xem
[kết quả hiện có](docs/tech-spike/decision.md) và
[checklist](docs/tech-spike/checklist.md).

**Nhánh 3–4 người chưa từng chạy thật** — số người do từng game quy định. Cờ
caro và cờ tướng đều dùng 2 người. Core có test cho N người, nhưng cần kiểm
chứng trên thiết bị thật khi thêm một game hỗ trợ 3–4 người. Không ép game 2
người thành 3–4 người chỉ để kiểm chứng platform.

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
