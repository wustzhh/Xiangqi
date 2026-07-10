import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_config.dart';

/// 双层加密存储
class SecureStorage {
  static final SecureStorage _instance = SecureStorage._();
  factory SecureStorage() => _instance;
  SecureStorage._();

  static const _fileName = '.xiangqi_key';

  // 两层密钥，硬编码在二进制中
  static final List<int> _key1 = _deriveKey('seed_xiangqi_2024_a', 0x5A);
  static final List<int> _key2 = _deriveKey('seed_deepseek_2024_b', 0x3C);

  static List<int> _deriveKey(String seed, int xorVal) {
    return utf8.encode(seed).map((b) => b ^ xorVal).toList();
  }

  static String encrypt(String plain) {
    if (plain.isEmpty) return '';
    List<int> bytes = utf8.encode(plain);
    bytes = _xorCipher(bytes, _key1);
    bytes = _shuffle(bytes, _key1.length);
    String layer1 = base64Encode(bytes);
    List<int> layer2 = utf8.encode(layer1);
    layer2 = _xorCipher(layer2, _key2);
    layer2 = _shuffle(layer2, _key2.length);
    return base64Encode(layer2);
  }

  static String decrypt(String cipher) {
    if (cipher.isEmpty) return '';
    try {
      List<int> bytes = base64Decode(cipher).toList();
      bytes = _unshuffle(bytes, _key2.length);
      bytes = _xorCipher(bytes, _key2);
      String layer1 = utf8.decode(bytes);
      List<int> layer2 = base64Decode(layer1).toList();
      layer2 = _unshuffle(layer2, _key1.length);
      layer2 = _xorCipher(layer2, _key1);
      return utf8.decode(layer2);
    } catch (e) {
      debugPrint('解密失败: $e');
      return '';
    }
  }

  static List<int> _xorCipher(List<int> data, List<int> key) {
    return List<int>.generate(data.length, (i) => data[i] ^ key[i % key.length]);
  }

  static List<int> _shuffle(List<int> data, int keyLen) {
    if (data.isEmpty) return data;
    final shift = keyLen % data.length;
    if (shift == 0) return List.from(data);
    return [...data.sublist(shift), ...data.sublist(0, shift)];
  }

  static List<int> _unshuffle(List<int> data, int keyLen) {
    if (data.isEmpty) return data;
    final shift = keyLen % data.length;
    if (shift == 0) return List.from(data);
    final split = data.length - shift;
    return [...data.sublist(split), ...data.sublist(0, split)];
  }

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> saveApiKey(String key) async {
    try {
      final file = await _getFile();
      await file.writeAsString(encrypt(key));
      AppConfig.deepSeekKey = key;
    } catch (e) {
      debugPrint('保存加密 Key 失败: $e');
    }
  }

  Future<String?> loadApiKey() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final decrypted = decrypt(content.trim());
      return decrypted.isEmpty ? null : decrypted;
    } catch (e) {
      debugPrint('加载加密 Key 失败: $e');
      return null;
    }
  }

  Future<void> deleteApiKey() async {
    try {
      final file = await _getFile();
      if (await file.exists()) await file.delete();
      AppConfig.deepSeekKey = null;
    } catch (_) {}
  }
}
