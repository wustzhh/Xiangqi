import 'package:flutter/material.dart';
import 'models/app_config.dart';
import 'services/secure_storage.dart';
import 'screens/home_screen.dart';

class XiangqiApp extends StatefulWidget {
  final bool useTraditional;
  final bool soundEnabled;

  const XiangqiApp({
    super.key,
    this.useTraditional = false,
    this.soundEnabled = true,
  });

  @override
  State<XiangqiApp> createState() => _XiangqiAppState();
}

class _XiangqiAppState extends State<XiangqiApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 预加载棋盘背景图
      precacheImage(const AssetImage('assets/images/board_wood.png'), context);
      // 异步加载已保存的 API Key
      SecureStorage().loadApiKey().then((key) {
        if (key != null && key.isNotEmpty && mounted) {
          AppConfig.deepSeekKey = key;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '中国象棋',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF8B4513),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
