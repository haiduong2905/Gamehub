# ADR-001 — Transport là WebSocket trên TCP

## Context

Hai điện thoại trong cùng Wi-Fi cần trao đổi nước đi. Một máy phải đóng vai
server. Game là turn-based, mỗi ván chỉ vài chục bản tin.

## Decision

Host chạy `HttpServer.bind(InternetAddress.anyIPv4, 0)` rồi nâng cấp lên
WebSocket bằng `WebSocketTransformer.upgrade()`. Client nối tới
`ws://<ip>:<cổng>`. Bản tin là JSON dạng text.

Cổng **0** — xin hệ điều hành một cổng trống rồi đọc lại cổng thật. Không
hardcode: hai app cùng máy, hoặc một lần hot restart chưa dọn sạch, sẽ đâm nhau.

## Alternatives

**Raw TCP + length-prefix.** Ít phụ thuộc hơn, nhưng phải tự viết code cắt
gói — nơi sinh bug âm thầm nhất trong networking. Và phải tự làm cơ chế phát
hiện half-open.

**UDP.** Cần cho game realtime, nhưng game ở đây là turn-based nên mất gói
phải tự xử lý lại — đắt hơn mà không được gì.

## Reason

- **Framing miễn phí.** Không phải tự cắt gói.
- **`pingInterval` có sẵn.** `dart:io` tự gửi ping và tự đóng socket khi không
  nhận được pong. Đây chính là thứ bắt được **half-open connection** khi ai đó
  rớt Wi-Fi đột ngột — TCP keepalive mặc định 2 tiếng, hoàn toàn vô dụng.
- **Debug được bằng bất kỳ ws client nào** trên máy tính, không cần máy thứ hai.

Lưu ý: *không* chọn vì "sau này lên Internet dùng chung code path" — relay cần
mô hình địa chỉ và xác thực hoàn toàn khác, nên đó là lý do yếu.

## Consequences

- `WebSocket.connect` **không có** tham số timeout. Bắt buộc bọc
  `.timeout(Duration(seconds: 5))`; thiếu nó, khi thiếu quyền mạng nội bộ trên
  Android 16/17 app sẽ treo đến hết TCP timeout của hệ thống thay vì báo lỗi.
- `HttpServer.close(force: true)` khi dừng, nếu không hot restart sẽ tích tụ
  server zombie giữ cổng.
- Overhead của WebSocket không đáng kể với turn-based, nhưng nếu sau này có
  game realtime thì phải xem lại — `Transport` đã là abstraction nên thay được.
