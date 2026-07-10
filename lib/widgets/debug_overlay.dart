import 'package:flutter/material.dart';
import '../engine/board.dart';
import '../engine/game_state.dart';
import '../engine/move.dart';
import '../engine/piece.dart';

/// 调试面板 — 覆盖层显示棋盘内部状态
class DebugOverlay extends StatelessWidget {
  final GameState gameState;

  const DebugOverlay({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xCC1A1A2E),
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header('调试面板'),
            const Divider(color: Colors.white30),
            _info('当前走子方', gameState.currentSide == Side.red ? '红方' : '黑方'),
            _info('步数', '${gameState.moveCount}'),
            _info('将军', gameState.inCheck ? '是' : '否'),
            _info('将杀', gameState.inCheckmate ? '是' : '否'),
            _info('对局结果', gameState.result.toString()),
            const SizedBox(height: 8),
            _header('棋盘数组'),
            _boardGrid(gameState.board),
            const SizedBox(height: 8),
            _header('走法列表'),
            if (gameState.moveHistory.isEmpty)
              const Text('（无）', style: TextStyle(color: Colors.white60, fontSize: 12))
            else
              ...gameState.moveHistory.map((m) => Text(
                    '  ${m.moveNumber}. ${m.notation}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _header(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.cyanAccent,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _boardGrid(Board board) {
    final rows = <Widget>[];

    // 表头
    rows.add(Row(
      children: [
        const SizedBox(width: 18),
        for (int c = 0; c < 9; c++)
          SizedBox(
            width: 24,
            child: Text('$c',
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 10)),
          ),
      ],
    ));

    for (int r = 0; r < 10; r++) {
      rows.add(Row(
        children: [
          SizedBox(
            width: 18,
            child: Text('$r',
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 10)),
          ),
          for (int c = 0; c < 9; c++)
            SizedBox(
              width: 24,
              height: 20,
              child: Center(
                child: () {
                  final p = board.at(Position(c, r));
                  return Text(
                    p?.displayName ?? '·',
                    style: TextStyle(
                      color: p != null
                          ? (p.side == Side.red
                              ? Colors.redAccent
                              : Colors.white)
                          : Colors.white24,
                      fontSize: 11,
                      fontWeight:
                          p != null ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }(),
              ),
            ),
        ],
      ));
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(4),
      child: Column(children: rows),
    );
  }
}
