import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xiangqi/app.dart';

void main() {
  testWidgets('App should display home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const XiangqiApp());

    // 验证主菜单标题
    expect(find.text('中国象棋'), findsOneWidget);
    expect(find.text('双人对弈'), findsOneWidget);
    expect(find.text('人机对战'), findsOneWidget);
  });
}
