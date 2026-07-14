/// 房间界面 — 等待/对局/观战
library screens.room_screen;

import 'dart:async';
import 'package:flutter/material.dart';
import '../engine/board.dart';
import '../engine/piece.dart';
import '../engine/rules.dart';
import '../models/room_info.dart';
import '../services/network_service.dart';
import '../widgets/chess_board.dart';
import '../widgets/swords_intro.dart';
import '../models/analysis_data.dart';
import '../utils/constants.dart';

class RoomScreen extends StatefulWidget {
  final String roomId;
  final String? initialSide;
  final bool gameAlreadyStarted;
  final bool isHost;  // 房主标记，由大厅传入
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

  // 当前房间状态
  String _roomName = '';
  List<PlayerInfo> _players = [];
  List<PlayerInfo> _spectators = [];
  String? _mySideStr;
  bool _gameStarted = false;
  bool _isHost = false;
  bool _myReady = false;
  bool _bothReady = false;
  bool _showIntro = false;
  bool _showSettings = true;  // 默认展开

  // 房间设置（本地缓存）
  Map<String, dynamic> _settings = {
    'canUndo': true,
    'timePerMove': 0,
    'totalTime': 0,
    'sideChoice': 'host_red',
  };

  // 对局状态
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
    if (widget.initialSide != null) {
      _mySideStr = widget.initialSide;
    }
    if (widget.isHost) {
      _isHost = true;
      if (_net.playerId != null) {
        _players = [
          PlayerInfo(id: _net.playerId!, name: _net.playerName ?? '我', side: 'red'),
        ];
      }
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

    switch (type) {
      case 'room_created':
        _isHost = true;
        _roomName = (data['room'] as Map<String, dynamic>?)?['name'] as String? ?? '';
        if (data['settings'] != null) {
          _settings = Map<String, dynamic>.from(data['settings'] as Map);
        }
        // 房主加入玩家列表
        if (_net.playerId != null) {
          _players = [
            PlayerInfo(id: _net.playerId!, name: _net.playerName ?? '我', side: 'red'),
          ];
        }
        break;

      case 'room_joined':
        _roomName = data['roomName'] as String? ?? '';
        _mySideStr = data['yourSide'] as String?;
        _players = (data['players'] as List<dynamic>?)
                ?.map((e) => PlayerInfo.fromJson(e as Map<String, dynamic>))
                .toList() ?? [];
        _spectators = (data['spectators'] as List<dynamic>?)
                ?.map((e) => PlayerInfo.fromJson(e as Map<String, dynamic>))
                .toList() ?? [];
        if (data['settings'] != null) {
          _settings = Map<String, dynamic>.from(data['settings'] as Map);
        }
        break;

      case 'player_joined':
        final player = data['player'] as Map<String, dynamic>?;
        if (player != null) {
          _players.add(PlayerInfo.fromJson(player));
        }
        break;

      case 'settings_updated':
        if (data['settings'] != null) {
          _settings = Map<String, dynamic>.from(data['settings'] as Map);
        }
        break;

      case 'ready_changed':
        final pid = data['playerId'] as String?;
        final ready = data['ready'] as bool? ?? false;
        final bothReady = data['bothReady'] as bool? ?? false;
        _bothReady = bothReady;
        // 更新自己的准备状态
        if (pid == _net.playerId) {
          _myReady = ready;
        }
        break;

      case 'game_start':
        _showIntro = true;
        _board = Board.initial();
        _rules = Rules(_board);
        _mySideStr = data['yourSide'] as String? ?? _mySideStr;
        _currentTurn = Side.red;
        _myTurn = _mySideStr == 'red';
        _selectedPos = null;
        _validMoves = [];
        _winner = null;
        break;

      case 'move_made':
        if (!_gameStarted) {
          _gameStarted = true;
          _board = Board.initial();
          _rules = Rules(_board);
          _currentTurn = Side.red;
          _myTurn = _mySideStr == 'red';
        }

        final fromData = data['from'] as Map<String, dynamic>;
        final toData = data['to'] as Map<String, dynamic>;
        final from = Position(fromData['col'] as int, fromData['row'] as int);
        final to = Position(toData['col'] as int, toData['row'] as int);

        _board.move(from, to);
        _rules = Rules(_board);

        _currentTurn = _currentTurn.opponent;
        _myTurn = !_isSpectator && _currentTurn == _mySide;
        _selectedPos = null;
        _validMoves = [];
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
      setState(() {
        _selectedPos = pos;
        _validMoves = _rules.getLegalMoves(pos);
      });
    } else {
      if (piece != null && piece.side == _mySide) {
        setState(() {
          _selectedPos = pos;
          _validMoves = _rules.getLegalMoves(pos);
        });
      } else if (_validMoves.contains(pos)) {
        _net.makeMove(_selectedPos!.col, _selectedPos!.row, pos.col, pos.row);
        setState(() {
          _selectedPos = null;
          _validMoves = [];
        });
      } else {
        setState(() {
          _selectedPos = null;
          _validMoves = [];
        });
      }
    }
  }

  void _onIntroComplete() {
    setState(() {
      _showIntro = false;
      _gameStarted = true;
    });
  }

  // ─── 构建 UI ───────────────────────────────

  Widget _buildPlayersList() {
    final redPlayer = _players.where((p) => p.side == 'red').firstOrNull;
    final blackPlayer = _players.where((p) => p.side == 'black').firstOrNull;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          _playerChip('🔴 红方', redPlayer?.name ?? '等待中...', _mySideStr == 'red'),
          const Spacer(),
          const Text('VS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const Spacer(),
          _playerChip('⚫ 黑方', blackPlayer?.name ?? '等待中...', _mySideStr == 'black'),
        ],
      ),
    );
  }

  Widget _playerChip(String label, String name, bool isMe) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
            color: isMe ? Colors.black87 : Colors.grey.shade600,
          ),
        ),
        if (isMe) const Text('(我)', style: TextStyle(fontSize: 10, color: Colors.blue)),
      ],
    );
  }

  Widget _buildSettingsPanel() {
    final settings = _settings;
    final canUndo = settings['canUndo'] as bool? ?? true;
    final timePerMove = settings['timePerMove'] as int? ?? 0;
    final totalTime = settings['totalTime'] as int? ?? 0;
    final sideChoice = settings['sideChoice'] as String? ?? 'host_red';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showSettings = !_showSettings),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.settings, size: 16),
                  const SizedBox(width: 6),
                  const Text('房间设置', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const Spacer(),
                  Icon(_showSettings ? Icons.expand_less : Icons.expand_more, size: 18),
                ],
              ),
            ),
          ),
          if (_showSettings) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 悔棋
                  SwitchListTile(
                    dense: true,
                    title: const Text('允许悔棋', style: TextStyle(fontSize: 13)),
                    value: canUndo,
                    onChanged: _isHost ? (v) => _updateSetting('canUndo', v) : null,
                    contentPadding: EdgeInsets.zero,
                  ),
                  // 步时
                  Row(
                    children: [
                      const Text('步时: ', style: TextStyle(fontSize: 13)),
                      Expanded(
                        child: Slider(
                          value: timePerMove.toDouble(),
                          max: 300,
                          divisions: 10,
                          label: timePerMove == 0 ? '不限' : '${timePerMove}秒',
                          onChanged: _isHost ? (v) => _updateSetting('timePerMove', v.round()) : null,
                        ),
                      ),
                      SizedBox(
                        width: 50,
                        child: Text(
                          timePerMove == 0 ? '不限' : '${timePerMove}秒',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  // 局时
                  Row(
                    children: [
                      const Text('局时: ', style: TextStyle(fontSize: 13)),
                      Expanded(
                        child: Slider(
                          value: totalTime.toDouble(),
                          max: 60,
                          divisions: 12,
                          label: totalTime == 0 ? '不限' : '${totalTime}分钟',
                          onChanged: _isHost ? (v) => _updateSetting('totalTime', v.round()) : null,
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          totalTime == 0 ? '不限' : '${totalTime}分钟',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  // 先后手
                  DropdownButtonFormField<String>(
                    value: sideChoice,
                    decoration: const InputDecoration(
                      labelText: '先后手',
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'host_red', child: Text('房主执红', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'host_black', child: Text('房主执黑', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'random', child: Text('随机分配', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: _isHost ? (v) => _updateSetting('sideChoice', v) : null,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _updateSetting(String key, dynamic value) {
    setState(() {
      _settings[key] = value;
      _net.updateSettings({key: value});
    });
  }

  Widget _buildWaitingUI() {
    final hasTwoPlayers = _players.length >= 2;

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_players.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: CircularProgressIndicator(),
            ),
          if (_players.isNotEmpty) ...[
            // 玩家准备状态
            ..._players.map((p) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: p.id == _net.playerId ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(p.name ?? '玩家', style: const TextStyle(fontSize: 14)),
                  const Spacer(),
                  Text(
                    p.id == _net.playerId ? (_myReady ? '✅ 已准备' : '⏳ 未准备') : '⏳ 等待中',
                    style: TextStyle(
                      fontSize: 12,
                      color: p.id == _net.playerId && _myReady ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 16),
          ],
          if (!hasTwoPlayers)
            const Text('等待对手加入...', style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 24),
          // 准备按钮
          if (hasTwoPlayers && !_myReady)
            FilledButton.icon(
              onPressed: () => _net.toggleReady(),
              icon: const Icon(Icons.check),
              label: const Text('准备'),
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
            ),
          if (hasTwoPlayers && _myReady)
            OutlinedButton.icon(
              onPressed: () => _net.toggleReady(),
              icon: const Icon(Icons.close),
              label: const Text('取消准备'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
            ),
          const SizedBox(height: 12),
          // 开始按钮（房主专用）
          if (_isHost && hasTwoPlayers)
            FilledButton.icon(
              onPressed: _bothReady ? () => _net.startGame() : null,
              icon: const Icon(Icons.play_arrow),
              label: Text(_bothReady ? '开始游戏' : '等待双方准备...'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(200, 44),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        _net.leaveRoom();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_roomName.isNotEmpty ? _roomName : '房间'),
          actions: [
            if (_gameStarted && !_isSpectator && _winner == null)
              IconButton(
                icon: const Icon(Icons.flag),
                tooltip: '认输',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('认输'),
                      content: const Text('确定要认输吗？'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                        FilledButton(onPressed: () {
                          Navigator.pop(ctx);
                          _net.resign();
                        }, child: const Text('认输', style: TextStyle(color: Colors.white)),
                          style: FilledButton.styleFrom(backgroundColor: Colors.red)),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                _buildPlayersList(),
                if (!_isSpectator && _spectators.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    color: Colors.amber.shade50,
                    child: Row(
                      children: [
                        const Icon(Icons.visibility, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text('观众: ${_spectators.map((p) => p.name).join(", ")}',
                            style: const TextStyle(fontSize: 11, color: Colors.amber)),
                      ],
                    ),
                  ),
                // 等待中 → 设置面板 + 准备按钮
                if (!_gameStarted && !_showIntro) ...[
                  _buildSettingsPanel(),
                  _buildWaitingUI(),
                ],
                // 游戏中 → 状态 + 棋盘
                if (_gameStarted && _winner == null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    color: _myTurn ? Colors.blue.shade50 : Colors.grey.shade100,
                    child: Row(
                      children: [
                        if (_myTurn) const Icon(Icons.play_arrow, size: 16, color: Colors.blue),
                        Text(
                          _isSpectator ? '观战中' :
                          _myTurn ? '轮到你了' : '等待对手走棋...',
                          style: TextStyle(
                            fontSize: 13,
                            color: _myTurn ? Colors.blue : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_gameStarted)
                  Expanded(
                    child: Center(
                      child: ChessBoard(
                        board: _board,
                        selectedPos: _selectedPos,
                        validMoves: _validMoves,
                        lastMove: null,
                        animPiece: null,
                        playerSide: _mySide ?? Side.red,
                        analysisMode: AnalysisMode.none,
                        onCellTap: _onCellTap,
                      ),
                    ),
                  ),
                // 游戏结束
                if (_winner != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.black87,
                    child: Column(
                      children: [
                        Text(
                          _winner == 'red' ? '🔴 红方胜！' : '⚫ 黑方胜！',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () {
                            _net.leaveRoom();
                            Navigator.pop(context);
                          },
                          child: const Text('返回大厅'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            // 开场动画覆盖层
            if (_showIntro)
              SwordsIntroAnimation(onComplete: _onIntroComplete),
          ],
        ),
      ),
    );
  }
}
