/// 房间界面 — 等待/对局/观战

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../engine/board.dart';
import '../engine/move.dart';
import '../engine/piece.dart';
import '../engine/rules.dart';
import '../models/room_info.dart';
import '../services/network_service.dart';
import '../widgets/chess_board.dart';
import '../widgets/swords_intro.dart';
import '../models/analysis_data.dart';

/// 调试日志
void _log(String msg) {
  print(msg);
  try {
    File('xiangqi_debug.txt').writeAsStringSync('$msg\n', mode: FileMode.append);
  } catch (_) {}
}

class RoomScreen extends StatefulWidget {
  final String roomId;
  final String? initialSide;
  final bool gameAlreadyStarted;
  final bool isHost;
  final Map<String, dynamic>? joinedData;
  const RoomScreen({
    super.key,
    required this.roomId,
    this.initialSide,
    this.gameAlreadyStarted = false,
    this.isHost = false,
    this.joinedData,
  });

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen>
    with SingleTickerProviderStateMixin {
  final NetworkService _net = NetworkService();
  StreamSubscription? _subscription;

  String _roomName = '';
  List<PlayerInfo> _players = [];
  // ignore: unused_field
  List<PlayerInfo> _spectators = [];
  String? _mySideStr;
  bool _gameStarted = false;
  bool _isHost = false;
  bool _myReady = false;
  bool _bothReady = false;
  bool _showIntro = false;
  bool _opponentDisconnected = false;

  // 局面分析
  AnalysisMode _analysisMode = AnalysisMode.none;
  AnalysisData? get _analysisData =>
      _analysisMode == AnalysisMode.none ? null : AnalysisData.compute(_board);

  // 棋谱
  final List<String> _moveList = [];
  bool _showMoveList = false;

  // 正在等待对方回应的请求
  bool _pendingDrawRequest = false;
  bool _pendingUndoRequest = false;
  bool _hasPendingRequest = false; // 对方发来的待处理请求

  // 走棋历史（用于悔棋）
  final List<Board> _boardHistory = [];

  // 房间设置
  Map<String, dynamic> _settings = {
    'canUndo': 'mutual',  // 'none' | 'mutual' | 'force'
    'undoLimit': 3,
    'timePerMove': 0,
    'totalTime': 0,
    'sideChoice': 'host_red',
  };

  Board _board = Board.initial();
  Rules _rules = Rules(Board.initial());
  Side _currentTurn = Side.red;
  bool _myTurn = false;
  Position? _selectedPos;
  List<Position> _validMoves = [];
  String? _winner;

  // 棋子移动动画
  Position? _animFrom;
  Position? _animTo;
  bool _isAnimating = false;
  late AnimationController _moveAnimCtrl;
  late Animation<double> _moveAnim;

  Side? _sideFromStr(String? s) {
    if (s == 'red') return Side.red;
    if (s == 'black') return Side.black;
    return null;
  }

  Side? get _mySide => _sideFromStr(_mySideStr);
  bool get _isSpectator => _mySide == null;

  @override
  void initState() {
    super.initState();
    _log('[RoomScreen] initState: isHost=${widget.isHost} initialSide=${widget.initialSide}');
    if (widget.initialSide != null) _mySideStr = widget.initialSide;
    if (widget.isHost) {
      _isHost = true;
      _players = [PlayerInfo(
        id: _net.playerId ?? 'host_${DateTime.now().millisecondsSinceEpoch}',
        name: _net.playerName ?? '我', side: 'red',
      )];
    }
    // 从 joinedData 恢复玩家列表和房间信息（首次加入和重连都用）
    if (widget.joinedData != null) {
      final data = widget.joinedData!;
      _roomName = data['roomName'] as String? ?? '';
      if (data['yourSide'] != null) _mySideStr = data['yourSide'] as String?;
      final playersRaw = data['players'] as List<dynamic>? ?? [];
      _players = playersRaw.map((e) => PlayerInfo.fromJson(e as Map<String, dynamic>)).toList();
      final specRaw = data['spectators'] as List<dynamic>? ?? [];
      _spectators = specRaw.map((e) => PlayerInfo.fromJson(e as Map<String, dynamic>)).toList();
      if (data['settings'] != null) _settings = Map<String, dynamic>.from(data['settings'] as Map);
      if (data['gameStarted'] == true) {
        _gameStarted = true;
        final history = data['moveHistory'] as List<dynamic>? ?? [];
        _replayMoves(history);
      }
    } else if (widget.gameAlreadyStarted) {
      _gameStarted = true;
      _board = Board.initial();
      _rules = Rules(_board);
      _currentTurn = Side.red;
      _myTurn = _mySideStr == 'red';
    }
    _moveAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _moveAnim = CurvedAnimation(parent: _moveAnimCtrl, curve: Curves.easeInOut);
    _moveAnimCtrl.addListener(_onAnimTick);
    _moveAnimCtrl.addStatusListener((s) { if (s == AnimationStatus.completed) _onMoveAnimComplete(); });
    _subscription = _net.messageController.stream.listen(_onMessage);
  }

  @override
  void dispose() {
    _moveAnimCtrl.dispose();
    _subscription?.cancel();
    _net.leaveRoom();
    super.dispose();
  }

  void _onMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    _log('[RoomScreen] msg: $type');

    switch (type) {
      case 'room_created':
        _isHost = true;
        _roomName = (data['room'] as Map<String, dynamic>?)?['name'] as String? ?? '';
        if (data['settings'] != null) _settings = Map<String, dynamic>.from(data['settings'] as Map);
        if (_net.playerId != null) {
          _players = [PlayerInfo(id: _net.playerId!, name: _net.playerName ?? '我', side: 'red')];
        }
        break;
      case 'room_joined':
        _roomName = data['roomName'] as String? ?? '';
        _mySideStr = data['yourSide'] as String?;
        _players = (data['players'] as List<dynamic>?)?.map((e) => PlayerInfo.fromJson(e as Map<String, dynamic>)).toList() ?? [];
        _spectators = (data['spectators'] as List<dynamic>?)?.map((e) => PlayerInfo.fromJson(e as Map<String, dynamic>)).toList() ?? [];
        if (data['settings'] != null) _settings = Map<String, dynamic>.from(data['settings'] as Map);
        // 重连时从 moveHistory 恢复棋盘
        if (data['reconnected'] == true && data['moveHistory'] != null) {
          final history = data['moveHistory'] as List<dynamic>;
          _replayMoves(history);
          _gameStarted = true;
        }
        break;
      case 'player_joined':
        final playerData = data['player'] as Map<String, dynamic>?;
        final isReconnected = data['reconnected'] == true;
        if (playerData != null) {
          final newP = PlayerInfo.fromJson(playerData);
          if (isReconnected && _gameStarted) {
            // 重连：更新玩家信息（替换已存在的或添加）
            _opponentDisconnected = false;
            final idx = _players.indexWhere((p) => p.side == newP.side);
            if (idx >= 0) {
              _players[idx] = newP;
            } else {
              _players.add(newP);
            }
          } else {
            _players.add(newP);
          }
        }
        break;
      case 'settings_updated':
        if (data['settings'] != null) _settings = Map<String, dynamic>.from(data['settings'] as Map);
        break;
      case 'ready_changed':
        final pid = data['playerId'] as String?;
        final ready = data['ready'] as bool? ?? false;
        _bothReady = data['bothReady'] as bool? ?? false;
        if (pid == _net.playerId) _myReady = ready;
        break;
      case 'game_start':
        _showIntro = true;
        _board = Board.initial(); _rules = Rules(_board);
        _mySideStr = data['yourSide'] as String? ?? _mySideStr;
        _currentTurn = Side.red; _myTurn = _mySideStr == 'red';
        _selectedPos = null; _validMoves = []; _winner = null;
        break;
      case 'move_made':
        if (!_gameStarted) { _gameStarted = true; _board = Board.initial(); _rules = Rules(_board); _currentTurn = Side.red; _myTurn = _mySideStr == 'red'; }
        final f = data['from'] as Map; final t = data['to'] as Map;
        _animFrom = Position(f['col'] as int, f['row'] as int);
        _animTo = Position(t['col'] as int, t['row'] as int);
        _isAnimating = true;
        // 记录走法文字（格式：棋子 起→止）
        final piece = _board.at(_animFrom!);
        final pieceName = piece != null ? _pieceChar(piece.type, piece.side) : '?';
        _moveList.add('$pieceName ${_posStr(_animFrom!)}→${_posStr(_animTo!)}');
        _moveAnimCtrl.forward(from: 0.0);
        break;
      case 'game_over':
        _winner = data['winner'] as String?;
        // 弹出对局结果弹窗
        WidgetsBinding.instance.addPostFrameCallback((_) => _showGameOverDialog(data));
        break;
       case 'player_left':
        final leftId = data['playerId'] as String?;
        final isDisconnected = data['disconnected'] == true;
        if (isDisconnected && _gameStarted) {
          // 对局中断线：标记为断线，不移除
          _opponentDisconnected = true;
        } else {
          _players.removeWhere((p) => p.id == leftId);
        }
        break;
      case 'room_closed':
        _showRoomClosedDialog(data['reason'] as String? ?? '房间已关闭');
        break;
      case 'room_updated':
        final action = data['action'] as String?;
        if (action == 'undo_response') {
          if (_boardHistory.length >= 2) {
            _boardHistory.removeLast();
            _boardHistory.removeLast();
            _board = _boardHistory.last;
            _rules = Rules(_board);
            _currentTurn = _currentTurn.opponent;
            _myTurn = _currentTurn == _mySide;
            _selectedPos = null; _validMoves = [];
          }
        } else if (action == 'draw_offer') {
          _hasPendingRequest = true;
          _showDrawUndoDialog(data, 'draw');
        } else if (action == 'undo_request') {
          _hasPendingRequest = true;
          _showDrawUndoDialog(data, 'undo');
        }
        break;
    }
    if (mounted) setState(() {});
  }

  void _onCellTap(Position pos) {
    if (!_gameStarted || _isSpectator || !_myTurn || _winner != null) return;
    if (_opponentDisconnected) return;
    if (_mySide == null) return;
    final piece = _board.at(pos);
    if (_selectedPos == null) {
      if (piece == null || piece.side != _mySide) return;
      if (piece.side != _currentTurn) return;
      setState(() { _selectedPos = pos; _validMoves = _rules.getLegalMoves(pos); });
    } else {
      if (piece != null && piece.side == _mySide) {
        setState(() { _selectedPos = pos; _validMoves = _rules.getLegalMoves(pos); });
      } else if (_validMoves.contains(pos)) {
        _net.makeMove(_selectedPos!.col, _selectedPos!.row, pos.col, pos.row);
        setState(() { _selectedPos = null; _validMoves = []; });
      } else {
        setState(() { _selectedPos = null; _validMoves = []; });
      }
    }
  }

  void _onIntroComplete() {
    setState(() { _showIntro = false; _gameStarted = true; });
  }
  void _showGameOverDialog(Map<String, dynamic> data) {
    final winner = data['winner'] as String? ?? 'none';
    final reason = data['reason'] as String? ?? '';
    if (!mounted) return;
    String title, msg;
    if (winner == 'draw') {
      title = '和棋';
      msg = reason.isNotEmpty ? reason : '双方握手言和';
    } else if ((winner == 'red' && _mySideStr == 'red') || (winner == 'black' && _mySideStr == 'black')) {
      title = '恭喜，你赢了！';
      msg = reason.isNotEmpty ? '原因：' + reason : '';
    } else {
      title = '你输了';
      msg = reason.isNotEmpty ? '原因：' + reason : '';
    }
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      title: Text(title, textAlign: TextAlign.center),
      content: msg.isNotEmpty ? Text(msg, textAlign: TextAlign.center) : null,
      actions: [FilledButton(onPressed: () { Navigator.pop(ctx); _net.leaveRoom(); Navigator.pop(context); }, child: const Text('返回大厅'))],
    ));
  }

  void _showDrawUndoDialog(Map<String, dynamic> data, String type) {
    final playerName = data['playerName'] as String? ?? '对方';
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      title: Text(type == 'draw' ? '求和请求' : '悔棋请求'),
      content: Text(playerName + '请求' + (type == 'draw' ? '和棋' : '悔棋') + '，是否同意？'),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () { Navigator.pop(ctx); _hasPendingRequest = false; _net.send({'type': 'draw_response', 'accept': false}); }, child: const Text('拒绝')),
        FilledButton(onPressed: () { Navigator.pop(ctx); _hasPendingRequest = false; _net.send({'type': 'draw_response', 'accept': true}); }, child: const Text('同意')),
      ],
    ));
  }


  void _onAnimTick() {
    if (!_isAnimating || !mounted) return;
    if (_moveAnimCtrl.value >= 1.0) return;
    setState(() {});
  }

  void _onMoveAnimComplete() {
    if (!mounted || _animFrom == null || _animTo == null) return;
    _board.move(_animFrom!, _animTo!);
    _rules = Rules(_board); _currentTurn = _currentTurn.opponent;
    _myTurn = !_isSpectator && _currentTurn == _mySide;
    _boardHistory.add(_board.copy());
    _selectedPos = null; _validMoves = [];
    setState(() { _isAnimating = false; _animFrom = null; _animTo = null; });
  }

  /// 从走棋历史重放重建棋盘（断线重连用）
  void _replayMoves(List<dynamic> history) {
    _board = Board.initial();
    for (final entry in history) {
      final f = entry['from'] as Map;
      final t = entry['to'] as Map;
      _board.move(Position(f['col'] as int, f['row'] as int),
                   Position(t['col'] as int, t['row'] as int));
    }
    _rules = Rules(_board);
    _currentTurn = history.length.isEven ? Side.red : Side.black;
    _myTurn = _currentTurn == _mySide;
  }

  void _showRoomClosedDialog(String reason) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('房间已关闭'),
        content: Text(reason),
        actions: [
          FilledButton(onPressed: () {
            Navigator.pop(ctx);
            Navigator.pop(context);
          }, child: const Text('返回大厅')),
        ],
      ),
    );
  }

  // ─── UI ─────────────────────────────────

  /// 顶层：玩家头像与 ID
  Widget _buildPlayersHeader() {
    final redPlayer = _players.where((p) => p.side == 'red').firstOrNull;
    final blackPlayer = _players.where((p) => p.side == 'black').firstOrNull;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF8B0000).withValues(alpha: 0.05), const Color(0xFFFFD700).withValues(alpha: 0.05)],
        ),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // 红方
          Expanded(child: _playerCard(
            name: redPlayer?.name ?? '红方',
            sideLabel: '红方',
            color: const Color(0xFFCC0000),
            bgColor: const Color(0xFFCC0000).withValues(alpha: 0.1),
            isMe: _mySideStr == 'red',
            isReady: redPlayer != null && ((_mySideStr == 'red' && _myReady) || (_mySideStr != 'red' && _bothReady)),
            isEmpty: redPlayer == null,
            isDisconnected: _gameStarted && _opponentDisconnected && _mySideStr != 'red',
          )),
          // VS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Text('VS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 2)),
                const SizedBox(height: 4),
                Container(width: 2, height: 20, color: Colors.grey.shade300),
              ],
            ),
          ),
          // 黑方
          Expanded(child: _playerCard(
            name: blackPlayer?.name ?? '黑方',
            sideLabel: '黑方',
            color: Colors.black87,
            bgColor: Colors.black.withValues(alpha: 0.08),
            isMe: _mySideStr == 'black',
            isReady: blackPlayer != null && ((_mySideStr == 'black' && _myReady) || (_mySideStr != 'black' && _bothReady)),
            isEmpty: blackPlayer == null,
            isDisconnected: _gameStarted && _opponentDisconnected && _mySideStr != 'black',
          )),
        ],
      ),
    );
  }

  Widget _playerCard({
    required String name,
    required String sideLabel,
    required Color color,
    required Color bgColor,
    required bool isMe,
    required bool isReady,
    required bool isEmpty,
    bool isDisconnected = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 头像
          CircleAvatar(
            radius: 24,
            backgroundColor: isEmpty ? Colors.grey.shade300 : color,
            child: isEmpty
                ? Icon(Icons.person_off, size: 22, color: Colors.grey.shade500)
                : Text(name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 6),
          // 名字
          Text(
            isEmpty ? '等待中...' : name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
              color: isEmpty ? Colors.grey : (isMe ? Colors.black87 : Colors.grey.shade700),
            ),
          ),
          const SizedBox(height: 4),
          // 标签行
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(sideLabel, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('我', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
              if (isDisconnected) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('等待重连中', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
              if (isReady) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('已准备', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 中间状态提示
  Widget _buildWaitingStatus() {
    final hasTwoPlayers = _players.length >= 2;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasTwoPlayers ? Icons.check_circle : Icons.hourglass_empty,
            size: 20,
            color: hasTwoPlayers ? Colors.green : const Color(0xFFB8860B),
          ),
          const SizedBox(width: 8),
          Text(
            hasTwoPlayers ? '两名玩家已就绪，可以开始对局' : '等待对手加入...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: hasTwoPlayers ? Colors.green.shade700 : const Color(0xFF8B6914),
            ),
          ),
        ],
      ),
    );
  }

  String _settingsStr(String key, String fallback) {
    final v = _settings[key];
    if (v is String) return v;
    if (v is bool && key == 'canUndo') return v ? 'mutual' : 'none';
    return fallback;
  }

  /// 中间区域：房间设置面板
  Widget _buildSettingsPanel() {
    final canUndo = _settingsStr('canUndo', 'mutual');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.tune, size: 18, color: const Color(0xFF8B0000)),
                const SizedBox(width: 8),
                const Text('房间设置', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                if (!_isHost) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('只读', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ),
                ],
              ],
            ),
          ),
          // 设置项
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                // 悔棋模式
                _buildSettingItem(
                  icon: Icons.undo,
                  label: '悔棋模式',
                  valueWidget: DropdownButton<String>(
                    value: canUndo,
                    underline: const SizedBox(),
                    isDense: true,
                    style: TextStyle(fontSize: 13, color: _isHost ? Colors.black87 : Colors.grey),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('无悔', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'mutual', child: Text('双方同意才悔棋', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'force', child: Text('强制悔棋(3次)', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: _isHost ? (v) => _updateSetting('canUndo', v) : null,
                  ),
                ),
                const Divider(height: 1, indent: 4),
                // 步时
                _buildTimeSetting(Icons.timer, '步时(秒)', 'timePerMove', 0, 300, 30),
                const Divider(height: 1, indent: 4),
                // 局时
                _buildTimeSetting(Icons.hourglass_bottom, '局时(分)', 'totalTime', 0, 60, 5),
                const Divider(height: 1, indent: 4),
                // 先后手
                _buildSettingItem(
                  icon: Icons.swap_horiz,
                  label: '先后手',
                  valueWidget: DropdownButton<String>(
                    value: _settings['sideChoice'] as String? ?? 'host_red',
                    underline: const SizedBox(),
                    isDense: true,
                    style: TextStyle(fontSize: 13, color: _isHost ? Colors.black87 : Colors.grey),
                    items: const [
                      DropdownMenuItem(value: 'host_red', child: Text('房主执红', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'host_black', child: Text('房主执黑', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'random', child: Text('随机分配', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: _isHost ? (v) => _updateSetting('sideChoice', v) : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _updateSetting(String key, dynamic value) {
    _settings[key] = value;
    _net.updateSettings({key: value});
    // 不调 setState，等服务端回声触发重建，避免闪动
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String label,
    required Widget valueWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF555555)))),
          const Spacer(),
          valueWidget,
        ],
      ),
    );
  }

  /// 步时/局时设置行（带 +/- 按钮）
  Widget _buildTimeSetting(IconData icon, String label, String key, int min, int max, int step) {
    final value = _settings[key] as int? ?? 0;
    final isMinDisabled = value <= min;
    final isMaxDisabled = value >= max;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF555555)))),
          const Spacer(),
          if (!_isHost)
            Text(
              value == 0 ? '不限' : '$value',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            )
          else ...[
            IconButton(
              icon: Icon(Icons.remove_circle_outline, size: 20,
                  color: isMinDisabled ? Colors.grey.shade300 : const Color(0xFF8B0000)),
              onPressed: isMinDisabled ? null : () => _updateSetting(key, (value - step).clamp(min, max)),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
            SizedBox(
              width: 48,
              child: Text(
                value == 0 ? '不限' : '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline, size: 20,
                  color: isMaxDisabled ? Colors.grey.shade300 : const Color(0xFF8B0000)),
              onPressed: isMaxDisabled ? null : () => _updateSetting(key, (value == 0 ? step : value + step).clamp(min, max)),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
    );
  }

  /// 底部：准备 + 开始按钮
  Widget _buildBottomActions() {
    final hasTwoPlayers = _players.length >= 2;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -4)),
        ],
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: _isSpectator
          ? const SizedBox()
          : _isHost
          ? Row(
              children: [
                // 先手：准备按钮（左）
                Expanded(child: _buildReadyButton()),
                const SizedBox(width: 12),
                // 先手：开始按钮（右）
                Expanded(child: _buildStartButton(hasTwoPlayers)),
              ],
            )
          : Center(
              child: SizedBox(
                width: hasTwoPlayers ? double.infinity : 280,
                child: _buildReadyButton(),
              ),
            ),
      ),
    );
  }

  Widget _buildReadyButton() {
    return SizedBox(
      height: 48,
      child: _myReady
        ? OutlinedButton.icon(
            onPressed: () => _net.toggleReady(),
            icon: const Icon(Icons.close, size: 20),
            label: const Text('取消准备', style: TextStyle(fontSize: 16)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange.shade700,
              side: BorderSide(color: Colors.orange.shade400),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          )
        : FilledButton.icon(
            onPressed: () => _net.toggleReady(),
            icon: const Icon(Icons.check, size: 20),
            label: const Text('准备', style: TextStyle(fontSize: 16)),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
    );
  }

  Widget _buildStartButton(bool hasTwoPlayers) {
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        onPressed: (hasTwoPlayers && _bothReady) ? () => _net.startGame() : null,
        icon: const Icon(Icons.play_arrow, size: 22),
        label: Text(
          !hasTwoPlayers ? '等待玩家加入'
          : !_bothReady ? '等待双方准备'
          : '开始游戏',
          style: const TextStyle(fontSize: 16),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFCC0000),
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade500,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // ─── 走法辅助 ────────────────────────────
  String _pieceChar(PieceType type, Side side) {
    const chars = {
      PieceType.general:   ['帥', '將'],
      PieceType.advisor: ['仕', '士'],
      PieceType.elephant: ['相', '象'],
      PieceType.horse:   ['傌', '馬'],
      PieceType.rook:   ['俥', '車'],
      PieceType.cannon: ['炮', '砲'],
      PieceType.soldier:   ['兵', '卒'],
    };
    return (chars[type] ?? ['?','?'])[side == Side.red ? 0 : 1];
  }

  String _posStr(Position p) => '${'一二三四五六七八九'[p.col]}${'１２３４５６７８９十'[p.row]}';

  // ─── 分析工具栏 ───────────────────────────
  Widget _buildAnalysisTools() {
    final modes = [
      (AnalysisMode.protection,  Icons.shield,    '护子'),
      (AnalysisMode.attack,   Icons.my_location,'攻击'),
      (AnalysisMode.safety,   Icons.security,   '安全'),
      (AnalysisMode.danger,   Icons.warning,    '危险'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final m in modes)
            _buildModeBtn(m.$1, m.$2, m.$3),
          // 棋谱按钮
          _buildModeBtn(AnalysisMode.none, Icons.list, '棋谱',
            onTap: () => setState(() => _showMoveList = !_showMoveList)),
          // 求和
          if (!_isSpectator)
            IconButton(
              icon: const Icon(Icons.handshake, size: 20, color: Colors.green),
              tooltip: '求和',
              onPressed: () { setState(() { _pendingDrawRequest = true; }); _net.send({'type': 'draw_offer'}); },
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          // 悔棋
          if (!_isSpectator)
            IconButton(
              icon: const Icon(Icons.undo, size: 20, color: Colors.brown),
              tooltip: '悔棋',
              onPressed: _canUndo ? () { setState(() { _pendingUndoRequest = true; }); _net.send({'type': 'undo_request'}); } : null,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
        ],
      ),
    );
  }

  bool get _canUndo {
    final setting = _settings['canUndo'] as String? ?? 'none';
    return setting != 'none' && !_isAnimating && _moveList.isNotEmpty && !_pendingUndoRequest;
  }

  Widget _buildModeBtn(AnalysisMode mode, IconData icon, String label, {VoidCallback? onTap}) {
    final active = (_analysisMode == mode && mode != AnalysisMode.none) || (label == '棋谱' && _showMoveList);
    return GestureDetector(
      onTap: onTap ?? () => setState(() {
        _analysisMode = _analysisMode == mode ? AnalysisMode.none : mode;
        _showMoveList = false;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Colors.blue.shade100 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: active ? Border.all(color: Colors.blue) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? Colors.blue : Colors.grey.shade600),
            const SizedBox(width: 3),
            Text(label, style: TextStyle(fontSize: 11, color: active ? Colors.blue : Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  // ─── 棋谱列表 ────────────────────────────
  Widget _buildMoveList() {
    if (!_showMoveList || _moveList.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        itemCount: _moveList.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text('${i+1}. ${_moveList[i]}',
            style: TextStyle(fontSize: 12, color: i.isOdd ? Colors.black87 : Colors.grey.shade700)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _log('[RoomScreen] build: game=$_gameStarted isHost=$_isHost p=${_players.length}');
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) return; _net.leaveRoom(); },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.flag, size: 18, color: const Color(0xFFCC0000)),
              const SizedBox(width: 8),
              Text(_roomName.isNotEmpty ? _roomName : '房间', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0.5,
          actions: [
            if (_gameStarted && !_isSpectator && _winner == null)
              IconButton(
                icon: const Icon(Icons.flag, color: Color(0xFFCC0000)),
                tooltip: '认输',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('认输'),
                      content: const Text('确定要认输吗？'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () { Navigator.pop(ctx); _net.resign(); },
                          child: const Text('认输', style: TextStyle(color: Colors.white))),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                // 等待状态
            if (!_gameStarted && !_showIntro) ...[
              _buildPlayersHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      // 等待提示
                      _buildWaitingStatus(),
                      // 设置面板
                      _buildSettingsPanel(),
                      const SizedBox(height: 80), // 给底部按钮留空间
                    ],
                  ),
                ),
              ),
              // 底部操作栏（固定在底部）
              _buildBottomActions(),
            ],
            // 游戏中
            if (_gameStarted) ...[
              // 对局中显示双方信息栏
              _buildPlayersHeader(),
              if (_winner == null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: _opponentDisconnected ? Colors.orange.shade50 : (_myTurn ? Colors.blue.shade50 : Colors.grey.shade100),
                  child: Row(
                    children: [
                      Icon(
                        _opponentDisconnected ? Icons.wifi_off : (_myTurn ? Icons.play_arrow : Icons.hourglass_empty),
                        size: 16,
                        color: _opponentDisconnected ? Colors.orange : (_myTurn ? Colors.blue : Colors.grey),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _opponentDisconnected
                              ? '对手已断线，等待重连中...'
                              : _isSpectator
                                  ? '观战中'
                                  : (_myTurn ? '轮到你了' : '等待对手走棋...'),
                          style: TextStyle(
                            fontSize: 13,
                            color: _opponentDisconnected ? Colors.orange.shade800 : (_myTurn ? Colors.blue : Colors.grey),
                            fontWeight: _opponentDisconnected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              _buildMoveList(),
              Expanded(child: Center(child: ChessBoard(
                board: _board, selectedPos: _selectedPos, validMoves: _validMoves,
                lastMove: null,
                animPiece: _isAnimating && _animFrom != null && _animTo != null
                    ? AnimationPiece(
                        piece: _board.at(_animFrom!)!,
                        from: _animFrom!,
                        to: _animTo!,
                        progress: _moveAnim.value,
                      )
                    : null,
                playerSide: _mySide ?? Side.red,
                analysisMode: _analysisMode,
                analysisData: _analysisData,
                onCellTap: _onCellTap,
              ))),
              // 分析工具栏
              if (_winner == null)
                _buildAnalysisTools(),
            ],
            // 游戏结束
            if (_winner != null)
              Container(
                padding: const EdgeInsets.all(16), color: Colors.black87,
                child: Column(children: [
                  Text(_winner == 'red' ? '🔴 红方胜！' : '⚫ 黑方胜！',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: () { _net.leaveRoom(); Navigator.pop(context); },
                      child: const Text('返回大厅')),
                ]),
              ),
            ],
          ),
            if (_showIntro)
              Positioned.fill(
                child: SwordsIntroAnimation(onComplete: _onIntroComplete),
              ),
          ],
        ),
      ),
    );
  }
}
