import 'board.dart';
import 'move.dart';
import 'piece.dart';

/// 对局结果
enum GameResult {
  playing, // 进行中
  redWin, // 红胜
  blackWin, // 黑胜
  draw, // 和棋
}

/// 游戏状态机 — 管理完整对局
///
/// 职责：
/// - 维护棋盘和走法历史
/// - 控制回合流转
/// - 检测将军/将杀
class GameState {
  Board board;
  Side currentSide;
  final List<Move> moveHistory;
  GameResult result;
  bool inCheck;
  bool inCheckmate;
  bool inStalemate;

  GameState({
    Board? board,
    this.currentSide = Side.red,
    List<Move>? moveHistory,
    this.result = GameResult.playing,
    this.inCheck = false,
    this.inCheckmate = false,
    this.inStalemate = false,
  })  : board = board ?? Board.initial(),
        moveHistory = moveHistory ?? [];

  /// 当前步数
  int get moveCount => moveHistory.length;

  /// 上一步走法
  Move? get lastMove => moveHistory.isEmpty ? null : moveHistory.last;

  /// 执行一步走法（仅执行，不校验合法性）
  Move? applyMove(Position from, Position to) {
    final piece = board.at(from);
    if (piece == null) return null;
    if (piece.side != currentSide) return null;

    final captured = board.move(from, to);

    final move = Move(
      from: from,
      to: to,
      piece: piece,
      captured: captured,
      moveNumber: moveCount + 1,
    );

    moveHistory.add(move);
    _advanceTurn();
    return move;
  }

  /// 撤销上一步
  Move? undoMove() {
    if (moveHistory.isEmpty) return null;

    final last = moveHistory.removeLast();
    // 恢复棋子
    board.set(last.from, last.piece);
    board.set(last.to, last.captured);

    currentSide = last.piece.side;
    result = GameResult.playing;
    inCheck = false;
    inCheckmate = false;
    inStalemate = false;

    return last;
  }

  /// 切换回合
  void _advanceTurn() {
    currentSide = currentSide.opponent;
  }

  /// 从当前状态创建快照（用于 AI 推演）
  GameState snapshot() {
    return GameState(
      board: board.copy(),
      currentSide: currentSide,
      moveHistory: List.from(moveHistory),
      result: result,
      inCheck: inCheck,
      inCheckmate: inCheckmate,
      inStalemate: inStalemate,
    );
  }
}
