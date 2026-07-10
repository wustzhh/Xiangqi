import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../engine/board.dart';
import '../engine/piece.dart';
import '../engine/rules.dart';
import 'search.dart';

/// DeepSeek AI 客户端
class DeepSeekClient {
  final String apiKey;

  DeepSeekClient(this.apiKey);

  static const _apiUrl = 'https://api.deepseek.com/v1/chat/completions';

  Future<MoveResult?> getMove(Board board, Side side) async {
    try {
      final prompt = _boardToPrompt(board, side);
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'deepseek-chat',
              'messages': [
                {
                  'role': 'system',
                  'content':
                      '你是一个中国象棋大师。分析棋盘局面，给出最佳走法。'
                          '走法格式：起点列,起点行->终点列,终点行'
                          '车/炮走直线，马走日(蹩马腿不行)，象走田(塞象眼不行)。'
                          '不要用车换兵，不要白白送子。'
                          '只回复走法格式，不要解释。'
                },
                {'role': 'user', 'content': prompt},
              ],
              'temperature': 0.1,
              'max_tokens': 100,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        debugPrint('DeepSeek API 错误: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = (data['choices'] as List).first['message']['content'] as String;

      // 解析走法
      final reg = RegExp(r'(\d+)\s*,\s*(\d+)\s*[-=>]+\s*(\d+)\s*,\s*(\d+)');
      final match = reg.firstMatch(content);
      if (match == null) return null;

      final from = Position(int.parse(match.group(1)!), int.parse(match.group(2)!));
      final to = Position(int.parse(match.group(3)!), int.parse(match.group(4)!));
      if (!from.isValid || !to.isValid) return null;

      // 走法合法性验证
      final piece = board.at(from);
      if (piece == null || piece.side != side) return null;

      final rules = Rules(board);
      final legalMoves = rules.getLegalMoves(from);
      if (!legalMoves.contains(to)) return null;

      return MoveResult(from: from, to: to, score: 0, depth: 0, nodesSearched: 0);
    } catch (e) {
      debugPrint('DeepSeek 调用失败: $e');
      return null;
    }
  }

  String _boardToPrompt(Board board, Side side) {
    final buf = StringBuffer();
    buf.writeln('当前棋盘（9列x10行，红方在下，黑方在上）：');
    buf.writeln('轮到${side == Side.red ? "红方" : "黑方"}走棋。');

    String pc(Piece? p) {
      if (p == null) return ' .';
      final r = p.side == Side.red;
      switch (p.type) {
        case PieceType.general: return r ? ' 帅' : ' 将';
        case PieceType.advisor: return r ? ' 仕' : ' 士';
        case PieceType.elephant: return r ? ' 相' : ' 象';
        case PieceType.horse: return r ? ' 马' : ' 马';
        case PieceType.rook: return r ? ' 车' : ' 车';
        case PieceType.cannon: return r ? ' 炮' : ' 砲';
        case PieceType.soldier: return r ? ' 兵' : ' 卒';
      }
    }

    for (int r = 0; r < 10; r++) {
      buf.write('$r');
      for (int c = 0; c < 9; c++) buf.write(pc(board.at(Position(c, r))));
      buf.writeln();
    }
    buf.writeln('  0 1 2 3 4 5 6 7 8');

    buf.writeln();
    buf.writeln('红方：');
    for (int r = 0; r < 10; r++)
      for (int c = 0; c < 9; c++) {
        final p = board.at(Position(c, r));
        if (p != null && p.side == Side.red) buf.write('${p.displayName}($c,$r) ');
      }
    buf.writeln();
    buf.writeln('黑方：');
    for (int r = 0; r < 10; r++)
      for (int c = 0; c < 9; c++) {
        final p = board.at(Position(c, r));
        if (p != null && p.side == Side.black) buf.write('${p.displayName}($c,$r) ');
      }
    return buf.toString();
  }
}
