import 'dart:math';
import '../engine/board.dart';
import '../engine/piece.dart';

/// Zobrist 哈希
class ZobristHash {
  static List<List<List<int>>>? _table;
  static final Random _rng = Random(0xABCD);

  static void _ensureTable() {
    if (_table != null) return;
    _table = List.generate(7, (_) => List.generate(
        2, (_) => List.generate(90, (_) => _rng.nextInt(1 << 30))));
  }

  static int hash(Board board) {
    _ensureTable();
    int h = 0;
    for (int r = 0; r < 10; r++)
      for (int c = 0; c < 9; c++) {
        final p = board.at(Position(c, r));
        if (p == null) continue;
        h ^= _table![p.type.index][p.side.index][r * 9 + c];
      }
    return h;
  }
}

/// 开局库
class OpeningBook {
  final Map<int, List<BookEntry>> _book = {};
  OpeningBook() { _buildBook(); }

  MoveFromTo? getBestMove(Board board) {
    final entries = _book[ZobristHash.hash(board)];
    if (entries == null || entries.isEmpty) return null;
    entries.sort((a, b) => b.weight.compareTo(a.weight));
    return entries.first.move;
  }

  void _addOpening(List<(int, int, int, int, int)> moves) {
    final board = Board.initial();
    for (final m in moves) {
      final from = Position(m.$1, m.$2);
      final to = Position(m.$3, m.$4);
      final piece = board.at(from);
      if (piece == null) continue;
      final hash = ZobristHash.hash(board);
      _book.putIfAbsent(hash, () => []).add(BookEntry(
          move: MoveFromTo(from.col, from.row, to.col, to.row), weight: m.$5));
      board.move(from, to);
    }
  }

  void _buildBook() {
    // ─── 中炮对屏风马（4回合）───
    _addOpening([
      (7,7,4,7,100), (1,0,2,2,100),
      (7,9,5,8,90),  (1,3,1,4,90),
      (8,9,6,9,85),  (0,0,2,0,85),
      (6,6,6,5,75),  (2,2,3,3,75),
    ]);
    // ─── 中炮对反宫马（3回合）───
    _addOpening([
      (7,7,4,7,95),  (1,0,2,2,95),
      (7,9,5,8,85),  (7,2,5,2,85),
      (8,9,6,9,80),  (0,0,2,0,80),
    ]);
    // ─── 顺炮直车对横车（3回合）───
    _addOpening([
      (7,7,4,7,90),  (1,7,4,7,90),
      (7,9,5,8,80),  (0,9,0,8,80), // 车1进1
      (8,9,6,9,75),  (0,8,3,8,75), // 车1平4
    ]);
    // ─── 仙人指路（3回合）───
    _addOpening([
      (6,6,6,5,85),  (1,3,1,4,80),
      (7,9,5,8,75),  (1,0,2,2,75),
      (6,9,4,7,70),  (7,2,4,2,70),
    ]);
    // ─── 飞相局（3回合）───
    _addOpening([
      (6,9,4,7,80),  (1,3,1,4,75),
      (7,9,5,8,70),  (1,0,2,2,70),
      (6,6,6,5,65),  (7,2,4,2,65),
    ]);
    // ─── 过宫炮（3回合）───
    _addOpening([
      (7,7,4,7,80),  (1,0,2,2,75),
      (7,9,5,8,70),  (1,3,1,4,65),
      (8,9,6,9,60),  (7,2,4,7,60),
    ]);
    // ─── 中炮进三兵（4回合）───
    _addOpening([
      (7,7,4,7,85),  (1,0,2,2,85),
      (6,6,6,5,75),  (1,3,1,4,75),
      (7,9,5,8,70),  (0,0,2,0,70),
      (1,9,2,7,65),  (2,0,4,2,65),
    ]);
    // ─── 中炮过河车（5回合）───
    _addOpening([
      (7,7,4,7,100), (1,0,2,2,100),
      (7,9,5,8,90),  (1,3,1,4,90),
      (8,9,6,9,85),  (0,0,2,0,85),
      (6,6,6,5,75),  (2,2,3,3,75),
      (6,9,6,3,70),  (3,0,4,1,70), // 车二进六 士4进5
    ]);
  }
}

class MoveFromTo {
  final int fromCol, fromRow, toCol, toRow;
  const MoveFromTo(this.fromCol, this.fromRow, this.toCol, this.toRow);
  Position get from => Position(fromCol, fromRow);
  Position get to => Position(toCol, toRow);
}

class BookEntry {
  final MoveFromTo move;
  final int weight;
  const BookEntry({required this.move, required this.weight});
}
