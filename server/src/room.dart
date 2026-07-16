/// 房间模型 — 管理玩家/观众列表和游戏状态
library server.room;

import 'protocol.dart';
import 'player_session.dart';

RoomParticipant? _findHost(List<RoomParticipant> participants, String hostId) {
  try {
    return participants.firstWhere((p) => p.id == hostId);
  } catch (_) {
    return null;
  }
}

/// 房间中的玩家角色
enum PlayerRole { player, spectator }

/// 房间中的单个参与者
class RoomParticipant {
  final PlayerSession session;
  final PlayerRole role;
  String? side;   // 'red' | 'black' | null
  bool ready = false;

  RoomParticipant({
    required this.session,
    required this.role,
    this.side,
  });

  String get id => session.id;
  String get name => session.name;
}

/// 房间设置
class RoomSettings {
  String canUndo = 'mutual'; // 'none' | 'mutual' | 'force'
  int timePerMove = 0;   // 步时（秒），0=不限
  int totalTime = 0;     // 局时（分钟），0=不限
  String sideChoice = 'host_red'; // host_red | host_black | random

  Map<String, dynamic> toJson() => {
    'canUndo': canUndo,
    'timePerMove': timePerMove,
    'totalTime': totalTime,
    'sideChoice': sideChoice,
  };

  void apply(Map<String, dynamic> data) {
    if (data.containsKey('canUndo')) canUndo = data['canUndo'] as String;
    if (data.containsKey('timePerMove')) timePerMove = data['timePerMove'] as int;
    if (data.containsKey('totalTime')) totalTime = data['totalTime'] as int;
    if (data.containsKey('sideChoice')) sideChoice = data['sideChoice'] as String;
  }
}

/// 房间状态
enum RoomStatus { waiting, playing, finished }

/// 房间模型
class Room {
  final String id;
  final String name;
  String hostId;
  final List<RoomParticipant> participants = [];
  RoomStatus status = RoomStatus.waiting;
  RoomSettings settings = RoomSettings();
  /// 走棋历史（用于重连恢复棋盘）
  final List<Map<String, dynamic>> moveHistory = [];

  /// 是否双方都准备好了
  bool get bothReady =>
      players.length == 2 && players.every((p) => p.ready);

  Room({
    required this.id,
    required this.name,
    required this.hostId,
  });

  /// 广播给房间里所有人
  void broadcast(String message) {
    for (final p in participants) {
      p.session.send(message);
    }
  }

  /// 广播服务端消息类型
  void broadcastMessage(ServerMsgType type, Map<String, dynamic> data) {
    final msg = buildServerMessage(type, data);
    broadcast(msg);
  }

  /// 发送给特定参与者（不包含本人）
  void broadcastToOthers(String excludeId, String message) {
    for (final p in participants) {
      if (p.id != excludeId) p.session.send(message);
    }
  }

  /// 获取玩家列表（仅 players）
  List<RoomParticipant> get players =>
      participants.where((p) => p.role == PlayerRole.player).toList();

  /// 获取观众列表
  List<RoomParticipant> get spectators =>
      participants.where((p) => p.role == PlayerRole.spectator).toList();

  bool get isFull => players.length >= 2;
  bool get isEmpty => participants.isEmpty;

  /// 添加参与者
  void addParticipant(RoomParticipant p) {
    participants.add(p);
    p.session.roomId = id;
  }

  /// 移除参与者
  void removeParticipant(String sessionId) {
    final idx = participants.indexWhere((p) => p.id == sessionId);
    if (idx >= 0) {
      participants[idx].session.roomId = null;
      participants.removeAt(idx);
    }
  }

  /// 获取参与者
  RoomParticipant? getParticipant(String sessionId) {
    try {
      return participants.firstWhere((p) => p.id == sessionId);
    } catch (_) {
      return null;
    }
  }

  /// 获取房间摘要（用于房间列表）
  RoomSummary get summary => RoomSummary(
    id: id,
    name: name,
    playerCount: players.length,
    spectatorCount: spectators.length,
    hostName: _findHost(participants, hostId)?.name ??
        (participants.isNotEmpty ? participants.first.name : '已离开'),
    gameStarted: status != RoomStatus.waiting,
    playerDeviceIds: players.map((p) => p.session.deviceId).toList(),
  );
}
