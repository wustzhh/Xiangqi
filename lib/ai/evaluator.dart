import '../engine/board.dart';
import '../engine/piece.dart';

/// 局面评估函数
///
/// 正值表示红方优势，负值表示黑方优势
class Evaluator {
  // ─── 子力基础价值 ─────────────────────────────────
  static const int _generalValue = 10000;
  static const int _rookValue = 900;
  static const int _cannonValue = 500;
  static const int _horseValue = 450;
  static const int _advisorValue = 200;
  static const int _elephantValue = 200;
  static const int _soldierBaseValue = 100;
  static const int _soldierRiverValue = 200; // 过河后价值翻倍

  /// 兵/卒位置价值表（红方视角，黑方对称翻转）
  /// 9列×10行，从黑方底线(0)到红方底线(9)
  static const List<List<int>> _soldierPosTable = [
    [0, 0, 0, 0, 0, 0, 0, 0, 0], // row 0
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [2, 6, 12, 18, 18, 18, 12, 6, 2], // row 4
    [6, 12, 18, 30, 36, 30, 18, 12, 6], // row 5
    [10, 20, 30, 42, 50, 42, 30, 20, 10], // row 6
    [12, 24, 36, 48, 56, 48, 36, 24, 12], // row 7
    [14, 26, 38, 50, 60, 50, 38, 26, 14], // row 8
    [0, 0, 0, 0, 0, 0, 0, 0, 0], // row 9（帅位）
  ];

  /// 马位置价值表
  static const List<List<int>> _horsePosTable = [
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [2, 4, 4, 8, 8, 8, 4, 4, 2],
    [4, 6, 10, 14, 14, 14, 10, 6, 4],
    [6, 10, 14, 18, 20, 18, 14, 10, 6],
    [6, 10, 14, 18, 20, 18, 14, 10, 6],
    [4, 6, 10, 14, 14, 14, 10, 6, 4],
    [2, 4, 4, 8, 8, 8, 4, 4, 2],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
  ];

  /// 炮位置价值表
  static const List<List<int>> _cannonPosTable = [
    [0, 0, 2, 6, 6, 6, 2, 0, 0],
    [0, 2, 4, 4, 8, 4, 4, 2, 0],
    [2, 4, 8, 6, 8, 6, 8, 4, 2],
    [0, 0, 0, 2, 4, 2, 0, 0, 0],
    [-2, 0, 4, 2, 6, 2, 4, 0, -2],
    [-2, 0, 4, 2, 6, 2, 4, 0, -2],
    [0, 0, 0, 2, 4, 2, 0, 0, 0],
    [2, 4, 8, 6, 8, 6, 8, 4, 2],
    [0, 2, 4, 4, 8, 4, 4, 2, 0],
    [0, 0, 2, 6, 6, 6, 2, 0, 0],
  ];

  /// 车位置价值表
  static const List<List<int>> _rookPosTable = [
    [6, 12, 6, 18, 24, 18, 6, 12, 6],
    [4, 8, 12, 16, 20, 16, 12, 8, 4],
    [-2, 4, 8, 12, 14, 12, 8, 4, -2],
    [-4, 0, 4, 6, 8, 6, 4, 0, -4],
    [-6, -2, 2, 4, 6, 4, 2, -2, -6],
    [-6, -2, 2, 4, 6, 4, 2, -2, -6],
    [-4, 0, 4, 6, 8, 6, 4, 0, -4],
    [-2, 4, 8, 12, 14, 12, 8, 4, -2],
    [4, 8, 12, 16, 20, 16, 12, 8, 4],
    [6, 12, 6, 18, 24, 18, 6, 12, 6],
  ];

  /// 完整的局面评估
  int evaluate(Board board) {
    int score = 0;
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final piece = board.at(Position(c, r));
        if (piece == null) continue;
        final value = _pieceValue(piece, c, r);
        score += piece.side == Side.red ? value : -value;
      }
    }
    return score;
  }

  /// 单个棋子的价值（子力 + 位置）
  int _pieceValue(Piece piece, int col, int row) {
    final base = _baseValue(piece);
    final pos = _posValue(piece, col, row);
    return base + pos;
  }

  int _baseValue(Piece piece) {
    switch (piece.type) {
      case PieceType.general:
        return _generalValue;
      case PieceType.rook:
        return _rookValue;
      case PieceType.cannon:
        return _cannonValue;
      case PieceType.horse:
        return _horseValue;
      case PieceType.advisor:
        return _advisorValue;
      case PieceType.elephant:
        return _elephantValue;
      case PieceType.soldier:
        return _soldierBaseValue;
    }
  }

  int _posValue(Piece piece, int col, int row) {
    // 红方在下方(row 5-9)，黑方在上方(row 0-4)
    // 位置表是红方视角，黑方需翻转
    final r = piece.side == Side.red ? row : 9 - row;
    final c = piece.side == Side.red ? col : 8 - col;

    switch (piece.type) {
      case PieceType.soldier:
        // 过河兵额外加价值
        final riverBonus = (piece.side == Side.red && row <= 4) ||
                (piece.side == Side.black && row >= 5)
            ? _soldierRiverValue - _soldierBaseValue
            : 0;
        return _soldierPosTable[r][c] + riverBonus;
      case PieceType.horse:
        return _horsePosTable[r][c];
      case PieceType.cannon:
        return _cannonPosTable[r][c];
      case PieceType.rook:
        return _rookPosTable[r][c];
      case PieceType.advisor:
        // 士在后排价值更高
        return (r >= 7) ? 10 : 0;
      case PieceType.elephant:
        return 0;
      case PieceType.general:
        return 0;
    }
  }
}
