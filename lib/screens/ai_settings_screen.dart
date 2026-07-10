import 'package:flutter/material.dart';
import '../ai/ai_player.dart';
import '../engine/piece.dart';
import 'game_screen.dart';

/// AI 对战设置页面
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  AiDifficulty _selectedDifficulty = AiDifficulty.medium;
  bool _playAsRed = true;

  static const _difficultyNames = {
    AiDifficulty.beginner: '新手',
    AiDifficulty.easy: '初级',
    AiDifficulty.medium: '中级',
    AiDifficulty.hard: '高级',
    AiDifficulty.master: '大师',
    AiDifficulty.legend: '传说',
  };

  static const _difficultyDescs = {
    AiDifficulty.beginner: '1层搜索 · 30%随机走，入门水平',
    AiDifficulty.easy: '2层搜索 · 基础水平，适合新手',
    AiDifficulty.medium: '3层搜索 · 会简单战术组合',
    AiDifficulty.hard: '开局库+4层搜索 · 开局稳健中盘有力',
    AiDifficulty.master: '开局库+迭代6层搜索(≈UCCI引擎) · 强力战术',
    AiDifficulty.legend: '开局库+DeepSeek AI介入+6层搜索 · 需在设置页填入API Key',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('人机对战设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          // ── 难度选择 ──
          const Text(
            '选择 AI 难度',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...AiDifficulty.values.map((d) {
            final selected = _selectedDifficulty == d;
            return Card(
              margin: const EdgeInsets.only(bottom: 4),
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: ListTile(
                dense: true,
                leading: Radio<AiDifficulty>(
                  value: d,
                  groupValue: _selectedDifficulty,
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedDifficulty = v);
                  },
                ),
                title: Text(
                  _difficultyNames[d]!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(_difficultyDescs[d]!,
                    style: const TextStyle(fontSize: 12)),
                onTap: () => setState(() => _selectedDifficulty = d),
              ),
            );
          }),
          const SizedBox(height: 16),

          const SizedBox(height: 16),

          // ── 先后手选择 ──
          const Text(
            '选择您的棋子颜色',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SideCard(
                  label: '执红（先手）',
                  side: Side.red,
                  selected: _playAsRed,
                  onTap: () => setState(() => _playAsRed = true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SideCard(
                  label: '执黑（后手）',
                  side: Side.black,
                  selected: !_playAsRed,
                  onTap: () => setState(() => _playAsRed = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── 开始按钮 ──
          FilledButton.icon(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => GameScreen(
                    isAiMode: true,
                    aiDifficulty: _selectedDifficulty,
                    playerSide: _playAsRed ? Side.red : Side.black,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('开始对局'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),
          // 底部留白防截断
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

/// 先后手选择卡片
class _SideCard extends StatelessWidget {
  final String label;
  final Side side;
  final bool selected;
  final VoidCallback onTap;

  const _SideCard({
    required this.label,
    required this.side,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sideColor =
        side == Side.red ? const Color(0xFFCC0000) : const Color(0xFF1A1A1A);
    return Card(
      color: selected
          ? sideColor.withValues(alpha: 0.15)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? sideColor : Colors.grey.shade300,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(
                Icons.circle,
                color: sideColor,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
