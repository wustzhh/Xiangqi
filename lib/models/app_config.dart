import 'package:shared_preferences/shared_preferences.dart';

/// 全局运行时配置
///
/// DeepSeek API Key 通过 SecureStorage 加密持久化。
/// 皮卡鱼引擎路径通过 SharedPreferences 持久化。
class AppConfig {
  /// DeepSeek API Key（仅在本次运行期间生效）
  static String? deepSeekKey;

  /// 皮卡鱼引擎路径
  static String? pikafishEnginePath;

  /// 从 SharedPreferences 加载已保存的引擎路径
  static Future<void> loadPikafishEnginePath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      pikafishEnginePath = prefs.getString('pikafish_engine_path');
    } catch (_) {}
  }

  /// 保存引擎路径到 SharedPreferences
  static Future<void> savePikafishEnginePath(String path) async {
    pikafishEnginePath = path;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (path.isEmpty) {
        await prefs.remove('pikafish_engine_path');
      } else {
        await prefs.setString('pikafish_engine_path', path);
      }
    } catch (_) {}
  }
}
