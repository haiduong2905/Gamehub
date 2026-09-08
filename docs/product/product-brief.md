# Product Brief — Game Hub

## Platform là gì?

Một ứng dụng di động chứa nhiều game đối kháng, chơi với nhau qua **Wi-Fi/LAN,
không cần Internet**. Người dùng chọn game, tạo phòng hoặc tìm phòng của người
khác trong cùng mạng, rồi chơi.

Điểm mấu chốt về mặt kỹ thuật: **phần lõi được xây một lần**. Game thứ hai chỉ
là một package mới cắm vào, không đụng đến phòng, mạng hay giao thức.

## Người dùng là ai?

Vài người ngồi cạnh nhau — trong lớp, quán cà phê, văn phòng, chuyến xe — muốn
chơi với nhau ngay mà không phải đăng ký tài khoản, không cần mạng 4G, không
cần Internet.

Hệ quả cho thiết kế:

- **Không tài khoản, không đăng nhập.** Chỉ một tên hiển thị, sửa được.
- **Vào chơi trong vài giây.** Không có màn onboarding.
- Người chơi biết nhau ngoài đời → phần bảo mật chỉ cần chống nhầm lẫn, không
  cần chống tấn công.

## Game đầu tiên là gì?

**Cờ caro 3x3 (X-O)**, 2 người. Chọn nó vì luật đơn giản đến mức không che
được lỗi của platform: nếu ván cờ chạy đúng qua hai máy thì phần phòng, mạng
và giao thức đã đúng.

## Phòng hoạt động thế nào?

```
Chọn game → Tạo phòng → chờ người vào → cả hai sẵn sàng
          → chủ phòng bắt đầu → chơi → kết quả → chơi lại
```

- Ai tạo phòng thì máy đó làm **host**, tức trọng tài của ván đấu.
- Người khác trong cùng Wi-Fi thấy phòng trong danh sách và chạm để vào. Nếu
  mạng chặn tự động tìm, họ **nhập địa chỉ `IP:cổng`** mà chủ phòng đọc cho.
- Phòng chứa 2–4 người tuỳ game. Cờ caro là 2.
- Không mật khẩu trong MVP.
- Mất kết nối được **giữ chỗ 30 giây**; quay lại kịp thì vào đúng chỗ ngồi cũ
  và nhận lại nguyên ván đang chơi.
- Chủ phòng thoát thì phòng đóng — máy giữ trạng thái ván đã biến mất.

## MVP bao gồm

- Danh sách game, tên hiển thị sửa được.
- Tạo phòng, tìm phòng tự động, vào phòng bằng địa chỉ nhập tay.
- Phòng chờ: danh sách người chơi, trạng thái sẵn sàng, chủ phòng bấm bắt đầu.
- Chơi cờ caro 2 người, host là trọng tài.
- Kết quả thắng / hoà / bỏ dở, chơi lại không cần tạo phòng mới.
- Xử lý mất kết nối: báo rõ, giữ chỗ, cho quay lại.
- Màn chẩn đoán mạng trong Cài đặt.
- Android. Kèm bản Windows desktop để phát triển cho nhanh.

## MVP KHÔNG bao gồm

- Internet, matchmaking, cloud, server.
- Tài khoản, đăng nhập, bạn bè.
- Xếp hạng, lịch sử trận, thành tích.
- Chat, biểu cảm.
- Quảng cáo, thanh toán.
- iOS (**hoãn**, không phải bỏ — xem [ADR-004](../architecture/decisions/ADR-004-hoan-ios.md)).
- Khán giả xem ké, mật khẩu phòng, hẹn giờ mỗi lượt.

## Điều đã biết là chưa chắc chắn

- **Nhánh 3–4 người chưa từng chạy thật.** Cờ caro luôn 2 người. Code đã viết
  cho N người và có test ở `platform_core`, nhưng game thật đầu tiên dùng tới
  nó sẽ là game thứ hai (dự kiến Dots and Boxes, 2–4 người).
- **Android có thể đẩy traffic sang 4G** khi Wi-Fi không có Internet. Đây là
  rủi ro số một, phải đo trên máy thật —
  xem [checklist Tech Spike](../tech-spike/checklist.md).
