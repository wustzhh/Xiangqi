/// 棋子颜色（红方/黑方）
enum Side {
  red,
  black;

  Side get opponent => this == red ? black : red;
}

/// 棋子类型
enum PieceType {
  general, // 将/帅
  advisor, // 士/仕
  elephant, // 象/相
  horse, // 马
  rook, // 车
  cannon, // 炮
  soldier, // 兵/卒
}

/// 棋子
class Piece {
  final PieceType type;
  final Side side;

  const Piece({required this.type, required this.side});

  /// 棋子名称（简体，默认用）
  String get displayName {
    switch (side) {
      case Side.red:
        switch (type) {
          case PieceType.general:
            return '帅';
          case PieceType.advisor:
            return '仕';
          case PieceType.elephant:
            return '相';
          case PieceType.horse:
            return '马';
          case PieceType.rook:
            return '车';
          case PieceType.cannon:
            return '炮';
          case PieceType.soldier:
            return '兵';
        }
      case Side.black:
        switch (type) {
          case PieceType.general:
            return '将';
          case PieceType.advisor:
            return '士';
          case PieceType.elephant:
            return '象';
          case PieceType.horse:
            return '马';
          case PieceType.rook:
            return '车';
          case PieceType.cannon:
            return '砲';
          case PieceType.soldier:
            return '卒';
        }
    }
  }

  /// 棋子名称（繁体）
  String get displayNameTraditional {
    switch (side) {
      case Side.red:
        switch (type) {
          case PieceType.general:
            return '帥';
          case PieceType.advisor:
            return '仕';
          case PieceType.elephant:
            return '相';
          case PieceType.horse:
            return '馬';
          case PieceType.rook:
            return '車';
          case PieceType.cannon:
            return '炮';
          case PieceType.soldier:
            return '兵';
        }
      case Side.black:
        switch (type) {
          case PieceType.general:
            return '將';
          case PieceType.advisor:
            return '士';
          case PieceType.elephant:
            return '象';
          case PieceType.horse:
            return '馬';
          case PieceType.rook:
            return '車';
          case PieceType.cannon:
            return '砲';
          case PieceType.soldier:
            return '卒';
        }
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Piece && type == other.type && side == other.side;

  @override
  int get hashCode => Object.hash(type, side);

  @override
  String toString() => '${side.name}(${displayName})';
}
