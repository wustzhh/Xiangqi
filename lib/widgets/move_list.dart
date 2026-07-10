import 'package:flutter/material.dart';
import '../models/game_record.dart';

/// 走法列表组件
class MoveList extends StatelessWidget {
  final List<RecordedMove> moves;
  final int? currentIndex; // 当前播放到的步数索引
  final ValueChanged<int>? onMoveTap;

  const MoveList({
    super.key,
    required this.moves,
    this.currentIndex,
    this.onMoveTap,
  });

  @override
  Widget build(BuildContext context) {
    if (moves.isEmpty) {
      return const Center(
        child: Text('暂无走法', style: TextStyle(color: Colors.grey)),
      );
    }

    // 每两步行一组（红+黑）
    final rows = <int>[];
    for (int i = 0; i < moves.length; i += 2) {
      rows.add(i);
    }

    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final redIdx = rows[index];
        final blackIdx = redIdx + 1;
        final redMove = moves[redIdx];
        final blackMove = blackIdx < moves.length ? moves[blackIdx] : null;
        final round = (redIdx ~/ 2) + 1;

        final isRedCurrent = currentIndex == redIdx;
        final isBlackCurrent = currentIndex == blackIdx;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: Row(
            children: [
              // 回合数
              SizedBox(
                width: 28,
                child: Text(
                  '$round.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // 红方走法
              Expanded(
                child: _MoveCell(
                  notation: redMove.notation,
                  isCurrent: isRedCurrent,
                  onTap: () => onMoveTap?.call(redIdx),
                ),
              ),
              const SizedBox(width: 4),
              // 黑方走法
              Expanded(
                child: blackMove != null
                    ? _MoveCell(
                        notation: blackMove.notation,
                        isCurrent: isBlackCurrent,
                        onTap: () => onMoveTap?.call(blackIdx),
                      )
                    : const SizedBox(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MoveCell extends StatelessWidget {
  final String notation;
  final bool isCurrent;
  final VoidCallback? onTap;

  const _MoveCell({
    required this.notation,
    required this.isCurrent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isCurrent
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          notation,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
        ),
      ),
    );
  }
}
