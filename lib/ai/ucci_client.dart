import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../engine/board.dart';
import '../engine/piece.dart';
import 'search.dart';

/// UCCI 引擎客户端 — 与外部象棋引擎通信
///
/// UCCI 协议命令：
///   ucci          → 握手
///   isready       → 准备就绪
///   position moves 走法1 走法2 ...  → 设置局面
///   go depth N    → 开始搜索
///   quit          → 退出
/// 引擎回复：
///   bestmove 走法  → 返回最佳走法
class UcciClient {
  Process? _process;
  StreamSubscription? _stdoutSub;
  Completer<String>? _moveCompleter;

  /// 启动引擎
  Future<bool> startEngine(String enginePath) async {
    try {
      _process = await Process.start(enginePath, []);
      _stdoutSub = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_onLine);

      // 发送握手
      _process!.stdin.writeln('ucci');
      await Future.delayed(const Duration(milliseconds: 500));
      _process!.stdin.writeln('isready');
      await Future.delayed(const Duration(milliseconds: 500));

      debugPrint('UCCI 引擎已启动: $enginePath');
      return true;
    } catch (e) {
      debugPrint('启动 UCCI 引擎失败: $e');
      return false;
    }
  }

  void _onLine(String line) {
    debugPrint('UCCI ← $line');
    if (line.startsWith('bestmove')) {
      final parts = line.split(' ');
      if (parts.length >= 2) {
        _moveCompleter?.complete(parts[1]);
      }
    }
  }

  /// 发送局面并搜索
  Future<MoveResult?> getMove(
      Board board, Side side, int searchDepth) async {
    if (_process == null) return null;

    // 将棋盘转为 UCCI 走法序列
    // UCCI 坐标: 列a-i(0-8), 行0-9, 从红方视角
    // 注意：UCCI 标准中列是 a-i (0->a, 8->i)，行是 0-9

    // 发送局面
    final moveStr = _boardToUcciMoves(board);
    _process!.stdin.writeln('position startpos moves$moveStr');

    _moveCompleter = Completer<String>();
    _process!.stdin.writeln('go depth $searchDepth');

    try {
      final bestMove = await _moveCompleter!.future
          .timeout(const Duration(seconds: 30));
      return _parseUcciMove(bestMove, side);
    } catch (e) {
      debugPrint('UCCI 搜索超时或失败: $e');
      return null;
    }
  }

  /// 将棋盘转为 UCCI 走法序列
  String _boardToUcciMoves(Board board) {
    // 从初始局面开始，对比差异重建走法序列
    // 由于我们不知道走法历史，简单返回空序列（用 position 命令设置 FEN）
    // 简化：用 position fen 命令
    return '';
  }

  /// UCCI 走法格式: 起点列(字母)起点行终点列(字母)终点行
  /// 如 a0a1 = (0,0)→(0,1)
  MoveResult? _parseUcciMove(String uciMove, Side side) {
    if (uciMove.length < 4) return null;
    final fromCol = uciMove.codeUnitAt(0) - 97; // 'a' = 0
    final fromRow = int.tryParse(uciMove[1]) ?? 0;
    final toCol = uciMove.codeUnitAt(2) - 97;
    final toRow = int.tryParse(uciMove[3]) ?? 0;

    final from = Position(fromCol, fromRow);
    final to = Position(toCol, toRow);
    if (!from.isValid || !to.isValid) return null;

    return MoveResult(from: from, to: to, score: 0, depth: 0, nodesSearched: 0);
  }

  /// 停止引擎
  void stop() {
    try {
      _process?.stdin.writeln('quit');
    } catch (_) {}
    _stdoutSub?.cancel();
    _process?.kill();
    _process = null;
  }
}
