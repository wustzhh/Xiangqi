import 'package:flutter/material.dart';
import '../ai/ai_player.dart';
import '../engine/game_state.dart';
import '../models/game_record.dart';
import '../services/storage_service.dart';
import 'replay_screen.dart';

/// 对局记录列表页面
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final StorageService _storage = StorageService();
  List<GameRecord>? _records;
  Map<String, int>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final records = await _storage.loadRecords();
    final stats = await _storage.getStats();
    setState(() {
      _records = records;
      _stats = stats;
      _loading = false;
    });
  }

  Future<void> _delete(String id) async {
    await _storage.deleteRecord(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('对局记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records == null || _records!.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sports_esports, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('暂无对局记录',
                          style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // 战绩统计
                    if (_stats != null) _buildStats(),
                    // 记录列表
                    Expanded(
                      child: ListView.builder(
                        itemCount: _records!.length,
                        itemBuilder: (context, index) =>
                            _buildRecordItem(_records![index]),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStats() {
    final s = _stats!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem('总局', '${s['total']}', Colors.grey),
          _statItem('胜', '${s['wins']}', Colors.green),
          _statItem('负', '${s['losses']}', Colors.red),
          _statItem('平', '${s['draws']}', Colors.blueGrey),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildRecordItem(GameRecord record) {
    final resultText = record.result == GameResult.redWin
        ? '红胜'
        : record.result == GameResult.blackWin
            ? '黑胜'
            : '和棋';
    final dateStr =
        '${record.playedAt.month}/${record.playedAt.day} ${record.playedAt.hour}:${record.playedAt.minute.toString().padLeft(2, '0')}';
    final redLabel =
        record.redPlayer.type == PlayerType.human ? '玩家' : 'AI${record.redPlayer.aiDifficulty != null ? "(${_difficultyName(record.redPlayer.aiDifficulty!)})" : ""}';
    final blackLabel =
        record.blackPlayer.type == PlayerType.human ? '玩家' : 'AI${record.blackPlayer.aiDifficulty != null ? "(${_difficultyName(record.blackPlayer.aiDifficulty!)})" : ""}';
    final subtitle = '$redLabel vs $blackLabel · ${record.totalMoves}步${record.endReason != null ? " · ${record.endReason}" : ""}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: record.result == GameResult.redWin
              ? Colors.red
              : record.result == GameResult.blackWin
                  ? Colors.black
                  : Colors.grey,
          radius: 18,
          child: Text(
            resultText,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(dateStr, style: const TextStyle(fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.replay, size: 20),
              tooltip: '复盘',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReplayScreen(record: record),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: '删除',
              onPressed: () => _delete(record.id),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReplayScreen(record: record),
            ),
          );
        },
      ),
    );
  }

  String _difficultyName(AiDifficulty d) {
    switch (d) {
      case AiDifficulty.beginner:
        return '新手';
      case AiDifficulty.easy:
        return '初级';
      case AiDifficulty.medium:
        return '中级';
      case AiDifficulty.hard:
        return '高级';
      case AiDifficulty.master:
        return '大师';
      case AiDifficulty.legend:
        return '传说';
    }
  }
}
