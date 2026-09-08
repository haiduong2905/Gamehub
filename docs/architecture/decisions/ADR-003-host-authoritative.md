# ADR-003 — Host là trọng tài duy nhất, phát full state mỗi lượt

## Context

Hai đến bốn máy cùng nhìn vào một ván cờ. Phải có cách để tất cả nhìn thấy
cùng một sự thật, kể cả khi mạng chậm hoặc có người bấm hai lần.

## Decision

1. Máy tạo phòng chạy `RoomHost` — **nơi duy nhất** được phép thay đổi state.
2. Client gửi **ý định** (`GAME_ACTION`), không bao giờ gửi state hay kết quả.
3. Host `validate` → `apply` → tăng `stateVersion` → phát `GAME_STATE` **đầy
   đủ** cho từng người (đã lọc qua `viewFor`).
4. Client chỉ vẽ lại. Không dự đoán, không delta, không rollback.
5. **Chủ phòng cũng đi qua đúng protocol đó**, qua một `LocalLinkPair` trong
   bộ nhớ.

## Alternatives

**Optimistic update + rollback.** Cần cho game realtime. Ở đây độ trễ LAN
khoảng 5–20ms, người chơi không cảm nhận được, nên chỉ tổ rước thêm cả một
lớp phức tạp.

**Delta state.** Tiết kiệm băng thông. Bàn cờ 3x3 nặng vài trăm byte — tiết
kiệm cái không đáng tiết kiệm, đổi lại rủi ro lệch trạng thái.

**Chủ phòng gọi thẳng vào logic thay vì qua protocol.** Ít code hơn, nhưng
đường code của host và của client sẽ khác nhau, và bug sẽ chỉ lộ ra ở một phía
— loại bug tốn nhiều thời gian nhất để tìm.

## Reason

Full state broadcast **loại bỏ hoàn toàn** khả năng hai máy lệch nhau: không
có state cục bộ nào để mà lệch. Với turn-based, chi phí gần bằng không.

## Consequences

- **Idempotency phải làm rõ ràng.** `GAME_ACTION` mang `actionId` và
  `expectedStateVersion`:
  - `actionId` đã dùng → `ActionDuplicate`, host chỉ lặng lẽ gửi lại state
    hiện tại. Bấm hai lần hoặc gửi lại sau khi reconnect không bao giờ áp dụng
    hai lần.
  - `expectedStateVersion` lệch → `STALE_STATE`, thường là do người chơi bấm
    đúng lúc nước đi của đối thủ vừa tới.

  `stateVersion` **không** dùng để loại bỏ gói cũ — TCP trên một socket đã
  đảm bảo thứ tự. Nó tồn tại cho hai việc trên và cho resync sau khi rejoin.

- **Thông tin ẩn phải chặn từ đầu.** `GameDefinition.viewFor(viewer, state)`
  mặc định trả nguyên state (đúng cho mọi game thông tin đầy đủ). Game có bài
  trên tay override để che bài người khác **trước khi** host gửi đi. Thêm sau
  sẽ phải sửa cả protocol, session và mọi game đã viết.

- **UI vẫn phải phản hồi tức thì.** Ô vừa chạm được vẽ mờ cho tới khi host xác
  nhận. Đó không phải dự đoán — ô đó chưa thuộc về ai — mà chỉ là cho người
  chơi biết cái chạm đã được ghi nhận.

- Chủ phòng thoát thì phòng chết. Chấp nhận được: tiến trình giữ state đã biến
  mất, không có gì để cứu.
