import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../engine/board.dart';
import '../engine/move.dart';
import '../engine/piece.dart';
import '../engine/rules.dart';
import 'search.dart';
import 'isolate_search.dart';
import 'opening_book.dart';
import 'ucci_client.dart';

/// AI 难度等级
///
/// 每个难度对应皮卡鱼 Skill Level（0=最弱，20=最强，即全开状态）。
/// Skill Level 控制引擎故意犯错的程度：值越低引擎越常下出劣着，
/// 值越高则越接近完全理性，20=不刻意犯错。
///
/// 各搜索引擎参数一览（皮卡鱼模式）：
/// ┌──────────┬──────┬──────────┬──────────┬──────────┐
/// │ 难度      │ 等级 │ Skill Lv │ 搜索深度  │ 思考时间  │
/// ├──────────┼──────┼──────────┼──────────┼──────────┤
/// │ 新手      │ ①   │    2     │  4 层    │  2 秒    │
/// │ 初级      │ ②   │    5     │  6 层    │  3 秒    │
/// │ 中级      │ ③   │    8     │ 10 层    │  5 秒    │
/// │ 高级      │ ④   │   12     │ 不限 ⏱   │  8 秒    │
/// │ 大师      │ ⑤   │   16     │ 不限 ⏱   │ 12 秒    │
/// │ 传说      │ ⑥   │   20     │ 不限 ⏱   │ 30 秒    │
/// └──────────┴──────┴──────────┴──────────┴──────────┘
///
/// 说明：
/// - Skill Level 0~20：值越小引擎故意犯错越多，水平越弱
/// - 搜索深度 = 0 表示不限制深度（走时间控制），引擎在时限内尽可能算深
/// - 高级以上（hard+）额外启用开局库，给 AI 更合理的开局着法
/// - 未检测到皮卡鱼时自动降级到内置搜索引擎（自实现 Minimax+Alpha-Beta）
enum AiDifficulty {
  /// 新手 — Skill Level=2, depth=4, 2秒
  /// 引擎频繁下出劣着，会主动送子、错失吃子机会。
  /// 额外：30% 概率随机选一步合法走法（更显笨拙）。
  /// 适合对象：完全不会象棋的初学者。
  beginner,

  /// 初级 — Skill Level=5, depth=6, 3秒
  /// 引擎偶尔犯错，能识别明显的吃子但不会深层计算。
  /// 适合对象：了解基本走法、刚学会规则的新手。
  easy,

  /// 中级 — Skill Level=8, depth=10, 5秒
  /// 引擎犯错的频率明显降低，能完成简单的战术组合（如捉双）。
  /// 适合对象：有一定对局经验、能看两三步的业余爱好者。
  medium,

  /// 高级 — Skill Level=12, 不限深度, 8秒, 启用开局库
  /// 引擎较少犯错，开局阶段走法合理（来自开局库），
  /// 中后盘能利用对手失误。不限深度意味着引擎在 8 秒内尽可能算深。
  /// 适合对象：熟悉常见开局、能进行中盘计算的业余中级。
  hard,

  /// 大师 — Skill Level=16, 不限深度, 12秒, 启用开局库
  /// 引擎极少犯错，战术准确度很高，接近最优走法。
  /// 开局库保障开局阶段的专业水准。
  /// 适合对象：具备系统训练、能深度计算的业余高手。
  master,

  /// 传说 — Skill Level=20, 不限深度, 30秒, 启用开局库
  /// 引擎全开状态，不刻意犯错，每步在 30 秒内全力搜索。
  /// 这是皮卡鱼能在该时限内达到的最强水平。
  /// 适合对象：希望挑战引擎极限的象棋强手。
  legend,
}

/// AI 难度对应的皮卡鱼（UCI 引擎）配置映射
///
/// 皮卡鱼 Skill Level 范围 0~20，控制引擎故意犯错的程度：
/// - 0：最弱——引擎频繁故意下劣着
/// - 20：最强——不刻意犯错，全开状态
///
/// 三个控制维度的设计原则：
/// | 字段            | 作用                          | 低难度方向  | 高难度方向  |
/// |-----------------|-------------------------------|------------|------------|
/// | pikafishSkillLevel | 引擎故意犯错的频率 0~20    | 较小值      | 较大值      |
/// | pikafishDepth     | 搜索深度上限（0=不限时间） | 浅层限制    | 不限（用时间控）|
/// | pikafishTimeMs    | 每步允许的搜索耗时          | 较短        | 较长        |
extension AiDifficultyPikafish on AiDifficulty {
  /// 皮卡鱼 Skill Level：0(最弱) ~ 20(最强)
  int get pikafishSkillLevel {
    switch (this) {
      case AiDifficulty.beginner:
        return 2;
      case AiDifficulty.easy:
        return 5;
      case AiDifficulty.medium:
        return 8;
      case AiDifficulty.hard:
        return 12;
      case AiDifficulty.master:
        return 16;
      case AiDifficulty.legend:
        return 20;
    }
  }

  /// 搜索深度（≤0 表示不限，用时间控制）
  int get pikafishDepth {
    switch (this) {
      case AiDifficulty.beginner:
        return 4;
      case AiDifficulty.easy:
        return 6;
      case AiDifficulty.medium:
        return 10;
      case AiDifficulty.hard:
        return 0; // 不限深度，用时间控制
      case AiDifficulty.master:
        return 0;
      case AiDifficulty.legend:
        return 0;
    }
  }

  /// 思考时间（毫秒）
  int get pikafishTimeMs {
    switch (this) {
      case AiDifficulty.beginner:
        return 2000;
      case AiDifficulty.easy:
        return 3000;
      case AiDifficulty.medium:
        return 5000;
      case AiDifficulty.hard:
        return 8000;
      case AiDifficulty.master:
        return 12000;
      case AiDifficulty.legend:
        return 30000;
    }
  }
}

/// AI 玩家 — 以皮卡鱼（UCCI 引擎）为主力，内置搜索为后备
///
/// 工作流程：
/// 1. 高级别（hard+）先查开局库
/// 2. 皮卡鱼引擎可用 → 用皮卡鱼搜索
/// 3. 皮卡鱼不可用 → 降级到内置搜索引擎
class AiPlayer {
  final AiDifficulty difficulty;
  final Side side;
  final SearchEngine _engine = SearchEngine();
  final OpeningBook _book = OpeningBook();
  UciClient? _ucci;
  bool _engineLoaded = false;
  bool _engineSearching = false;
  Completer<MoveResult?>? _completer;

  AiPlayer({required this.difficulty, required this.side});

  String get difficultyName {
    switch (difficulty) {
      case AiDifficulty.beginner:
        return '新手';
      case AiDifficulty.easy:
        return '初级';
      case AiDifficulty.medium:
        return '中级';
      case AiDifficulty.hard:
        return '高级';
      case AiDifficulty.master:
        return '大师';
      case AiDifficulty.legend:
        return '传说';
    }
  }

  /// 尝试加载皮卡鱼引擎
  /// userPath: 用户指定的引擎路径（可选）
  Future<bool> loadPikafishEngine({String? userPath}) async {
    if (_engineLoaded && _ucci != null) return true;

    final detectedPath = await UciClient.detectEngine(userPath: userPath);
    if (detectedPath == null) {
      debugPrint('AI: 未检测到皮卡鱼引擎，将使用内置搜索');
      return false;
    }

    _ucci = UciClient();
    final ok = await _ucci!.startEngine(detectedPath);
    _engineLoaded = ok;

    if (!ok) {
      debugPrint('AI: 皮卡鱼引擎启动失败，将使用内置搜索');
      _ucci?.quit();
      _ucci = null;
    }

    return _engineLoaded;
  }

  /// 判断皮卡鱼是否可用
  bool get hasPikafish => _engineLoaded && _ucci != null && _ucci!.isReady;

  /// AI 思考并返回最佳走法
  Future<MoveResult?> think(Board board, {List<Move>? moveHistory}) async {
    _completer = Completer<MoveResult?>();

    // 高级别（hard+）先查开局库
    if (difficulty.index >= AiDifficulty.hard.index) {
      if (_tryOpeningBook(board)) return _completer!.future;
    }

    // 皮卡鱼引擎可用 → 用它搜索
    if (hasPikafish) {
      return _searchWithPikafish(board, moveHistory: moveHistory);
    }

    // 降级到内置搜索
    return _searchWithBuiltin(board);
  }

  /// 使用皮卡鱼（UCCI）引擎搜索
  Future<MoveResult?> _searchWithPikafish(Board board,
      {List<Move>? moveHistory}) async {
    _engineSearching = true;

    try {
      final skillLevel = difficulty.pikafishSkillLevel;
      final depth = difficulty.pikafishDepth;
      final timeMs = difficulty.pikafishTimeMs;

      final hasHistory = moveHistory != null && moveHistory.isNotEmpty;

      MoveResult? result;
      if (hasHistory && _ucci != null) {
        result = await _ucci!.getMoveWithHistory(
          board,
          side,
          moveHistory,
          depth,
          movetimeMs: timeMs,
          skillLevel: skillLevel,
        );
      } else if (_ucci != null) {
        result = await _ucci!.getMove(
          board,
          side,
          depth,
          movetimeMs: timeMs,
          skillLevel: skillLevel,
        );
      }

      if (result != null) {
        // 新手档：30% 概率随机走
        if (difficulty == AiDifficulty.beginner &&
            Random().nextDouble() < 0.3) {
          final randomMove = _randomMove(board);
          if (randomMove != null) {
            _completer?.complete(randomMove);
            _engineSearching = false;
            return randomMove;
          }
        }

        _completer?.complete(result);
        _engineSearching = false;
        return result;
      }

      // 皮卡鱼搜索失败，降级到内置搜索
      debugPrint('AI: 皮卡鱼搜索失败，降级到内置搜索');
      _engineSearching = false;
      return _searchWithBuiltin(board);
    } catch (e) {
      debugPrint('AI: 皮卡鱼搜索异常: $e');
      _engineSearching = false;
      return _searchWithBuiltin(board);
    }
  }

  /// 使用内置搜索引擎（后备方案）
  Future<MoveResult?> _searchWithBuiltin(Board board) async {
    try {
      final depth = _builtinDepth;
      final timeLimit = _builtinTimeLimit;

      final task = SearchTask(
        boardInts: board.toIntList(),
        sideIndex: side == Side.red ? 0 : 1,
        depth: depth,
        timeLimitMs: timeLimit,
        useIterative: difficulty == AiDifficulty.master ||
            difficulty == AiDifficulty.legend,
        iterativeTimeLimitMs: timeLimit,
      );
      final result = await Isolate.run(() => runSearchInIsolate(task));
      var finalResult = result?.toMoveResult();

      // 新手档：30% 随机
      if (difficulty == AiDifficulty.beginner &&
          finalResult != null &&
          Random().nextDouble() < 0.3) {
        finalResult = _randomMove(board);
      }

      _completer?.complete(finalResult);
      return finalResult;
    } catch (e) {
      debugPrint('AI: 内置搜索失败: $e');
      _completer?.complete(null);
      return null;
    }
  }

  /// 所有高级档（hard+）共用：先查开局库
  bool _tryOpeningBook(Board board) {
    final bookMove = _book.getBestMove(board);
    if (bookMove == null) return false;
    final rules = Rules(board);
    final legalMoves = rules.getLegalMoves(bookMove.from);
    if (legalMoves.contains(bookMove.to)) {
      _completer?.complete(MoveResult(
        from: bookMove.from,
        to: bookMove.to,
        score: 100,
        depth: 0,
        nodesSearched: 0,
      ));
      return true;
    }
    return false;
  }

  // ── 内置搜索配置（后备方案） ──

  int get _builtinDepth {
    switch (difficulty) {
      case AiDifficulty.beginner:
        return 1;
      case AiDifficulty.easy:
        return 2;
      case AiDifficulty.medium:
        return 3;
      case AiDifficulty.hard:
        return 4;
      case AiDifficulty.master:
        return 6;
      case AiDifficulty.legend:
        return 6;
    }
  }

  int get _builtinTimeLimit {
    switch (difficulty) {
      case AiDifficulty.beginner:
        return 3000;
      case AiDifficulty.easy:
        return 5000;
      case AiDifficulty.medium:
        return 8000;
      case AiDifficulty.hard:
        return 12000;
      case AiDifficulty.master:
        return 15000;
      case AiDifficulty.legend:
        return 20000;
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

  /// 取消思考
  void cancel() {
    _engine.cancel();
    if (_ucci != null && _engineSearching) {
      _ucci!.stop();
    }
    _completer?.complete(null);
  }
}
