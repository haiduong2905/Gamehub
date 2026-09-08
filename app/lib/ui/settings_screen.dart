import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/identity.dart';
import '../transport/lan/network_interfaces.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _nickname;

  @override
  void initState() {
    super.initState();
    _nickname = TextEditingController(
      text: ref.read(identityProvider).valueOrNull?.nickname ?? '',
    );
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
    final theme = Theme.of(context);
    final identity = ref.watch(identityProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            'Tên hiển thị',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nickname,
            textInputAction: TextInputAction.done,
            maxLength: 20,
            decoration: const InputDecoration(hintText: 'Tên của bạn'),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _save, child: const Text('Lưu')),
          const SizedBox(height: 32),
          Text(
            'Chẩn đoán mạng',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Dùng khi máy khác không thấy phòng của bạn.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          const _NetworkDiagnostics(),
          const SizedBox(height: 32),
          if (identity != null)
            Text(
              'Mã thiết bị: ${identity.playerId}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// Hiện các địa chỉ mạng mà app sẽ dùng để quảng bá phòng.
///
/// Khi "không ai thấy phòng của tôi", câu hỏi đầu tiên luôn là máy đang đứng
/// ở địa chỉ nào - và liệu nó có phải địa chỉ Wi-Fi hay không.
class _NetworkDiagnostics extends StatelessWidget {
  const _NetworkDiagnostics();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<List<LocalAddress>>(
      future: pickLocalAddresses(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          );
        }

        final addresses = snapshot.data!;
        if (addresses.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Không tìm thấy địa chỉ mạng nội bộ nào. '
              'Hãy bật Wi-Fi và nối vào cùng mạng với máy kia.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          );
        }

        return Column(
          children: [
            for (final address in addresses)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.lan_outlined),
                  title: Text(address.address),
                  subtitle: Text(address.interfaceName),
                  trailing: address == addresses.first
                      ? Chip(
                          label: const Text('Đang dùng'),
                          backgroundColor:
                              theme.colorScheme.primaryContainer,
                          side: BorderSide.none,
                        )
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}
