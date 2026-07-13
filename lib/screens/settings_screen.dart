import 'package:flutter/material.dart';
import '../models/app_config.dart';
import '../services/secure_storage.dart';
import '../utils/constants.dart';

/// 设置页面 — 配置 DeepSeek API Key
/// API Key 通过 SecureStorage 双层加密保存到本地
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _deepSeekCtrl;
  late TextEditingController _hostCtrl;
  late TextEditingController _portCtrl;
  bool _loading = true;
  bool _serverChanged = false;

  @override
  void initState() {
    super.initState();
    _deepSeekCtrl = TextEditingController();
    _hostCtrl = TextEditingController(text: ServerConfig.host);
    _portCtrl = TextEditingController(text: ServerConfig.port.toString());
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
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveServerConfig() async {
    final host = _hostCtrl.text.trim();
    final portStr = _portCtrl.text.trim();
    final port = int.tryParse(portStr);

    if (host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入服务器地址')),
      );
      return;
    }
    if (port == null || port < 1 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效端口（1-65535）')),
      );
      return;
    }

    await ServerConfig.save(host, port);
    setState(() => _serverChanged = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('服务器地址已保存为 $host:$port')),
      );
    }
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

                // ── 服务器地址 ──
                const Text(
                  '网络对战服务器',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '修改后需重启「网络对战」页面生效。',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _hostCtrl,
                        decoration: const InputDecoration(
                          labelText: '服务器地址',
                          hintText: 'IP 或域名',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => _serverChanged = true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _portCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '端口',
                          hintText: '8080',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => _serverChanged = true,
                      ),
                    ),
                  ],
                ),
                if (_serverChanged) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saveServerConfig,
                      icon: const Icon(Icons.save),
                      label: const Text('保存服务器地址'),
                    ),
                  ),
                ],
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
