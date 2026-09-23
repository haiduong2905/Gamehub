import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_audio/game_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAudioKey = 'audio_settings';

/// Bộ điều khiển âm thanh của cả app, đã nối với bộ nhớ máy.
///
/// [GameAudioController] nằm ở package dùng chung và **không biết lưu xuống
/// đâu** — đó là chủ ý, để package game không phải kéo theo
/// `shared_preferences`. Chỗ này là nơi ghép hai nửa lại: nghe controller đổi
/// rồi ghi xuống đĩa.
///
/// Giá trị mặc định là `volume: 1.0`, tức **đúng bằng âm lượng media của máy**
/// — `audioplayers` phát qua luồng media nên nút âm lượng của thiết bị vẫn là
/// thứ quyết định cuối cùng. Thanh trượt ở màn Cài đặt là hệ số nhân xuống,
/// dùng khi muốn game nhỏ hơn phần còn lại của máy.
final audioControllerProvider = Provider<GameAudioController>((ref) {
  final controller = GameAudioController();

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAudioKey, jsonEncode(controller.settings.toJson()));
  }

  controller.addListener(save);

  // Đọc lại cài đặt đã lưu. Chạy bất đồng bộ: app hiện ra ngay với mặc định,
  // rồi nhảy sang giá trị đã lưu - âm thanh không phải thứ đáng chặn màn hình.
  Future<void>(() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kAudioKey);
    if (stored == null) return;
    try {
      final json = jsonDecode(stored) as Map<String, Object?>;
      // removeListener trước khi gán để lần đọc này không ghi ngược lại đĩa.
      controller
        ..removeListener(save)
        ..settings = AudioSettings.fromJson(json)
        ..addListener(save);
    } on FormatException {
      // Dữ liệu hỏng thì bỏ qua, dùng mặc định.
    }
  });

  ref.onDispose(() {
    controller
      ..removeListener(save)
      ..dispose();
  });

  return controller;
});
