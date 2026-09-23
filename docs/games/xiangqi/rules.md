# Luật cờ tướng

## Bàn và lượt

Bàn gồm 9 đường dọc, 10 đường ngang, tổng cộng 90 giao điểm. Sông nằm giữa
hàng 4 và 5. Mỗi bên có cung 3×3 với hai đường chéo. Mỗi bên có 16 quân:
1 Tướng, 2 Sĩ, 2 Tượng, 2 Xe, 2 Mã, 2 Pháo và 5 Tốt. Đỏ đi trước; hai bên
luân phiên một nước. Số người của game này là đúng 2.
Khi tạo phòng, chủ phòng chọn cầm Đỏ hoặc Đen; người còn lại cầm màu kia.
Đỏ luôn là bên đi trước.
Quân Đen đã bị ăn hiển thị phía trên bàn; quân Đỏ đã bị ăn hiển thị phía dưới.
Hai người chơi cùng thấy danh sách này sau mỗi nước bắt quân.

## Di chuyển

| Quân | Luật |
|---|---|
| Tướng | Đi một giao điểm ngang hoặc dọc trong cung; hai Tướng không được lộ mặt trên cùng cột. |
| Sĩ | Đi chéo một giao điểm trong cung. |
| Tượng | Đi chéo hai giao điểm, không qua sông; bị chặn nếu giao điểm giữa có quân. |
| Xe | Đi ngang hoặc dọc bất kỳ khoảng cách nào khi đường đi trống. |
| Mã | Đi 2+1 giao điểm; bị cản nếu giao điểm sát nó theo hướng đi hai ô có quân. |
| Pháo | Đi như Xe trên đường trống; khi ăn phải nhảy qua đúng một quân bất kỳ. |
| Tốt | Chưa qua sông chỉ tiến một giao điểm; qua sông được tiến hoặc ngang một giao điểm, không lùi. |

Không được ăn quân mình hoặc đi nước khiến Tướng mình bị chiếu.

## Kết quả

- Chiếu bí Tướng đối phương là thắng. Hết nước hợp lệ khi bị chiếu là chiếu bí.
- Người chơi có thể xin thua khi đến lượt; đối thủ thắng ngay. Hết giờ hoặc phạm
  luật bị xử thua khi có quy định thời gian và xử phạt cụ thể.
- Khi đến lượt, mỗi người có thể cầu hòa. Đối thủ chọn **Đồng ý** để kết thúc
  hòa hoặc **Từ chối** để tiếp tục lượt của người xin. Mỗi người được cầu hòa
  tối đa ba lần trong một ván. Nếu cả ba lần đều bị từ chối, người xin bị xử
  thua ngay ở lần từ chối thứ ba.
- Hòa khi không bên nào còn khả năng chiếu bí hoặc khi lặp nước theo quy định.

Chế độ chơi với máy dùng cùng quy tắc ba lần. Máy đồng ý cầu hòa khi đánh giá
đang thua rõ (chênh ít nhất 500 điểm), còn lại từ chối.

Âm thanh cục bộ gồm tiếng gõ gỗ ngắn khi đặt quân, tiếng va chạm hai nhịp khi
bắt quân và chuỗi chuông ba nốt khi kết thúc bằng chiếu bí.
Người chơi có thể dùng âm lượng thiết bị để điều chỉnh.

## Quy định cần chốt trước khi triển khai

- Thời lượng đồng hồ và cách tính hết giờ.
- Tiêu chí chính xác cho thế cờ không đủ lực và số lần lặp, cách xử lý chiếu
  liên tục/đuổi quân liên tục.

Phiên bản code hiện tại chưa tự động xử các trường hợp trong mục này. Phần
luật di chuyển và chiếu bí vẫn phải qua kiểm thử đầy đủ trước khi nghiệm thu.
