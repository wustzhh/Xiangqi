import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../engine/board.dart';
import '../engine/move.dart';
import '../engine/piece.dart';
import 'search.dart';

/// UCI 引擎客户端 — 与皮卡鱼等外部中国象棋引擎通信
///
/// 皮卡鱼基于 Stockfish，使用标准 UCI 协议：
///   - 握手 (uci / uciok)
///   - 选项设置 (setoption)
///   - 局面设置 (position fen / startpos moves)
///   - 搜索 (go depth / go movetime)
///   - 停止 (stop)
///   - 退出 (quit)
class UciClient {
  Process? _process;
  StreamSubscription? _stdoutSub;
  Completer<String>? _moveCompleter;
  bool _ready = false;
  bool _engineReady = false;

  bool get isReady => _ready && _engineReady;

  /// 尝试自动检测皮卡鱼引擎
  /// 搜索路径：1) 应用目录下的 pikafish.exe  2) 用户配置路径
  static Future<String?> detectEngine({String? userPath}) async {
    // 用户配置路径优先
    if (userPath != null && userPath.isNotEmpty) {
      final file = File(userPath);
      if (await file.exists()) return userPath;
    }

    // 常见搜索路径
    const candidates = [
      'pikafish.exe',
      'Pikafish.exe',
      'engines/pikafish.exe',
      'engines/Pikafish.exe',
      'engines/pikafish-bmi2.exe',
      'engines/pikafish-sse41-popcnt.exe',
      'engines/pikafish-avx2.exe',
      'assets/engines/pikafish.exe',
      'assets/engines/Pikafish.exe',
    ];

    for (final path in candidates) {
      final file = File(path);
      if (await file.exists()) {
        debugPrint('UCI: 自动检测到引擎: $path');
        return file.absolute.path;
      }
    }

    return null;
  }

  /// 启动引擎
  Future<bool> startEngine(String enginePath) async {
    try {
      _process = await Process.start(enginePath, []);
      _stdoutSub = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_onLine);

      _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.isNotEmpty) debugPrint('UCI(stderr): $line');
      });

      // UCI 握手
      _process!.stdin.writeln('uci');
      _moveCompleter = Completer<String>();

      // 等待 uciok
      try {
        await _moveCompleter!.future.timeout(const Duration(seconds: 5));
        _engineReady = true;
      } on TimeoutException {
        debugPrint('UCI 引擎握手超时');
        return false;
      }

      // 配置引擎选项
      _process!.stdin.writeln('setoption name Threads value 1');
      _process!.stdin.writeln('setoption name Hash value 32');
      _process!.stdin.writeln('setoption name Ponder value false');

      // 等待引擎就绪
      _process!.stdin.writeln('isready');
      _moveCompleter = Completer<String>();
      try {
        await _moveCompleter!.future.timeout(const Duration(seconds: 5));
        _ready = true;
      } on TimeoutException {
        debugPrint('UCI 引擎就绪超时');
        return false;
      }

      debugPrint('UCI 引擎已启动: $enginePath');
      return true;
    } catch (e) {
      debugPrint('启动 UCI 引擎失败: $e');
      return false;
    }
  }

  /// 设置难度等级（Skill Level）
  /// Pikafish Skill Level: 0 (最弱) ~ 20 (最强)
  void setSkillLevel(int level) {
    if (_process == null) return;
    final clamped = level.clamp(0, 20);
    _process!.stdin.writeln('setoption name Skill Level value $clamped');
    debugPrint('UCI: 设置 Skill Level = $clamped');
  }

  void _onLine(String line) {
    debugPrint('UCI ← $line');

    if (line.startsWith('uciok')) {
      _moveCompleter?.complete('uciok');
    } else if (line.startsWith('readyok')) {
      _moveCompleter?.complete('readyok');
    } else if (line.startsWith('bestmove')) {
      final parts = line.split(' ');
      if (parts.length >= 2) {
        _moveCompleter?.complete(parts[1]);
      }
    } else if (line.startsWith('info')) {
      // 引擎搜索信息，忽略
    }
  }

  /// 将内部坐标转为 UCI 坐标字符串
  /// 例：Position(0,0) → "a0", Position(8,9) → "i9"
  static String _posToUci(Position pos) {
    final col = String.fromCharCode(97 + pos.col); // a=0, b=1, ..., i=8
    return '$col${pos.row}';
  }

  /// 将走法历史转为 UCI 走法序列字符串
  /// 例：["a0a1", "i9i8", ...]
  static String _movesToUci(List<Move> history) {
    if (history.isEmpty) return '';
    return ' moves ${history.map((m) {
      final from = _posToUci(m.from);
      final to = _posToUci(m.to);
      return '$from$to';
    }).join(' ')}';
  }

  /// 发送局面并搜索最佳走法
  Future<MoveResult?> getMove(
    Board board,
    Side side,
    int maxDepth, {
    int movetimeMs = 5000,
    int skillLevel = 20,
  }) async {
    if (_process == null || !_ready) return null;

    // 设置难度
    setSkillLevel(skillLevel);

    // 转换为 FEN
    final fen = board.toFen();
    final sideChar = side == Side.red ? 'w' : 'b';
    _process!.stdin.writeln('position fen $fen $sideChar');

    // 发送搜索命令
    _moveCompleter = Completer<String>();

    if (maxDepth > 0 && maxDepth < 30) {
      _process!.stdin.writeln('go depth $maxDepth');
    } else {
      _process!.stdin.writeln('go movetime $movetimeMs');
    }

    try {
      final bestMove = await _moveCompleter!.future
          .timeout(Duration(milliseconds: movetimeMs + 3000));
      return _parseUciMove(bestMove, side);
    } catch (e) {
      debugPrint('UCI 搜索超时或失败: $e');
      return null;
    }
  }

  /// 发送走法历史（使用 startpos + moves）并搜索
  Future<MoveResult?> getMoveWithHistory(
    Board board,
    Side side,
    List<Move> moveHistory,
    int maxDepth, {
    int movetimeMs = 5000,
    int skillLevel = 20,
  }) async {
    if (_process == null || !_ready) return null;

    setSkillLevel(skillLevel);

    // 用 startpos + 走法序列（引擎知道完整历史）
    final movesStr = _movesToUci(moveHistory);
    _process!.stdin.writeln('position startpos$movesStr');

    _moveCompleter = Completer<String>();

    if (maxDepth > 0 && maxDepth < 30) {
      _process!.stdin.writeln('go depth $maxDepth');
    } else {
      _process!.stdin.writeln('go movetime $movetimeMs');
    }

    try {
      final bestMove = await _moveCompleter!.future
          .timeout(Duration(milliseconds: movetimeMs + 3000));
      return _parseUciMove(bestMove, side);
    } catch (e) {
      debugPrint('UCI 搜索超时或失败: $e');
      return null;
    }
  }

  /// UCI 走法格式: 起点列字母起点行终点列字母终点行
  /// 如 a0a1 = (0,0)→(0,1)
  MoveResult? _parseUciMove(String uciMove, Side side) {
    if (uciMove.length < 4) return null;
    final fromCol = uciMove.codeUnitAt(0) - 97; // 'a' = 0
    final fromRow = int.tryParse(uciMove[1]) ?? 0;
    final toCol = uciMove.codeUnitAt(2) - 97;
    final toRow = int.tryParse(uciMove[3]) ?? 0;

    final from = Position(fromCol, fromRow);
    final to = Position(toCol, toRow);
    if (!from.isValid || !to.isValid) return null;

    debugPrint('UCI 走法: $uciMove → ($fromCol,$fromRow)→($toCol,$toRow)');
    return MoveResult(from: from, to: to, score: 0, depth: 0, nodesSearched: 0);
  }

  /// 停止搜索
  void stop() {
    try {
      _process?.stdin.writeln('stop');
    } catch (_) {}
  }

  /// 关闭引擎
  void quit() {
    try {
      _process?.stdin.writeln('quit');
    } catch (_) {}
    _stdoutSub?.cancel();
    try {
      _process?.kill();
    } catch (_) {}
    _process = null;
    _ready = false;
    _engineReady = false;
  }
}
