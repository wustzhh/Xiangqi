/// 房间管理器 — 创建/加入/离开房间，管理游戏流程
library server.room_manager;

import 'dart:collection';
import 'dart:async';
import 'protocol.dart';
import 'player_session.dart';
import 'room.dart';

/// 房间管理器
class RoomManager {
  static const int maxRooms = 10;
  static const int maxParticipantsPerRoom = 10;
  static const int maxPlayersPerRoom = 2;
  static const int reconnectTimeout = 30; // 重连超时秒数

  final Map<String, Room> _rooms = LinkedHashMap();
  final Map<String, _DisconnectedPlayer> _disconnected = {};
  int _nextRoomNumber = 1;

  /// 获取房间列表
  List<RoomSummary> get roomList =>
      _rooms.values.map((r) => r.summary).toList();

  /// 通过 ID 查找房间
  Room? findRoom(String roomId) => _rooms[roomId];

  /// 创建房间
  Room? createRoom(String name, PlayerSession host) {
    if (_rooms.length >= maxRooms) return null;

    final roomId = 'room_${_nextRoomNumber++}';
    final room = Room(id: roomId, name: name, hostId: host.id);

    final participant = RoomParticipant(
      session: host,
      role: PlayerRole.player,
      side: 'red',
    );
    room.addParticipant(participant);
    _rooms[roomId] = room;

    host.sendMessage(ServerMsgType.roomCreated, {
      'roomId': roomId,
      'room': room.summary.toJson(),
      'settings': room.settings.toJson(),
    });

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

    // 对局中只允许观战
    if (room.status == RoomStatus.playing && !asSpectator) {
      joiner.sendError('对局已开始，只能观战');
      return;
    }

    if (room.participants.length >= maxParticipantsPerRoom) {
      joiner.sendError('房间已满');
      return;
    }

    // 分配角色
    PlayerRole role;
    String? side;

    if (asSpectator || room.isFull || room.status != RoomStatus.waiting) {
      role = PlayerRole.spectator;
      side = null;
    } else {
      role = PlayerRole.player;
      side = 'black';
    }

    final participant = RoomParticipant(
      session: joiner,
      role: role,
      side: side,
    );
    room.addParticipant(participant);

    // 通知加入者（含设置）
    final playersJson = room.players.map((p) => PlayerInfo(
      id: p.id, name: p.name, side: p.side,
    ).toJson()).toList();
    final spectatorsJson = room.spectators.map((p) => PlayerInfo(
      id: p.id, name: p.name, side: p.side,
    ).toJson()).toList();

    print('[joinRoom] ${joiner.name} 加入 ${room.name}, 角色=${role.name} side=$side, 玩家数=${room.players.length}/$maxPlayersPerRoom');
    joiner.sendMessage(ServerMsgType.roomJoined, {
      'roomId': roomId,
      'roomName': room.name,
      'players': playersJson,
      'spectators': spectatorsJson,
      'yourSide': side,
      'settings': room.settings.toJson(),
    });

    // 通知房间里其他人
    room.broadcastToOthers(joiner.id, buildServerMessage(
      ServerMsgType.playerJoined, {
        'player': PlayerInfo(id: joiner.id, name: joiner.name, side: side).toJson(),
      },
    ));

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
      _rooms.remove(roomId);
    } else {
      room.broadcastToOthers(session.id, buildServerMessage(
        ServerMsgType.playerLeft, {
          'playerId': session.id,
          'playerName': session.name,
        },
      ));

      if (wasPlayer && room.status == RoomStatus.playing) {
        _endGame(room, 'red', '对方离开');
      }

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

    room.broadcast(buildServerMessage(ServerMsgType.moveMade, {
      'from': from,
      'to': to,
      'playerId': session.id,
      'playerName': session.name,
    }));

    // 保存走棋历史
    room.moveHistory.add({
      'from': from,
      'to': to,
      'playerId': session.id,
      'side': room.getParticipant(session.id)?.side,
    });
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

    final winner = participant.side == 'red' ? 'black' : 'red';
    _endGame(room, winner, '认输');
  }

  /// 处理设置更新
  void handleUpdateSettings(PlayerSession session, Map<String, dynamic> data) {
    final room = _rooms[session.roomId];
    if (room == null || session.id != room.hostId) {
      session.sendError('只有房主可以修改设置');
      return;
    }
    if (room.status != RoomStatus.waiting) {
      session.sendError('游戏已开始，无法修改设置');
      return;
    }
    room.settings.apply(data);
    room.broadcastMessage(ServerMsgType.settingsUpdated, {
      'settings': room.settings.toJson(),
    });
  }

  /// 处理准备/取消准备
  void handleReadyToggle(PlayerSession session) {
    final room = _rooms[session.roomId];
    if (room == null) return;
    final participant = room.getParticipant(session.id);
    if (participant == null || participant.role != PlayerRole.player) return;
    if (room.status != RoomStatus.waiting) return;

    participant.ready = !participant.ready;
    room.broadcastMessage(ServerMsgType.readyChanged, {
      'playerId': session.id,
      'ready': participant.ready,
      'bothReady': room.bothReady,
    });
    print('[准备] ${session.name}: ready=${participant.ready}, bothReady=${room.bothReady}');
  }

  /// 处理开始游戏（房主点击）
  void handleStartGame(PlayerSession session) {
    final room = _rooms[session.roomId];
    if (room == null || session.id != room.hostId) {
      session.sendError('只有房主可以开始游戏');
      return;
    }
    if (room.status != RoomStatus.waiting) {
      session.sendError('游戏已开始');
      return;
    }
    if (room.players.length < 2) {
      session.sendError('玩家不足');
      return;
    }
    if (!room.bothReady) {
      session.sendError('双方都准备好后才能开始');
      return;
    }

    // 根据 sideChoice 分配先后手
    final players = room.players;
    if (room.settings.sideChoice == 'random') {
      // 随机分配
      final redPlayer = players[0];
      final blackPlayer = players[1];
      if (DateTime.now().millisecondsSinceEpoch.isEven) {
        redPlayer.side = 'red';
        blackPlayer.side = 'black';
      } else {
        redPlayer.side = 'black';
        blackPlayer.side = 'red';
      }
    } // host_red/host_black uses the sides already assigned in joinRoom

    _startGame(room);
  }

  // ═══════════════════════════════════════════
  //  断线重连
  // ═══════════════════════════════════════════

  /// 玩家断开连接（移到等待重连池）
  void handleDisconnect(PlayerSession session) {
    final roomId = session.roomId;
    if (roomId == null) return;

    final room = _rooms[roomId];
    if (room == null) return;

    final wasPlayer = room.getParticipant(session.id)?.role == PlayerRole.player;
    if (!wasPlayer) {
      // 观众断线直接移除
      leaveRoom(session);
      return;
    }

    // 通知其他人玩家暂时断开
    room.broadcast(buildServerMessage(ServerMsgType.playerLeft, {
      'playerId': session.id,
      'playerName': session.name,
      'disconnected': true,
    }));

    // 启动 30s 重连计时器
    final side = room.getParticipant(session.id)?.side ?? 'red';
    final timer = Timer(Duration(seconds: reconnectTimeout), () {
      // 超时未重连，结束游戏
      if (_disconnected.containsKey(session.id)) {
        _disconnected.remove(session.id);
        room.removeParticipant(session.id);
        _endGame(room, side == 'red' ? 'black' : 'red', '对方超时未重连');
        _broadcastRoomList();
      }
    });

    _disconnected[session.id] = _DisconnectedPlayer(
      session: session,
      roomId: roomId,
      timer: timer,
    );
  }

  /// 重连（用 deviceId 恢复）
  bool tryReconnect(PlayerSession newSession) {
    // 查找断线玩家中 deviceId 匹配的
    String? matchedId;
    for (final entry in _disconnected.entries) {
      if (entry.value.session.deviceId == newSession.deviceId &&
          entry.value.session.id != newSession.id) {
        matchedId = entry.key;
        break;
      }
    }
    if (matchedId == null) return false;

    final old = _disconnected.remove(matchedId)!;

    old.timer.cancel(); // 取消超时计时器

    final room = _rooms[old.roomId];
    if (room == null) return false;

    // 找到旧的参与者并替换 session
    final participant = room.getParticipant(newSession.id);
    if (participant == null) return false;

    // 更新 session 引用
    participant.session.disconnect(); // 关闭旧连接
    // 替换为新 session
    final idx = room.participants.indexOf(participant);
    room.participants[idx] = RoomParticipant(
      session: newSession,
      role: participant.role,
      side: participant.side,
    );
    newSession.roomId = room.id;

    // 通知房间所有人重连成功
    room.broadcast(buildServerMessage(ServerMsgType.playerJoined, {
      'player': PlayerInfo(id: newSession.id, name: newSession.name, side: participant.side).toJson(),
      'reconnected': true,
    }));

    // 恢复游戏所需的完整状态给重连者
    final playersJson = room.players.map((p) => PlayerInfo(
      id: p.id, name: p.name, side: p.side,
    ).toJson()).toList();
    final spectatorsJson = room.spectators.map((p) => PlayerInfo(
      id: p.id, name: p.name, side: p.side,
    ).toJson()).toList();

    newSession.sendMessage(ServerMsgType.roomJoined, {
      'roomId': room.id,
      'roomName': room.name,
      'players': playersJson,
      'spectators': spectatorsJson,
      'yourSide': participant.side,
      'gameStarted': true,
      'reconnected': true,
      'moveHistory': room.moveHistory,
    });

    return true;
  }

  // ═══════════════════════════════════════════

  void _startGame(Room room) {
    room.status = RoomStatus.playing;

    final players = room.players;
    print('开始游戏: 房间 ${room.id}, 玩家数 ${players.length}');
    for (final p in players) {
      try {
        final opponent = players.firstWhere((o) => o.id != p.id);
        p.session.sendMessage(ServerMsgType.gameStart, {
          'yourSide': p.side,
          'opponent': opponent.name,
          'roomId': room.id,
        });
        print('  已发送 game_start 给 ${p.name} (${p.id}) 对手=${opponent.name} side=${p.side}');
      } catch (e) {
        print('  ERROR: 发送 game_start 给 ${p.name} (${p.id}) 失败: $e');
      }
    }

    for (final s in room.spectators) {
      try {
        s.session.sendMessage(ServerMsgType.gameStart, {
          'yourSide': null,
          'opponent': null,
          'roomId': room.id,
        });
      } catch (_) {}
    }
  }

  void _endGame(Room room, String winner, String reason) {
    room.status = RoomStatus.finished;

    room.broadcastMessage(ServerMsgType.gameOver, {
      'winner': winner,
      'reason': reason,
    });

    _broadcastRoomList();
  }

  void _broadcastRoomList() {
    onRoomListChanged?.call();
  }

  void Function()? onRoomListChanged;
}

/// 断线等待重连的玩家
class _DisconnectedPlayer {
  final PlayerSession session;
  final String roomId;
  final Timer timer;

  _DisconnectedPlayer({
    required this.session,
    required this.roomId,
    required this.timer,
  });
}
