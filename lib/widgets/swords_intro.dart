/// 双剑交叉开场动画 — "3, 2, 1, GO!" + ⚔️ 双剑交叉
library widgets.swords_intro;

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
  late Animation<double> _scaleAnim;
  late Animation<double> _rotateAnim;
  late Animation<int> _countdownAnim;
  late Animation<double> _fadeOutAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _scaleAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.elasticOut)),
    );

    _rotateAnim = Tween<double>(begin: -0.3, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    _countdownAnim = IntTween(begin: 3, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.linear)),
    );

    _fadeOutAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.65, 1.0, curve: Curves.easeOut)),
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
                // 双剑交叉 emoji
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..scale(_scaleAnim.value)
                    ..rotateZ(_rotateAnim.value),
                  child: const Text(
                    '⚔️',
                    style: TextStyle(
                      fontSize: 120,
                      shadows: [
                        Shadow(blurRadius: 40, color: Color(0x44FFD700)),
                        Shadow(blurRadius: 80, color: Color(0x22FF4500)),
                      ],
                    ),
                  ),
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
