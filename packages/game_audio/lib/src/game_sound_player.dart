import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'audio_settings.dart';

/// Phát các tiếng ngắn của game, tôn trọng cài đặt âm thanh.
///
/// Dùng một nhóm player xoay vòng thay vì một player cho mỗi loại tiếng. Lý
/// do: hai nước đi liền nhau trên LAN có thể cách nhau vài chục mili giây, mà
/// gọi `play` lại trên cùng một player sẽ **cắt ngang** tiếng đang kêu. Xoay
/// vòng thì tiếng trước kêu hết, và số player không phụ thuộc vào game có bao
/// nhiêu loại tiếng.
class GameSoundPlayer {
  GameSoundPlayer({this.controller, int voices = 3})
      : assert(voices > 0, 'phải có ít nhất một player'),
        _voices = List.generate(voices, (_) => AudioPlayer()) {
    for (final player in _voices) {
      player.audioCache = AudioCache(prefix: '');
    }
  }

  /// `null` nghĩa là không có cài đặt nào phía trên — chạy với mặc định.
  final GameAudioController? controller;

  final List<AudioPlayer> _voices;
  int _next = 0;
  bool _disposed = false;

  AudioSettings get _settings => controller?.settings ?? const AudioSettings();

  /// Phát một tiếng. [asset] là đường dẫn đầy đủ kiểu
  /// `packages/game_tictactoe/assets/sounds/pen_x.wav`.
  Future<void> play(String asset) async {
    if (_disposed) return;
    final settings = _settings;
    if (!settings.effectsEnabled || settings.effectsVolume <= 0) return;

    final player = _voices[_next];
    _next = (_next + 1) % _voices.length;

    try {
      await player.setVolume(settings.effectsVolume);
      await player.play(AssetSource(asset));
    } catch (_) {
      // Âm thanh là phần thêm: máy không có ngõ ra âm thanh, hoặc trình duyệt
      // chưa cho phát trước khi người dùng chạm, vẫn phải chơi được.
    }
  }

  void dispose() {
    _disposed = true;
    for (final player in _voices) {
      unawaited(player.dispose());
    }
  }
}
