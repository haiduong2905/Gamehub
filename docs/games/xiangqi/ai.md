# AI cờ tướng

Màn **Chơi với máy** có bốn mức tương ứng các nhóm Elo tham chiếu:

| Mức hiển thị | Nhóm Elo | Cấu hình hiện tại |
|---|---:|---|
| Tập sự | Dưới 1200 | Tìm 1 lớp, chọn ngẫu nhiên trong 4 nước được chấm cao nhất. |
| Kỳ thủ Phong trào | 1200–1599 | Tìm tối đa 2 lớp, 1.800 nút. |
| Nhất cấp Kỳ sĩ | 1600–1999 | Tìm tối đa 3 lớp, 6.500 nút. |
| Tượng kỳ Đại sư | 2000–2399 | Tìm tối đa 4 lớp, 18.000 nút. |

AI dùng alpha-beta, ưu tiên xét nước ăn quân, và đánh giá giá trị quân cùng vị
trí Tốt, Mã, Xe, Pháo. Khi còn nước đi, mỗi mức trả một nước hợp lệ; khi chạm giới hạn
nút, AI dùng kết quả từ độ sâu đã tìm xong gần nhất.

**Các khoảng Elo ở trên là nhãn tham chiếu, chưa phải Elo đã đo.** Chưa có
bộ đối thủ chuẩn và đủ ván đấu để khẳng định sức cờ thực tế đạt các khoảng
này. Trước khi công bố Elo như điểm xếp hạng, cần chạy đấu thử có kiểm soát,
đo tỉ lệ thắng theo từng mức và hiệu chỉnh cấu hình AI.
