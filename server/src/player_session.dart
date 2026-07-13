/// WebSocket 玩家连接会话管理
library server.player_session;

import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'protocol.dart';

/// 玩家连接会话
class PlayerSession {
  final WebSocketChannel channel;
  final String id;          // 唯一 ID
  final String deviceId;    // 设备 ID（用于重连识别）
  String name;              // 显示名称（可修改）
  String? roomId;           // 当前所在的房间 ID

  PlayerSession({
    required this.channel,
    required this.id,
    required this.deviceId,
    required this.name,
  });

  /// 发送 JSON 消息
  void send(String message) {
    try {
      channel.sink.add(message);
    } catch (_) {
      // 连接已关闭
    }
  }

  /// 发送服务端消息
  void sendMessage(ServerMsgType type, Map<String, dynamic> data) {
    send(buildServerMessage(type, data));
  }

  /// 发送错误消息
  void sendError(String message) {
    sendMessage(ServerMsgType.error, {'message': message});
  }

  /// 断开连接
  void disconnect() {
    try {
      channel.sink.close();
    } catch (_) {}
  }
}
