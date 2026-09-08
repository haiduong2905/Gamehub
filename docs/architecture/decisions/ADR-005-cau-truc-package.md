# ADR-005 — Chỉ tách package ở ranh giới có giá trị thật

## Context

Bản spec đòi tách rõ Game Hub / Room / Network / Game. Cách máy móc là mỗi tầng
một package. Nhưng mỗi package là thêm một `pubspec.yaml` phải nuôi.

## Decision

```
packages/platform_core/     package riêng, PURE DART
packages/game_tictactoe/    package riêng, mỗi game một package
app/lib/transport/lan/      KHÔNG tách package
```

## Reason

**`platform_core` phải là package riêng.** Đó là thứ cưỡng chế "phòng và game
không biết gì về socket" ở mức hệ thống package chứ không phải mức kỷ luật cá
nhân. Nó chạy được bằng `dart test` thuần, không cần Flutter binding — nên bộ
test logic chạy dưới một giây.

**Mỗi game một package.** Đó chính là đơn vị "cắm vào" mà cả kiến trúc hướng
tới. Package chứa cả luật (`lib/src/logic/`, pure Dart) lẫn widget bàn cờ
(`lib/src/ui/`, Flutter), nên thêm game là thêm **một** thứ chứ không phải hai.

**`LanTransport` thì không tách.** Nó vẫn phải là code Flutter (bonsoir là
plugin), chỉ có đúng một nơi dùng, nên tách ra chỉ tốn thêm một pubspec mà
không được gì. Chiều phụ thuộc vẫn được đảm bảo vì `platform_core` không thể
import ngược lên app.

Tách nó ra khi nào xuất hiện người dùng thứ hai — ví dụ khi thêm transport
Internet, hoặc khi có app thứ hai.

## Alternatives

**Mỗi tầng một package (4–5 package).** Đúng sách vở, nhưng ba trong số đó chỉ
có một consumer duy nhất.

**Một package duy nhất, chia bằng thư mục.** Ít ma sát nhất, nhưng mất hẳn
khả năng cưỡng chế: không có gì ngăn ai đó `import 'dart:io'` vào `room/`.

**Dùng `melos`.** Không cần: dùng path dependency thẳng, đơn giản hơn và không
phải cài thêm công cụ.

## Consequences

- Chiều phụ thuộc được canh bằng test, không bằng lời hứa
  ([`architecture_test.dart`](../../../packages/platform_core/test/architecture_test.dart)):
  - `platform_core` không được phụ thuộc `flutter`, `bonsoir`, `nsd`, `http`…
  - không file nào trong core được import `dart:io` hay `package:flutter`
  - core không được nhắc tên một game cụ thể (trong code, không tính comment)

- **`LoopbackTransport` nằm trong `platform_core`, không phải trong test.** Nó
  là một implementation hợp lệ của `Transport`, và là thứ cho phép app chạy
  toàn bộ luồng phòng + ván đấu mà không cần thiết bị. Hai điều kiện để nó
  không thành cái bẫy:
  1. **Serialize thật** — truyền chuỗi JSON, không đưa thẳng tham chiếu object.
     Nếu đưa thẳng, hai bên dùng chung một instance, bug aliasing bị giấu đi và
     codec không hề được test.
  2. **Giao tin bất đồng bộ** (qua `Timer`). Giao đồng bộ thì code sẽ vô tình
     phụ thuộc thứ tự đó rồi vỡ khi lên mạng thật.

- Tầng mạng của app được lấy qua provider
  ([`network_providers.dart`](../../../app/lib/state/network_providers.dart)),
  nên câu hỏi review "Network có thay transport được không?" trả lời được bằng
  code: test của app override ba provider đó và chạy cả app trên Loopback.

- **Lưu ý khi viết widget test:** `LocalLink` giao tin qua `Timer`, mà trong
  `testWidgets` Timer chạy trên đồng hồ giả. Mọi thao tác điều khiển mạng bên
  trong widget test phải nằm trong `tester.runAsync`, nếu không test sẽ treo.
  Đây là lý do test "chạm ô rồi nước đi chạy qua host" được đặt ở đúng hai
  tầng riêng: bàn cờ test bằng widget test thuần, còn đường đi qua mạng test
  bằng `test()` thường.
