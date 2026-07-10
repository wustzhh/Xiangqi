import 'board.dart';
import 'piece.dart';

/// 规则引擎 — 生成合法走法、检测将军/将杀
///
/// 中国象棋规则：
/// - 帅/将：九宫内走一步，不能对面
/// - 士/仕：九宫内走斜线
/// - 象/相：走田字，不能过河，塞象眼
/// - 马：走日字，蹩马腿
/// - 车：直线走，不能越子
/// - 炮：直线走，吃子须隔一子
/// - 兵/卒：过河前只能前进，过河后可横走
class Rules {
  final Board board;

  const Rules(this.board);

  // ─── 走法生成 ─────────────────────────────────────

  /// 生成某位置所有合法走法
  List<Position> getLegalMoves(Position pos) {
    final piece = board.at(pos);
    if (piece == null) return [];

    final rawMoves = _getRawMoves(pos, piece);
    // 过滤：走完后不能被将军
    return rawMoves.where((to) {
      final testBoard = board.copy();
      testBoard.move(pos, to);
      return !_isInCheck(testBoard, piece.side);
    }).toList();
  }

  /// 生成某方所有合法走法（按位置）
  Map<Position, List<Position>> allLegalMoves(Side side) {
    final result = <Position, List<Position>>{};
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final pos = Position(c, r);
        final piece = board.at(pos);
        if (piece != null && piece.side == side) {
          final moves = getLegalMoves(pos);
          if (moves.isNotEmpty) {
            result[pos] = moves;
          }
        }
      }
    }
    return result;
  }

  /// 获取某位置所有可走到的位置（含空位和敌方棋子位置，不含友军占据）
  ///
  /// 用于显示攻击范围：空位=可走到，敌方棋子=可吃掉
  List<Position> getRawMoves(Position pos) {
    final piece = board.at(pos);
    if (piece == null) return [];
    return _getRawMoves(pos, piece);
  }

  /// 获取某棋子护住的友军位置
  ///
  /// "护住"指：如果该位置的友军被敌方吃掉，当前棋子可以回吃
  /// - 车/炮：沿直线滑动，遇到的第一颗友军被护住
  ///   - 炮的特殊性：跳过第一颗棋子（炮架），第二颗友军也可以被护住
  /// - 马/象/士/兵/将：攻击范围内的友军（不过滤己方占据的方格）
  List<Position> getProtectedFriendlies(Position pos) {
    final piece = board.at(pos);
    if (piece == null) return [];
    final result = <Position>{};

    switch (piece.type) {
      case PieceType.rook:
      case PieceType.cannon:
        {
          const dirs = [(0, -1), (0, 1), (-1, 0), (1, 0)];
          for (final d in dirs) {
            int c = pos.col + d.$1;
            int r = pos.row + d.$2;
            int piecesPassed = 0;
            while (c >= 0 && c <= 8 && r >= 0 && r <= 9) {
              final target = board.at(Position(c, r));
              if (target != null) {
                piecesPassed++;
                if (piece.type == PieceType.rook) {
                  // 车：遇到第一颗子
                  if (target.side == piece.side) result.add(Position(c, r));
                  break;
                } else {
                  // 炮：跳过炮架，检查第二颗
                  if (piecesPassed == 2) {
                    if (target.side == piece.side) result.add(Position(c, r));
                    break;
                  }
                }
              }
              c += d.$1;
              r += d.$2;
            }
          }
        }
        break;

      default:
        // 非滑动棋子：直接计算攻击范围内的友军
        result.addAll(_computeNonSlidingProtected(pos, piece));
        break;
    }

    return result.toList();
  }

  /// 非滑动棋子的护子计算（不过滤己方占据）
  List<Position> _computeNonSlidingProtected(Position pos, Piece piece) {
    final f = <Position>[];
    switch (piece.type) {
      case PieceType.horse:
        {
          const dirs = [
            (0, -1, -1, -2), (0, -1, 1, -2),
            (-1, 0, -2, -1), (1, 0, 2, -1),
            (-1, 0, -2, 1), (1, 0, 2, 1),
            (0, 1, -1, 2), (0, 1, 1, 2),
          ];
          for (final d in dirs) {
            final leg = Position(pos.col + d.$1, pos.row + d.$2);
            if (!leg.isValid) continue;
            if (board.at(leg) != null) continue;
            final t = Position(pos.col + d.$3, pos.row + d.$4);
            if (!t.isValid) continue;
            final p = board.at(t);
            if (p != null && p.side == piece.side) f.add(t);
          }
        }
        break;
      case PieceType.elephant:
        {
          const dirs = [
            (-2, -2, -1, -1), (-2, 2, -1, 1),
            (2, -2, 1, -1), (2, 2, 1, 1),
          ];
          final rows = piece.side == Side.red ? [5, 6, 7, 8, 9] : [0, 1, 2, 3, 4];
          for (final d in dirs) {
            final t = Position(pos.col + d.$1, pos.row + d.$2);
            if (!t.isValid || !rows.contains(t.row)) continue;
            final eye = Position(pos.col + d.$3, pos.row + d.$4);
            if (board.at(eye) != null) continue;
            final p = board.at(t);
            if (p != null && p.side == piece.side) f.add(t);
          }
        }
        break;
      case PieceType.advisor:
        {
          const pc = [3, 4, 5];
          final pr = piece.side == Side.red ? [7, 8, 9] : [0, 1, 2];
          for (final d in [(-1, -1), (-1, 1), (1, -1), (1, 1)]) {
            final t = Position(pos.col + d.$1, pos.row + d.$2);
            if (!pc.contains(t.col) || !pr.contains(t.row)) continue;
            final p = board.at(t);
            if (p != null && p.side == piece.side) f.add(t);
          }
        }
        break;
      case PieceType.general:
        {
          const pc = [3, 4, 5];
          final pr = piece.side == Side.red ? [7, 8, 9] : [0, 1, 2];
          for (final d in [(0, -1), (0, 1), (-1, 0), (1, 0)]) {
            final t = Position(pos.col + d.$1, pos.row + d.$2);
            if (!pc.contains(t.col) || !pr.contains(t.row)) continue;
            final p = board.at(t);
            if (p != null && p.side == piece.side) f.add(t);
          }
        }
        break;
      case PieceType.soldier:
        {
          final fwd = piece.side == Side.red ? -1 : 1;
          final crossed = piece.side == Side.red ? pos.row <= 4 : pos.row >= 5;
          final t0 = Position(pos.col, pos.row + fwd);
          if (t0.isValid) {
            final p = board.at(t0);
            if (p != null && p.side == piece.side) f.add(t0);
          }
          if (crossed) {
            for (final dc in [-1, 1]) {
              final t = Position(pos.col + dc, pos.row);
              if (t.isValid) {
                final p = board.at(t);
                if (p != null && p.side == piece.side) f.add(t);
              }
            }
          }
        }
        break;
      default:
        break;
    }
    return f;
  }

  // ─── 走法生成（不校验将军） ────────────────────────

  List<Position> _getRawMoves(Position pos, Piece piece) {
    switch (piece.type) {
      case PieceType.general:
        return _generalMoves(pos, piece);
      case PieceType.advisor:
        return _advisorMoves(pos, piece);
      case PieceType.elephant:
        return _elephantMoves(pos, piece);
      case PieceType.horse:
        return _horseMoves(pos, piece);
      case PieceType.rook:
        return _rookMoves(pos, piece);
      case PieceType.cannon:
        return _cannonMoves(pos, piece);
      case PieceType.soldier:
        return _soldierMoves(pos, piece);
    }
  }

  /// 将/帅：九宫内走一步
  List<Position> _generalMoves(Position pos, Piece piece) {
    final moves = <Position>[];
    final palaceCols = [3, 4, 5];
    final palaceRows = piece.side == Side.red ? [7, 8, 9] : [0, 1, 2];

    const dirs = [
      (0, -1),
      (0, 1),
      (-1, 0),
      (1, 0)
    ];
    for (final d in dirs) {
      final to = Position(pos.col + d.$1, pos.row + d.$2);
      if (!palaceCols.contains(to.col) || !palaceRows.contains(to.row)) continue;
      final target = board.at(to);
      if (target == null || target.side != piece.side) {
        moves.add(to);
      }
    }

    // 帅对面：如果两将同列且中间无子，可以将对方将
    _addFlyingGeneralMove(pos, piece, moves);

    return moves;
  }

  /// 对面将（飞将）：两将同列无子间隔时可吃
  void _addFlyingGeneralMove(Position pos, Piece piece, List<Position> moves) {
    final opponentGeneralRow = piece.side == Side.red ? 0 : 9;
    // 检查同列
    for (int r = 0; r < 10; r++) {
      final p = board.at(Position(pos.col, r));
      if (p != null && p.type == PieceType.general && p.side != piece.side) {
        // 检查中间是否有子
        final minR = pos.row < r ? pos.row : r;
        final maxR = pos.row < r ? r : pos.row;
        bool blocked = false;
        for (int mr = minR + 1; mr < maxR; mr++) {
          if (board.at(Position(pos.col, mr)) != null) {
            blocked = true;
            break;
          }
        }
        if (!blocked) {
          moves.add(Position(pos.col, opponentGeneralRow));
        }
        break;
      }
    }
  }

  /// 士/仕：九宫内走斜线
  List<Position> _advisorMoves(Position pos, Piece piece) {
    final moves = <Position>[];
    final palaceCols = [3, 4, 5];
    final palaceRows = piece.side == Side.red ? [7, 8, 9] : [0, 1, 2];

    const dirs = [(-1, -1), (-1, 1), (1, -1), (1, 1)];
    for (final d in dirs) {
      final to = Position(pos.col + d.$1, pos.row + d.$2);
      if (!palaceCols.contains(to.col) || !palaceRows.contains(to.row)) continue;
      final target = board.at(to);
      if (target == null || target.side != piece.side) {
        moves.add(to);
      }
    }
    return moves;
  }

  /// 象/相：田字走，不能过河，塞象眼
  List<Position> _elephantMoves(Position pos, Piece piece) {
    final moves = <Position>[];
    final redSide = piece.side == Side.red;
    final rows = redSide ? [5, 6, 7, 8, 9] : [0, 1, 2, 3, 4];

    const dirs = [
      (-2, -2, -1, -1),
      (-2, 2, -1, 1),
      (2, -2, 1, -1),
      (2, 2, 1, 1),
    ];
    for (final d in dirs) {
      final to = Position(pos.col + d.$1, pos.row + d.$2);
      if (to.col < 0 || to.col > 8 || !rows.contains(to.row)) continue;
      // 塞象眼
      final eye = Position(pos.col + d.$3, pos.row + d.$4);
      if (board.at(eye) != null) continue;
      final target = board.at(to);
      if (target == null || target.side != piece.side) {
        moves.add(to);
      }
    }
    return moves;
  }

  /// 马：日字走，蹩马腿
  List<Position> _horseMoves(Position pos, Piece piece) {
    final moves = <Position>[];
    // 蹩腿方向：(legDCol, legDRow, dCol, dRow)
    const dirs = [
      (0, -1, -1, -2), // 左上
      (0, -1, 1, -2), // 右上
      (-1, 0, -2, -1), // 左上一
      (1, 0, 2, -1), // 右上一
      (-1, 0, -2, 1), // 左下一
      (1, 0, 2, 1), // 右下一
      (0, 1, -1, 2), // 左下
      (0, 1, 1, 2), // 右下
    ];
    for (final d in dirs) {
      final legCol = pos.col + d.$1;
      final legRow = pos.row + d.$2;
      final toCol = pos.col + d.$3;
      final toRow = pos.row + d.$4;
      // 蹩腿检测
      if (legCol < 0 || legCol > 8 || legRow < 0 || legRow > 9) continue;
      if (board.at(Position(legCol, legRow)) != null) continue;
      final to = Position(toCol, toRow);
      if (!to.isValid) continue;
      final target = board.at(to);
      if (target == null || target.side != piece.side) {
        moves.add(to);
      }
    }
    return moves;
  }

  /// 车：直线走
  List<Position> _rookMoves(Position pos, Piece piece) {
    return _slideMoves(pos, piece, false);
  }

  /// 炮：直线走，吃子须隔一子
  List<Position> _cannonMoves(Position pos, Piece piece) {
    return _slideMoves(pos, piece, true);
  }

  /// 滑动走法（车/炮共用）
  List<Position> _slideMoves(Position pos, Piece piece, bool isCannon) {
    final moves = <Position>[];
    const dirs = [(0, -1), (0, 1), (-1, 0), (1, 0)];

    for (final d in dirs) {
      int c = pos.col + d.$1;
      int r = pos.row + d.$2;
      bool jumped = false;

      while (c >= 0 && c <= 8 && r >= 0 && r <= 9) {
        final target = board.at(Position(c, r));
        if (target == null) {
          if (!isCannon || !jumped) {
            moves.add(Position(c, r));
          }
        } else {
          if (!isCannon) {
            // 车：遇到敌方可以吃
            if (target.side != piece.side) {
              moves.add(Position(c, r));
            }
          } else {
            // 炮
            if (!jumped) {
              // 还没隔子，跳过此子
              jumped = true;
            } else {
              // 已经隔了一个子，可以吃
              if (target.side != piece.side) {
                moves.add(Position(c, r));
              }
              break;
            }
          }
          if (!isCannon) break; // 车遇子即停
          // 炮跳过炮架后继续寻找吃子目标（不在这里 break）
        }
        c += d.$1;
        r += d.$2;
      }
    }
    return moves;
  }

  /// 兵/卒：过河前只能前进，过河后可横走
  List<Position> _soldierMoves(Position pos, Piece piece) {
    final moves = <Position>[];
    final forward = piece.side == Side.red ? -1 : 1;
    final crossedRiver = piece.side == Side.red ? pos.row <= 4 : pos.row >= 5;

    // 前进
    final fwd = Position(pos.col, pos.row + forward);
    if (fwd.isValid) {
      final target = board.at(fwd);
      if (target == null || target.side != piece.side) {
        moves.add(fwd);
      }
    }

    // 过河后可横走
    if (crossedRiver) {
      for (final dc in [-1, 1]) {
        final to = Position(pos.col + dc, pos.row);
        if (to.isValid) {
          final target = board.at(to);
          if (target == null || target.side != piece.side) {
            moves.add(to);
          }
        }
      }
    }

    return moves;
  }

  // ─── 将军检测 ─────────────────────────────────────

  /// 检测某方是否被将军
  bool isInCheck(Side side) => _isInCheck(board, side);

  /// 检测某方是否被将杀（无合法走法且被将军）
  bool isCheckmate(Side side) {
    if (!_isInCheck(board, side)) return false;
    return _noLegalMoves(side);
  }

  /// 检测某方是否困毙（无合法走法但不被将军）
  bool isStalemate(Side side) {
    if (_isInCheck(board, side)) return false;
    return _noLegalMoves(side);
  }

  /// 在给定棋盘上检测某方是否被将军
  static bool _isInCheck(Board board, Side side) {
    // 找将/帅位置
    Position? generalPos;
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final p = board.at(Position(c, r));
        if (p != null && p.type == PieceType.general && p.side == side) {
          generalPos = Position(c, r);
        }
      }
    }
    if (generalPos == null) return true; // 被吃了也算输

    final opponent = side.opponent;
    final rules = Rules(board);

    // 检查对方所有棋子是否能攻击到将
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final p = board.at(Position(c, r));
        if (p != null && p.side == opponent) {
          final rawMoves = rules._getRawMoves(Position(c, r), p);
          if (rawMoves.contains(generalPos)) return true;
        }
      }
    }

    return false;
  }

  /// 某方是否无合法走法
  bool _noLegalMoves(Side side) {
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final pos = Position(c, r);
        final p = board.at(pos);
        if (p != null && p.side == side) {
          final moves = getLegalMoves(pos);
          if (moves.isNotEmpty) return false;
        }
      }
    }
    return true;
  }
}
