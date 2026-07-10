import '../engine/board.dart';
import '../engine/piece.dart';
import 'search.dart';
import 'evaluator.dart';

/// Isolate 搜索入口参数（必须是纯数据，可跨 Isolate 传递）
class SearchTask {
  final List<int> boardInts;
  final int sideIndex; // 0=red, 1=black
  final int depth;
  final int timeLimitMs;
  final bool useIterative;
  final int iterativeTimeLimitMs;

  const SearchTask({
    required this.boardInts,
    required this.sideIndex,
    required this.depth,
    this.timeLimitMs = 8000,
    this.useIterative = false,
    this.iterativeTimeLimitMs = 20000,
  });
}

/// Isolate 搜索返回结果
class SearchResult {
  final int fromCol;
  final int fromRow;
  final int toCol;
  final int toRow;
  final int score;
  final int depth;
  final int nodesSearched;

  const SearchResult({
    required this.fromCol,
    required this.fromRow,
    required this.toCol,
    required this.toRow,
    required this.score,
    required this.depth,
    required this.nodesSearched,
  });

  /// 转为 MoveResult
  MoveResult? toMoveResult() {
    final from = Position(fromCol, fromRow);
    final to = Position(toCol, toRow);
    if (!from.isValid || !to.isValid) return null;
    return MoveResult(
      from: from,
      to: to,
      score: score,
      depth: depth,
      nodesSearched: nodesSearched,
    );
  }
}

/// 在 Isolate 中运行的搜索入口（顶层函数，不可闭包）
SearchResult? runSearchInIsolate(SearchTask task) {
  final board = Board.fromIntList(task.boardInts);
  final side = task.sideIndex == 0 ? Side.red : Side.black;
  final engine = SearchEngine();

  MoveResult? result;
  if (task.useIterative) {
    result = engine.findBestMoveIterative(board, side, task.depth,
        depthTimeLimitMs: task.iterativeTimeLimitMs);
  } else {
    result = engine.findBestMove(board, side, task.depth,
        timeLimitMs: task.timeLimitMs);
  }

  if (result == null) return null;

  return SearchResult(
    fromCol: result.from.col,
    fromRow: result.from.row,
    toCol: result.to.col,
    toRow: result.to.row,
    score: result.score,
    depth: result.depth,
    nodesSearched: result.nodesSearched,
  );
}
