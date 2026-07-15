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

  /// 每档难度的参数描述
  static const _difficultyStandards = {
    AiDifficulty.beginner: 'SL 2 · 深度4层 · 2秒 · 30%随机走',
    AiDifficulty.easy: 'SL 5 · 深度6层 · 3秒',
    AiDifficulty.medium: 'SL 8 · 深度10层 · 5秒',
    AiDifficulty.hard: 'SL 12 · 不限深度 · 8秒 · 开局库',
    AiDifficulty.master: 'SL 16 · 不限深度 · 12秒 · 开局库',
    AiDifficulty.legend: 'SL 20 · 不限深度 · 30秒 · 开局库',
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
          // ── 参数说明 ──
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'SL = Skill Level（0最弱~20最强），控制引擎故意犯错的频率。'
              '值越低越常下劣着，值越高越接近最优走法。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),

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
                subtitle: Text(
                  _difficultyStandards[d]!,
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () => setState(() => _selectedDifficulty = d),
              ),
            );
          }),
          const SizedBox(height: 16),

          // ── 引擎提示 ──
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.amber),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '使用皮卡鱼引擎（UCI 协议）。可在「设置」页配置引擎路径。'
                    '未找到引擎时自动降级到内置搜索。',
                    style: TextStyle(fontSize: 12, color: Colors.brown),
                  ),
                ),
              ],
            ),
          ),
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
