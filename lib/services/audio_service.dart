import 'package:audioplayers/audioplayers.dart';
import '../utils/constants.dart';

/// 音效管理服务
class AudioService {
  static final AudioService _instance = AudioService._();
  factory AudioService() => _instance;
  AudioService._();

  final AudioPlayer _player = AudioPlayer();
  bool _enabled = true;

  bool get enabled => _enabled;
  set enabled(bool value) {
    _enabled = value;
  }

  /// 走棋音效（文件不存在时静默忽略）
  Future<void> playMove() => _play(AudioPaths.move);
  Future<void> playCapture() => _play(AudioPaths.capture);
  Future<void> playCheck() => _play(AudioPaths.check);
  Future<void> playVictory() => _play(AudioPaths.victory);

  Future<void> _play(String path) async {
    if (!_enabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource(path.replaceFirst('assets/', '')));
    } catch (_) {
      // 音效文件缺失时静默忽略
    }
  }

  void dispose() {
    _player.dispose();
  }
}
