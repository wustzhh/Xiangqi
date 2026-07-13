/// 大厅界面 — 房间列表 + 创建/加入房间
library screens.lobby_screen;

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/room_info.dart';
import '../services/network_service.dart';
import 'room_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final NetworkService _net = NetworkService();
  StreamSubscription? _subscription;

  final _hostController = TextEditingController(text: '212.129.243.158');
  final _portController = TextEditingController(text: '8080');

  @override
  void initState() {
    super.initState();
    _subscription = _net.messageController.stream.listen(_onMessage);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
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
    }
    setState(() {});
  }

  void _enterRoom(String roomId) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomScreen(roomId: roomId),
      ),
    );
  }

  Future<void> _connect() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8080;
    if (host.isEmpty) return;

    final ok = await _net.connect(host, port);
    if (ok) {
      _net.requestRoomList();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已连接服务器'), backgroundColor: Colors.green),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('连接失败'), backgroundColor: Colors.red),
        );
      }
    }
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
      body: Column(
        children: [
          if (!connected) _buildConnectPanel(),
          if (connected) _buildConnectionBar(),
          const Divider(height: 1),
          Expanded(child: _buildRoomList()),
        ],
      ),
      floatingActionButton: connected
          ? FloatingActionButton(
              onPressed: _showCreateDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildConnectPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: '服务器地址',
              hintText: 'IP 地址或域名',
              prefixIcon: Icon(Icons.computer),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _portController,
            decoration: const InputDecoration(
              labelText: '端口',
              hintText: '8080',
              prefixIcon: Icon(Icons.numbers),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _connect,
              icon: const Icon(Icons.link),
              label: const Text('连接服务器'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.green.shade50,
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: const BoxDecoration(
              color: Colors.green, shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '已连接 · ${_net.playerName ?? ""}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () {
              _net.disconnect();
              setState(() {});
            },
            child: const Text('断开', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomList() {
    if (_net.state == NetConnectionState.connecting) {
      return const Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('连接中...'),
        ],
      ));
    }

    if (_net.state != NetConnectionState.connected) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('未连接', style: TextStyle(color: Colors.grey, fontSize: 16)),
            SizedBox(height: 4),
            Text('请先连接服务器', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

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
