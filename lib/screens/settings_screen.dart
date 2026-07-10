import 'package:flutter/material.dart';
import '../models/app_config.dart';
import '../services/secure_storage.dart';

/// 设置页面 — 配置 DeepSeek API Key
/// API Key 通过 SecureStorage 双层加密保存到本地
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _deepSeekCtrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _deepSeekCtrl = TextEditingController();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final saved = await SecureStorage().loadApiKey();
    if (saved != null && saved.isNotEmpty) {
      AppConfig.deepSeekKey = saved;
      _deepSeekCtrl.text = saved;
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _deepSeekCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // ── DeepSeek API Key ──
                const Text(
                  'DeepSeek API Key',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _deepSeekCtrl.text.isEmpty
                      ? '填入后自动加密保存。可游玩「传说」难度。'
                      : '已加密保存，关闭程序后重新打开仍然有效。',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _deepSeekCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'sk-xxx*********xxxx',
                    border: const OutlineInputBorder(),
                    suffixIcon: _deepSeekCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _deepSeekCtrl.clear();
                              SecureStorage().deleteApiKey();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) {
                    final key = v.trim();
                    if (key.isNotEmpty && key.length > 10) {
                      SecureStorage().saveApiKey(key);
                    }
                    AppConfig.deepSeekKey = key.isEmpty ? null : key;
                    setState(() {});
                  },
                ),
                if (_deepSeekCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '✓ 已加密保存',
                    style: TextStyle(fontSize: 13, color: Colors.green.shade600),
                  ),
                ],
                const SizedBox(height: 32),

                // ── UCCI 引擎路径 ──
                const Text(
                  'UCCI 引擎路径',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '选填，一般不需要。不填时「大师」自动使用内置迭代加深搜索（6层）。',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    hintText: '（无需填写，暂无可用引擎）',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.folder_open),
                      tooltip: '选择引擎文件',
                      onPressed: () {},
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── 安全说明 ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('关于安全性',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 8),
                      Text(
                        '• API Key 使用双层加密存储到本地\n'
                        '  （第一层 XOR+变位 → Base64 → 第二层 XOR+变位）\n'
                        '• 密钥来自代码内部，不在任何文件中明文出现\n'
                        '• 关闭程序后重新打开仍有效\n'
                        '• 仅用于调用 DeepSeek API，不会发往其他服务器',
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
    );
  }
}
