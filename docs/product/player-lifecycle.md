# Vòng đời người chơi

Bổ sung cho [room-lifecycle.md](room-lifecycle.md), nhìn từ phía một người chơi.

## Danh tính

Mỗi máy sinh một `playerId` ngẫu nhiên ở lần chạy đầu và **lưu lại vĩnh viễn**
(`SharedPreferences`). Đây là thứ cho phép quay lại đúng chỗ ngồi cũ sau khi
mất kết nối, nên tuyệt đối không được sinh mới mỗi lần mở app.

Tên hiển thị sửa được trong Cài đặt, mặc định là `Nguoi choi XXXX`.

Không tài khoản, không đăng nhập, không server — xem
[product-brief](product-brief.md).

## Các bước

```
  Mở app
    │
    ▼
  DISCOVERED ──── thấy phòng trong danh sách (hoặc có địa chỉ nhập tay)
    │
    │ chạm vào phòng
    ▼
  CONNECTING ──── WebSocket.connect, timeout 5 giây
    │
    ├──✗ TIMEOUT / REFUSED / UNREACHABLE / NO_PERMISSION
    │       → báo lỗi bằng tiếng Việt, ở lại danh sách phòng
    ▼
  JOINING ─────── gửi JOIN_REQUEST
    │
    ├──✗ ROOM_FULL / GAME_IN_PROGRESS / PROTOCOL_MISMATCH / ID_TAKEN
    │       → báo lý do (lý do từ chối luôn thắng "mất kết nối")
    ▼
  IN_ROOM ─────── trong phòng chờ, bấm sẵn sàng
    │
    │ chủ phòng bắt đầu
    ▼
  PLAYING ─────── đến lượt thì đi, không thì chờ
    │
    ▼
  FINISHED ────── xem kết quả, bấm chơi lại hoặc rời phòng
```

Cài đặt: [`ClientPhase`](../../packages/platform_core/lib/src/room/room_client.dart).

## Trạng thái trong lúc đi một nước

Người chơi chạm ô → client gửi `GAME_ACTION` và đánh dấu **đang chờ**:

```
chạm ô ──► ô vẽ mờ + "Đang gửi nước đi…"
              │
              ├── host chấp nhận ──► GAME_STATE, ô hiện rõ, đến lượt đối thủ
              │
              └── host từ chối ────► ERROR, ô mờ biến mất, hiện lý do
```

Trong lúc chờ, **mọi ô đều không bấm được** — tránh người chơi bấm nhanh gửi
hai nước liền. Đây không phải dự đoán lạc quan: client không hề tự vẽ kết quả,
ô mờ chỉ là báo cho người dùng biết cái chạm đã được ghi nhận.

## Người chơi này rời đi thì người khác thấy gì

| Việc xảy ra | Người còn lại thấy |
|---|---|
| Bấm rời phòng | Người đó biến mất khỏi danh sách ngay |
| Rớt Wi-Fi / tắt app | Sau ~10 giây: biểu tượng mất kết nối + "đang chờ quay lại" |
| Quay lại trong 30 giây | Trở lại bình thường, ván tiếp tục |
| Quá 30 giây | Bị loại. Nếu thiếu người thì ván bỏ dở, **phòng vẫn mở** |
| Chủ phòng thoát | Phòng đóng, mọi người về danh sách kèm lý do |

## Ba thứ dễ làm sai

**Không được rời phòng khi app xuống nền.** `AppLifecycleState.paused` bắn ra
cả khi kéo thanh thông báo, mở Control Center, gặp hộp thoại xin quyền, chia
đôi màn hình, hay có cuộc gọi đến.

**Không được tự viết heartbeat ở tầng ứng dụng.** `WebSocket.pingInterval` của
`dart:io` đã làm đúng việc đó ở tầng dưới. Timer 3 giây tự viết vừa tốn pin
vừa bị Doze của Android xử lý.

**Không được để màn hình tắt trong lúc chơi.** Hệ điều hành treo socket sau
khoảng 30 giây và ván đấu chết một cách khó hiểu. App bật `wakelock_plus`
trong suốt trạng thái `PLAYING`.
