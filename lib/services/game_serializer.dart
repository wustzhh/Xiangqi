import 'dart:convert';
import '../models/game_record.dart';

/// 对局序列化 — GameRecord ↔ JSON
class GameSerializer {
  /// 将 GameRecord 序列化为 JSON 字符串
  static String toJson(GameRecord record) {
    return const JsonEncoder.withIndent('  ').convert(record.toJson());
  }

  /// 从 JSON 字符串反序列化为 GameRecord
  static GameRecord fromJson(String json) {
    return GameRecord.fromJson(
        jsonDecode(json) as Map<String, dynamic>);
  }

  /// 将多条记录序列化为 JSON 数组字符串
  static String listToJson(List<GameRecord> records) {
    return const JsonEncoder.withIndent('  ')
        .convert(records.map((r) => r.toJson()).toList());
  }

  /// 从 JSON 数组字符串反序列化为记录列表
  static List<GameRecord> listFromJson(String json) {
    final list = jsonDecode(json) as List;
    return list
        .map((e) => GameRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
