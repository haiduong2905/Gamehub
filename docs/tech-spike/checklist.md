# Tech Spike — checklist kiểm chứng trên thiết bị thật

Bản spec (mục 15) bắt buộc phải qua Tech Spike trước khi tin vào tầng mạng.
Toàn bộ logic đã được kiểm chứng bằng `LoopbackTransport` trên máy tính; phần
**chưa** kiểm chứng được là những thứ chỉ lộ ra trên Android thật.

**Cần: 2 máy Android thật, cùng một Wi-Fi.** Máy ảo không dùng được — hai
emulator không thấy nhau qua mDNS và nằm sau NAT riêng (10.0.2.x).

Ghi kết quả vào `docs/tech-spike/decision.md` theo mẫu ở cuối file này.

---

## Ưu tiên 1 — những thứ có thể chặn cả dự án

### 1.1. Android có đẩy traffic sang 4G không? ⚠️ RỦI RO LỚN NHẤT

Khi Wi-Fi **không có Internet** — đúng kịch bản của dự án này — Android đánh
dấu mạng đó *unvalidated* và đặt default network sang cellular. Socket không
bind sẽ dùng bảng định tuyến của cellular, vốn không có đường tới subnet
Wi-Fi.

| Bước | Kỳ vọng |
|---|---|
| Nối cả 2 máy vào Wi-Fi **không có Internet** (ví dụ phát hotspot từ máy thứ 3 rồi tắt 4G của máy đó) | |
| Bật 4G trên cả 2 máy | |
| Tạo phòng ở máy A, vào phòng từ máy B | Vào được |
| Nếu lỗi `UNREACHABLE` / timeout | **Đây chính là vấn đề** |

**Nếu hỏng**: cần platform channel Kotlin (~30 dòng) gọi
`ConnectivityManager.requestNetwork(TRANSPORT_WIFI)` + `bindProcessToNetwork`.
Dart thuần không làm được.

Ghi lại: có hỏng không, trên Android bản nào, tắt 4G đi thì có hết không.

### 1.2. mDNS trả về IP số hay hostname `.local`?

`InternetAddress.lookup` của `dart:io` **không** đi qua resolver mDNS trên
Android. Nếu bonsoir trả về `Ten-May.local` thì kết nối sẽ chết.

Code đã xử lý: `LanDiscovery._numericHost()` bỏ phòng nào không đổi được ra
số. Cần xác nhận trên máy thật là **không có phòng nào bị bỏ oan**.

| Bước | Kỳ vọng |
|---|---|
| Máy A tạo phòng, máy B mở danh sách phòng | Phòng của A hiện ra |
| Vào **Cài đặt → Chẩn đoán mạng** trên máy A | IP hiện ra khớp với địa chỉ ở màn hình chờ |

### 1.3. Quyền mạng nội bộ

| Bước | Kỳ vọng |
|---|---|
| Cài đặt lần đầu, mở màn tìm phòng | Android hỏi quyền "thiết bị ở gần" |
| Bấm **Từ chối** | Hiện màn hình giải thích + nút "Mở Cài đặt", **không** treo im lặng |
| Cấp quyền trong Cài đặt rồi quay lại | Quét lại được |

Ghi lại phiên bản Android của từng máy test.

---

## Ưu tiên 2 — chất lượng kết nối

| Chỉ số | Ngưỡng đạt | Đo thế nào |
|---|---|---|
| Thời gian thấy phòng | ≤ 3s | Bấm giờ từ lúc mở màn tìm phòng |
| Thời gian vào phòng | ≤ 1s | Từ lúc chạm phòng đến khi thấy phòng chờ |
| Độ trễ nước đi | không cảm nhận được | Đánh một ô, xem máy kia hiện sau bao lâu |
| Chạy liên tục 30 phút | không đơ, không nóng bất thường | Để phòng mở, thỉnh thoảng đánh một nước |

---

## Ưu tiên 3 — mất kết nối

| Kịch bản | Kỳ vọng |
|---|---|
| Máy B tắt Wi-Fi giữa ván | Trong ~10s máy A hiện "mất kết nối, đang chờ quay lại" |
| Bật Wi-Fi lại trong 30s | B vào lại đúng chỗ ngồi, ván tiếp tục từ đúng nước đi cuối |
| Để quá 30s | Ván tính là bỏ dở, A về màn kết quả |
| Máy A (chủ phòng) thoát app | B nhận "Người tạo phòng đã thoát" và về danh sách |
| Kéo thanh thông báo rồi thả xuống | **Không được** rời phòng |
| Nhận cuộc gọi rồi tắt máy | **Không được** rời phòng |
| Khoá màn hình giữa ván | Màn hình phải tự sáng trong lúc chơi (wakelock), nên tình huống này chỉ xảy ra khi người dùng bấm nút nguồn |
| Chuyển app khác rồi quay lại sau 2 phút | Hoặc chơi tiếp được, hoặc báo mất kết nối rõ ràng — không được đơ |

---

## Ưu tiên 4 — mạng bất thường

| Kịch bản | Kỳ vọng |
|---|---|
| Wi-Fi có **AP isolation** (nhiều Wi-Fi khách sạn/công ty) | Không thấy phòng, và nhập địa chỉ tay cũng không vào được. Phải báo lỗi rõ ràng, không treo. |
| Wi-Fi chặn mDNS nhưng cho unicast | Không thấy phòng, nhưng **nhập địa chỉ tay phải vào được** |
| Hai máy khác subnet | Báo `UNREACHABLE`, không treo |
| Chủ phòng tắt app đột ngột (vuốt khỏi recent) | Phòng "ma" có thể còn trong danh sách vài giây (mDNS TTL); chạm vào phải báo lỗi êm, không crash |

---

## Ưu tiên 5 — nhiều người chơi

Cờ caro chỉ 2 người, nên nhánh 3–4 người **chưa từng chạy thật**. Khi thêm
game nhiều người (Dots and Boxes), phải test lại:

- 4 người vào cùng một phòng, lượt xoay đúng thứ tự chỗ ngồi.
- Người thứ 3 rớt khi còn 3 người → ván **vẫn tiếp tục**.
- Phòng đầy → người thứ 5 nhận "Phòng đã đủ người".

---

## Mẫu `decision.md`

```
Ngày test:
Thiết bị A:            (model, Android version)
Thiết bị B:            (model, Android version)
Router / Wi-Fi:

Technology:            Flutter <version>
Transport:             WebSocket trên TCP (dart:io)
Discovery:             mDNS/Bonjour qua bonsoir, service type _gamehub._tcp
Connection:            host-authoritative, host chạy HttpServer trên cổng động

Thời gian thấy phòng:
Thời gian vào phòng:
Độ trễ nước đi:

Android đẩy sang 4G:   CÓ / KHÔNG   (nếu CÓ: cần platform channel bind network)
mDNS trả IP số:        CÓ / KHÔNG
Quyền hoạt động đúng:  CÓ / KHÔNG

Android support:
iOS support:           CHƯA TEST (chưa có Mac / tài khoản Apple Developer)
Android <-> iOS:       CHƯA TEST

Known limitations:

Decision:              PASS / FAIL
```

Không PASS thì **không** làm tiếp tính năng mới — sửa tầng mạng trước.
