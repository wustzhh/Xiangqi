/// WebSocket 玩家连接会话管理
library server.player_session;

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'protocol.dart';

/// 玩家连接会话
class PlayerSession {
  final WebSocketChannel channel;
  final String id;          // 唯一 ID
  final String name;        // 显示名称（游客_xxxx）
  StreamSubscription? _subscription;
  String? roomId;           // 当前所在的房间 ID

  /// 收到消息时的回调
  void Function(String raw)? onMessage;
  /// 连接关闭时的回调
  void Function()? onDisconnect;

  PlayerSession({
    required this.channel,
    required this.id,
    required this.name,
  }) {
    _subscription = channel.stream.listen(
      (data) {
        final raw = data is List<int> ? utf8.decode(data) : data.toString();
        onMessage?.call(raw);
      },
      onDone: () => onDisconnect?.call(),
      onError: (_) => onDisconnect?.call(),
      cancelOnError: false,
    );
  }

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
    _subscription?.cancel();
    try {
      channel.sink.close();
    } catch (_) {}
  }
}
