/// 设备标识服务 — 生成固定匿名设备 ID
library services.device_id;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _keyDeviceId = 'device_uuid';

/// 获取设备匿名 ID（首次生成 UUID 并持久化）
Future<String> getDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  String? id = prefs.getString(_keyDeviceId);
  if (id == null || id.isEmpty) {
    id = const Uuid().v4();
    await prefs.setString(_keyDeviceId, id);
  }
  return id;
}

/// 获取游客显示名称
Future<String> getDisplayName() async {
  final id = await getDeviceId();
  return '游客_${id.substring(0, 8)}';
}
