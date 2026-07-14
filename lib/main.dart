import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'app.dart';
import 'utils/constants.dart';

/// 全局日志路径（在 main 中初始化，供各模块使用）
String? logFilePath;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServerConfig.init();
  try {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    logFilePath = '${dir.path}/xiangqi_log.txt';
    await File(logFilePath!).writeAsString('=== Xiangqi Started ===\n');
  } catch (e) {
    try {
      File('C:/xiangqi_err.txt').writeAsStringSync('$e');
    } catch (_) {}
  }
  runApp(const XiangqiApp());
}
