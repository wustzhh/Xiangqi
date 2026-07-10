import 'dart:async';
import 'package:flutter/material.dart';
import '../engine/board.dart';
import '../engine/game_state.dart';
import '../engine/piece.dart';
import '../engine/rules.dart';
import '../models/game_record.dart';
import '../utils/constants.dart';
import '../widgets/chess_board.dart';
import '../widgets/move_list.dart';

/// 复盘页面
class ReplayScreen extends StatefulWidget {
  final GameRecord record;

  const ReplayScreen({super.key, required this.record});

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen>
    with SingleTickerProviderStateMixin {
  late Board _board;
  int _currentIndex = -1;
  Timer? _autoPlayTimer;
  bool _isAutoPlaying = false;
  bool _showMoveList = true;
  bool _isEditMode = false;

  // 动画
  late AnimationController _animController;
  AnimationPiece? _animPiece;
  bool _isAnimating = false;
  int? _pendingTargetIndex; // 动画完成后跳到的步数

  // 分支模拟
  List<RecordedMove> _branchMoves = [];
  int _branchStartIndex = -1;

  // 编辑模式选中
  Position? _editSelected;
  List<Position> _editValidMoves = [];

  @override
  void initState() {
    super.initState();
    _board = Board.initial();
    _animController = AnimationController(
      vsync: this,
      duration: moveAnimDuration,
    );
    _animController.addListener(_onAnimTick);
    _animController.addStatusListener(_onAnimDone);
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _animController.removeListener(_onAnimTick);
    _animController.removeStatusListener(_onAnimDone);
    _animController.dispose();
    super.dispose();
  }

  void _onAnimTick() {
    if (_pendingTargetIndex == null) return;
    final idx = _pendingTargetIndex!;
    if (idx < 0 || idx >= _allMoves.length) return;
    final m = _allMoves[idx];
    final piece = _board.at(Position(m.fromCol, m.fromRow));
    if (piece == null) return;
    setState(() {
      _animPiece = AnimationPiece(
        piece: piece,
        from: Position(m.fromCol, m.fromRow),
        to: Position(m.toCol, m.toRow),
        progress: _animController.value,
      );
    });
  }

  void _onAnimDone(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_pendingTargetIndex == null) return;
    // 动画完成，真正走棋
    final idx = _pendingTargetIndex!;
    _applyMove(idx);
    setState(() {
      _animPiece = null;
      _isAnimating = false;
      _currentIndex = idx;
      _pendingTargetIndex = null;
    });
    // 如果在自动播放中，继续下一步
    if (_isAutoPlaying && _currentIndex < _allMoves.length - 1) {
      // 定时器会触发下一步（不经过 _goToMove）
    }
  }

  /// 所有走法（原记录 + 分支）
  List<RecordedMove> get _allMoves =>
      _branchMoves.isEmpty
          ? widget.record.moves
          : widget.record.moves.sublist(0, _branchStartIndex + 1) + _branchMoves;

  /// 应用一步走法（直接修改棋盘，无动画）
  void _applyMove(int index) {
    final m = _allMoves[index];
    _board.move(Position(m.fromCol, m.fromRow), Position(m.toCol, m.toRow));
  }

  /// 重建棋盘到指定步数
  void _rebuildBoardTo(int index) {
    _board = Board.initial();
    for (int i = 0; i <= index && i < _allMoves.length; i++) {
      _applyMove(i);
    }
  }

  /// 跳到指定步数（带动画，自动播放时不取消定时器）
  void _goToMove(int index, {bool fromAutoPlay = false}) {
    if (_isAnimating) return;
    index = index.clamp(-1, _allMoves.length - 1);

    if (!fromAutoPlay) {
      // 手动跳转：直接走，无动画
      _autoPlayTimer?.cancel();
      _isAutoPlaying = false;
      _rebuildBoardTo(index);
      setState(() {
        _currentIndex = index;
        _animPiece = null;
      });
    } else {
      // 自动播放下一步：带动画
      if (index < 0 || index > _currentIndex + 1) return;
      if (index == _currentIndex + 1) {
        // 预走棋（让棋盘先到目标步的前一步）
        _rebuildBoardTo(index - 1);
        setState(() {
          _pendingTargetIndex = index;
          _isAnimating = true;
        });
        _animController.forward(from: 0);
      } else {
        _rebuildBoardTo(index);
        setState(() {
          _currentIndex = index;
        });
      }
    }
  }

  void _prevStep() {
    if (_currentIndex > -1) _goToMove(_currentIndex - 1);
  }

  void _nextStep() {
    if (_currentIndex < _allMoves.length - 1) {
      _goToMove(_currentIndex + 1, fromAutoPlay: _isAutoPlaying);
    }
  }

  void _toStart() => _goToMove(-1);

  void _toEnd() => _goToMove(_allMoves.length - 1);

  void _toggleAutoPlay() {
    if (_isAutoPlaying) {
      _autoPlayTimer?.cancel();
      setState(() => _isAutoPlaying = false);
      return;
    }
    // 如果已经在最后，从头开始
    if (_currentIndex >= _allMoves.length - 1) {
      _rebuildBoardTo(-1);
      _currentIndex = -1;
    }
    setState(() => _isAutoPlaying = true);
    _autoPlayTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (!mounted) return;
      if (_currentIndex < _allMoves.length - 1) {
        _nextStep();
      } else {
        _autoPlayTimer?.cancel();
        setState(() => _isAutoPlaying = false);
      }
    });
  }

  /// 进入/退出编辑模式
  void _toggleEditMode() {
    _autoPlayTimer?.cancel();
    _isAutoPlaying = false;
    if (_isEditMode) {
      // 退出编辑：保留分支
      setState(() => _isEditMode = false);
    } else {
      // 进入编辑：记录分支起点
      setState(() {
        _isEditMode = true;
        _branchStartIndex = _currentIndex;
        _editSelected = null;
        _editValidMoves = [];
      });
    }
  }

  /// 还原到分支前
  void _restoreToBranchPoint() {
    if (_branchMoves.isEmpty) return;
    setState(() {
      _branchMoves.clear();
      _branchStartIndex = -1;
      _isEditMode = false;
      _editSelected = null;
      _editValidMoves = [];
      _rebuildBoardTo(_currentIndex);
    });
  }

  /// 编辑模式点击棋盘（同游戏界面交互）
  void _onEditTap(Position pos) {
    if (_isAnimating) return;

    final piece = _board.at(pos);
    // 确定当前该谁走
    final historyCount = _branchStartIndex >= 0
        ? _branchStartIndex + _branchMoves.length + 1
        : _currentIndex + 1;
    final currentSide = historyCount % 2 == 0 ? Side.red : Side.black;

    if (_editSelected == null) {
      if (piece == null || piece.side != currentSide) return;
      final rules = Rules(_board);
      final moves = rules.getLegalMoves(pos);
      if (moves.isEmpty) return;
      setState(() {
        _editSelected = pos;
        _editValidMoves = moves;
      });
    } else {
      if (piece != null && piece.side == currentSide) {
        // 切换选中
        final rules = Rules(_board);
        final moves = rules.getLegalMoves(pos);
        setState(() {
          _editSelected = pos;
          _editValidMoves = moves;
        });
      } else if (_editValidMoves.contains(pos)) {
        // 走棋
        _makeBranchMove(_editSelected!, pos);
        setState(() {
          _editSelected = null;
          _editValidMoves = [];
        });
      } else {
        setState(() {
          _editSelected = null;
          _editValidMoves = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final totalMoves = _allMoves.length;
    final progress = totalMoves > 0
        ? ((_currentIndex + 1) / totalMoves).clamp(0.0, 1.0)
        : 0.0;

    final redLabel = record.redPlayer.type == PlayerType.human ? '玩家' : 'AI';
    final blackLabel =
        record.blackPlayer.type == PlayerType.human ? '玩家' : 'AI';
    final resultText = record.result == GameResult.redWin
        ? '红胜'
        : record.result == GameResult.blackWin ? '黑胜' : '和棋';
    final hasBranch = _branchMoves.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(hasBranch ? '复盘（分支中）' : '复盘 — $resultText'),
        actions: [
          if (hasBranch)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: '还原分支',
              onPressed: _restoreToBranchPoint,
            ),
          IconButton(
            icon: Icon(_isEditMode ? Icons.edit_off : Icons.edit),
            tooltip: _isEditMode ? '退出编辑' : '编辑/模拟',
            onPressed: _toggleEditMode,
          ),
          IconButton(
            icon: Icon(_showMoveList ? Icons.list : Icons.list_alt),
            tooltip: '走法列表',
            onPressed: () => setState(() => _showMoveList = !_showMoveList),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isEditMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.orange.shade100,
              child: const Text('模拟模式 — 点击棋盘走棋',
                  style: TextStyle(fontSize: 13, color: Colors.orange)),
            ),
          if (hasBranch)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: Colors.purple.shade100,
              child: Text('分支中（${_branchMoves.length}步）',
                  style: TextStyle(fontSize: 13, color: Colors.purple.shade700)),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _sideInfo(Side.red, redLabel),
                const SizedBox(width: 16),
                Text(resultText,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                _sideInfo(Side.black, blackLabel),
              ],
            ),
          ),
          Expanded(
            child: _showMoveList
                ? Row(
                    children: [
                      Expanded(flex: 3, child: _buildBoard()),
                      SizedBox(
                        width: 160,
                        child: MoveList(
                          moves: _allMoves,
                          currentIndex: _currentIndex,
                          onMoveTap: (i) => _goToMove(i),
                        ),
                      ),
                    ],
                  )
                : _buildBoard(),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: progress,
                  onChanged: (v) {
                    final idx = (v * totalMoves).round() - 1;
                    _goToMove(idx.clamp(-1, totalMoves - 1));
                  },
                ),
                Text('${_currentIndex + 1} / $totalMoves',
                    style:
                        const TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.skip_previous),
                        tooltip: '跳到开头',
                        onPressed: _toStart),
                    IconButton(
                        icon: const Icon(Icons.chevron_left),
                        tooltip: '上一步',
                        onPressed: _prevStep),
                    IconButton(
                        icon: Icon(_isAutoPlaying
                            ? Icons.pause
                            : Icons.play_arrow),
                        tooltip: _isAutoPlaying ? '暂停' : '自动播放',
                        onPressed: _toggleAutoPlay),
                    IconButton(
                        icon: const Icon(Icons.chevron_right),
                        tooltip: '下一步',
                        onPressed: _nextStep),
                    IconButton(
                        icon: const Icon(Icons.skip_next),
                        tooltip: '跳到结尾',
                        onPressed: _toEnd),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideInfo(Side side, String label) {
    final color = side == Side.red ? Colors.red : Colors.black;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: color, size: 12),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 13, color: color)),
      ],
    );
  }

  Widget _buildBoard() {
    final lastMove = _currentIndex >= 0 && _currentIndex < _allMoves.length
        ? _allMoves[_currentIndex].toMove()
        : null;

    return Padding(
      padding: const EdgeInsets.all(4),
      child: ChessBoard(
        board: _board,
        selectedPos: _isEditMode ? _editSelected : null,
        validMoves: _isEditMode ? _editValidMoves : const [],
        lastMove: lastMove,
        animPiece: _animPiece,
        onCellTap: _isEditMode ? _onEditTap : (_) {},
      ),
    );
  }

  /// 编辑模式走棋
  void _makeBranchMove(Position from, Position to) {
    if (_branchStartIndex == -1) _branchStartIndex = _currentIndex;
    // 截断：删除分支起点后的所有原分支走法
    // 记录当前棋盘上的棋子信息
    final piece = _board.at(from);
    final captured = _board.at(to);
    if (piece == null) return;

    _board.move(from, to);
    final recordedMove = RecordedMove(
      moveNumber: _currentIndex + 2,
      fromCol: from.col,
      fromRow: from.row,
      toCol: to.col,
      toRow: to.row,
      pieceType: piece.type.name,
      side: piece.side.name,
      capturedType: captured?.type.name,
      capturedSide: captured?.side.name,
    );
    _branchMoves.add(recordedMove);
    setState(() {
      _currentIndex = _branchStartIndex + _branchMoves.length;
    });
  }
}
