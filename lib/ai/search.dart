import 'dart:math';
import '../engine/board.dart';
import '../engine/piece.dart';
import '../engine/rules.dart';
import 'evaluator.dart';

/// 走法评分（用于走法排序）
class _MoveScore {
  final Position from;
  final Position to;
  final int score;
  const _MoveScore(this.from, this.to, this.score);
}

/// 搜索引擎 — Minimax + Alpha-Beta 剪枝
///
/// 优化：
/// - 原地走棋（不 copy，快 5-10 倍）
/// - 杀手走法（Killer Move）
/// - 静态搜索（Quiescence Search）
/// - 迭代加深保留最佳走法
class SearchEngine {
  final Evaluator _evaluator = Evaluator();
  int _nodesSearched = 0;
  bool _cancelled = false;
  int _maxDepth = 0;
  Stopwatch _stopwatch = Stopwatch();
  int _timeLimitMs = 8000;

  // 杀手走法表 [depth][slot]（0 和 1 两个槽）
  final List<List<_MoveScore?>> _killers =
      List.generate(64, (_) => List.filled(2, null));

  // 迭代加深保留的上层最佳走法
  _MoveScore? _bestMoveFromPrev;

  /// 搜索最佳走法
  MoveResult? findBestMove(Board board, Side side, int maxDepth,
      {int? timeLimitMs}) {
    _cancelled = false;
    _nodesSearched = 0;
    _maxDepth = maxDepth;
    _stopwatch = Stopwatch()..start();
    if (timeLimitMs != null) _timeLimitMs = timeLimitMs;
    // 清空杀手走法
    for (int i = 0; i < _killers.length; i++) {
      _killers[i][0] = null;
      _killers[i][1] = null;
    }

    final rules = Rules(board);
    final allMoves = rules.allLegalMoves(side);
    if (allMoves.isEmpty) return null;

    // 如果只有一种走法，直接返回
    if (allMoves.length == 1 && allMoves.values.first.length == 1) {
      final entry = allMoves.entries.first;
      return MoveResult(
        from: entry.key,
        to: entry.value.first,
        score: 0,
        depth: 0,
        nodesSearched: 1,
      );
    }

    MoveResult? bestResult;
    final isMaximizing = side == Side.red;

    // 收集走法，上层最佳优先
    List<_MoveScore> scoredMoves = [];
    for (final entry in allMoves.entries) {
      for (final to in entry.value) {
        int score;
        if (_bestMoveFromPrev != null &&
            _bestMoveFromPrev!.from == entry.key &&
            _bestMoveFromPrev!.to == to) {
          score = 100000; // 上层最佳走法优先
        } else {
          score = _scoreMove(board, entry.key, to, side);
        }
        scoredMoves.add(_MoveScore(entry.key, to, score));
      }
    }

    // 走法排序
    scoredMoves.sort((a, b) => b.score.compareTo(a.score));

    for (final move in scoredMoves) {
      if (_cancelled) break;

      final captured = board.moveInPlace(move.from, move.to);
      final piece = board.at(move.to)!;
      final eval = _alphaBeta(board, maxDepth - 1, -100000, 100000,
          !isMaximizing, 0);
      board.undoMoveInPlace(move.from, move.to, piece, captured);

      if (bestResult == null ||
          (isMaximizing && eval > bestResult.score) ||
          (!isMaximizing && eval < bestResult.score)) {
        bestResult = MoveResult(
          from: move.from,
          to: move.to,
          score: eval,
          depth: maxDepth,
          nodesSearched: _nodesSearched,
        );
        // 保存最佳走法
        _bestMoveFromPrev = move;
      }
    }

    return bestResult;
  }

  /// 迭代加深搜索（大师级）
  MoveResult? findBestMoveIterative(Board board, Side side, int maxDepth,
      {int depthTimeLimitMs = 15000}) {
    MoveResult? best;
    _bestMoveFromPrev = null; // 上层最佳走法每轮重置
    final deadline = Stopwatch()..start();
    for (int d = 2; d <= maxDepth; d += 2) {
      if (_cancelled) break;
      final remaining =
          (depthTimeLimitMs - deadline.elapsedMilliseconds).clamp(2000, depthTimeLimitMs);
      final result = findBestMove(board, side, d, timeLimitMs: remaining);
      if (result != null) {
        best = result;
        // 更新上层最佳走法供下一层用
      }
    }
    return best;
  }

  void cancel() => _cancelled = true;

  /// Alpha-Beta 搜索
  int _alphaBeta(Board board, int depth, int alpha, int beta,
      bool maximizing, int ply) {
    _nodesSearched++;

    final side = maximizing ? Side.red : Side.black;
    final rules = Rules(board);

    // 检测将杀/困毙
    if (rules.isCheckmate(side)) {
      return maximizing
          ? -99999 + (_maxDepth - depth)
          : 99999 - (_maxDepth - depth);
    }
    if (rules.isStalemate(side)) {
      return 0;
    }

    // 到达叶节点：做静态搜索（只搜吃子）
    if (depth == 0) {
      return _quiesce(board, alpha, beta, maximizing, 0);
    }

    final allMoves = rules.allLegalMoves(side);
    if (allMoves.isEmpty) {
      return maximizing ? -99999 : 99999;
    }

    // 生成走法并排序（杀手走法靠前）
    List<_MoveScore> moves = [];
    for (final entry in allMoves.entries) {
      for (final to in entry.value) {
        int score = _scoreMove(board, entry.key, to, side);
        // 检查杀手走法
        if (_killers[ply][0] != null &&
            _killers[ply][0]!.from == entry.key &&
            _killers[ply][0]!.to == to) {
          score += 5000;
        } else if (_killers[ply][1] != null &&
            _killers[ply][1]!.from == entry.key &&
            _killers[ply][1]!.to == to) {
          score += 3000;
        }
        moves.add(_MoveScore(entry.key, to, score));
      }
    }
    moves.sort((a, b) => b.score.compareTo(a.score));

    int bestValue = maximizing ? -100000 : 100000;
    _MoveScore? bestMove;

    for (final move in moves) {
      if (_cancelled) return 0;
      if (_stopwatch.elapsedMilliseconds > _timeLimitMs) {
        _cancelled = true;
        return 0;
      }

      final captured = board.moveInPlace(move.from, move.to);
      final piece = board.at(move.to)!;
      final value = _alphaBeta(
          board, depth - 1, alpha, beta, !maximizing, ply + 1);
      board.undoMoveInPlace(move.from, move.to, piece, captured);

      if (maximizing) {
        if (value > bestValue) {
          bestValue = value;
          bestMove = move;
        }
        alpha = max(alpha, value);
      } else {
        if (value < bestValue) {
          bestValue = value;
          bestMove = move;
        }
        beta = min(beta, value);
      }

      if (beta <= alpha) {
        // 剪枝：记录杀手走法
        if (bestMove != null) {
          _killers[ply][1] = _killers[ply][0];
          _killers[ply][0] = bestMove;
        }
        break;
      }
    }

    return bestValue;
  }

  /// 静态搜索（Quiescence Search）：只搜索吃子走法
  /// 解决"水平线效应"——到大 depth=0 后继续搜吃子
  int _quiesce(Board board, int alpha, int beta, bool maximizing, int ply) {
    _nodesSearched++;

    // 先评估当前局面
    final standPat = _evaluator.evaluate(board);
    if (maximizing) {
      if (standPat >= beta) return beta;
      if (standPat > alpha) alpha = standPat;
    } else {
      if (standPat <= alpha) return alpha;
      if (standPat < beta) beta = standPat;
    }

    final side = maximizing ? Side.red : Side.black;
    final rules = Rules(board);

    // 检测将杀/困毙
    if (rules.isCheckmate(side)) return maximizing ? -99999 + ply : 99999 - ply;
    if (rules.isStalemate(side)) return 0;

    // 只生成吃子走法
    final allMoves = rules.allLegalMoves(side);
    if (allMoves.isEmpty) {
      return maximizing ? -99999 + ply : 99999 - ply;
    }

    // 只保留有吃子的走法，按被吃子价值排序
    List<_MoveScore> capMoves = [];
    for (final entry in allMoves.entries) {
      for (final to in entry.value) {
        final captured = board.at(to);
        if (captured == null) continue;
        capMoves.add(_MoveScore(
            entry.key, to, _captureValue(captured.type) * 10));
      }
    }
    if (capMoves.isEmpty) return standPat;
    capMoves.sort((a, b) => b.score.compareTo(a.score));

    for (final move in capMoves) {
      if (_cancelled) return standPat;
      if (_stopwatch.elapsedMilliseconds > _timeLimitMs) {
        return standPat;
      }
      // 静态搜索深度限制（防无限递归）
      if (ply > 8) return standPat;

      final captured = board.moveInPlace(move.from, move.to);
      final piece = board.at(move.to)!;
      final value = _quiesce(board, alpha, beta, !maximizing, ply + 1);
      board.undoMoveInPlace(move.from, move.to, piece, captured);

      if (maximizing) {
        if (value >= beta) return beta;
        if (value > alpha) alpha = value;
      } else {
        if (value <= alpha) return alpha;
        if (value < beta) beta = value;
      }
    }

    return standPat;
  }

  /// 走法评分：吃子优先 + 杀手优先
  int _scoreMove(Board board, Position from, Position to, Side side) {
    int score = 0;

    final captured = board.at(to);
    if (captured != null) {
      score += _captureValue(captured.type) * 10;
    }

    final piece = board.at(from);
    if (piece != null && piece.type == PieceType.soldier) {
      final crossed = side == Side.red ? to.row <= 4 : to.row >= 5;
      if (crossed) score += 50;
    }
    if (to.col == 4 &&
        (piece?.type == PieceType.rook || piece?.type == PieceType.cannon)) {
      score += 20;
    }

    return score;
  }

  int _captureValue(PieceType type) {
    switch (type) {
      case PieceType.rook:
        return 90;
      case PieceType.cannon:
        return 50;
      case PieceType.horse:
        return 45;
      case PieceType.advisor:
        return 20;
      case PieceType.elephant:
        return 20;
      case PieceType.soldier:
        return 10;
      case PieceType.general:
        return 1000;
    }
  }
}

/// 搜索返回结果
class MoveResult {
  final Position from;
  final Position to;
  final int score;
  final int depth;
  final int nodesSearched;

  const MoveResult({
    required this.from,
    required this.to,
    required this.score,
    required this.depth,
    required this.nodesSearched,
  });
}
