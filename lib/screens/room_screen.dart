/// 房间界面 — 等待/对局/观战

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../engine/board.dart';
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
  const RoomScreen({
    super.key,
    required this.roomId,
    this.initialSide,
    this.gameAlreadyStarted = false,
    this.isHost = false,
  });

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
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
    if (widget.gameAlreadyStarted) {
      _gameStarted = true;
      _board = Board.initial();
      _rules = Rules(_board);
      _currentTurn = Side.red;
      _myTurn = _mySideStr == 'red';
    }
    _subscription = _net.messageController.stream.listen(_onMessage);
  }

  @override
  void dispose() {
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
        break;
      case 'player_joined':
        final player = data['player'] as Map<String, dynamic>?;
        if (player != null) _players.add(PlayerInfo.fromJson(player));
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
        _board.move(Position(f['col'] as int, f['row'] as int), Position(t['col'] as int, t['row'] as int));
        _rules = Rules(_board); _currentTurn = _currentTurn.opponent;
        _myTurn = !_isSpectator && _currentTurn == _mySide;
        _selectedPos = null; _validMoves = [];
        break;
      case 'game_over':
        _winner = data['winner'] as String?;
        break;
      case 'player_left':
        _players.removeWhere((p) => p.id == data['playerId'] as String?);
        break;
    }
    if (mounted) setState(() {});
  }

  void _onCellTap(Position pos) {
    if (!_gameStarted || _isSpectator || !_myTurn || _winner != null) return;
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

  /// 中间区域：房间设置面板
  Widget _buildSettingsPanel() {
    final canUndo = _settings['canUndo'] as String? ?? 'mutual';

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
    setState(() { _settings[key] = value; _net.updateSettings({key: value}); });
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
              icon: Icon(Icons.remove_circle_outline, size: 20, color: const Color(0xFF8B0000)),
              onPressed: value > min ? () => _updateSetting(key, value - step) : null,
              constraints: const BoxConstraints(),
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
              icon: Icon(Icons.add_circle_outline, size: 20, color: const Color(0xFF8B0000)),
              onPressed: value < max ? () => _updateSetting(key, value == 0 ? step : value + step) : null,
              constraints: const BoxConstraints(),
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
        child: _isHost
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
        body: Column(
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
              if (_winner == null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: _myTurn ? Colors.blue.shade50 : Colors.grey.shade100,
                  child: Row(
                    children: [
                      if (_myTurn) const Icon(Icons.play_arrow, size: 16, color: Colors.blue),
                      Text(_isSpectator ? '观战中' : (_myTurn ? '轮到你了' : '等待对手走棋...'),
                        style: TextStyle(fontSize: 13, color: _myTurn ? Colors.blue : Colors.grey)),
                    ],
                  ),
                ),
              Expanded(child: Center(child: ChessBoard(
                board: _board, selectedPos: _selectedPos, validMoves: _validMoves,
                lastMove: null, animPiece: null,
                playerSide: _mySide ?? Side.red,
                analysisMode: AnalysisMode.none, onCellTap: _onCellTap,
              ))),
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
            if (_showIntro) SwordsIntroAnimation(onComplete: _onIntroComplete),
          ],
        ),
      ),
    );
  }
}
