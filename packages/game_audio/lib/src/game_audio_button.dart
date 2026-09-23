import 'package:flutter/material.dart';

import 'audio_settings.dart';

enum _AudioToggle { effects, music }

/// Nút loa đặt trong AppBar của màn ván đấu.
///
/// Mở ra hai mục có dấu tích: hiệu ứng và nhạc nền. Hai thứ này bị tắt vì hai
/// lý do khác nhau nên phải tắt được riêng — bật nhạc của mình mà vẫn muốn
/// nghe tiếng đặt quân là trường hợp thường gặp nhất.
///
/// Âm lượng không nằm ở đây mà ở màn Cài đặt: nó là thứ chỉnh một lần, còn
/// trong ván đấu thì thao tác cần là tắt nhanh.
///
/// Không có [GameAudioScope] phía trên thì nút tự ẩn, thay vì hiện ra một nút
/// bấm không có tác dụng.
class GameAudioButton extends StatelessWidget {
  const GameAudioButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = GameAudioScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();

    final settings = controller.settings;

    return PopupMenuButton<_AudioToggle>(
      tooltip: 'Âm thanh',
      icon: Icon(settings.silent ? Icons.volume_off : Icons.volume_up),
      onSelected: (choice) => switch (choice) {
        _AudioToggle.effects => controller.setEffectsEnabled(
            enabled: !settings.effectsEnabled,
          ),
        _AudioToggle.music => controller.setMusicEnabled(
            enabled: !settings.musicEnabled,
          ),
      },
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: _AudioToggle.effects,
          checked: settings.effectsEnabled,
          child: const Text('Hiệu ứng'),
        ),
        CheckedPopupMenuItem(
          value: _AudioToggle.music,
          checked: settings.musicEnabled,
          child: const Text('Nhạc nền'),
        ),
      ],
    );
  }
}
