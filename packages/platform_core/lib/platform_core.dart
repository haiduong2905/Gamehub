/// Core cua Game Hub.
///
/// Pure Dart: khong import Flutter, khong import dart:io. Do la thu cuong che
/// nguyen tac "game va phong khong biet gi ve socket" o muc he thong package,
/// chu khong phai o muc ky luat ca nhan.
library;

export 'src/game/game_adapter.dart';
export 'src/game/game_definition.dart';
export 'src/game/game_registry.dart';
export 'src/game/game_view.dart';
export 'src/game/game_result.dart';
export 'src/protocol/ids.dart';
export 'src/protocol/message_codec.dart';
export 'src/protocol/messages.dart';
export 'src/room/room_client.dart';
export 'src/room/room_host.dart';
export 'src/room/room_models.dart';
export 'src/session/game_session.dart';
export 'src/transport/local_link.dart';
export 'src/transport/loopback_transport.dart';
export 'src/transport/transport.dart';
