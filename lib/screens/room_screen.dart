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
import '../models/analysis_data.dart';
import '../utils/constants.dart';

class RoomScreen extends StatefulWidget {
  final String roomId;
  const RoomScreen({super.key, required this.roomId});

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
  String? _mySideStr; // 'red', 'black', or null (spectator)
  bool _gameStarted = false;

  // 对局状态 — 手动跟踪回合
  Board _board = Board.initial();
  Rules _rules = Rules(Board.initial());
  Side _currentTurn = Side.red; // 红先
  bool _myTurn = false;
  Position? _selectedPos;
  List<Position> _validMoves = [];
  String? _winner;

  /// 将 'red'/'black' 字符串转为 Side 枚举
  Side? _sideFromStr(String? s) {
    if (s == 'red') return Side.red;
    if (s == 'black') return Side.black;
    return null;
  }

  /// 我的 Side（null=观战）
  Side? get _mySide => _sideFromStr(_mySideStr);

  /// 是否观战
  bool get _isSpectator => _mySide == null;

  @override
  void initState() {
    super.initState();
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
      case 'room_joined':
        _roomName = data['roomName'] as String? ?? '';
        _mySideStr = data['yourSide'] as String?;
        _players = (data['players'] as List<dynamic>?)
                ?.map((e) => PlayerInfo.fromJson(e as Map<String, dynamic>))
                .toList() ?? [];
        _spectators = (data['spectators'] as List<dynamic>?)
                ?.map((e) => PlayerInfo.fromJson(e as Map<String, dynamic>))
                .toList() ?? [];
        break;

      case 'player_joined':
      case 'player_left':
      case 'room_updated':
        // 这些需要刷新状态
        break;

      case 'game_start':
        _gameStarted = true;
        _board = Board.initial();
        _rules = Rules(_board);
        _mySideStr = data['yourSide'] as String?;
        _currentTurn = Side.red;
        _myTurn = _mySideStr == 'red';
        _selectedPos = null;
        _validMoves = [];
        _winner = null;
        break;

      case 'move_made':
        final fromData = data['from'] as Map<String, dynamic>;
        final toData = data['to'] as Map<String, dynamic>;
        final from = Position(fromData['col'] as int, fromData['row'] as int);
        final to = Position(toData['col'] as int, toData['row'] as int);

        _board.move(from, to);
        _rules = Rules(_board);

        // 切换回合
        _currentTurn = _currentTurn.opponent;
        _myTurn = !_isSpectator && _currentTurn == _mySide;
        _selectedPos = null;
        _validMoves = [];
        break;

      case 'game_over':
        _winner = data['winner'] as String?;
        break;
    }

    if (mounted) setState(() {});
  }

  void _onCellTap(Position pos) {
    if (!_gameStarted || _isSpectator || !_myTurn || _winner != null) return;
    if (_mySide == null) return;

    final piece = _board.at(pos);

    if (_selectedPos == null) {
      // 选择自己的棋子
      if (piece == null || piece.side != _mySide) return;
      // 必须轮到该方
      if (piece.side != _currentTurn) return;
      setState(() {
        _selectedPos = pos;
        _validMoves = _rules.getLegalMoves(pos);
      });
    } else {
      if (piece != null && piece.side == _mySide) {
        // 切换选中
        setState(() {
          _selectedPos = pos;
          _validMoves = _rules.getLegalMoves(pos);
        });
      } else if (_validMoves.contains(pos)) {
        // 发送走棋到服务端
        _net.makeMove(_selectedPos!.col, _selectedPos!.row, pos.col, pos.row);
        // 本地即时更新
        _board.move(_selectedPos!, pos);
        _rules = Rules(_board);
        _currentTurn = _currentTurn.opponent;
        setState(() {
          _selectedPos = null;
          _validMoves = [];
          _myTurn = false;
        });
      } else {
        setState(() {
          _selectedPos = null;
          _validMoves = [];
        });
      }
    }
  }

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
        body: Column(
          children: [
            _buildPlayersList(),
            // 观众列表
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
            // 状态信息
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
            // 棋盘
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
            // 等待中
            if (!_gameStarted)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('等待对手加入...', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
