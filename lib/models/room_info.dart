/// 房间信息数据模型
library models.room_info;

/// 房间摘要（来自房间列表）
class RoomInfo {
  final String id;
  final String name;
  final int playerCount;
  final int spectatorCount;
  final String hostName;
  final bool gameStarted;
  final List<String> playerDeviceIds;

  const RoomInfo({
    required this.id,
    required this.name,
    required this.playerCount,
    required this.spectatorCount,
    required this.hostName,
    required this.gameStarted,
    this.playerDeviceIds = const [],
  });

  factory RoomInfo.fromJson(Map<String, dynamic> json) => RoomInfo(
    id: json['id'] as String,
    name: json['name'] as String,
    playerCount: json['playerCount'] as int? ?? 0,
    spectatorCount: json['spectatorCount'] as int? ?? 0,
    hostName: json['hostName'] as String? ?? '',
    gameStarted: json['gameStarted'] as bool? ?? false,
    playerDeviceIds: (json['playerDeviceIds'] as List<dynamic>?)
        ?.map((e) => e as String).toList() ?? [],
  );
}

/// 玩家信息
class PlayerInfo {
  final String id;
  final String name;
  final String? side; // 'red' | 'black' | null

  const PlayerInfo({
    required this.id,
    required this.name,
    this.side,
  });

  factory PlayerInfo.fromJson(Map<String, dynamic> json) => PlayerInfo(
    id: json['id'] as String,
    name: json['name'] as String,
    side: json['side'] as String?,
  );
}
