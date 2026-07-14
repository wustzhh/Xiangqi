import 'package:flutter/material.dart';
import 'app.dart';
import 'utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServerConfig.init();
  runApp(const XiangqiApp());
}
