/// WebSocket 网络服务 — 连接服务器、消息收发
library services.network_service;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/room_info.dart';

/// 连接状态
enum NetConnectionState { disconnected, connecting, connected }

/// 网络服务单例
class NetworkService extends ChangeNotifier {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  WebSocketChannel? _channel;
  NetConnectionState _state = NetConnectionState.disconnected;
  StreamSubscription? _subscription;
  bool _reconnecting = false;
  /// 当前连接状态
  NetConnectionState get state => _state;

  /// 玩家 ID（服务端分配）
  String? playerId;

  /// 玩家名称
  String? playerName;

  /// 房间列表
  List<RoomInfo> rooms = [];

  /// 消息回调（外部订阅）
  final StreamController<Map<String, dynamic>> messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  void dispose() {
    disconnect();
    messageController.close();
    super.dispose();
  }

  /// 连接到服务器
  Future<bool> connect(String host, int port) async {
    if (_state == NetConnectionState.connecting) return false;
    if (_state == NetConnectionState.connected) {
      disconnect();
    }

    _state = NetConnectionState.connecting;
    notifyListeners();

    try {
      final uri = Uri.parse('ws://$host:$port');
      _channel = WebSocketChannel.connect(uri);

      // 等待连接建立
      await _channel!.ready;

      _state = NetConnectionState.connected;
      _reconnecting = false;
      notifyListeners();

      _setupListener();
      return true;
    } catch (e) {
      _state = NetConnectionState.disconnected;
      notifyListeners();
      debugPrint('连接失败: $e');
      return false;
    }
  }

  /// 断开连接
  void disconnect() {
    _subscription?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _state = NetConnectionState.disconnected;
    playerId = null;
    playerName = null;
    rooms = [];
    notifyListeners();
  }

  /// 设置消息监听
  void _setupListener() {
    _subscription?.cancel();
    _subscription = _channel!.stream.listen(
      (data) {
        final raw = data is List<int> ? utf8.decode(data) : data.toString();
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          _handleMessage(json);
        } catch (e) {
          debugPrint('消息解析失败: $e');
        }
      },
      onDone: () {
        _state = NetConnectionState.disconnected;
        notifyListeners();
        debugPrint('连接已关闭');
      },
      onError: (e) {
        _state = NetConnectionState.disconnected;
        notifyListeners();
        debugPrint('连接错误: $e');
      },
    );
  }

  /// 发送消息
  void send(Map<String, dynamic> data) {
    if (_state != NetConnectionState.connected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode(data));
    } catch (e) {
      debugPrint('发送失败: $e');
    }
  }

  /// 处理服务端消息
  void _handleMessage(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';

    switch (type) {
      case 'room_joined':
        // 初始连接时收到的
        if (data['playerId'] != null) {
          playerId = data['playerId'] as String;
        }
        if (data['playerName'] != null) {
          playerName = data['playerName'] as String;
        }
        break;

      case 'room_list':
        final roomList = data['rooms'] as List<dynamic>? ?? [];
        rooms = roomList.map((r) => RoomInfo.fromJson(r as Map<String, dynamic>)).toList();
        break;
    }

    // 转发给所有监听者
    messageController.add(data);
    notifyListeners();
  }

  // ─── 高级 API ─────────────────────────────

  /// 刷新房间列表
  void requestRoomList() {
    send({'type': 'list_rooms'});
  }

  /// 创建房间
  void createRoom(String roomName) {
    send({
      'type': 'create_room',
      'roomName': roomName,
    });
  }

  /// 加入房间
  void joinRoom(String roomId, {bool asSpectator = false}) {
    send({
      'type': 'join_room',
      'roomId': roomId,
      'asSpectator': asSpectator,
    });
  }

  /// 离开房间
  void leaveRoom() {
    send({'type': 'leave_room'});
  }

  /// 走棋
  void makeMove(int fromCol, int fromRow, int toCol, int toRow) {
    send({
      'type': 'make_move',
      'from': {'col': fromCol, 'row': fromRow},
      'to': {'col': toCol, 'row': toRow},
    });
  }

  /// 认输
  void resign() {
    send({'type': 'resign'});
  }
}
