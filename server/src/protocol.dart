/// 通信协议 — 消息类型定义和 JSON 编解码
library server.protocol;

import 'dart:convert';

// ═══════════════════════════════════════════
//  消息类型枚举
// ═══════════════════════════════════════════

/// 客户端→服务端 消息类型
enum ClientMsgType {
  createRoom('create_room'),
  joinRoom('join_room'),
  leaveRoom('leave_room'),
  listRooms('list_rooms'),
  makeMove('make_move'),
  chat('chat'),
  resign('resign'),
  drawOffer('draw_offer'),
  drawResponse('draw_response'),
  ready('ready'),
  unknown('');

  final String value;
  const ClientMsgType(this.value);

  static ClientMsgType fromString(String s) {
    return ClientMsgType.values.firstWhere(
      (e) => e.value == s,
      orElse: () => ClientMsgType.unknown,
    );
  }
}

/// 服务端→客户端 消息类型
enum ServerMsgType {
  roomList('room_list'),
  roomCreated('room_created'),
  roomJoined('room_joined'),
  playerJoined('player_joined'),
  playerLeft('player_left'),
  gameStart('game_start'),
  gameOver('game_over'),
  moveMade('move_made'),
  chat('chat'),
  error('error'),
  roomUpdated('room_updated'),
  unknown('');

  final String value;
  const ServerMsgType(this.value);

  String toJson() => value;
}

// ═══════════════════════════════════════════
//  数据结构
// ═══════════════════════════════════════════

class PositionData {
  final int col;
  final int row;
  PositionData(this.col, this.row);

  Map<String, dynamic> toJson() => {'col': col, 'row': row};
  factory PositionData.fromJson(Map<String, dynamic> json) =>
      PositionData(json['col'] as int, json['row'] as int);
}

class PlayerInfo {
  final String id;
  final String name;
  final String? side; // 'red' | 'black' | null (spectator)

  const PlayerInfo({
    required this.id,
    required this.name,
    this.side,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'side': side,
  };

  factory PlayerInfo.fromJson(Map<String, dynamic> json) => PlayerInfo(
    id: json['id'] as String,
    name: json['name'] as String,
    side: json['side'] as String?,
  );
}

class RoomSummary {
  final String id;
  final String name;
  final int playerCount;
  final int spectatorCount;
  final String hostName;
  final bool gameStarted;

  const RoomSummary({
    required this.id,
    required this.name,
    required this.playerCount,
    required this.spectatorCount,
    required this.hostName,
    required this.gameStarted,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'playerCount': playerCount,
    'spectatorCount': spectatorCount,
    'hostName': hostName,
    'gameStarted': gameStarted,
  };
}

// ═══════════════════════════════════════════
//  消息解析
// ═══════════════════════════════════════════

/// 解析客户端消息，返回 (type, data)
ParsedClientMessage parseClientMessage(String raw) {
  try {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final typeStr = json['type'] as String? ?? '';
    final type = ClientMsgType.fromString(typeStr);
    return ParsedClientMessage(type, json);
  } catch (_) {
    return ParsedClientMessage(ClientMsgType.unknown, {});
  }
}

class ParsedClientMessage {
  final ClientMsgType type;
  final Map<String, dynamic> data;
  const ParsedClientMessage(this.type, this.data);
}

/// 构建服务端消息
String buildServerMessage(ServerMsgType type, Map<String, dynamic> data) {
  data['type'] = type.toJson();
  return jsonEncode(data);
}
