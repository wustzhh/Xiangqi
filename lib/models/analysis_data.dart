import '../engine/board.dart';
import '../engine/piece.dart';
import '../engine/rules.dart';

enum AnalysisMode {
  none,
  protection,
  attack,
  safety,
  danger,
}

class AnalysisData {
  final Map<int, int> protectionCount;
  final Map<int, List<Position>> protectors;
  final Map<int, int> attackCount;
  final Map<int, List<Position>> attackers;
  final Map<int, int> safetyScore;
  final Map<int, int> dangerScore;
  /// 炮只能移动到（不能吃）的位置 → 危险格用黄色
  final Set<int> cannonMoveOnly;

  const AnalysisData({
    required this.protectionCount,
    required this.protectors,
    required this.attackCount,
    required this.attackers,
    required this.safetyScore,
    required this.dangerScore,
    required this.cannonMoveOnly,
  });

  static int _pk(int col, int row) => row * 9 + col;

  factory AnalysisData.compute(Board board) {
    final pCount = <int, int>{};
    final prot = <int, List<Position>>{};
    final enemyAttCount = <int, int>{};
    final enemyAtt = <int, List<Position>>{};
    final allAttCount = <int, int>{};
    final cannonMove = <int>{};
    final rules = Rules(board);

    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final pos = Position(c, r);
        final piece = board.at(pos);
        if (piece == null) continue;

        // 护子
        final protected = rules.getProtectedFriendlies(pos);
        for (final friendly in protected) {
          final key = _pk(friendly.col, friendly.row);
          pCount[key] = (pCount[key] ?? 0) + 1;
          prot.putIfAbsent(key, () => []).add(pos);
        }

        // 攻击范围
        final rawMoves = rules.getRawMoves(pos);

        // 敌方攻击标记
        if (piece.side == Side.black) {
          // 炮的特殊处理：移动位和吃子位分开标记
          if (piece.type == PieceType.cannon) {
            _markCannonDanger(board, pos, enemyAttCount, enemyAtt, cannonMove);
          } else {
            for (final target in rawMoves) {
              final tKey = _pk(target.col, target.row);
              enemyAttCount[tKey] = (enemyAttCount[tKey] ?? 0) + 1;
              enemyAtt.putIfAbsent(tKey, () => []).add(pos);
            }
          }
        }

        // 所有棋子攻敌统计（安全分用）
        for (final target in rawMoves) {
          final tp = board.at(target);
          if (tp != null && tp.side != piece.side) {
            final tKey = _pk(target.col, target.row);
            allAttCount[tKey] = (allAttCount[tKey] ?? 0) + 1;
          }
        }
      }
    }

    // 安全分
    final safety = <int, int>{};
    for (final key in {...pCount.keys, ...allAttCount.keys}) {
      safety[key] = (pCount[key] ?? 0) - (allAttCount[key] ?? 0);
    }

    // 危险度
    final danger = <int, int>{};
    for (final entry in enemyAttCount.entries) {
      final col = entry.key % 9;
      final row = entry.key ~/ 9;
      if (col >= 0 && col < 9 && row >= 0 && row < 10) {
        danger[entry.key] = entry.value;
      }
    }

    return AnalysisData(
      protectionCount: pCount,
      protectors: prot,
      attackCount: enemyAttCount,
      attackers: enemyAtt,
      safetyScore: safety,
      dangerScore: danger,
      cannonMoveOnly: cannonMove,
    );
  }

  /// 炮的危险标记：移动位(黄色)和吃子位(红色)分开
  static void _markCannonDanger(
    Board board,
    Position pos,
    Map<int, int> count,
    Map<int, List<Position>> att,
    Set<int> cannonMove,
  ) {
    const dirs = [(0, -1), (0, 1), (-1, 0), (1, 0)];
    for (final d in dirs) {
      int cr = pos.row + d.$1;
      int cc = pos.col + d.$2;
      bool jumped = false;

      while (cc >= 0 && cc <= 8 && cr >= 0 && cr <= 9) {
        final target = board.at(Position(cc, cr));
        if (target == null) {
          if (!jumped) {
            // 炮架前：只能移动到，不能吃 → 黄色
            cannonMove.add(_pk(cc, cr));
            count[_pk(cc, cr)] = (count[_pk(cc, cr)] ?? 0) + 1;
            att.putIfAbsent(_pk(cc, cr), () => []).add(pos);
          } else {
            // 炮架后：可以吃 → 红色
            count[_pk(cc, cr)] = (count[_pk(cc, cr)] ?? 0) + 1;
            att.putIfAbsent(_pk(cc, cr), () => []).add(pos);
          }
        } else {
          if (!jumped) {
            jumped = true; // 遇到炮架，跳过
          } else {
            // 炮架后的棋子（敌方=可吃，我方=不可吃但仍是危险位）
            count[_pk(cc, cr)] = (count[_pk(cc, cr)] ?? 0) + 1;
            att.putIfAbsent(_pk(cc, cr), () => []).add(pos);
            break;
          }
        }
        cr += d.$1;
        cc += d.$2;
      }
    }
  }
}
