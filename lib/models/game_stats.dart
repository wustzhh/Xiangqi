import '../engine/board.dart';
import '../engine/move.dart';
import '../engine/piece.dart';
import '../engine/rules.dart';

/// 局面统计数据
class GameStats {
  /// 红方被吃的棋子列表（按价值排序）
  final List<Piece> redCaptured;

  /// 黑方被吃的棋子列表（按价值排序）
  final List<Piece> blackCaptured;

  /// 红方被护住的棋子数量
  final int redProtectedCount;

  /// 黑方被护住的棋子数量
  final int blackProtectedCount;

  /// 红方哪些棋子正被敌方攻击（位置列表）
  final List<Position> redUnderAttack;

  /// 黑方哪些棋子正被敌方攻击（位置列表）
  final List<Position> blackUnderAttack;

  const GameStats({
    required this.redCaptured,
    required this.blackCaptured,
    required this.redProtectedCount,
    required this.blackProtectedCount,
    required this.redUnderAttack,
    required this.blackUnderAttack,
  });

  /// 从棋盘和走法历史计算统计
  factory GameStats.compute(Board board, List<Move> moveHistory) {
    // 被吃的棋子 = 从走法历史中反向收集
    final redCaptured = <Piece>[];
    final blackCaptured = <Piece>[];
    for (final move in moveHistory) {
      if (move.captured != null) {
        if (move.captured!.side == Side.red) {
          redCaptured.add(move.captured!);
        } else {
          blackCaptured.add(move.captured!);
        }
      }
    }

    // 护子统计
    int redProtected = 0;
    int blackProtected = 0;
    final redUnderAttack = <Position>[];
    final blackUnderAttack = <Position>[];

    final rules = Rules(board);
    // 遍历所有棋子，统计护子和被攻击情况
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final pos = Position(c, r);
        final piece = board.at(pos);
        if (piece == null) continue;

        // 检查这个棋子护住了多少友军
        final protected = rules.getProtectedFriendlies(pos);
        if (piece.side == Side.red) {
          redProtected += protected.length;
        } else {
          blackProtected += protected.length;
        }

        // 检查这个棋子是否在敌方攻击范围内
        // 对每个敌方棋子，检查其攻击范围是否包含此位置
        final enemySide = piece.side.opponent;
        bool underAttack = false;
        for (int er = 0; er < 10 && !underAttack; er++) {
          for (int ec = 0; ec < 9 && !underAttack; ec++) {
            final epos = Position(ec, er);
            final ep = board.at(epos);
            if (ep == null || ep.side != enemySide) continue;
            final attackRange = rules.getProtectedFriendlies(epos);
            if (attackRange.contains(pos)) {
              underAttack = true;
            }
          }
        }
        if (underAttack) {
          if (piece.side == Side.red) {
            redUnderAttack.add(pos);
          } else {
            blackUnderAttack.add(pos);
          }
        }
      }
    }

    return GameStats(
      redCaptured: redCaptured,
      blackCaptured: blackCaptured,
      redProtectedCount: redProtected,
      blackProtectedCount: blackProtected,
      redUnderAttack: redUnderAttack,
      blackUnderAttack: blackUnderAttack,
    );
  }

  /// 被吃棋子数量的显示文字
  String get capturedText =>
      '吃子 红${redCaptured.length}:黑${blackCaptured.length}';

  /// 护子数量的显示文字
  String get protectedText =>
      '护子 红$redProtectedCount:黑$blackProtectedCount';
}
