# Vòng đời phòng và người chơi

## Trạng thái phòng

```
                    ┌─────────┐
     tạo phòng ────►│ WAITING │◄──── có người rời / bỏ sẵn sàng
                    └────┬────┘
                         │ đủ người VÀ tất cả sẵn sàng
                         ▼
                    ┌─────────┐
                    │  READY  │
                    └────┬────┘
                         │ chủ phòng bấm "Bắt đầu ván"
                         ▼
                    ┌─────────┐
                    │ PLAYING │
                    └────┬────┘
                         │ thắng / hoà / bỏ dở
                         ▼
                    ┌──────────┐
                    │ FINISHED │──── mọi người sẵn sàng lại ──► PLAYING
                    └────┬─────┘
                         │ chủ phòng thoát
                         ▼
                    ┌─────────┐
                    │ CLOSED  │
                    └─────────┘
```

Cài đặt trong [`RoomStatus`](../../packages/platform_core/lib/src/room/room_models.dart)
và [`RoomHost`](../../packages/platform_core/lib/src/room/room_host.dart).

### Ai được làm gì

| Hành động | Ai | Điều kiện |
|---|---|---|
| Bắt đầu ván | **chỉ chủ phòng** | đủ người tối thiểu, tất cả sẵn sàng |
| Sẵn sàng / bỏ sẵn sàng | mọi người | chưa vào ván |
| Đi một nước | người đến lượt | đang chơi, không có nước đang chờ |
| Rời phòng | mọi người | bất cứ lúc nào |

Ván mới **reset trạng thái sẵn sàng của tất cả** — không ai bị kéo vào ván mới
khi chưa muốn.

## Trạng thái người chơi

```
        vào phòng
            │
            ▼
      ┌───────────┐   mất kết nối    ┌──────────────┐
      │ CONNECTED │─────────────────►│ DISCONNECTED │
      └───────────┘◄─────────────────└──────┬───────┘
            ▲       quay lại trong 30s      │
            │                        quá 30 giây
            │                               ▼
            │                        ┌─────────────┐
            └─── bấm rời phòng ─────►│  bị loại    │
                                     └─────────────┘
```

## Mất kết nối — chi tiết

**Phát hiện bằng gì:** `WebSocket.pingInterval = 5s` của `dart:io`. Không tự
viết heartbeat ở tầng ứng dụng — xem [ADR-001](../architecture/decisions/ADR-001-transport.md).

**Phân biệt hai việc rất khác nhau:**

| Sự việc | Xử lý |
|---|---|
| Người dùng bấm **Rời phòng** | Loại ngay, không chờ |
| Socket chết (rớt Wi-Fi, tắt app) | Giữ chỗ 30 giây |
| App xuống nền (`AppLifecycleState.paused`) | **Không làm gì** |

Việc thứ ba quan trọng: `paused` bắn ra cả khi người dùng kéo thanh thông báo,
mở Control Center, gặp hộp thoại xin quyền, chia đôi màn hình, hay có cuộc gọi
đến. Đá người chơi ra khỏi phòng vì những chuyện đó là sai. Cơ chế thật là
**timeout phía host** — và `detached` trên Android cũng không đáng tin vì tiến
trình bị kill thẳng.

**Khi hết 30 giây:**

- Người đó bị loại khỏi phòng.
- Nếu đang chơi mà số người còn lại **ít hơn mức tối thiểu** của game → ván
  tính là bỏ dở (`GameOutcome.abandoned`, lý do `OPPONENT_LEFT`).
- Nếu vẫn đủ người (game 3–4 người) → **ván tiếp tục**.
- **Phòng vẫn mở**, chủ phòng có thể chờ người mới vào.

**Quay lại trong 30 giây:** client gửi lại `JOIN_REQUEST` kèm `roomSecret` đã
lưu. Vào đúng chỗ ngồi cũ, và nếu đang giữa ván thì host gửi lại `GAME_START`
với state hiện tại để dựng lại toàn bộ ván.

`roomSecret` là chuỗi ngẫu nhiên 12 ký tự host cấp lúc vào phòng. Đây là chống
nhầm lẫn giữa vài người quen trong cùng phòng, **không phải chống tấn công** —
cố tình làm crypto ở đây là thừa.

**Chủ phòng mất kết nối:** phòng đóng ngay với mã `HOST_LEFT`, không chờ. Tiến
trình giữ trạng thái ván đã biến mất, không có gì để cứu.

## Từ chối vào phòng

| Mã | Khi nào |
|---|---|
| `ROOM_FULL` | đã đủ người |
| `GAME_IN_PROGRESS` | ván đã bắt đầu (MVP không có khán giả) |
| `ROOM_CLOSED` | phòng đã đóng |
| `ID_TAKEN` | trùng mã thiết bị nhưng sai `roomSecret` |
| `PROTOCOL_MISMATCH` | hai máy chạy hai phiên bản protocol khác nhau |

Host gửi lý do rồi đóng kết nối. Phía client, **lý do từ chối luôn thắng** sự
kiện "kết nối đã đóng" đến ngay sau đó — nói "phòng đã đầy" hữu ích hơn nhiều
so với "mất kết nối". Đây là lỗi mà test đã bắt được trong lúc phát triển.
