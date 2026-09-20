/// Dịch mã lỗi ổn định của core sang câu tiếng Việt nói rõ người dùng cần làm gì.
///
/// Core và tầng transport chỉ phát ra mã (`ROOM_FULL`, `NO_PERMISSION`...).
/// Toàn bộ phần chữ nghĩa nằm ở đây, một chỗ duy nhất.
library;

String messageForCode(String? code, {String? fallback}) {
  if (code == null) return fallback ?? 'Đã có lỗi xảy ra.';

  return switch (code) {
    // Vào phòng
    'ROOM_FULL' => 'Phòng đã đủ người.',
    'GAME_IN_PROGRESS' => 'Ván đấu đã bắt đầu, không vào được nữa.',
    'ROOM_CLOSED' => 'Phòng đã đóng.',
    'ID_TAKEN' => 'Đã có người khác dùng chỗ này trong phòng.',
    'PROTOCOL_MISMATCH' =>
      'Hai máy đang chạy hai phiên bản khác nhau. Hãy cập nhật cùng một bản.',

    // Trong ván
    'NOT_YOUR_TURN' => 'Chưa đến lượt bạn.',
    'CELL_TAKEN' => 'Ô này đã có người đánh.',
    'OUT_OF_BOARD' => 'Nước đi nằm ngoài bàn cờ.',
    'GAME_FINISHED' => 'Ván đấu đã kết thúc.',
    'TURN_TIMEOUT' => 'Hết thời gian lượt. Đối thủ thắng.',
    'GAME_TIMEOUT' => 'Hết thời gian ván đấu.',
    'STALE_STATE' => 'Bàn cờ vừa thay đổi, hãy thử lại.',
    'NOT_HOST' => 'Chỉ người tạo phòng mới bắt đầu được ván đấu.',
    'NOT_ENOUGH_PLAYERS' => 'Chưa đủ người chơi.',
    'NOT_ALL_READY' => 'Còn người chưa sẵn sàng.',
    'ALREADY_PLAYING' => 'Ván đấu đang diễn ra.',

    // Phòng đóng
    'HOST_LEFT' => 'Người tạo phòng đã thoát.',
    'HOST_CLOSED' => 'Phòng đã được đóng.',
    'CONNECTION_LOST' => 'Mất kết nối tới phòng.',

    // Mạng
    'NO_PERMISSION' =>
      'Ứng dụng chưa được cấp quyền truy cập mạng nội bộ. '
          'Hãy cấp quyền trong Cài đặt rồi thử lại.',
    'TIMEOUT' =>
      'Không kết nối được. Kiểm tra xem hai máy có chung một mạng Wi-Fi không.',
    'REFUSED' => 'Phòng này không còn mở nữa.',
    'UNREACHABLE' =>
      'Không tới được máy kia. Thường là do hai máy khác mạng, '
          'hoặc điện thoại đang ưu tiên dùng 4G thay vì Wi-Fi.',
    'HOST_FAILED' => 'Không mở được phòng.',
    'CONNECT_FAILED' => 'Không kết nối được tới phòng.',

    _ => fallback ?? 'Đã có lỗi xảy ra ($code).',
  };
}

/// Lý do ván đấu kết thúc mà không phải do luật chơi.
String messageForAbandonReason(String? reason) => switch (reason) {
      'OPPONENT_LEFT' => 'Đối thủ đã rời trận.',
      _ => 'Ván đấu bị bỏ dở.',
    };
