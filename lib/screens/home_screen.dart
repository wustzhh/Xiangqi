import 'package:flutter/material.dart';
import 'ai_settings_screen.dart';
import 'game_screen.dart';
import 'lobby_screen.dart';
import 'records_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('中国象棋'),
        centerTitle: true,
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
