# Giao thức

## Khung bản tin

```json
{ "v": 1, "type": "GAME_ACTION", "payload": { } }
```

Cài đặt: [`messages.dart`](../../packages/platform_core/lib/src/protocol/messages.dart),
[`message_codec.dart`](../../packages/platform_core/lib/src/protocol/message_codec.dart).

`Message` là **`sealed class` của Dart 3**: mọi `switch` trên nó đều được
compiler kiểm tra đủ nhánh. Thêm một loại bản tin mà quên xử lý ở đâu đó sẽ là
**lỗi biên dịch**, không phải bug lúc chạy. Đây chính là thứ `freezed` cung
cấp, nhưng có sẵn miễn phí và không cần `build_runner`.

Codec viết tay có chủ đích: protocol là thứ phải kiểm soát bằng tay khi nâng
phiên bản. Đổi lại, mỗi thay đổi phải có
[golden test](../../packages/platform_core/test/protocol/message_codec_test.dart)
đi kèm — fixture JSON cố định cho từng loại bản tin.

## Bảng bản tin

Bảng này **chính là** quy tắc host-authoritative: không có bản tin nào cho
phép client gửi state hay kết quả lên.

### Client → Host

| Type | Nội dung | Ghi chú |
|---|---|---|
| `JOIN_REQUEST` | playerId, nickname, protocolVersion, roomSecret? | có `roomSecret` = đang quay lại |
| `PLAYER_READY` | ready | |
| `START_GAME` | — | **chỉ chủ phòng**; cũng dùng để chơi lại |
| `GAME_ACTION` | actionId, expectedStateVersion, action | **ý định**, không phải kết quả |
| `LEAVE_ROOM` | — | chỉ khi người dùng thật sự bấm rời |
| `PING` | nonce, sentAtMillis | chỉ để đo RTT hiển thị |

### Host → Client

| Type | Nội dung | Ghi chú |
|---|---|---|
| `ROOM_JOINED` | you, roomSecret, snapshot | client lưu `roomSecret` để quay lại |
| `JOIN_REJECTED` | code, message? | rồi đóng kết nối |
| `ROOM_UPDATE` | snapshot, reason, actorPlayerId? | xem bên dưới |
| `GAME_START` | gameId, stateVersion, state, currentActors, seatOrder | `state` đã lọc qua `viewFor` |
| `GAME_STATE` | stateVersion, state, currentActors, lastActionId? | phát mỗi lượt |
| `GAME_RESULT` | stateVersion, state, result | chỉ host được gửi |
| `ROOM_CLOSED` | code, message? | |
| `ERROR` | code, message?, actionId? | không đóng kết nối |
| `PONG` | nonce, sentAtMillis | |

## Vì sao `ROOM_UPDATE` thay cho `PLAYER_JOINED` / `PLAYER_LEFT`

Spec (mục 13) liệt kê hai bản tin riêng. Ở đây gộp thành một `ROOM_UPDATE`
mang **nguyên snapshot** kèm `reason` (`playerJoined`, `playerLeft`,
`playerDisconnected`, `playerReconnected`, `readyChanged`, `statusChanged`).

Lý do: chỉ có **một** đường code áp dụng snapshot, nên client không thể trôi
trạng thái so với host. `reason` vẫn cho UI đủ thông tin để hiện "X đã vào
phòng". Gửi sự kiện lẻ thì client phải tự dựng lại trạng thái — đúng loại code
sinh bug lệch trạng thái mà cả kiến trúc này đang tránh.

## Idempotency

`GAME_ACTION` mang `actionId` và `expectedStateVersion`:

| Tình huống | Host trả về |
|---|---|
| `actionId` đã áp dụng | lặng lẽ gửi lại `GAME_STATE` hiện tại |
| `expectedStateVersion` lệch | `ERROR` mã `STALE_STATE` + state hiện tại |
| chưa đến lượt | `ERROR` mã `NOT_YOUR_TURN` |
| game từ chối theo luật | `ERROR` mã của game (`CELL_TAKEN`…) |

Nhờ vậy bấm hai lần hoặc gửi lại sau khi reconnect **không bao giờ** áp dụng
hai lần.

Lưu ý: `stateVersion` **không** dùng để loại gói cũ — TCP trên một socket đã
đảm bảo thứ tự. Nó tồn tại cho idempotency và cho resync sau khi rejoin.

## Tương thích ngược

Decoder **không bao giờ ném lỗi** vì bản tin lạ:

- `type` không nhận ra → `UnknownMessage`, bên nhận bỏ qua.
- `v` khác `kProtocolVersion` → `UnknownMessage` kèm phiên bản đọc được.

Nhờ vậy một bản cũ không chết khi gặp bản tin của bản mới hơn. Còn việc hai máy
lệch phiên bản được chặn thẳng ở bước `JOIN_REQUEST` với mã `PROTOCOL_MISMATCH`
và một câu tiếng Việt nói rõ phải cập nhật.

Chỉ ném `FormatException` khi chuỗi không phải JSON hợp lệ — đó là lỗi tầng
dưới, không phải chuyện tương thích.

## Platform không hiểu luật game

`action`, `state` và `result` là hộp đen với phòng và tầng mạng. Chúng chỉ đi
qua `GameAdapter`. Nhờ vậy thêm game mới không phải sửa giao thức.

Ngoại lệ duy nhất, và là ngoại lệ có chủ đích: `currentActors` — **game tự khai
báo** ai đang đến lượt, để UI chung hiện được "Lượt của bạn" mà không phải hiểu
luật. Platform không suy ra, chỉ nhận.
