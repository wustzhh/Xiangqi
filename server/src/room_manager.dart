/// 房间管理器 — 创建/加入/离开房间，管理游戏流程
library server.room_manager;

import 'dart:collection';
import 'protocol.dart';
import 'player_session.dart';
import 'room.dart';

/// 房间管理器
class RoomManager {
  static const int maxRooms = 10;
  static const int maxParticipantsPerRoom = 10;
  static const int maxPlayersPerRoom = 2;

  final Map<String, Room> _rooms = LinkedHashMap();
  int _nextRoomNumber = 1;

  /// 获取房间列表
  List<RoomSummary> get roomList =>
      _rooms.values.map((r) => r.summary).toList();

  /// 创建房间
  Room? createRoom(String name, PlayerSession host) {
    if (_rooms.length >= maxRooms) return null;

    final roomId = 'room_${_nextRoomNumber++}';
    final room = Room(id: roomId, name: name, hostId: host.id);

    // 房主自动成为红方玩家
    final participant = RoomParticipant(
      session: host,
      role: PlayerRole.player,
      side: 'red',
    );
    room.addParticipant(participant);
    _rooms[roomId] = room;

    // 通知房主创建成功
    host.sendMessage(ServerMsgType.roomCreated, {
      'roomId': roomId,
      'room': room.summary.toJson(),
    });

    // 通知所有在线的客户端更新房间列表
    _broadcastRoomList();
    return room;
  }

  /// 加入房间
  void joinRoom(String roomId, PlayerSession joiner, bool asSpectator) {
    final room = _rooms[roomId];
    if (room == null) {
      joiner.sendError('房间不存在');
      return;
    }

    if (room.status != RoomStatus.waiting) {
      joiner.sendError('对局已开始，无法加入');
      return;
    }

    if (room.participants.length >= maxParticipantsPerRoom) {
      joiner.sendError('房间已满');
      return;
    }

    // 分配角色
    PlayerRole role;
    String? side;

    if (asSpectator || room.isFull) {
      role = PlayerRole.spectator;
      side = null;
    } else {
      role = PlayerRole.player;
      // 红方已被房主占用，新玩家自动为黑方
      side = 'black';
    }

    final participant = RoomParticipant(
      session: joiner,
      role: role,
      side: side,
    );
    room.addParticipant(participant);

    // 通知加入者
    final playersJson = room.players.map((p) => PlayerInfo(
      id: p.id, name: p.name, side: p.side,
    ).toJson()).toList();
    final spectatorsJson = room.spectators.map((p) => PlayerInfo(
      id: p.id, name: p.name, side: p.side,
    ).toJson()).toList();

    joiner.sendMessage(ServerMsgType.roomJoined, {
      'roomId': roomId,
      'roomName': room.name,
      'players': playersJson,
      'spectators': spectatorsJson,
      'yourSide': side,
    });

    // 通知房间里其他人
    room.broadcastToOthers(joiner.id, buildServerMessage(
      ServerMsgType.playerJoined, {
        'player': PlayerInfo(id: joiner.id, name: joiner.name, side: side).toJson(),
      },
    ));

    // 如果凑齐了两个玩家，开始游戏
    if (room.players.length == maxPlayersPerRoom) {
      _startGame(room);
    }

    // 更新房间列表
    _broadcastRoomList();
  }

  /// 离开房间
  void leaveRoom(PlayerSession session) {
    final roomId = session.roomId;
    if (roomId == null) return;

    final room = _rooms[roomId];
    if (room == null) return;

    final wasPlayer = room.getParticipant(session.id)?.role == PlayerRole.player;

    room.removeParticipant(session.id);

    if (room.isEmpty) {
      // 房间没人了，删除
      _rooms.remove(roomId);
    } else {
      // 通知其他人
      room.broadcastToOthers(session.id, buildServerMessage(
        ServerMsgType.playerLeft, {
          'playerId': session.id,
          'playerName': session.name,
        },
      ));

      // 如果走了一个玩家，结束游戏
      if (wasPlayer && room.status == RoomStatus.playing) {
        _endGame(room, 'red', '对方离开');
      }

      // 如果房间空了或者玩家全走了
      if (room.players.isEmpty && room.status == RoomStatus.playing) {
        _endGame(room, 'black', '对方离开');
        _rooms.remove(roomId);
      }
    }

    _broadcastRoomList();
  }

  /// 处理走棋
  void handleMove(PlayerSession session, Map<String, dynamic> data) {
    final roomId = session.roomId;
    if (roomId == null) {
      session.sendError('不在房间中');
      return;
    }

    final room = _rooms[roomId];
    if (room == null) {
      session.sendError('房间不存在');
      return;
    }

    if (room.status != RoomStatus.playing) {
      session.sendError('对局未开始');
      return;
    }

    final from = data['from'] as Map<String, dynamic>?;
    final to = data['to'] as Map<String, dynamic>?;
    if (from == null || to == null) {
      session.sendError('走法数据无效');
      return;
    }

    // 广播走棋给房间所有人（含发送者自己，便于同步）
    room.broadcast(buildServerMessage(ServerMsgType.moveMade, {
      'from': from,
      'to': to,
      'playerId': session.id,
      'playerName': session.name,
    }));
  }

  /// 处理认输
  void handleResign(PlayerSession session) {
    final roomId = session.roomId;
    if (roomId == null) {
      session.sendError('不在房间中');
      return;
    }

    final room = _rooms[roomId];
    if (room == null || room.status != RoomStatus.playing) return;

    final participant = room.getParticipant(session.id);
    if (participant == null || participant.role != PlayerRole.player) return;

    // 认输方输，对方赢
    final winner = participant.side == 'red' ? 'black' : 'red';
    _endGame(room, winner, '认输');
  }

  /// 处理和棋请求
  void handleDrawOffer(PlayerSession session) {
    final roomId = session.roomId;
    if (roomId == null) return;

    final room = _rooms[roomId];
    if (room == null) return;

    room.broadcastToOthers(session.id, buildServerMessage(
      ServerMsgType.chat, {
        'playerName': session.name,
        'message': '请求和棋',
      },
    ));
  }

  /// 玩家断线处理
  void handleDisconnect(PlayerSession session) {
    leaveRoom(session);
  }

  /// 开始游戏
  void _startGame(Room room) {
    room.status = RoomStatus.playing;

    final players = room.players;
    for (final p in players) {
      p.session.sendMessage(ServerMsgType.gameStart, {
        'yourSide': p.side,
        'opponent': players.firstWhere((o) => o.id != p.id).name,
        'roomId': room.id,
      });
    }

    // 通知观众
    for (final s in room.spectators) {
      s.session.sendMessage(ServerMsgType.gameStart, {
        'yourSide': null,
        'opponent': null,
        'roomId': room.id,
      });
    }
  }

  /// 结束游戏
  void _endGame(Room room, String winner, String reason) {
    room.status = RoomStatus.finished;

    room.broadcastMessage(ServerMsgType.gameOver, {
      'winner': winner,
      'reason': reason,
    });

    _broadcastRoomList();
  }

  /// 广播房间列表给所有在线的客户端
  void _broadcastRoomList() {
    // 这个由 main.dart 来管理，因为这里没有所有连接的列表
    // 提供一个回调让 main.dart 来刷新
    onRoomListChanged?.call();
  }

  /// 房间列表变化时的回调
  void Function()? onRoomListChanged;
}
