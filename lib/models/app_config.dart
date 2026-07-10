/// 全局运行时配置（仅内存，不持久化）
///
/// 所有配置项在应用关闭后自动销毁。
/// 不要添加任何写入磁盘的逻辑。
class AppConfig {
  /// DeepSeek API Key（仅在本次运行期间生效）
  static String? deepSeekKey;

  /// UCCI 引擎路径
  static String? ucciEnginePath;
}
