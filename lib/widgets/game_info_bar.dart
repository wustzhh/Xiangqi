import 'package:flutter/material.dart';
import '../engine/piece.dart';
import '../utils/constants.dart';

/// 游戏信息栏 — 显示当前轮到谁、将军状态等
class GameInfoBar extends StatelessWidget {
  final Side currentSide;
  final bool inCheck;
  final int moveCount;

  const GameInfoBar({
    super.key,
    required this.currentSide,
    this.inCheck = false,
    this.moveCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final sideName = currentSide == Side.red ? '红方' : '黑方';
    final sideColor = currentSide == Side.red ? AppColors.pieceRed : AppColors.pieceBlack;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.circle,
            color: sideColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            sideName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: sideColor,
            ),
          ),
          if (inCheck) ...[
            const SizedBox(width: 12),
            const Chip(
              label: Text('将军！', style: TextStyle(fontSize: 14)),
              backgroundColor: Colors.redAccent,
              labelStyle: TextStyle(color: Colors.white),
            ),
          ],
          const Spacer(),
          Text(
            '第 $moveCount 手',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
