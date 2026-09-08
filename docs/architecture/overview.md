# Kiến trúc Game Hub

## Bốn tầng

```
┌──────────────────────────────────────────────┐
│  GAME HUB (app/lib/ui)                       │
│  Home · Danh sách phòng · Phòng chờ · Ván     │
└───────────────────────┬──────────────────────┘
                        │
┌───────────────────────▼──────────────────────┐
│  ROOM  (platform_core/room)                  │
│  RoomHost = trọng tài  ·  RoomClient = người  │
│  chơi.  Không biết luật của bất kỳ game nào.  │
└───────────────────────┬──────────────────────┘
                        │
┌───────────────────────▼──────────────────────┐
│  TRANSPORT  (interface ở core, LAN ở app)    │
│  Discovery · Connect · Messaging             │
└───────────────────────┬──────────────────────┘
                        │
┌───────────────────────▼──────────────────────┐
│  GAME  (packages/game_*)                     │
│  Chỉ luật chơi. Không biết gì về mạng.        │
└──────────────────────────────────────────────┘
```

## Nguyên tắc: một chiều phụ thuộc, kiểm tra được

```
platform_core   →  (không phụ thuộc gì)
game_tictactoe  →  platform_core
app             →  cả hai
```

Ba câu hỏi review kiến trúc ở mục 24 của spec đã được biến thành test tự động
trong [`packages/platform_core/test/architecture_test.dart`](../../packages/platform_core/test/architecture_test.dart):

- `platform_core` không phụ thuộc Flutter hay thư viện mạng nào.
- Không file nào trong core import `dart:io` hay `package:flutter`.
- Core không nhắc tên một game cụ thể nào (trong code, không tính comment).

## Host là trọng tài duy nhất

```
Người chơi chạm ô
      │
      ▼  GAME_ACTION (ý định, kèm actionId + expectedStateVersion)
   RoomHost
      │  validate → apply → tăng stateVersion
      ▼  GAME_STATE (state đầy đủ, riêng cho từng người)
Mọi người chơi vẽ lại
```

Client **không bao giờ** tự áp dụng nước đi hay tự kết luận thắng thua. Ô vừa
chạm được vẽ mờ cho đến khi host xác nhận — đó là phản hồi tức thì, không phải
dự đoán.

Turn-based nên host phát **full state** mỗi lượt: chi phí không đáng kể, đổi
lại loại bỏ hoàn toàn khả năng hai máy lệch nhau.

## Host cũng chơi qua chính protocol đó

Đây là quyết định dễ bị bỏ qua nhưng quan trọng:

```
  Máy của chủ phòng                    Máy của khách
┌────────────────────┐               ┌──────────────┐
│ RoomHost           │               │              │
│    ▲               │               │              │
│    │ LocalLinkPair │◄── WebSocket ─┤ RoomClient   │
│    ▼ (trong RAM)   │               │              │
│ RoomClient  ← UI   │               │      ↑ UI    │
└────────────────────┘               └──────────────┘
```

Chủ phòng tự nối một ống trong bộ nhớ tới chính mình thay vì gọi thẳng vào
logic. Nhờ vậy UI chỉ có **một** đường code, và bug không thể chỉ lộ ra ở một
phía.

## Game cắm vào bằng hai nửa

`GameDefinition` là pure Dart nên không thể chứa `Widget`. Registry vì thế
tách làm hai, khớp nhau qua `gameId`:

| Nửa | Ở đâu | Chứa gì |
|---|---|---|
| `GameRegistry` | `platform_core` | luật chơi, validate, apply, codec |
| `CatalogEntry.buildBoard` | `app/lib/state/catalog.dart` | widget bàn cờ |

Cầu nối là [`GameView`](../../packages/platform_core/lib/src/game/game_view.dart)
— dữ liệu thuần, không có kiểu nào của Flutter, nên nó ở được trong core. Nhờ
vậy package của game vừa chứa luật vừa chứa widget mà không sinh phụ thuộc vòng.

Generic `GameDefinition<S, A>` được bọc sau `GameAdapter` **không generic**,
chỉ nói chuyện bằng JSON đã encode. Encode/decode xảy ra đúng một chỗ: tại biên
đó. Nếu không, `dynamic` sẽ lan khắp `GameSession` và `RoomHost`.

## LoopbackTransport

`Transport` là interface, nên toàn bộ platform chạy được trên một "mạng LAN
giả" nằm gọn trong bộ nhớ. Hệ quả: tạo phòng, vào phòng, chơi hết ván, mất kết
nối, quay lại — tất cả test được bằng `dart test` / `flutter test`, không cần
thiết bị.

Hai điều kiện để nó không thành cái bẫy, cả hai đều được giữ:

1. **Serialize thật.** Truyền chuỗi JSON, không đưa thẳng tham chiếu object —
   nếu không sẽ có bug aliasing bị giấu và codec không hề được test.
2. **Giao tin bất đồng bộ.** Nếu giao đồng bộ, code sẽ vô tình phụ thuộc thứ
   tự đó rồi vỡ khi lên mạng thật.

## Vòng đời phòng

```
WAITING ──(đủ người + tất cả sẵn sàng)──► READY
   ▲                                        │
   │                                   (host bắt đầu)
   │                                        ▼
FINISHED ◄──(thắng/hoà/bỏ dở)────────── PLAYING
   │
   └──(host thoát)──► CLOSED
```

Người chơi mất kết nối được giữ chỗ 30 giây. Quay lại đúng trong khoảng đó thì
vào lại chỗ ngồi cũ và nhận lại nguyên ván đang chơi. Quá hạn thì bị loại; nếu
còn ít hơn số người tối thiểu thì ván tính là bỏ dở, nhưng **phòng vẫn mở** để
chủ phòng chờ người mới.

## Tài liệu liên quan

- [ADR-001 — Transport](decisions/ADR-001-transport.md)
- [ADR-002 — Discovery](decisions/ADR-002-discovery.md)
- [ADR-003 — Host authoritative](decisions/ADR-003-host-authoritative.md)
- [ADR-004 — Hoãn iOS](decisions/ADR-004-hoan-ios.md)
- [Checklist Tech Spike](../tech-spike/checklist.md)
