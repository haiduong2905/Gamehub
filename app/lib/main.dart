import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_audio/game_audio.dart';

import 'state/audio.dart';
import 'theme.dart';
import 'ui/loading_screen.dart';

void main() {
  runApp(const ProviderScope(child: GameHubApp()));
}

class GameHubApp extends ConsumerWidget {
  const GameHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Scope đặt **ngoài** MaterialApp để mọi màn hình, kể cả màn được push lên
    // route mới, đều đọc được cài đặt âm thanh.
    return GameAudioScope(
      controller: ref.watch(audioControllerProvider),
      child: MaterialApp(
        title: 'Game Hub',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const LoadingScreen(),
      ),
    );
  }
}
