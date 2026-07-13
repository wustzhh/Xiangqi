/// 双剑交叉开场动画 — "3, 2, 1, GO!" + 两把剑交叉
library widgets.swords_intro;

import 'dart:math';
import 'package:flutter/material.dart';

class SwordsIntroAnimation extends StatefulWidget {
  final VoidCallback onComplete;
  const SwordsIntroAnimation({super.key, required this.onComplete});

  @override
  State<SwordsIntroAnimation> createState() => _SwordsIntroAnimationState();
}

class _SwordsIntroAnimationState extends State<SwordsIntroAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _swordAnim;
  late Animation<int> _countdownAnim;
  late Animation<double> _fadeOutAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _swordAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)),
    );

    _countdownAnim = IntTween(begin: 3, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.linear)),
    );

    _fadeOutAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.7, 1.0, curve: Curves.easeOut)),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeOutAnim.value,
          child: Container(
            color: Colors.black87,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 双剑交叉
                CustomPaint(
                  size: const Size(300, 300),
                  painter: _SwordsPainter(progress: _swordAnim.value),
                ),
                // 倒计时
                Positioned(
                  bottom: 120,
                  child: _countdownAnim.value > 0
                      ? Text(
                          '${_countdownAnim.value}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(blurRadius: 20, color: Colors.red)],
                          ),
                        )
                      : const SizedBox(),
                ),
                // 文字
                Positioned(
                  bottom: 60,
                  child: Text(
                    '决 战 在 即',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 18,
                      letterSpacing: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SwordsPainter extends CustomPainter {
  final double progress;

  _SwordsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final bladeLen = size.width * 0.4;
    final hiltLen = bladeLen * 0.25;
    final totalLen = bladeLen + hiltLen;

    final angle = pi / 6 + (pi / 3) * (1 - progress); // 从 60° 到 0°(交叉)

    for (final dir in [-1, 1]) {
      final startAngle = pi / 2 + dir * angle;
      final endAngle = startAngle + pi;

      // 剑刃
      final bladeStart = center + Offset(cos(startAngle) * hiltLen, sin(startAngle) * hiltLen);
      final bladeEnd = center + Offset(cos(startAngle) * totalLen, sin(startAngle) * totalLen);

      final bladePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.9 - (1 - progress) * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(bladeStart, bladeEnd, bladePaint);

      // 剑柄
      final hiltStart = center;
      final hiltEnd = bladeStart;

      final hiltPaint = Paint()
        ..color = Colors.orange.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(hiltStart, hiltEnd, hiltPaint);

      // 剑柄末端圆球
      canvas.drawCircle(center, 4, Paint()..color = Colors.orange);
    }

    // 火花效果
    if (progress > 0.5) {
      final sparkPaint = Paint()
        ..color = Colors.orange.withValues(alpha: (progress - 0.5) * 2 * 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

      for (int i = 0; i < 8; i++) {
        final sparkAngle = pi * 2 * (i / 8 + progress * 0.1);
        final sparkDist = 10 + progress * 20;
        final sparkPos = center + Offset(cos(sparkAngle) * sparkDist, sin(sparkAngle) * sparkDist);
        canvas.drawCircle(sparkPos, 3 + progress * 2, sparkPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
