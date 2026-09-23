import 'package:flutter/widgets.dart';

/// Cài đặt âm thanh, dùng chung cho mọi game.
///
/// Tách hiệu ứng và nhạc nền làm hai công tắc riêng vì hai thứ này bị tắt vì
/// hai lý do khác nhau: nhạc nền tắt khi người chơi đang nghe thứ khác, còn
/// hiệu ứng tắt khi họ cần yên tĩnh hoàn toàn.
@immutable
class AudioSettings {
  const AudioSettings({
    this.effectsEnabled = true,
    this.musicEnabled = true,
    this.volume = 1,
  });

  /// Tiếng của từng thao tác: đặt quân, ăn quân, chiếu hết.
  final bool effectsEnabled;

  /// Nhạc nền chạy suốt ván đấu.
  final bool musicEnabled;

  /// Hệ số 0..1 **nhân lên trên** âm lượng media của thiết bị.
  ///
  /// Không phải âm lượng tuyệt đối: `audioplayers` phát qua luồng media của
  /// hệ điều hành, nên nút âm lượng của máy vẫn là thứ quyết định cuối cùng.
  /// Để mặc định 1.0 nghĩa là "đúng bằng âm lượng media người dùng đang đặt";
  /// kéo xuống là muốn game nhỏ hơn phần còn lại của máy.
  final double volume;

  bool get silent => !effectsEnabled && !musicEnabled;

  /// Âm lượng nhạc nền: luôn nhỏ hơn hiệu ứng, nếu không tiếng đặt quân sẽ
  /// chìm trong nền.
  double get musicVolume => volume * 0.34;

  double get effectsVolume => volume;

  AudioSettings copyWith({
    bool? effectsEnabled,
    bool? musicEnabled,
    double? volume,
  }) =>
      AudioSettings(
        effectsEnabled: effectsEnabled ?? this.effectsEnabled,
        musicEnabled: musicEnabled ?? this.musicEnabled,
        volume: volume ?? this.volume,
      );

  Map<String, Object?> toJson() => {
        'effects': effectsEnabled,
        'music': musicEnabled,
        'volume': volume,
      };

  /// Đọc lại từ bộ nhớ. Thiếu khoá nào thì dùng mặc định của khoá đó, để bản
  /// cũ đã lưu vẫn đọc được sau khi thêm tuỳ chọn mới.
  factory AudioSettings.fromJson(Map<String, Object?> json) => AudioSettings(
        effectsEnabled: json['effects'] as bool? ?? true,
        musicEnabled: json['music'] as bool? ?? true,
        volume: (json['volume'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 1,
      );

  @override
  bool operator ==(Object other) =>
      other is AudioSettings &&
      other.effectsEnabled == effectsEnabled &&
      other.musicEnabled == musicEnabled &&
      other.volume == volume;

  @override
  int get hashCode => Object.hash(effectsEnabled, musicEnabled, volume);

  @override
  String toString() => 'AudioSettings(effects: $effectsEnabled, '
      'music: $musicEnabled, volume: $volume)';
}

/// Nguồn sự thật cho cài đặt âm thanh trong lúc chạy.
///
/// Package này **không** biết lưu xuống đâu — đó là việc của `app`. Ai muốn
/// lưu thì `addListener` rồi đọc [settings]. Nhờ vậy package game không phải
/// kéo theo `shared_preferences` hay Riverpod.
class GameAudioController extends ChangeNotifier {
  GameAudioController([AudioSettings settings = const AudioSettings()])
      : _settings = settings;

  AudioSettings _settings;

  AudioSettings get settings => _settings;

  set settings(AudioSettings value) {
    if (_settings == value) return;
    _settings = value;
    notifyListeners();
  }

  void setEffectsEnabled({required bool enabled}) =>
      settings = _settings.copyWith(effectsEnabled: enabled);

  void setMusicEnabled({required bool enabled}) =>
      settings = _settings.copyWith(musicEnabled: enabled);

  void setVolume(double value) =>
      settings = _settings.copyWith(volume: value.clamp(0, 1));

  /// Công tắc tổng cho nút trong game: đang có tiếng thì tắt cả hai, đang câm
  /// thì bật lại cả hai.
  void toggleAll() {
    final on = _settings.silent;
    settings = _settings.copyWith(effectsEnabled: on, musicEnabled: on);
  }
}

/// Đưa [GameAudioController] xuống cả cây widget.
///
/// Dùng [InheritedNotifier] nên widget nào đọc qua [of] sẽ tự vẽ lại khi cài
/// đặt đổi — nút loa trong game đổi biểu tượng ngay khi tắt tiếng ở màn Cài
/// đặt, không cần dây nối riêng.
class GameAudioScope extends InheritedNotifier<GameAudioController> {
  const GameAudioScope({
    required GameAudioController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  /// Trả về `null` khi không có scope nào phía trên.
  ///
  /// Cố ý cho phép thiếu: widget test dựng bàn cờ trần không có scope, và khi
  /// đó game phải chạy im lặng chứ không được ném lỗi.
  static GameAudioController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameAudioScope>()?.notifier;

  /// Như [maybeOf] nhưng **không** đăng ký phụ thuộc.
  ///
  /// Dùng cho nơi chỉ phát tiếng: nó đọc cài đặt tại đúng lúc phát nên không
  /// cần vẽ lại khi cài đặt đổi. Bàn cờ caro có 400 ô — vẽ lại cả bàn chỉ vì
  /// ai đó kéo thanh âm lượng là phí.
  static GameAudioController? readOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<GameAudioScope>()?.notifier;

  /// Cài đặt hiện hành, hoặc mặc định nếu không có scope.
  static AudioSettings settingsOf(BuildContext context) =>
      maybeOf(context)?.settings ?? const AudioSettings();
}
