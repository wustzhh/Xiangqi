/// 中国象棋 WebSocket 对战服务器
///
/// 启动：dart run bin/main.dart
/// 监听端口：通过环境变量 PORT 或命令行参数指定，默认 8080
library;

import 'dart:io';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../src/protocol.dart';
import '../src/player_session.dart';
import '../src/room_manager.dart';

final RoomManager roomManager = RoomManager();
final List<PlayerSession> _allSessions = [];
int _nextPlayerId = 1;

void main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ??
              (args.isNotEmpty ? int.tryParse(args[0]) : null) ??
              8080;

  roomManager.onRoomListChanged = _broadcastRoomListToAll;

  final handler = webSocketHandler((WebSocketChannel channel) {
    _handleConnection(channel);
  });

  final server = await shelf_io.serve(handler, '0.0.0.0', port);
  print('中国象棋服务器已启动: ws://${server.address.host}:${server.port}');
  print('支持最多 $maxRooms 个房间，每房间最多 $maxParticipantsPerRoom 人');
}

// ═══════════════════════════════════════════
//  连接管理
// ═══════════════════════════════════════════

void _handleConnection(WebSocketChannel channel) {
  // 生成玩家 ID 和名称
  final playerId = 'p${_nextPlayerId++}';
  final playerName = '游客_${playerId}';

  final session = PlayerSession(
    channel: channel,
    id: playerId,
    name: playerName,
  );

  session.onMessage = (raw) => _handleMessage(session, raw);
  session.onDisconnect = () => _handleDisconnect(session);

  _allSessions.add(session);

  // 发送初始状态：你的 ID 和房间列表
  session.send(buildServerMessage(ServerMsgType.roomJoined, {
    'roomId': null,
    'roomName': null,
    'players': [],
    'spectators': [],
    'yourSide': null,
    'playerId': playerId,
    'playerName': playerName,
  }));
  _broadcastRoomListToAll();

  print('玩家连接: $playerName ($playerId) — 当前在线: ${_allSessions.length}');
}

void _handleDisconnect(PlayerSession session) {
  _allSessions.remove(session);
  roomManager.handleDisconnect(session);
  print('玩家断开: ${session.name} — 当前在线: ${_allSessions.length}');
}

// ═══════════════════════════════════════════
//  消息路由
// ═══════════════════════════════════════════

void _handleMessage(PlayerSession session, String raw) {
  final parsed = parseClientMessage(raw);

  switch (parsed.type) {
    case ClientMsgType.createRoom:
      _handleCreateRoom(session, parsed.data);
      break;
    case ClientMsgType.joinRoom:
      _handleJoinRoom(session, parsed.data);
      break;
    case ClientMsgType.leaveRoom:
      roomManager.leaveRoom(session);
      break;
    case ClientMsgType.listRooms:
      _sendRoomList(session);
      break;
    case ClientMsgType.makeMove:
      roomManager.handleMove(session, parsed.data);
      break;
    case ClientMsgType.resign:
      roomManager.handleResign(session);
      break;
    case ClientMsgType.drawOffer:
      roomManager.handleDrawOffer(session);
      break;
    case ClientMsgType.chat:
      _handleChat(session, parsed.data);
      break;
    case ClientMsgType.unknown:
      session.sendError('未知消息类型');
      break;
    default:
      session.sendError('未实现的消息类型');
      break;
  }
}

void _handleCreateRoom(PlayerSession session, Map<String, dynamic> data) {
  final roomName = data['roomName'] as String? ?? '${session.name}的房间';
  final room = roomManager.createRoom(roomName, session);
  if (room == null) {
    session.sendError('房间已满（最多$maxRooms个）');
  }
}

void _handleJoinRoom(PlayerSession session, Map<String, dynamic> data) {
  final roomId = data['roomId'] as String?;
  if (roomId == null) {
    session.sendError('缺少房间ID');
    return;
  }
  final asSpectator = data['asSpectator'] as bool? ?? false;
  roomManager.joinRoom(roomId, session, asSpectator);
}

void _handleChat(PlayerSession session, Map<String, dynamic> data) {
  // 目前只是广播给同房间的人
  final roomId = session.roomId;
  if (roomId == null) return;
  final message = data['message'] as String?;
  if (message == null || message.trim().isEmpty) return;
  // 由客户端直接处理
}

// ═══════════════════════════════════════════
//  广播
// ═══════════════════════════════════════════

void _broadcastRoomListToAll() {
  final msg = buildServerMessage(ServerMsgType.roomList, {
    'rooms': roomManager.roomList.map((r) => r.toJson()).toList(),
  });
  for (final s in _allSessions) {
    s.send(msg);
  }
}

void _sendRoomList(PlayerSession session) {
  session.send(buildServerMessage(ServerMsgType.roomList, {
    'rooms': roomManager.roomList.map((r) => r.toJson()).toList(),
  }));
}

const int maxRooms = 10;
const int maxParticipantsPerRoom = 10;
