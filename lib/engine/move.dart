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

  /// 走法的代数记谱（简略版）
  String get notation {
    final name = piece.displayName;
    final capturedStr = captured != null ? 'x' : '-';
    return '$name(${from.col},${from.row})$capturedStr(${to.col},${to.row})';
  }

  @override
  String toString() => notation;
}
