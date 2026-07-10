import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/game_record.dart';
import 'game_serializer.dart';

/// 本地存储服务 — 对局记录的保存、加载、列表、删除
class StorageService {
  static final StorageService _instance = StorageService._();
  factory StorageService() => _instance;
  StorageService._();

  static const _fileName = 'game_records.json';
  List<GameRecord>? _cache;

  /// 获取存储文件路径
  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// 加载所有对局记录
  Future<List<GameRecord>> loadRecords() async {
    if (_cache != null) return _cache!;
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        _cache = [];
        return _cache!;
      }
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        _cache = [];
        return _cache!;
      }
      _cache = GameSerializer.listFromJson(content);
      // 按时间倒序
      _cache!.sort((a, b) => b.playedAt.compareTo(a.playedAt));
      return _cache!;
    } catch (e) {
      debugPrint('加载对局记录失败: $e');
      _cache = [];
      return _cache!;
    }
  }

  /// 保存一条新记录
  Future<void> saveRecord(GameRecord record) async {
    await loadRecords(); // 确保缓存加载
    _cache!.insert(0, record); // 最新放最前
    await _flush();
  }

  /// 删除一条记录
  Future<void> deleteRecord(String id) async {
    await loadRecords();
    _cache!.removeWhere((r) => r.id == id);
    await _flush();
  }

  /// 获取战绩统计
  Future<Map<String, int>> getStats() async {
    final records = await loadRecords();
    int wins = 0;
    int losses = 0;
    int draws = 0;
    for (final r in records) {
      // 统计：只看有人类玩家的对局
      if (r.redPlayer.type.name == 'human' &&
          r.blackPlayer.type.name == 'ai') {
        if (r.result.name == 'redWin') wins++;
        if (r.result.name == 'blackWin') losses++;
      } else if (r.redPlayer.type.name == 'ai' &&
          r.blackPlayer.type.name == 'human') {
        if (r.result.name == 'blackWin') wins++;
        if (r.result.name == 'redWin') losses++;
      }
    }
    return {
      'total': records.length,
      'wins': wins,
      'losses': losses,
      'draws': draws,
    };
  }

  /// 写入磁盘
  Future<void> _flush() async {
    try {
      final file = await _getFile();
      await file.writeAsString(GameSerializer.listToJson(_cache!));
    } catch (e) {
      debugPrint('保存对局记录失败: $e');
    }
  }

  /// 清除缓存（用于测试）
  void clearCache() => _cache = null;
}
