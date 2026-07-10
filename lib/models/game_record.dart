import '../engine/move.dart';
import '../engine/piece.dart';
import '../engine/board.dart';
import '../engine/game_state.dart';
import '../ai/ai_player.dart';

/// 玩家配置
class PlayerConfig {
  final PlayerType type;
  final Side side;
  final AiDifficulty? aiDifficulty;

  const PlayerConfig({
    required this.type,
    required this.side,
    this.aiDifficulty,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'side': side.name,
        'aiDifficulty': aiDifficulty?.name,
      };

  factory PlayerConfig.fromJson(Map<String, dynamic> json) => PlayerConfig(
        type: PlayerType.values.byName(json['type'] as String),
        side: Side.values.byName(json['side'] as String),
        aiDifficulty: json['aiDifficulty'] != null
            ? AiDifficulty.values.byName(json['aiDifficulty'] as String)
            : null,
      );
}

enum PlayerType { human, ai }

/// 对局记录
class GameRecord {
  final String id;
  final DateTime playedAt;
  final PlayerConfig redPlayer;
  final PlayerConfig blackPlayer;
  final GameResult result;
  final String? endReason; // "将杀" / "困毙"
  final int totalMoves;
  final List<RecordedMove> moves;

  const GameRecord({
    required this.id,
    required this.playedAt,
    required this.redPlayer,
    required this.blackPlayer,
    required this.result,
    this.endReason,
    required this.totalMoves,
    required this.moves,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'playedAt': playedAt.toIso8601String(),
        'redPlayer': redPlayer.toJson(),
        'blackPlayer': blackPlayer.toJson(),
        'result': result.name,
        'endReason': endReason,
        'totalMoves': totalMoves,
        'moves': moves.map((m) => m.toJson()).toList(),
      };

  factory GameRecord.fromJson(Map<String, dynamic> json) => GameRecord(
        id: json['id'] as String,
        playedAt: DateTime.parse(json['playedAt'] as String),
        redPlayer:
            PlayerConfig.fromJson(json['redPlayer'] as Map<String, dynamic>),
        blackPlayer:
            PlayerConfig.fromJson(json['blackPlayer'] as Map<String, dynamic>),
        result: GameResult.values.byName(json['result'] as String),
        endReason: json['endReason'] as String?,
        totalMoves: json['totalMoves'] as int,
        moves: (json['moves'] as List)
            .map((m) =>
                RecordedMove.fromJson(m as Map<String, dynamic>))
            .toList(),
      );

  /// 创建唯一 ID
  static String generateId() =>
      DateTime.now().millisecondsSinceEpoch.toString();
}

/// 可序列化的走法记录
class RecordedMove {
  final int moveNumber;
  final int fromCol;
  final int fromRow;
  final int toCol;
  final int toRow;
  final String pieceType; // PieceType.name
  final String side; // Side.name
  final String? capturedType;
  final String? capturedSide;

  const RecordedMove({
    required this.moveNumber,
    required this.fromCol,
    required this.fromRow,
    required this.toCol,
    required this.toRow,
    required this.pieceType,
    required this.side,
    this.capturedType,
    this.capturedSide,
  });

  Map<String, dynamic> toJson() => {
        'moveNumber': moveNumber,
        'fromCol': fromCol,
        'fromRow': fromRow,
        'toCol': toCol,
        'toRow': toRow,
        'pieceType': pieceType,
        'side': side,
        'capturedType': capturedType,
        'capturedSide': capturedSide,
      };

  factory RecordedMove.fromJson(Map<String, dynamic> json) => RecordedMove(
        moveNumber: json['moveNumber'] as int,
        fromCol: json['fromCol'] as int,
        fromRow: json['fromRow'] as int,
        toCol: json['toCol'] as int,
        toRow: json['toRow'] as int,
        pieceType: json['pieceType'] as String,
        side: json['side'] as String,
        capturedType: json['capturedType'] as String?,
        capturedSide: json['capturedSide'] as String?,
      );

  /// 从 Move + Piece 创建
  factory RecordedMove.fromMove(Move move) => RecordedMove(
        moveNumber: move.moveNumber,
        fromCol: move.from.col,
        fromRow: move.from.row,
        toCol: move.to.col,
        toRow: move.to.row,
        pieceType: move.piece.type.name,
        side: move.piece.side.name,
        capturedType: move.captured?.type.name,
        capturedSide: move.captured?.side.name,
      );

  /// 还原为 Move 对象（不含 board 引用）
  Move toMove() {
    return Move(
      from: Position(fromCol, fromRow),
      to: Position(toCol, toRow),
      piece: Piece(
        type: PieceType.values.byName(pieceType),
        side: Side.values.byName(side),
      ),
      captured: capturedType != null
          ? Piece(
              type: PieceType.values.byName(capturedType!),
              side: Side.values.byName(capturedSide!),
            )
          : null,
      moveNumber: moveNumber,
    );
  }

  String get notation {
    final name = Piece(
      type: PieceType.values.byName(pieceType),
      side: Side.values.byName(side),
    ).displayName;
    final cap = capturedType != null ? 'x' : '-';
    return '$name($fromCol,$fromRow)$cap($toCol,$toRow)';
  }
}
