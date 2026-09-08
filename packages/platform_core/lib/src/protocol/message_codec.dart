import 'dart:convert';

import 'messages.dart';

/// Chuyen [Message] qua lai voi chuoi JSON tren day.
///
/// Khung ban tin:
/// ```json
/// { "v": 1, "type": "GAME_ACTION", "payload": { } }
/// ```
///
/// Codec viet tay co chu dich: protocol la thu phai kiem soat bang tay khi
/// nang phien ban. Doi lai, moi thay doi o day phai co golden test di kem.
class MessageCodec {
  const MessageCodec._();

  static String encode(Message message) => jsonEncode(<String, dynamic>{
        'v': kProtocolVersion,
        'type': message.type,
        'payload': message.toPayload(),
      });

  /// Khong bao gio nem loi vi ban tin la: tra ve [UnknownMessage] de mot ban
  /// cu van song sot khi gap ban tin cua ban moi hon.
  ///
  /// Van nem [FormatException] neu chuoi khong phai JSON hop le - do la loi
  /// tang duoi, khong phai chuyen tuong thich protocol.
  static Message decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw FormatException('Ban tin khong phai JSON object', raw);
    }
    final envelope = decoded.cast<String, dynamic>();
    final version = envelope['v'] as int?;
    final type = envelope['type'] as String? ?? '';
    final payload = (envelope['payload'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    if (version != kProtocolVersion) {
      return UnknownMessage(
        rawType: type,
        payload: payload,
        protocolVersion: version,
      );
    }

    return switch (type) {
      'JOIN_REQUEST' => JoinRequest.fromPayload(payload),
      'PLAYER_READY' => PlayerReady.fromPayload(payload),
      'START_GAME' => StartGame.fromPayload(payload),
      'GAME_ACTION' => GameActionMessage.fromPayload(payload),
      'LEAVE_ROOM' => LeaveRoom.fromPayload(payload),
      'PING' => Ping.fromPayload(payload),
      'ROOM_JOINED' => RoomJoined.fromPayload(payload),
      'JOIN_REJECTED' => JoinRejected.fromPayload(payload),
      'ROOM_UPDATE' => RoomUpdate.fromPayload(payload),
      'GAME_START' => GameStart.fromPayload(payload),
      'GAME_STATE' => GameStateMessage.fromPayload(payload),
      'GAME_RESULT' => GameResultMessage.fromPayload(payload),
      'ROOM_CLOSED' => RoomClosed.fromPayload(payload),
      'ERROR' => ErrorMessage.fromPayload(payload),
      'PONG' => Pong.fromPayload(payload),
      _ => UnknownMessage(
          rawType: type,
          payload: payload,
          protocolVersion: version,
        ),
    };
  }
}
