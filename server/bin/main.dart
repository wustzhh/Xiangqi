/// 中国象棋 WebSocket 对战服务器
library;

import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../src/protocol.dart';
import '../src/player_session.dart';
import '../src/room_manager.dart';

final RoomManager roomManager = RoomManager();
final List<PlayerSession> _allSessions = [];

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
  print('断线重连等待时间: 30秒');
}

// ═══════════════════════════════════════════
//  连接管理
// ═══════════════════════════════════════════

void _handleConnection(WebSocketChannel channel) {
  bool idReceived = false;

  // 先建立临时监听，等收到 deviceId 后再正式注册
  channel.stream.listen(
    (data) {
      final raw = data is List<int> ? utf8.decode(data) : data.toString();
      if (!idReceived) {
        idReceived = true;
        _setupSession(channel, raw);
      } else {
        // 找到这个 channel 对应的 session 再处理消息
        final session = _allSessions.cast<PlayerSession?>().firstWhere(
          (s) => s?.channel == channel,
          orElse: () => null,
        );
        if (session != null) {
          _handleMessage(session, raw);
        }
      }
    },
    onDone: () {
      final session = _allSessions.cast<PlayerSession?>().firstWhere(
        (s) => s?.channel == channel,
        orElse: () => null,
      );
      if (session != null) _handleDisconnect(session);
    },
    onError: (_) {},
  );
}

void _setupSession(WebSocketChannel channel, String firstMessage) {
  final parsed = parseClientMessage(firstMessage);
  String playerId;
  String playerName;

  // 从 client 消息中提取 deviceId
  final deviceId = parsed.data['deviceId'] as String?;
  if (deviceId != null && deviceId.isNotEmpty) {
    playerId = deviceId.length > 16 ? deviceId.substring(0, 16) : deviceId;
    playerName = '游客_${playerId.substring(0, 8)}';
  } else {
    // 旧客户端兼容
    playerId = 'p${DateTime.now().millisecondsSinceEpoch}';
    playerName = '游客_${playerId.substring(0, 8)}';
  }

  final session = PlayerSession(
    channel: channel,
    id: playerId,
    name: playerName,
  );

  session.onMessage = (raw) => _handleMessage(session, raw);
  session.onDisconnect = () => _handleDisconnect(session);

  // 尝试重连
  final reconnected = roomManager.tryReconnect(session);

  _allSessions.add(session);

  if (reconnected) {
    print('玩家重连成功: $playerName ($playerId)');
  } else {
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

  // 如果第一条消息不是 device_id，当作正常消息处理
  if (parsed.type != ClientMsgType.unknown) {
    _handleMessage(session, firstMessage);
  }
}

void _handleDisconnect(PlayerSession session) {
  _allSessions.remove(session);
  roomManager.handleDisconnect(session);
  print('玩家断开: ${session.name} — 将等待30秒重连');
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
    case ClientMsgType.unknown:
      // device_id 等无需处理
      break;
    default:
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
