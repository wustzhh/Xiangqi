/// 大厅界面 — 房间列表 + 创建/加入房间（自动连接）
library screens.lobby_screen;

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/room_info.dart';
import '../services/network_service.dart';
import '../utils/constants.dart';
import 'room_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final NetworkService _net = NetworkService();
  StreamSubscription? _subscription;
  bool _connecting = true;

  @override
  void initState() {
    super.initState();
    _subscription = _net.messageController.stream.listen(_onMessage);
    _autoConnect();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _autoConnect() async {
    await _net.connect(ServerConfig.host, ServerConfig.port);
    if (mounted) {
      setState(() => _connecting = false);
      if (_net.state == NetConnectionState.connected) {
        _net.requestRoomList();
      }
    }
  }

  void _onMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == 'room_created') {
      _enterRoom(data['roomId'] as String);
    } else if (type == 'room_joined') {
      _enterRoom(data['roomId'] as String);
    } else if (type == 'error') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] as String? ?? '错误')),
        );
      }
    } else if (type == 'profile_updated') {
      // 档案更新
    }
    if (mounted) setState(() {});
  }

  void _enterRoom(String roomId) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomScreen(roomId: roomId),
      ),
    ).then((_) {
      // 返回大厅后刷新房间列表
      _net.requestRoomList();
    });
  }

  void _showCreateDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建房间'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '房间名称',
            hintText: '我的房间',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () {
            Navigator.pop(ctx);
            final name = nameController.text.trim();
            _net.createRoom(name.isNotEmpty ? name : '${_net.playerName ?? "我"}的房间');
          }, child: const Text('创建')),
        ],
      ),
    );
  }

  void _showJoinDialog(RoomInfo room) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('加入 ${room.name}'),
        content: Text('房主: ${room.hostName}\n玩家: ${room.playerCount}/2\n观众: ${room.spectatorCount}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          if (!room.gameStarted)
            FilledButton(onPressed: () {
              Navigator.pop(ctx);
              _net.joinRoom(room.id);
            }, child: const Text('加入对局')),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: () {
            Navigator.pop(ctx);
            _net.joinRoom(room.id, asSpectator: true);
          }, child: const Text('观战')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = _net.state == NetConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('网络对战'),
        actions: [
          if (connected)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _net.requestRoomList(),
            ),
        ],
      ),
      body: _connecting
          ? const Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('连接服务器...'),
              ],
            ))
          : !connected
              ? _buildDisconnected()
              : _buildRoomList(),
      floatingActionButton: connected
          ? FloatingActionButton(
              onPressed: _showCreateDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildDisconnected() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('连接失败', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              setState(() => _connecting = true);
              _autoConnect();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('重新连接'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomList() {
    if (_net.rooms.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.meeting_room, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('暂无房间', style: TextStyle(color: Colors.grey, fontSize: 16)),
            SizedBox(height: 4),
            Text('点击右下角 + 创建房间', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _net.requestRoomList(),
      child: ListView.builder(
        itemCount: _net.rooms.length,
        itemBuilder: (_, i) {
          final room = _net.rooms[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: Icon(
                room.gameStarted ? Icons.videogame_asset : Icons.meeting_room,
                color: room.gameStarted ? Colors.orange : Colors.green,
              ),
              title: Text(room.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                '房主: ${room.hostName}  ·  ${room.playerCount}/2人  ·  观众: ${room.spectatorCount}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: room.gameStarted
                  ? const Chip(label: Text('对局中', style: TextStyle(fontSize: 11)))
                  : ElevatedButton(
                      onPressed: () => _showJoinDialog(room),
                      child: const Text('加入'),
                    ),
              onTap: () => _showJoinDialog(room),
            ),
          );
        },
      ),
    );
  }
}
