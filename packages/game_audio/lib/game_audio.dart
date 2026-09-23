/// Cài đặt và phát âm thanh, dùng chung cho mọi game trong Game Hub.
///
/// Tồn tại vì cài đặt âm thanh là thứ **cả app lẫn từng game đều cần đọc**,
/// mà hai bên không được biết nhau: game không được phụ thuộc vào `app`, còn
/// `platform_core` là pure Dart nên không chứa được `Widget` hay plugin.
///
/// Chiều phụ thuộc:
///
/// ```
/// game_audio  ->  flutter + audioplayers
/// game_*      ->  platform_core, game_audio
/// app         ->  tất cả
/// ```
///
/// `app` sở hữu việc **lưu** cài đặt; package này chỉ giữ giá trị đang dùng và
/// báo khi nó đổi.
library;

export 'src/audio_settings.dart';
export 'src/game_audio_button.dart';
export 'src/game_music.dart';
export 'src/game_sound_player.dart';
