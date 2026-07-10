import 'piece.dart';

/// 棋盘位置坐标
class Position {
  final int col; // 0-8
  final int row; // 0-9

  const Position(this.col, this.row);

  bool get isValid => col >= 0 && col <= 8 && row >= 0 && row <= 9;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Position && col == other.col && row == other.row;

  @override
  int get hashCode => Object.hash(col, row);

  @override
  String toString() => '($col,$row)';
}

/// 棋盘数据模型 — 9列 × 10行
///
/// board[row][col] 取值：
///   - null: 空位
///   - Piece: 有棋子
///
/// 红方在下方 (row 5-9)，黑方在上方 (row 0-4)
class Board {
  final List<List<Piece?>> grid;

  Board() : grid = List.generate(10, (_) => List.filled(9, null));

  /// 从已有网格创建棋盘副本
  Board.from(List<List<Piece?>> source)
      : grid = source.map((row) => List<Piece?>.from(row)).toList();

  /// 获取某位置的棋子
  Piece? at(Position pos) => grid[pos.row][pos.col];

  /// 放置棋子
  void set(Position pos, Piece? piece) {
    grid[pos.row][pos.col] = piece;
  }

  /// 移动棋子（起点→终点，含吃子）
  Piece? move(Position from, Position to) {
    final piece = at(from);
    if (piece == null) return null;
    final captured = at(to);
    set(to, piece);
    set(from, null);
    return captured;
  }

  /// 原地走棋（用于搜索引擎，避免 copy 开销）
  /// 返回被吃棋子，用于 undoMoveInPlace 恢复
  Piece? moveInPlace(Position from, Position to) {
    final piece = grid[from.row][from.col];
    if (piece == null) return null;
    final captured = grid[to.row][to.col];
    grid[to.row][to.col] = piece;
    grid[from.row][from.col] = null;
    return captured;
  }

  /// 撤销原地走棋
  void undoMoveInPlace(Position from, Position to, Piece piece, Piece? captured) {
    grid[from.row][from.col] = piece;
    grid[to.row][to.col] = captured;
  }

  /// 序列化为 90 整数列表（用于跨 Isolate 传递）
  /// 编码：0=空, 1~7=红方 type.index+1, -1~-7=黑方 -(type.index+1)
  List<int> toIntList() {
    final result = List.filled(90, 0);
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final p = grid[r][c];
        if (p == null) continue;
        result[r * 9 + c] =
            p.side == Side.red ? (p.type.index + 1) : -(p.type.index + 1);
      }
    }
    return result;
  }

  /// 从整数列表还原棋盘
  factory Board.fromIntList(List<int> data) {
    final board = Board();
    for (int r = 0; r < 10 && r * 9 + 8 < data.length; r++) {
      for (int c = 0; c < 9; c++) {
        final val = data[r * 9 + c];
        if (val == 0) continue;
        final side = val > 0 ? Side.red : Side.black;
        final type = PieceType.values[(val.abs() - 1)];
        board.grid[r][c] = Piece(type: type, side: side);
      }
    }
    return board;
  }

  /// 查找所有某方棋子
  List<MapEntry<Position, Piece>> findPieces(Side side) {
    final result = <MapEntry<Position, Piece>>[];
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final piece = grid[r][c];
        if (piece != null && piece.side == side) {
          result.add(MapEntry(Position(c, r), piece));
        }
      }
    }
    return result;
  }

  /// 创建深拷贝
  Board copy() => Board.from(grid);

  /// 初始局面
  ///
  /// 列:  0  1  2  3  4  5  6  7  8
  /// 行 0: 車 馬 象 士 將 士 象 馬 車  ← 黑方
  /// 行 1: 空 空 空 空 空 空 空 空 空
  /// 行 2: 空 砲 空 空 空 空 空 砲 空
  /// 行 3: 卒 空 卒 空 卒 空 卒 空 卒
  /// 行 4: 空 空 空 空 空 空 空 空 空  ← 楚河
  /// ────────────────────────────────
  /// 行 5: 空 空 空 空 空 空 空 空 空  ← 汉界
  /// 行 6: 兵 空 兵 空 兵 空 兵 空 兵
  /// 行 7: 空 炮 空 空 空 空 空 炮 空
  /// 行 8: 空 空 空 空 空 空 空 空 空
  /// 行 9: 車 馬 相 仕 帥 仕 相 馬 車  ← 红方
  factory Board.initial() {
    final board = Board();
    final p = PieceType.values;
    final red = Side.red;
    final black = Side.black;

    // 黑方 (上方, row 0-4)
    board.grid[0][0] = Piece(type: p[PieceType.rook.index], side: black);
    board.grid[0][1] = Piece(type: p[PieceType.horse.index], side: black);
    board.grid[0][2] = Piece(type: p[PieceType.elephant.index], side: black);
    board.grid[0][3] = Piece(type: p[PieceType.advisor.index], side: black);
    board.grid[0][4] = Piece(type: p[PieceType.general.index], side: black);
    board.grid[0][5] = Piece(type: p[PieceType.advisor.index], side: black);
    board.grid[0][6] = Piece(type: p[PieceType.elephant.index], side: black);
    board.grid[0][7] = Piece(type: p[PieceType.horse.index], side: black);
    board.grid[0][8] = Piece(type: p[PieceType.rook.index], side: black);
    board.grid[2][1] = Piece(type: p[PieceType.cannon.index], side: black);
    board.grid[2][7] = Piece(type: p[PieceType.cannon.index], side: black);
    for (int c = 0; c < 9; c += 2) {
      board.grid[3][c] = Piece(type: p[PieceType.soldier.index], side: black);
    }

    // 红方 (下方, row 5-9)
    board.grid[9][0] = Piece(type: p[PieceType.rook.index], side: red);
    board.grid[9][1] = Piece(type: p[PieceType.horse.index], side: red);
    board.grid[9][2] = Piece(type: p[PieceType.elephant.index], side: red);
    board.grid[9][3] = Piece(type: p[PieceType.advisor.index], side: red);
    board.grid[9][4] = Piece(type: p[PieceType.general.index], side: red);
    board.grid[9][5] = Piece(type: p[PieceType.advisor.index], side: red);
    board.grid[9][6] = Piece(type: p[PieceType.elephant.index], side: red);
    board.grid[9][7] = Piece(type: p[PieceType.horse.index], side: red);
    board.grid[9][8] = Piece(type: p[PieceType.rook.index], side: red);
    board.grid[7][1] = Piece(type: p[PieceType.cannon.index], side: red);
    board.grid[7][7] = Piece(type: p[PieceType.cannon.index], side: red);
    for (int c = 0; c < 9; c += 2) {
      board.grid[6][c] = Piece(type: p[PieceType.soldier.index], side: red);
    }

    return board;
  }

  @override
  String toString() {
    final buf = StringBuffer("  0 1 2 3 4 5 6 7 8\n");
    for (int r = 0; r < 10; r++) {
      buf.write('$r ');
      for (int c = 0; c < 9; c++) {
        final p = grid[r][c];
        if (p == null) {
          buf.write('. ');
        } else {
          buf.write('${p.side == Side.red ? "r" : "b"}${p.displayName} ');
        }
      }
      if (r == 4) buf.write('← 楚河');
      if (r == 5) buf.write('← 汉界');
      buf.writeln();
    }
    return buf.toString();
  }
}
