import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_audio/game_audio.dart';

import '../state/identity.dart';
import '../transport/lan/network_interfaces.dart';
import 'app_ui.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _maxNickname = 20;

  late final TextEditingController _nickname;

  @override
  void initState() {
    super.initState();
    _nickname = TextEditingController(
      text: ref.read(identityProvider).valueOrNull?.nickname ?? '',
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(identityProvider.notifier).setNickname(_nickname.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu tên hiển thị')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(identityProvider).valueOrNull;

    return AppInkPage(
      header: const AppInkHeader(height: 84, child: _Title()),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
        children: [
          const _Label('Tên hiển thị'),
          const SizedBox(height: 10),
          TextField(
            controller: _nickname,
            textInputAction: TextInputAction.done,
            maxLength: _maxNickname,
            style: const TextStyle(fontSize: 16, color: AppInk.ink),
            decoration: _inputDecoration(),
            onSubmitted: (_) => _save(),
          ),
          // Bộ đếm tự vẽ chứ không dùng `counterText` mặc định: nó nằm sát
          // dưới ô nhập và kéo theo cả một khoảng đệm cố định, làm nút Lưu bị
          // đẩy xuống.
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_nickname.text.characters.length}/$_maxNickname',
                style: const TextStyle(fontSize: 12, color: AppInk.muted),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _WoodButton(label: 'Lưu', onPressed: _save),
          const SizedBox(height: 26),
          const _SectionRule('Âm thanh'),
          const SizedBox(height: 6),
          const _AudioSettings(),
          const SizedBox(height: 26),
          const _SectionRule('Chẩn đoán mạng'),
          const SizedBox(height: 4),
          const Text(
            'Dùng khi máy khác không thấy phòng của bạn.',
            style: TextStyle(fontSize: 13, color: AppInk.muted),
          ),
          const SizedBox(height: 12),
          const _NetworkDiagnostics(),
          const SizedBox(height: 26),
          if (identity != null) _DeviceId(playerId: identity.playerId),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration() => InputDecoration(
      filled: true,
      fillColor: AppInk.card,
      isDense: true,
      counterText: '',
      hintText: 'Tên của bạn',
      hintStyle: const TextStyle(color: AppInk.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: _fieldBorder(AppInk.cardBorder),
      enabledBorder: _fieldBorder(AppInk.cardBorder),
      focusedBorder: _fieldBorder(AppInk.woodLight),
    );

OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: 1.2),
    );

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            'Cài đặt',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppInk.ink,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Quay lại',
              color: AppInk.ink,
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppInk.ink,
        ),
      );
}

/// Tên mục kèm một đường kẻ chạy hết phần còn lại của hàng.
class _SectionRule extends StatelessWidget {
  const _SectionRule(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _Label(text),
          const SizedBox(width: 12),
          const Expanded(child: Divider(color: AppInk.cardBorder, height: 1)),
        ],
      );
}

/// Nút chính của màn: nền gỗ, chữ vàng nhạt.
class _WoodButton extends StatelessWidget {
  const _WoodButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppInk.wood,
          foregroundColor: const Color(0xFFF3E3C6),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppInk.woodLight, width: 1.5),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      );
}

/// Bật tắt và chỉnh âm lượng cho mọi game.
///
/// Đọc thẳng từ [GameAudioScope] chứ không qua Riverpod: cùng một nguồn với
/// nút loa trong ván đấu, nên tắt ở đâu cũng thấy ngay ở chỗ kia.
class _AudioSettings extends StatelessWidget {
  const _AudioSettings();

  @override
  Widget build(BuildContext context) {
    final controller = GameAudioScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    final settings = controller.settings;

    return Column(
      children: [
        _ToggleRow(
          icon: Icons.volume_up_rounded,
          title: 'Hiệu ứng trong game',
          subtitle: 'Tiếng đặt quân, ăn quân, kết thúc ván.',
          value: settings.effectsEnabled,
          onChanged: (value) => controller.setEffectsEnabled(enabled: value),
        ),
        _ToggleRow(
          icon: Icons.music_note_rounded,
          title: 'Nhạc nền',
          subtitle: 'Chạy trong suốt ván đấu.',
          value: settings.musicEnabled,
          onChanged: (value) => controller.setMusicEnabled(enabled: value),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.volume_down_rounded, color: AppInk.woodLight),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppInk.woodLight,
                  inactiveTrackColor: AppInk.cardBorder,
                  thumbColor: AppInk.woodLight,
                  overlayColor: AppInk.woodLight.withValues(alpha: 0.12),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: settings.volume,
                  max: 1,
                  divisions: 20,
                  label: '${(settings.volume * 100).round()}%',
                  onChanged: settings.silent ? null : controller.setVolume,
                ),
              ),
            ),
            SizedBox(
              width: 46,
              child: Text(
                '${(settings.volume * 100).round()}%',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppInk.ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Tính trên âm lượng media của thiết bị: để 100% là đúng bằng mức '
          'bạn đang đặt trên máy, kéo xuống khi muốn game nhỏ hơn.',
          style: TextStyle(fontSize: 12.5, height: 1.4, color: AppInk.muted),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppInk.card,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 19, color: AppInk.woodLight),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: AppInk.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12.5, color: AppInk.muted),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: AppInk.woodLight,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: AppInk.cardBorder,
              trackOutlineColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
            ),
          ],
        ),
      );
}

/// Hiện các địa chỉ mạng mà app sẽ dùng để quảng bá phòng.
///
/// Khi "không ai thấy phòng của tôi", câu hỏi đầu tiên luôn là máy đang đứng
/// ở địa chỉ nào — và liệu nó có phải địa chỉ Wi-Fi hay không.
class _NetworkDiagnostics extends StatelessWidget {
  const _NetworkDiagnostics();

  @override
  Widget build(BuildContext context) => FutureBuilder<List<LocalAddress>>(
        future: pickLocalAddresses(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(
                color: AppInk.woodLight,
                backgroundColor: AppInk.cardBorder,
              ),
            );
          }

          final addresses = snapshot.data!;
          if (addresses.isEmpty) {
            return const AppInkCard(
              padding: EdgeInsets.all(16),
              child: Text(
                'Không tìm thấy địa chỉ mạng nội bộ nào. '
                'Hãy bật Wi-Fi và nối vào cùng mạng với máy kia.',
                style:
                    TextStyle(fontSize: 13.5, height: 1.4, color: AppInk.seal),
              ),
            );
          }

          return Column(
            children: [
              for (final address in addresses)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppInkCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.lan_outlined,
                            size: 24, color: AppInk.woodLight),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                address.address,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppInk.ink,
                                  fontFeatures: [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                address.interfaceName,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppInk.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Địa chỉ đầu danh sách là địa chỉ app thật sự quảng
                        // bá; những cái sau chỉ để đối chiếu khi gỡ rối.
                        if (address == addresses.first) const _InUseChip(),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

class _InUseChip extends StatelessWidget {
  const _InUseChip();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFDDEBD6),
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Text(
          'Đang dùng',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF3F6B3A),
          ),
        ),
      );
}

/// Mã máy này, sao chép được.
///
/// Đây là thứ host dùng để nhận ra ai quay lại sau khi mất kết nối, nên khi
/// cần gỡ rối "sao tôi vào lại thành người khác" thì phải đọc được nó ra.
class _DeviceId extends StatelessWidget {
  const _DeviceId({required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.smartphone_rounded, size: 18, color: AppInk.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mã thiết bị: $playerId',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: AppInk.muted),
            ),
          ),
          IconButton(
            tooltip: 'Sao chép mã thiết bị',
            iconSize: 18,
            color: AppInk.muted,
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: playerId));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã sao chép mã thiết bị')),
              );
            },
          ),
        ],
      );
}
