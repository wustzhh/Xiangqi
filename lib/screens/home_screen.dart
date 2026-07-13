import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/network_service.dart';
import '../services/device_id.dart';
import 'ai_settings_screen.dart';
import 'game_screen.dart';
import 'lobby_screen.dart';
import 'records_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NetworkService _net = NetworkService();
  StreamSubscription? _subscription;
  String _displayName = '';
  String? _avatarBase64;

  @override
  void initState() {
    super.initState();
    _subscription = _net.messageController.stream.listen(_onMessage);
    _loadProfile();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final name = await getDisplayName();
    if (mounted) setState(() => _displayName = name);
  }

  void _onMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == 'profile_updated') {
      if (data['playerId'] == _net.playerId) {
        final name = data['name'] as String?;
        final avatar = data['avatar'] as String?;
        if (mounted) {
          setState(() {
            if (name != null) _displayName = name;
            _avatarBase64 = avatar;
          });
        }
      }
    }
  }

  void _showProfileDialog() {
    final nameCtrl = TextEditingController(text: _displayName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑档案'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头像预览
            CircleAvatar(
              radius: 36,
              backgroundColor: Colors.brown.shade100,
              backgroundImage: _avatarBase64 != null
                  ? MemoryImage(base64Decode(_avatarBase64!))
                  : null,
              child: _avatarBase64 == null
                  ? Text(_displayName.isNotEmpty
                      ? _displayName[0].toUpperCase()
                      : '?',
                      style: const TextStyle(fontSize: 28, color: Colors.brown))
                  : null,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                // 内置默认头像颜色
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('头像功能暂用颜色标识')),
                );
              },
              icon: const Icon(Icons.photo_camera, size: 16),
              label: const Text('更换头像', style: TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: '昵称',
                hintText: '输入你的昵称',
                border: OutlineInputBorder(),
              ),
              maxLength: 12,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () {
            final newName = nameCtrl.text.trim();
            if (newName.isEmpty) return;
            if (_net.state == NetConnectionState.connected) {
              _net.updateProfile(name: newName);
            } else {
              setState(() => _displayName = newName);
            }
            Navigator.pop(ctx);
          }, child: const Text('保存')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('中国象棋'),
        centerTitle: true,
        leading: GestureDetector(
          onTap: _showProfileDialog,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.brown.shade100,
                  backgroundImage: _avatarBase64 != null
                      ? MemoryImage(base64Decode(_avatarBase64!))
                      : null,
                  child: _avatarBase64 == null
                      ? Text(
                          _displayName.isNotEmpty
                              ? _displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              fontSize: 14,
                              color: Colors.brown,
                              fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '中国象棋',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const GameScreen(isAiMode: false),
                  ),
                );
              },
              icon: const Icon(Icons.people),
              label: const Text('双人对弈'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(220, 56),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AiSettingsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.computer),
              label: const Text('人机对战'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(220, 56),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RecordsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text('对局记录'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(220, 56),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LobbyScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.wifi),
              label: const Text('网络对战'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(220, 56),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
