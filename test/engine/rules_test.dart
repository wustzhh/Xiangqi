import 'package:test/test.dart';
import 'package:xiangqi/engine/board.dart';
import 'package:xiangqi/engine/piece.dart';
import 'package:xiangqi/engine/rules.dart';

void main() {
  // 通用：将帅放在不同列，避免飞将干扰
  final _redGeneral = Position(3, 9);
  final _blackGeneral = Position(4, 0);

  void setupGenerals(Board board) {
    board.set(_redGeneral, const Piece(type: PieceType.general, side: Side.red));
    board.set(_blackGeneral, const Piece(type: PieceType.general, side: Side.black));
  }

  group('Rules - 走法生成', () {
    test('初始局面，红方有约44种合法走法', () {
      final board = Board.initial();
      final rules = Rules(board);
      final moves = rules.allLegalMoves(Side.red);

      int totalMoves = 0;
      for (final entry in moves.entries) {
        totalMoves += entry.value.length;
      }
      expect(totalMoves, greaterThan(30));
      expect(totalMoves, lessThan(60));
    });

    test('初始局面，兵只能前进', () {
      final board = Board.initial();
      final rules = Rules(board);

      for (int c = 0; c < 9; c += 2) {
        final moves = rules.getLegalMoves(Position(c, 6));
        expect(moves.length, 1);
        expect(moves[0].row, 5);
        expect(moves[0].col, c);
      }
    });

    test('过河兵可以横走', () {
      final board = Board();
      setupGenerals(board);
      // 黑卒在 (3,5)，已过河
      board.set(Position(3, 5), const Piece(type: PieceType.soldier, side: Side.black));
      final rules = Rules(board);
      final moves = rules.getLegalMoves(Position(3, 5));

      // 黑方前进方向是 row+1，所以 (3,6) 是前进
      // 左横 (2,5)，右横 (4,5) = 共3个
      expect(moves.length, 3);
      expect(moves, contains(Position(2, 5))); // 左横
      expect(moves, contains(Position(3, 6))); // 前进
      expect(moves, contains(Position(4, 5))); // 右横
    });
  });

  group('Rules - 将军检测', () {
    test('初始局面不被将军', () {
      final board = Board.initial();
      final rules = Rules(board);
      expect(rules.isInCheck(Side.red), false);
      expect(rules.isInCheck(Side.black), false);
    });

    test('车将军检测', () {
      final board = Board();
      setupGenerals(board);
      // 黑车在 (8,9)，与红帅 (3,9) 同行
      board.set(Position(8, 9), const Piece(type: PieceType.rook, side: Side.black));
      final rules = Rules(board);
      expect(rules.isInCheck(Side.red), true);
    });

    test('马将军检测', () {
      final board = Board();
      setupGenerals(board);
      // 黑马在 (1,8)，可走到 (3,9) 将军（帅的位置）
      // 蹩腿位置 (2,8) 为空
      board.set(Position(1, 8), const Piece(type: PieceType.horse, side: Side.black));
      final rules = Rules(board);
      expect(rules.isInCheck(Side.red), true);
    });

    test('将杀检测', () {
      final board = Board();
      board.set(Position(3, 9), const Piece(type: PieceType.general, side: Side.red));
      board.set(Position(4, 0), const Piece(type: PieceType.general, side: Side.black));
      // 黑车封 row 9
      board.set(Position(0, 9), const Piece(type: PieceType.rook, side: Side.black));
      // 另一个黑车封 row 8，让帅无法下移
      board.set(Position(0, 8), const Piece(type: PieceType.rook, side: Side.black));
      final rules = Rules(board);
      expect(rules.isCheckmate(Side.red), true);
    });

    test('对面将（飞将）— 非起始位置', () {
      // 黑将在(4,1)，红帅在(4,8)— 同列、不在 row 0/9
      // 旧版 Bug：opponentGeneralRow 硬编码为 0/9，检测不到此情况
      final board = Board();
      board.set(Position(4, 1), const Piece(type: PieceType.general, side: Side.black));
      board.set(Position(4, 8), const Piece(type: PieceType.general, side: Side.red));
      final rules = Rules(board);
      expect(rules.isInCheck(Side.red), true);
      expect(rules.isInCheck(Side.black), true);
    });

    test('对面将（飞将）— 中间有子不算', () {
      final board = Board();
      board.set(Position(4, 1), const Piece(type: PieceType.general, side: Side.black));
      board.set(Position(4, 9), const Piece(type: PieceType.general, side: Side.red));
      // 中间有红兵挡住
      board.set(Position(4, 5), const Piece(type: PieceType.soldier, side: Side.red));
      final rules = Rules(board);
      expect(rules.isInCheck(Side.red), false);
      expect(rules.isInCheck(Side.black), false);
    });

    test('对面将（飞将）', () {
      final board = Board();
      board.set(Position(4, 0), const Piece(type: PieceType.general, side: Side.black));
      board.set(Position(4, 9), const Piece(type: PieceType.general, side: Side.red));
      final rules = Rules(board);
      expect(rules.isInCheck(Side.red), true);
      expect(rules.isInCheck(Side.black), true);
    });
  });

  group('Rules - 棋子走法', () {
    test('象不能过河', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(2, 5), const Piece(type: PieceType.elephant, side: Side.red));
      final rules = Rules(board);
      final moves = rules.getLegalMoves(Position(2, 5));
      for (final move in moves) {
        expect(move.row, greaterThanOrEqualTo(5));
      }
    });

    test('塞象眼', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(2, 7), const Piece(type: PieceType.elephant, side: Side.red));
      // (3,6) 是 (2,7)->(4,5) 和 (2,7)->(4,9) 的象眼
      board.set(Position(3, 6), const Piece(type: PieceType.soldier, side: Side.black));
      final rules = Rules(board);
      final moves = rules.getLegalMoves(Position(2, 7));
      // (3,6) 是 (2,7)->(4,5) 的象眼，不阻塞 (4,9)
      expect(moves.length, 3);
      expect(moves, contains(Position(0, 5)));
      expect(moves, contains(Position(0, 9)));
      expect(moves, contains(Position(4, 9)));
      expect(moves, isNot(contains(Position(4, 5))));
    });

    test('蹩马腿', () {
      final board = Board();
      setupGenerals(board);
      // 红马在 (2,2)，(2,1) 有红车蹩住向下的腿
      board.set(Position(2, 2), const Piece(type: PieceType.horse, side: Side.red));
      board.set(Position(2, 1), const Piece(type: PieceType.rook, side: Side.red));
      final rules = Rules(board);
      final moves = rules.getLegalMoves(Position(2, 2));
      // 被蹩腿后不能走到 (1,0) 和 (3,0)
      expect(moves, isNot(contains(Position(1, 0))));
      expect(moves, isNot(contains(Position(3, 0))));
      // 其他走法仍然有效
      expect(moves.length, 6);
    });

    test('炮隔子吃', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(1, 7), const Piece(type: PieceType.cannon, side: Side.red));
      board.set(Position(1, 5), const Piece(type: PieceType.soldier, side: Side.red)); // 炮架
      board.set(Position(1, 0), const Piece(type: PieceType.rook, side: Side.black)); // 可吃
      final rules = Rules(board);
      final moves = rules.getLegalMoves(Position(1, 7));
      // 炮可以走到空位：上(1,6)，下(1,8)(1,9)，左右等
      expect(moves, contains(Position(1, 6)));
      expect(moves, contains(Position(1, 8)));
      expect(moves, contains(Position(0, 7)));
      // 炮可以隔兵吃车
      expect(moves, contains(Position(1, 0)));
      // 兵在 (1,5) 不能走（己方）
      expect(moves, isNot(contains(Position(1, 5))));
      // 炮跳过兵后不能停到空位 (1,4~1,1)
      expect(moves, isNot(contains(Position(1, 4))));
      expect(moves, isNot(contains(Position(1, 1))));
    });

    test('车直线走', () {
      final board = Board();
      setupGenerals(board);
      board.set(Position(0, 7), const Piece(type: PieceType.rook, side: Side.red));
      board.set(Position(0, 4), const Piece(type: PieceType.soldier, side: Side.black)); // 可吃
      final rules = Rules(board);
      final moves = rules.getLegalMoves(Position(0, 7));
      // 车可以走 (0,5)(0,6) 空位，吃 (0,4)
      expect(moves, contains(Position(0, 4)));
      expect(moves, contains(Position(0, 5)));
      expect(moves, contains(Position(0, 6)));
      // 车不能越过 (0,4) 到 (0,3) 以下
      expect(moves, isNot(contains(Position(0, 3))));
    });
  });
}
