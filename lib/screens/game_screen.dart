import 'package:flutter/material.dart';
import '../ai/ai_player.dart';
import '../ai/search.dart';
import '../engine/board.dart';
import '../engine/game_state.dart';
import '../engine/piece.dart';
import '../engine/rules.dart';
import '../utils/constants.dart';
import '../models/game_record.dart';
import '../models/app_config.dart';
import '../models/game_stats.dart';
import '../models/analysis_data.dart';
import '../services/storage_service.dart';
import '../widgets/chess_board.dart';
import '../widgets/debug_overlay.dart';
import '../widgets/game_info_bar.dart';

class GameScreen extends StatefulWidget {
  final bool isAiMode;
  final AiDifficulty aiDifficulty;
  final Side playerSide;

  const GameScreen({
    super.key,
    this.isAiMode = false,
    this.aiDifficulty = AiDifficulty.medium,
    this.playerSide = Side.red,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late GameState _gameState;
  late Rules _rules;
  AiPlayer? _aiPlayer;
  bool _aiThinking = false;

  Position? _selectedPos;
  List<Position> _validMoves = [];
  bool _showDebug = false;
  AnalysisMode _analysisMode = AnalysisMode.none;
  Position? _analysisSelectedPos;

  // 动画
  late AnimationController _animController;
  AnimationPiece? _animPiece;
  bool _isAnimating = false;
  Position? _pendingFrom;
  Position? _pendingTo;

  @override
  void initState() {
    super.initState();
    _gameState = GameState();
    _rules = Rules(_gameState.board);

    if (widget.isAiMode) {
      _aiPlayer = AiPlayer(
        difficulty: widget.aiDifficulty,
        side: widget.playerSide.opponent,
      );
      // 传说档：从 AppConfig 读取 DeepSeek API Key
      if (widget.aiDifficulty == AiDifficulty.legend) {
        final key = AppConfig.deepSeekKey;
        if (key != null && key.isNotEmpty) {
          _aiPlayer!.setDeepSeekKey(key);
        }
      }
      // AI 先手：等第一帧渲染后再触发，避免 setState 在 mount 前调用
      if (widget.playerSide == Side.black) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _triggerAi();
        });
      }
    }

    _animController = AnimationController(
      vsync: this,
      duration: moveAnimDuration,
    );
    _animController.addListener(_onAnimTick);
    _animController.addStatusListener(_onAnimDone);
  }

  @override
  void dispose() {
    _aiPlayer?.cancel();
    _animController.removeListener(_onAnimTick);
    _animController.removeStatusListener(_onAnimDone);
    _animController.dispose();
    super.dispose();
  }

  void _onAnimTick() {
    if (_pendingFrom == null || _pendingTo == null) return;
    final piece = _gameState.board.at(_pendingFrom!);
    if (piece == null) return;
    setState(() {
      _animPiece = AnimationPiece(
        piece: piece,
        from: _pendingFrom!,
        to: _pendingTo!,
        progress: _animController.value,
      );
    });
  }

  void _onAnimDone(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_pendingFrom == null || _pendingTo == null) return;

    _gameState.applyMove(_pendingFrom!, _pendingTo!);
    _rules = Rules(_gameState.board);
    final endReason = _checkGameEnd();

    setState(() {
      _animPiece = null;
      _isAnimating = false;
      _pendingFrom = null;
      _pendingTo = null;
      _selectedPos = null;
      _validMoves = [];
    });

    if (_gameState.result != GameResult.playing && endReason != null) {
      _saveRecord(endReason);
    }

    // AI 模式：只有真正轮到 AI 时才触发
    if (_gameState.result == GameResult.playing && widget.isAiMode &&
        _gameState.currentSide == _aiPlayer?.side) {
      _triggerAi();
    }
  }

  /// 检查游戏是否结束，返回结束原因或 null
  String? _checkGameEnd() {
    _gameState.inCheck = _rules.isInCheck(_gameState.currentSide);
    _gameState.inCheckmate = _rules.isCheckmate(_gameState.currentSide);
    _gameState.inStalemate = false;
    if (_gameState.inCheckmate) {
      _gameState.result = _gameState.currentSide == Side.red
          ? GameResult.blackWin
          : GameResult.redWin;
      return '将杀';
    }
    if (_rules.isStalemate(_gameState.currentSide)) {
      _gameState.inStalemate = true;
      _gameState.result = _gameState.currentSide == Side.red
          ? GameResult.blackWin
          : GameResult.redWin;
      return '困毙';
    }
    return null;
  }

  /// 保存对局记录
  void _saveRecord(String endReason) {
    final moves = _gameState.moveHistory
        .map((m) => RecordedMove.fromMove(m))
        .toList();
    final record = GameRecord(
      id: GameRecord.generateId(),
      playedAt: DateTime.now(),
      redPlayer: PlayerConfig(
        type: widget.isAiMode && widget.playerSide != Side.red
            ? PlayerType.ai
            : PlayerType.human,
        side: Side.red,
        aiDifficulty: widget.isAiMode && widget.playerSide != Side.red
            ? widget.aiDifficulty
            : null,
      ),
      blackPlayer: PlayerConfig(
        type: widget.isAiMode && widget.playerSide != Side.black
            ? PlayerType.ai
            : PlayerType.human,
        side: Side.black,
        aiDifficulty: widget.isAiMode && widget.playerSide != Side.black
            ? widget.aiDifficulty
            : null,
      ),
      result: _gameState.result,
      endReason: endReason,
      totalMoves: _gameState.moveCount,
      moves: moves,
    );
    StorageService().saveRecord(record);
  }

  void _onCellTap(Position pos) {
    if (_isAnimating || _aiThinking) return;

    // 分析模式：记录点击位置用于显示详情，不影响正常下棋
    if (_analysisMode != AnalysisMode.none) {
      final piece = _gameState.board.at(pos);
      if (_analysisMode == AnalysisMode.protection || _analysisMode == AnalysisMode.safety) {
        // 护子/安全：点友方棋子查看保护详情
        if (piece != null && piece.side == _gameState.currentSide) {
          setState(() => _analysisSelectedPos = _analysisSelectedPos == pos ? null : pos);
        } else {
          setState(() => _analysisSelectedPos = null);
        }
      } else {
        // 攻击/危险：点敌方棋子查看其攻击范围
        final enemySide = _gameState.currentSide.opponent;
        if (piece != null && piece.side == enemySide) {
          setState(() => _analysisSelectedPos = _analysisSelectedPos == pos ? null : pos);
        } else {
          setState(() => _analysisSelectedPos = null);
        }
      }
      // 不 return，继续走正常下棋逻辑
    }

    final piece = _gameState.board.at(pos);

    if (_selectedPos == null) {
      // 没有选中：选自己的棋子
      if (piece == null) return;
      // AI 模式：只能点己方棋子
      if (widget.isAiMode && piece.side != widget.playerSide) return;
      // 必须轮到该方
      if (piece.side != _gameState.currentSide) return;
      setState(() {
        _selectedPos = pos;
        _validMoves = _rules.getLegalMoves(pos);
      });
    } else {
      // 已选中：走棋或切换选中
      if (piece != null && piece.side == _gameState.currentSide) {
        if (pos == _selectedPos) {
          // 点同一个棋子：取消选中
          setState(() {
            _selectedPos = null;
            _validMoves = [];
          });
        } else {
          // 点不同的友方棋子：切换选中
          setState(() {
            _selectedPos = pos;
            _validMoves = _rules.getLegalMoves(pos);
          });
        }
      } else if (_validMoves.contains(pos)) {
        // 合法走法：启动动画
        _pendingFrom = _selectedPos;
        _pendingTo = pos;
        _isAnimating = true;
        _animController.forward(from: 0);
      } else {
        // 无效点击：取消选中
        setState(() {
          _selectedPos = null;
          _validMoves = [];
        });
      }
    }
  }

  Future<void> _triggerAi() async {
    if (_aiPlayer == null || _aiThinking || !mounted) return;
    // 不是AI的回合就不触发（双重保障）
    if (_gameState.currentSide != _aiPlayer!.side) return;

    setState(() => _aiThinking = true);

    MoveResult? result;
    try {
      result = await _aiPlayer!.think(_gameState.board);
    } catch (e) {
      debugPrint('AI 搜索出错: $e');
    }

    if (!mounted) return;

    if (result == null) {
      setState(() => _aiThinking = false);
      return;
    }

    final r = result!;
    // AI 走棋带动画
    setState(() {
      _aiThinking = false;
      _pendingFrom = r.from;
      _pendingTo = r.to;
      _isAnimating = true;
    });
    _animController.forward(from: 0);
  }

  void _undo() {
    if (_isAnimating || _aiThinking) return;
    // AI 模式：悔两步（玩家+AI）
    for (int i = 0; i < (widget.isAiMode ? 2 : 1); i++) {
      final undone = _gameState.undoMove();
      if (undone == null) break;
    }
    _rules = Rules(_gameState.board);
    setState(() {
      _selectedPos = null;
      _validMoves = [];
    });
  }

  void _reset() {
    if (_isAnimating) return;
    _aiPlayer?.cancel();
    _animController.reset();
    setState(() {
      _gameState = GameState();
      _rules = Rules(_gameState.board);
      _selectedPos = null;
      _validMoves = [];
      _animPiece = null;
      _pendingFrom = null;
      _pendingTo = null;
      _aiThinking = false;
      _analysisMode = AnalysisMode.none;
      _analysisSelectedPos = null;
    });
    if (widget.isAiMode && widget.playerSide == Side.black) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _triggerAi();
      });
    }
  }

  /// 局面统计行
  Widget _buildStatsRow() {
    final stats = GameStats.compute(_gameState.board, _gameState.moveHistory);
    final currentSide = _gameState.currentSide;
    final attacked = currentSide == Side.red
        ? stats.redUnderAttack
        : stats.blackUnderAttack;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          _statChip(Icons.sports_kabaddi, stats.capturedText, Colors.brown),
          const SizedBox(width: 8),
          _statChip(Icons.shield, stats.protectedText, Colors.green),
          const SizedBox(width: 8),
          if (attacked.isNotEmpty)
            _statChip(Icons.warning, '${attacked.length}子被攻', Colors.red),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Widget _buildAnalysisButtons() {
    final modes = <(AnalysisMode, IconData, String)>[
      (AnalysisMode.protection, Icons.shield, '护子'),
      (AnalysisMode.attack, Icons.gps_fixed, '攻击'),
      (AnalysisMode.safety, Icons.verified_user, '安全'),
      (AnalysisMode.danger, Icons.warning, '危险'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: modes.map((m) {
          final active = _analysisMode == m.$1;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FilterChip(
              label: Text(m.$3, style: const TextStyle(fontSize: 11)),
              selected: active,
              onSelected: (_) => setState(() {
                _analysisMode = active ? AnalysisMode.none : m.$1;
                _analysisSelectedPos = null;
              }),
              selectedColor: m.$1 == AnalysisMode.protection
                  ? Colors.green.shade100
                  : m.$1 == AnalysisMode.attack
                      ? Colors.red.shade100
                      : m.$1 == AnalysisMode.safety
                          ? Colors.blue.shade100
                          : Colors.orange.shade100,
              avatar: Icon(m.$2, size: 14, color: active ? Colors.black87 : Colors.grey),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 走法列表（左）
    final moveList = _gameState.moveCount > 0
        ? SizedBox(
            width: 140,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(6),
                  child: Text('棋谱', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: _gameState.moveCount,
                    itemBuilder: (context, i) {
                      final move = _gameState.moveHistory[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        child: Text(
                          '${move.moveNumber}. ${move.notation}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          )
        : const SizedBox(width: 0);

    // 右侧功能按钮
    final rightButtons = SizedBox(
      width: 56,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _sideButton(Icons.shield, '护子', AnalysisMode.protection, Colors.green),
          const SizedBox(height: 4),
          _sideButton(Icons.gps_fixed, '攻击', AnalysisMode.attack, Colors.red),
          const SizedBox(height: 4),
          _sideButton(Icons.verified_user, '安全', AnalysisMode.safety, Colors.blue),
          const SizedBox(height: 4),
          _sideButton(Icons.warning, '危险', AnalysisMode.danger, Colors.orange),
        ],
      ),
    );

    // 中央棋盘区域
    final boardArea = Column(
      children: [
        GameInfoBar(
          currentSide: _gameState.currentSide,
          inCheck: _gameState.inCheck,
          moveCount: _gameState.moveCount,
        ),
        _buildStatsRow(),
        if (widget.isAiMode)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_aiThinking) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                if (_aiThinking) const SizedBox(width: 6),
                Text(
                  _aiThinking ? 'AI 思考中... (${_aiPlayer?.difficultyName ?? ''})' : '${_aiPlayer?.difficultyName ?? ''} 模式',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        Flexible(
          flex: 1,
          fit: FlexFit.loose,
          child: ChessBoard(
            board: _gameState.board,
            selectedPos: _selectedPos,
            validMoves: _validMoves,
            lastMove: _gameState.lastMove,
            animPiece: _animPiece,
            playerSide: widget.playerSide,
            analysisMode: _analysisMode,
            analysisData: _analysisMode != AnalysisMode.none ? AnalysisData.compute(_gameState.board) : null,
            analysisSelectedPos: _analysisMode != AnalysisMode.none ? _analysisSelectedPos : null,
            onCellTap: _onCellTap,
            onCellHover: _analysisMode != AnalysisMode.none
                ? (pos) {
                    if (pos == null) {
                      setState(() => _analysisSelectedPos = null);
                      return;
                    }
                    final piece = _gameState.board.at(pos);
                    if (_analysisMode == AnalysisMode.protection || _analysisMode == AnalysisMode.safety) {
                      if (piece != null && piece.side == _gameState.currentSide) {
                        if (_analysisSelectedPos != pos) setState(() => _analysisSelectedPos = pos);
                      } else {
                        if (_analysisSelectedPos != null) setState(() => _analysisSelectedPos = null);
                      }
                    } else {
                      final enemySide = _gameState.currentSide.opponent;
                      if (piece != null && piece.side == enemySide) {
                        if (_analysisSelectedPos != pos) setState(() => _analysisSelectedPos = pos);
                      } else {
                        if (_analysisSelectedPos != null) setState(() => _analysisSelectedPos = null);
                      }
                    }
                  }
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(icon: const Icon(Icons.undo), tooltip: '悔棋', onPressed: _undo),
            const SizedBox(width: 16),
            IconButton(icon: const Icon(Icons.refresh), tooltip: '重新开始', onPressed: _reset),
            const SizedBox(width: 16),
            IconButton(
              icon: Icon(_showDebug ? Icons.bug_report : Icons.bug_report_outlined),
              tooltip: '调试面板', onPressed: () => setState(() => _showDebug = !_showDebug),
            ),
          ],
        ),
        if (_gameState.result != GameResult.playing)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip(
                  label: Text(_gameState.result == GameResult.redWin ? '红方胜！' : '黑方胜！',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  backgroundColor: _gameState.result == GameResult.redWin ? Colors.red : Colors.black,
                ),
                const SizedBox(height: 4),
                Text(_gameState.inCheckmate ? '将杀' : (_gameState.inStalemate ? '困毙' : ''),
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('中国象棋')),
      body: Center(
        child: _showDebug
            ? Row(
                children: [
                  Expanded(child: boardArea),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.4, child: DebugOverlay(gameState: _gameState)),
                ],
              )
            : Row(
                children: [
                  moveList,
                  const VerticalDivider(width: 1),
                  Expanded(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: boardArea)),
                  if (_gameState.result == GameResult.playing) ...[
                    const VerticalDivider(width: 1),
                    rightButtons,
                  ],
                ],
              ),
      ),
    );
  }

  Widget _sideButton(IconData icon, String label, AnalysisMode mode, Color color) {
    final active = _analysisMode == mode;
    return GestureDetector(
      onTap: () => setState(() {
        _analysisMode = active ? AnalysisMode.none : mode;
        _analysisSelectedPos = null;
      }),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? color : Colors.grey.shade300, width: active ? 2 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: active ? color : Colors.grey),
            Text(label, style: TextStyle(fontSize: 9, color: active ? color : Colors.grey)),
          ],
        ),
      ),
    );
  }
}
