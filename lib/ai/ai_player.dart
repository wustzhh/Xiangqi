import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../engine/board.dart';
import '../engine/piece.dart';
import '../engine/rules.dart';
import 'search.dart';
import 'isolate_search.dart';
import 'opening_book.dart';
import 'ucci_client.dart';
import 'deepseek_client.dart';

/// AI 难度等级
enum AiDifficulty {
  beginner,  // 新手 (depth 1 + 30%随机)
  easy,      // 初级 (depth 2)
  medium,    // 中级 (depth 3)
  hard,      // 高级 (开局库 + depth 4)
  master,    // 大师 (开局库 + 迭代2→4→6 + 可选UCCI)
  legend,    // 传说 (开局库 + 迭代2→4→6 + DeepSeek)
}

/// AI 玩家
class AiPlayer {
  final AiDifficulty difficulty;
  final Side side;
  final SearchEngine _engine = SearchEngine();
  final OpeningBook _book = OpeningBook();
  UcciClient? _ucci;
  DeepSeekClient? _deepSeek;
  Completer<MoveResult?>? _completer;

  AiPlayer({required this.difficulty, required this.side});

  String get difficultyName {
    switch (difficulty) {
      case AiDifficulty.beginner: return '新手';
      case AiDifficulty.easy: return '初级';
      case AiDifficulty.medium: return '中级';
      case AiDifficulty.hard: return '高级';
      case AiDifficulty.master: return '大师';
      case AiDifficulty.legend: return '传说';
    }
  }

  int get _searchDepth {
    switch (difficulty) {
      case AiDifficulty.beginner: return 1;
      case AiDifficulty.easy: return 2;
      case AiDifficulty.medium: return 3;
      case AiDifficulty.hard: return 4;
      case AiDifficulty.master: return 6;
      case AiDifficulty.legend: return 6;
    }
  }

  bool get _useIterative =>
      difficulty == AiDifficulty.master || difficulty == AiDifficulty.legend;

  void setDeepSeekKey(String key) {
    _deepSeek = DeepSeekClient(key);
  }

  Future<bool> setUcciEngine(String path) async {
    _ucci = UcciClient();
    return _ucci!.startEngine(path);
  }

  /// 所有高级档（4/5/6）共用：先查开局库
  bool _tryOpeningBook(Board board) {
    if (difficulty.index < AiDifficulty.hard.index) return false;
    final bookMove = _book.getBestMove(board);
    if (bookMove == null) return false;
    final rules = Rules(board);
    final legalMoves = rules.getLegalMoves(bookMove.from);
    if (legalMoves.contains(bookMove.to)) {
      _completer?.complete(MoveResult(
        from: bookMove.from,
        to: bookMove.to,
        score: 100, depth: 0, nodesSearched: 0,
      ));
      return true;
    }
    return false;
  }

  Future<MoveResult?> think(Board board) async {
    _completer = Completer<MoveResult?>();

    // 开局库（4/5/6档）
    if (_tryOpeningBook(board)) return _completer!.future;

    // 第5档（大师）：UCCI 引擎（如果配置了）
    if (difficulty == AiDifficulty.master && _ucci != null) {
      final result = await _ucci!.getMove(board, side, 8);
      if (result != null) {
        _completer?.complete(result);
        return _completer!.future;
      }
    }

    // 第6档（传说）：DeepSeek AI + 搜索并行
    if (difficulty == AiDifficulty.legend && _deepSeek != null) {
      // 先启动搜索（主力）
      _startIsolateSearch(board);
      // 同时尝试 DeepSeek（锦上添花）
      final dsResult = await _deepSeek!.getMove(board, side);
      if (dsResult != null && _completer != null && !_completer!.isCompleted) {
        // DeepSeek 走法需额外验证：不能明显送子
        final captured = board.at(dsResult.to);
        if (captured != null) {
          final movingPiece = board.at(dsResult.from);
          if (movingPiece != null) {
            final val = _pieceValue(movingPiece.type);
            final capVal = _pieceValue(captured.type);
            // 如果用高价值换低价值（车换兵等），不信任 DeepSeek
            if (val > capVal + 200) {
              debugPrint('DeepSeek 走法被拒（价值不对等），等待搜索结果');
              return _completer!.future;
            }
          }
        }
        // DeepSeek 走法看起来合理，使用它
        _completer?.complete(dsResult);
      }
      return _completer!.future;
    }

    // 搜索（1-3档 + 4/5档回退）
    _startIsolateSearch(board);
    return _completer!.future;
  }

  Future<void> _startIsolateSearch(Board board) async {
    try {
      final int timeLimit = difficulty == AiDifficulty.legend
          ? 25000
          : difficulty == AiDifficulty.master ? 20000
          : _timeLimitForDepth(_searchDepth);

      if (_useIterative) {
        final task = SearchTask(
          boardInts: board.toIntList(),
          sideIndex: side == Side.red ? 0 : 1,
          depth: _searchDepth,
          timeLimitMs: timeLimit,
          useIterative: true,
          iterativeTimeLimitMs: timeLimit,
        );
        final result = await Isolate.run(() => runSearchInIsolate(task));
        var finalResult = result?.toMoveResult();
        if (difficulty == AiDifficulty.beginner && finalResult != null &&
            Random().nextDouble() < 0.3) {
          finalResult = _randomMove(board);
        }
        if (_completer != null && !_completer!.isCompleted) {
          _completer?.complete(finalResult);
        }
      } else {
        final task = SearchTask(
          boardInts: board.toIntList(),
          sideIndex: side == Side.red ? 0 : 1,
          depth: _searchDepth,
          timeLimitMs: timeLimit,
          useIterative: false,
        );
        final result = await Isolate.run(() => runSearchInIsolate(task));
        var finalResult = result?.toMoveResult();
        if (difficulty == AiDifficulty.beginner && finalResult != null &&
            Random().nextDouble() < 0.3) {
          finalResult = _randomMove(board);
        }
        _completer?.complete(finalResult);
      }
    } catch (e) {
      debugPrint('Isolate 搜索失败: $e');
      if (_completer != null && !_completer!.isCompleted) {
        _completer?.complete(null);
      }
    }
  }

  int _pieceValue(PieceType type) {
    switch (type) {
      case PieceType.rook: return 900;
      case PieceType.cannon: return 500;
      case PieceType.horse: return 450;
      case PieceType.advisor: return 200;
      case PieceType.elephant: return 200;
      case PieceType.soldier: return 100;
      case PieceType.general: return 10000;
    }
  }

  MoveResult? _randomMove(Board board) {
    final rules = Rules(board);
    final allMoves = rules.allLegalMoves(side);
    if (allMoves.isEmpty) return null;
    final fromKeys = allMoves.keys.toList();
    final from = fromKeys[Random().nextInt(fromKeys.length)];
    final targets = allMoves[from]!;
    final to = targets[Random().nextInt(targets.length)];
    return MoveResult(from: from, to: to, score: 0, depth: 0, nodesSearched: 0);
  }

  int _timeLimitForDepth(int depth) {
    if (depth <= 1) return 3000;
    if (depth <= 2) return 5000;
    if (depth <= 3) return 8000;
    if (depth <= 4) return 12000;
    return 15000;
  }

  void cancel() {
    _engine.cancel();
    _ucci?.stop();
    _completer?.complete(null);
  }
}
