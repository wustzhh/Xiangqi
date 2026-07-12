import 'board.dart';
import 'piece.dart';

/// 一步走法
class Move {
  final Position from;
  final Position to;
  final Piece piece;
  final Piece? captured;
  final int moveNumber; // 第几步

  const Move({
    required this.from,
    required this.to,
    required this.piece,
    this.captured,
    required this.moveNumber,
  });

  /// 红方列号：col 8→一, col 7→二, ..., col 0→九
  static const _redCol = ['九','八','七','六','五','四','三','二','一'];
  /// 黑方列号：col 0→1, col 1→2, ..., col 8→9
  static const _blackCol = ['1','2','3','4','5','6','7','8','9'];
  /// 数字转中文（用于步数）
  static const _nums = ['○','一','二','三','四','五','六','七','八','九'];

  /// 中国象棋代数记谱
  String get chineseNotation {
    final name = piece.displayName;
    final isRed = piece.side == Side.red;

    final fc = isRed ? _redCol[from.col] : _blackCol[from.col];

    if (from.row == to.row) {
      // 平
      final tc = isRed ? _redCol[to.col] : _blackCol[to.col];
      final cap = captured != null ? '吃' : '';
      return '$name$fc${cap}平$tc';
    }

    // 前进/后退
    final forward = isRed ? to.row < from.row : to.row > from.row;
    final dir = forward ? '进' : '退';

    // 滑动棋子（车/炮/兵/帅）：步数
    // 非滑动棋子（马/士/象）：目标列号
    final isSliding = switch (piece.type) {
      PieceType.rook || PieceType.cannon || PieceType.soldier || PieceType.general => true,
      _ => false,
    };

    if (isSliding) {
      final steps = (to.row - from.row).abs();
      final cap = captured != null ? '吃' : '';
      return '$name$fc${cap}$dir${_nums[steps]}';
    } else {
      final tc = isRed ? _redCol[to.col] : _blackCol[to.col];
      final cap = captured != null ? '吃' : '';
      return '$name$fc${cap}$dir$tc';
    }
  }

  /// 走法的代数记谱（简略版，带坐标）
  String get notation {
    final name = piece.displayName;
    final capturedStr = captured != null ? 'x' : '-';
    return '$name(${from.col},${from.row})$capturedStr(${to.col},${to.row})';
  }

  @override
  String toString() => chineseNotation;
}
