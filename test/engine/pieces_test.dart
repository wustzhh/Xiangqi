import 'package:test/test.dart';
import 'package:xiangqi/engine/board.dart';
import 'package:xiangqi/engine/piece.dart';
import 'package:xiangqi/engine/rules.dart';

void main() {
  final _redGeneral = Position(3, 9);
  final _blackGeneral = Position(4, 0);

  void setupGenerals(Board board) {
    board.set(_redGeneral, const Piece(type: PieceType.general, side: Side.red));
    board.set(_blackGeneral, const Piece(type: PieceType.general, side: Side.black));
  }

  Set<Position> getTargets(Board board, Position pos) {
    return Rules(board).getLegalMoves(pos).toSet();
  }

  // ─── 帅/将 ─────────────────────────────────────
  group('帅/将', () {
    test('帅只能在九宫内移动', () {
      final board = Board();
      board.set(Position(4, 9), const Piece(type: PieceType.general, side: Side.red));
      board.set(Position(6, 0), const Piece(type: PieceType.general, side: Side.black));
      final moves = getTargets(board, Position(4, 9));
      expect(moves.length, 3);
      expect(moves, contains(Position(3, 9)));
      expect(moves, contains(Position(4, 8)));
      expect(moves, contains(Position(5, 9)));
    });

    test('帅不能走出九宫', () {
      final board = Board();
      board.set(Position(3, 9), const Piece(type: PieceType.general, side: Side.red));
      board.set(Position(6, 0), const Piece(type: PieceType.general, side: Side.black));
      final moves = getTargets(board, Position(3, 9));
      expect(moves, isNot(contains(Position(2, 9))));
      expect(moves, isNot(contains(Position(3, 10))));
    });

    test('帅可以吃子', () {
      final board = Board();
      board.set(Position(4, 9), const Piece(type: PieceType.general, side: Side.red));
      board.set(Position(6, 0), const Piece(type: PieceType.general, side: Side.black));
      board.set(Position(5, 9), const Piece(type: PieceType.soldier, side: Side.black));
      final moves = getTargets(board, Position(4, 9));
      expect(moves, contains(Position(5, 9)));
    });

    test('帅不能走到己方子上', () {
      final board = Board();
      board.set(Position(4, 9), const Piece(type: PieceType.general, side: Side.red));
      board.set(Position(6, 0), const Piece(type: PieceType.general, side: Side.black));
      board.set(Position(3, 9), const Piece(type: PieceType.advisor, side: Side.red));
      final moves = getTargets(board, Position(4, 9));
      expect(moves, isNot(contains(Position(3, 9))));
    });
  });

  // ─── 士/仕 ─────────────────────────────────────
  group('士/仕', () {
    test('仕只能在九宫内走斜线', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(4, 8), const Piece(type: PieceType.advisor, side: Side.red));
      final moves = getTargets(board, Position(4, 8));
      expect(moves.length, 3);
      expect(moves, contains(Position(3, 7)));
      expect(moves, contains(Position(5, 7)));
      expect(moves, contains(Position(5, 9)));
      expect(moves, isNot(contains(Position(3, 9))));
    });

    test('仕不能走出九宫', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(3, 7), const Piece(type: PieceType.advisor, side: Side.red));
      final moves = getTargets(board, Position(3, 7));
      expect(moves.length, 1);
      expect(moves, contains(Position(4, 8)));
    });

    test('仕可以吃敌子', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(4, 8), const Piece(type: PieceType.advisor, side: Side.red));
      board.set(Position(5, 9), const Piece(type: PieceType.soldier, side: Side.black));
      final moves = getTargets(board, Position(4, 8));
      expect(moves, contains(Position(5, 9)));
    });
  });

  // ─── 象/相 ─────────────────────────────────────
  group('象/相', () {
    test('相走田字', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(2, 7), const Piece(type: PieceType.elephant, side: Side.red));
      final moves = getTargets(board, Position(2, 7));
      expect(moves.length, 4);
      expect(moves, contains(Position(0, 5)));
      expect(moves, contains(Position(4, 5)));
      expect(moves, contains(Position(0, 9)));
      expect(moves, contains(Position(4, 9)));
    });

    test('相不能过河', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(4, 5), const Piece(type: PieceType.elephant, side: Side.red));
      final moves = getTargets(board, Position(4, 5));
      for (final m in moves) {
        expect(m.row, greaterThanOrEqualTo(5), reason: '相不能过河');
      }
    });

    test('塞象眼', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(2, 7), const Piece(type: PieceType.elephant, side: Side.red));
      board.set(Position(3, 6), const Piece(type: PieceType.soldier, side: Side.black));
      final moves = getTargets(board, Position(2, 7));
      expect(moves, isNot(contains(Position(4, 5))));
      expect(moves, contains(Position(4, 9)));
    });

    test('象可以吃子', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(2, 7), const Piece(type: PieceType.elephant, side: Side.red));
      board.set(Position(0, 5), const Piece(type: PieceType.soldier, side: Side.black));
      final moves = getTargets(board, Position(2, 7));
      expect(moves, contains(Position(0, 5)));
    });
  });

  // ─── 马 ────────────────────────────────────────
  group('马', () {
    test('马走日字', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(3, 4), const Piece(type: PieceType.horse, side: Side.red));
      final moves = getTargets(board, Position(3, 4));
      expect(moves.length, 8);
    });

    test('蹩马腿', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(2, 2), const Piece(type: PieceType.horse, side: Side.red));
      board.set(Position(2, 1), const Piece(type: PieceType.rook, side: Side.red));
      final moves = getTargets(board, Position(2, 2));
      expect(moves, isNot(contains(Position(1, 0))));
      expect(moves, isNot(contains(Position(3, 0))));
      expect(moves.length, 6);
    });

    test('马吃子', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(2, 2), const Piece(type: PieceType.horse, side: Side.red));
      board.set(Position(0, 1), const Piece(type: PieceType.soldier, side: Side.black));
      final moves = getTargets(board, Position(2, 2));
      expect(moves, contains(Position(0, 1)));
    });

    test('马不能走到己方子上', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(2, 2), const Piece(type: PieceType.horse, side: Side.red));
      board.set(Position(0, 1), const Piece(type: PieceType.rook, side: Side.red));
      final moves = getTargets(board, Position(2, 2));
      expect(moves, isNot(contains(Position(0, 1))));
    });

    test('马在边角走法受限', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(0, 0), const Piece(type: PieceType.horse, side: Side.black));
      final moves = getTargets(board, Position(0, 0));
      expect(moves.length, 2);
      expect(moves, contains(Position(1, 2)));
      expect(moves, contains(Position(2, 1)));
    });
  });

  // ─── 车 ────────────────────────────────────────
  group('车', () {
    test('车直线走全部空位', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(0, 7), const Piece(type: PieceType.rook, side: Side.red));
      final moves = getTargets(board, Position(0, 7));
      expect(moves.length, 17);
    });

    test('车遇敌可吃，不能越过', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(0, 7), const Piece(type: PieceType.rook, side: Side.red));
      board.set(Position(0, 4), const Piece(type: PieceType.soldier, side: Side.black));
      final moves = getTargets(board, Position(0, 7));
      expect(moves, contains(Position(0, 4)));
      expect(moves, isNot(contains(Position(0, 3))));
    });

    test('车遇己方子挡住', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(0, 7), const Piece(type: PieceType.rook, side: Side.red));
      board.set(Position(0, 5), const Piece(type: PieceType.soldier, side: Side.red));
      final moves = getTargets(board, Position(0, 7));
      expect(moves, contains(Position(0, 6)));
      expect(moves, isNot(contains(Position(0, 5))));
      expect(moves, isNot(contains(Position(0, 4))));
    });
  });

  // ─── 炮 ────────────────────────────────────────
  group('炮', () {
    test('炮无炮架时只能走不能吃', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(1, 7), const Piece(type: PieceType.cannon, side: Side.red));
      board.set(Position(1, 0), const Piece(type: PieceType.rook, side: Side.black));
      final moves = getTargets(board, Position(1, 7));
      expect(moves, isNot(contains(Position(1, 0))));
      expect(moves, contains(Position(1, 6)));
    });

    test('炮隔一子吃', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(1, 7), const Piece(type: PieceType.cannon, side: Side.red));
      board.set(Position(1, 5), const Piece(type: PieceType.soldier, side: Side.red));
      board.set(Position(1, 0), const Piece(type: PieceType.rook, side: Side.black));
      final moves = getTargets(board, Position(1, 7));
      expect(moves, contains(Position(1, 0)));
      expect(moves, isNot(contains(Position(1, 5))));
      expect(moves, isNot(contains(Position(1, 4))));
    });

    test('炮隔一子吃（首个遇敌子可吃）', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(1, 7), const Piece(type: PieceType.cannon, side: Side.red));
      board.set(Position(1, 5), const Piece(type: PieceType.soldier, side: Side.red));
      board.set(Position(1, 3), const Piece(type: PieceType.rook, side: Side.black));
      board.set(Position(1, 0), const Piece(type: PieceType.rook, side: Side.black));
      final moves = getTargets(board, Position(1, 7));
      expect(moves, contains(Position(1, 3))); // 隔一子吃
      expect(moves, isNot(contains(Position(1, 0)))); // 隔两子不能吃
    });

    test('炮不能吃己方子', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(1, 7), const Piece(type: PieceType.cannon, side: Side.red));
      board.set(Position(1, 5), const Piece(type: PieceType.soldier, side: Side.red));
      board.set(Position(1, 3), const Piece(type: PieceType.rook, side: Side.red));
      final moves = getTargets(board, Position(1, 7));
      expect(moves, isNot(contains(Position(1, 3))));
    });

    test('炮横线吃子', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(3, 5), const Piece(type: PieceType.cannon, side: Side.red));
      board.set(Position(5, 5), const Piece(type: PieceType.soldier, side: Side.black));
      board.set(Position(8, 5), const Piece(type: PieceType.rook, side: Side.black));
      final moves = getTargets(board, Position(3, 5));
      expect(moves, contains(Position(8, 5)));
    });
  });

  // ─── 兵/卒 ─────────────────────────────────────
  group('兵/卒', () {
    test('未过河兵只能前进', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(2, 6), const Piece(type: PieceType.soldier, side: Side.red));
      final moves = getTargets(board, Position(2, 6));
      expect(moves.length, 1);
      expect(moves, contains(Position(2, 5)));
    });

    test('过河兵可以前进和横走', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(2, 4), const Piece(type: PieceType.soldier, side: Side.red));
      final moves = getTargets(board, Position(2, 4));
      expect(moves.length, 3);
      expect(moves, contains(Position(2, 3)));
      expect(moves, contains(Position(1, 4)));
      expect(moves, contains(Position(3, 4)));
    });

    test('过河兵不能后退', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(2, 4), const Piece(type: PieceType.soldier, side: Side.red));
      final moves = getTargets(board, Position(2, 4));
      expect(moves, isNot(contains(Position(2, 5))));
    });

    test('黑卒前进方向相反', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(2, 3), const Piece(type: PieceType.soldier, side: Side.black));
      final moves = getTargets(board, Position(2, 3));
      expect(moves, contains(Position(2, 4)));
      expect(moves, isNot(contains(Position(2, 2))));
    });

    test('黑卒过河可横走', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(2, 5), const Piece(type: PieceType.soldier, side: Side.black));
      final moves = getTargets(board, Position(2, 5));
      expect(moves.length, 3);
      expect(moves, contains(Position(2, 6)));
      expect(moves, contains(Position(1, 5)));
      expect(moves, contains(Position(3, 5)));
    });

    test('兵吃子', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(2, 4), const Piece(type: PieceType.soldier, side: Side.red));
      board.set(Position(2, 3), const Piece(type: PieceType.rook, side: Side.black));
      final moves = getTargets(board, Position(2, 4));
      expect(moves, contains(Position(2, 3)));
    });
  });

  // ─── 将军检测 ──────────────────────────────────
  group('将军检测', () {
    test('车将军', () {
      final board = Board();
      board.set(Position(4, 9), const Piece(type: PieceType.general, side: Side.red));
      board.set(Position(5, 0), const Piece(type: PieceType.general, side: Side.black));
      board.set(Position(0, 9), const Piece(type: PieceType.rook, side: Side.black));
      expect(Rules(board).isInCheck(Side.red), true);
    });

    test('炮将军', () {
      final board = Board();
      board.set(Position(4, 9), const Piece(type: PieceType.general, side: Side.red));
      board.set(Position(5, 0), const Piece(type: PieceType.general, side: Side.black));
      board.set(Position(4, 3), const Piece(type: PieceType.cannon, side: Side.black));
      board.set(Position(4, 6), const Piece(type: PieceType.soldier, side: Side.black));
      expect(Rules(board).isInCheck(Side.red), true);
    });

    test('马将军', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(1, 8), const Piece(type: PieceType.horse, side: Side.black));
      expect(Rules(board).isInCheck(Side.red), true);
    });

    test('兵将军', () {
      final board = Board();
      board.set(Position(4, 9), const Piece(type: PieceType.general, side: Side.red));
      board.set(Position(5, 0), const Piece(type: PieceType.general, side: Side.black));
      board.set(Position(4, 8), const Piece(type: PieceType.soldier, side: Side.black));
      expect(Rules(board).isInCheck(Side.red), true);
    });

    test('士不能将军', () {
      final board = Board();
      board.set(Position(4, 9), const Piece(type: PieceType.general, side: Side.red));
      board.set(Position(5, 0), const Piece(type: PieceType.general, side: Side.black));
      board.set(Position(4, 1), const Piece(type: PieceType.advisor, side: Side.black));
      expect(Rules(board).isInCheck(Side.red), false);
    });

    test('解将：垫子', () {
      final board = Board();
      board.set(Position(4, 9), const Piece(type: PieceType.general, side: Side.red));
      board.set(Position(5, 0), const Piece(type: PieceType.general, side: Side.black));
      board.set(Position(0, 9), const Piece(type: PieceType.rook, side: Side.black));
      expect(Rules(board).isInCheck(Side.red), true);
      board.set(Position(2, 9), const Piece(type: PieceType.rook, side: Side.red));
      expect(Rules(board).isInCheck(Side.red), false);
    });

    test('将杀检测', () {
      final board = Board();
      board.set(Position(3, 9), const Piece(type: PieceType.general, side: Side.red));
      board.set(Position(4, 0), const Piece(type: PieceType.general, side: Side.black));
      board.set(Position(0, 9), const Piece(type: PieceType.rook, side: Side.black));
      board.set(Position(0, 8), const Piece(type: PieceType.rook, side: Side.black));
      expect(Rules(board).isCheckmate(Side.red), true);
    });
  });

  // ─── 特殊规则 ──────────────────────────────────
  group('特殊规则', () {
    test('对面将（飞将）', () {
      final board = Board();
      board.set(Position(4, 0), const Piece(type: PieceType.general, side: Side.black));
      board.set(Position(4, 9), const Piece(type: PieceType.general, side: Side.red));
      final rules = Rules(board);
      expect(rules.isInCheck(Side.red), true);
      expect(rules.isInCheck(Side.black), true);
    });

    test('对面将 — 非起始位置', () {
      final board = Board();
      board.set(Position(4, 2), const Piece(type: PieceType.general, side: Side.black));
      board.set(Position(4, 7), const Piece(type: PieceType.general, side: Side.red));
      final rules = Rules(board);
      expect(rules.isInCheck(Side.red), true);
      expect(rules.isInCheck(Side.black), true);
    });

    test('对面将 — 中间有子阻挡不算', () {
      final board = Board();
      board.set(Position(4, 1), const Piece(type: PieceType.general, side: Side.black));
      board.set(Position(4, 9), const Piece(type: PieceType.general, side: Side.red));
      board.set(Position(4, 5), const Piece(type: PieceType.soldier, side: Side.red));
      final rules = Rules(board);
      expect(rules.isInCheck(Side.red), false);
      expect(rules.isInCheck(Side.black), false);
    });

    test('送将的棋被过滤', () {
      final board = Board();
      board.set(Position(4, 9), const Piece(type: PieceType.general, side: Side.red));
      board.set(Position(5, 0), const Piece(type: PieceType.general, side: Side.black));
      board.set(Position(4, 8), const Piece(type: PieceType.rook, side: Side.red));
      board.set(Position(4, 2), const Piece(type: PieceType.rook, side: Side.black));
      final rules = Rules(board);
      final moves = rules.getLegalMoves(Position(4, 8));
      for (final m in moves) {
        expect(m.col, equals(4), reason: '离开第4列会送将');
      }
      expect(moves, contains(Position(4, 7)));
    });

    test('将可以吃子解将', () {
      final board = Board();
      board.set(Position(4, 9), const Piece(type: PieceType.general, side: Side.red));
      board.set(Position(5, 0), const Piece(type: PieceType.general, side: Side.black));
      board.set(Position(5, 5), const Piece(type: PieceType.soldier, side: Side.red));
      board.set(Position(5, 9), const Piece(type: PieceType.rook, side: Side.black));
      final rules = Rules(board);
      expect(rules.isInCheck(Side.red), true);
      final moves = rules.getLegalMoves(Position(4, 9));
      expect(moves, contains(Position(5, 9)));
    });

    test('将不能走到将军位', () {
      final board = Board();
      board.set(Position(4, 9), const Piece(type: PieceType.general, side: Side.red));
      board.set(Position(5, 0), const Piece(type: PieceType.general, side: Side.black));
      board.set(Position(5, 9), const Piece(type: PieceType.rook, side: Side.black));
      final moves = Rules(board).getLegalMoves(Position(4, 9));
      expect(moves, isNot(contains(Position(3, 9))));
    });
  });
}
