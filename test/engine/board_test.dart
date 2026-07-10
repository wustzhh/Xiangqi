import 'package:test/test.dart';
import 'package:xiangqi/engine/board.dart';
import 'package:xiangqi/engine/piece.dart';

void main() {
  group('Board - 棋盘数据模型', () {
    test('初始局面正确', () {
      final board = Board.initial();

      // 红方将帅
      final generalRed = board.at(Position(4, 9));
      expect(generalRed, isNotNull);
      expect(generalRed!.type, PieceType.general);
      expect(generalRed.side, Side.red);

      // 黑方将帅
      final generalBlack = board.at(Position(4, 0));
      expect(generalBlack, isNotNull);
      expect(generalBlack!.type, PieceType.general);
      expect(generalBlack.side, Side.black);

      // 红方车
      final rookRed = board.at(Position(0, 9));
      expect(rookRed, isNotNull);
      expect(rookRed!.type, PieceType.rook);
      expect(rookRed.side, Side.red);

      // 红方兵在 row 6
      for (int c = 0; c < 9; c += 2) {
        final soldier = board.at(Position(c, 6));
        expect(soldier, isNotNull);
        expect(soldier!.type, PieceType.soldier);
        expect(soldier.side, Side.red);
      }

      // 黑方卒在 row 3
      for (int c = 0; c < 9; c += 2) {
        final soldier = board.at(Position(c, 3));
        expect(soldier, isNotNull);
        expect(soldier!.type, PieceType.soldier);
        expect(soldier.side, Side.black);
      }

      // 空格
      expect(board.at(Position(0, 1)), isNull);
      expect(board.at(Position(4, 4)), isNull);
      expect(board.at(Position(4, 5)), isNull);
    });

    test('移动棋子', () {
      final board = Board.initial();
      final from = Position(1, 9); // 马
      final to = Position(2, 7);
      final captured = board.move(from, to);

      expect(board.at(from), isNull);
      expect(board.at(to), isNotNull);
      expect(captured, isNull);
    });

    test('深拷贝不共享引用', () {
      final board = Board.initial();
      final copy = board.copy();

      // 修改副本
      copy.move(Position(1, 9), Position(2, 7));
      expect(board.at(Position(1, 9)), isNotNull);
      expect(copy.at(Position(1, 9)), isNull);
    });

    test('查找某方棋子', () {
      final board = Board.initial();
      final redPieces = board.findPieces(Side.red);
      final blackPieces = board.findPieces(Side.black);

      expect(redPieces.length, 16);
      expect(blackPieces.length, 16);
    });

    test('无效位置抛出异常', () {
      final board = Board.initial();
      expect(() => board.at(Position(-1, 0)), throwsRangeError);
    });
  });
}
