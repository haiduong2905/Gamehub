import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import 'audio_settings.dart';

/// Nhạc nền mặc định, dùng chung cho mọi game.
///
/// Để ở package dùng chung chứ không ở từng game: thêm game mới là có nhạc
/// nền ngay, không phải tự đi kiếm nhạc. Game nào muốn màu riêng thì truyền
/// [GameMusic.asset] của mình.
const kDefaultMusicAsset = 'packages/game_audio/assets/music/ambient.mp3';

/// Chạy nhạc nền suốt thời gian [child] còn nằm trên màn hình.
///
/// Bọc quanh khu vực ván đấu. Rời màn hình là nhạc tắt, không phải nhớ gọi
/// stop ở đâu cả — đó là lý do nó là widget chứ không phải một hàm.
///
/// Nhạc cũng **tạm dừng khi app xuống nền**. Đây không mâu thuẫn với ràng buộc
/// "`AppLifecycleState.paused` không được rời phòng": dừng nhạc không đụng gì
/// tới phòng, chỉ là không phát tiếng khi người chơi đã chuyển sang app khác.
class GameMusic extends StatefulWidget {
  const GameMusic({
    required this.child,
    this.asset = kDefaultMusicAsset,
    super.key,
  });

  final Widget child;
  final String asset;

  @override
  State<GameMusic> createState() => _GameMusicState();
}

class _GameMusicState extends State<GameMusic> with WidgetsBindingObserver {
  final _player = AudioPlayer();
  GameAudioController? _controller;
  bool _playing = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _player
      ..audioCache = AudioCache(prefix: '')
      ..setReleaseMode(ReleaseMode.loop);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = GameAudioScope.maybeOf(context);
    if (controller != _controller) {
      _controller?.removeListener(_sync);
      _controller = controller?..addListener(_sync);
    }
    unawaited(_sync());
  }

  @override
  void didUpdateWidget(GameMusic oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      _playing = false;
      unawaited(_sync());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    unawaited(_sync());
  }

  /// Đưa trình phát về đúng trạng thái mà cài đặt đang yêu cầu.
  ///
  /// Viết theo kiểu "so trạng thái mong muốn với trạng thái hiện tại" chứ
  /// không phải chuỗi bật/tắt, vì hàm này bị gọi từ bốn nguồn — dựng widget,
  /// đổi cài đặt, đổi asset, đổi vòng đời — và chúng có thể chồng lên nhau.
  Future<void> _sync() async {
    if (!mounted) return;
    final settings = _controller?.settings ?? const AudioSettings();
    final shouldPlay =
        settings.musicEnabled && settings.musicVolume > 0 && _foreground;

    try {
      if (shouldPlay) {
        await _player.setVolume(settings.musicVolume);
        if (!_playing) {
          _playing = true;
          await _player.play(AssetSource(widget.asset));
        }
      } else if (_playing) {
        _playing = false;
        await _player.stop();
      }
    } catch (error) {
      // Không có ngõ ra âm thanh, hoặc trình duyệt chưa cho phát: ván đấu vẫn
      // phải chạy bình thường. Nhưng nuốt lỗi **im lặng** thì mất nhạc trở
      // thành một bí ẩn không lần ra được — đổi file nhạc xong không nghe gì
      // mà không có lấy một dòng nào để bám. In đúng một dòng, kèm tên asset.
      _playing = false;
      debugPrint('GameMusic: không phát được "${widget.asset}" — $error');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_sync);
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
