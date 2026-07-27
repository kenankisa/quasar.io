import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/lang_scope.dart';
import '../utils/diamond_ui.dart';
import '../utils/responsive_layout.dart';

/// Center-screen diamond reward burst — fades in, holds, then fades out (~2s).
class DiamondRewardFlash {
  DiamondRewardFlash._();

  static const _duration = Duration(milliseconds: 2000);

  static Future<void> show(
    BuildContext context, {
    required int diamonds,
  }) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final completer = Completer<void>();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _DiamondRewardFlashOverlay(
        diamonds: diamonds,
        onFinished: () {
          if (entry.mounted) entry.remove();
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );

    overlay.insert(entry);
    await completer.future.timeout(
      _duration + const Duration(milliseconds: 200),
      onTimeout: () {
        if (entry.mounted) entry.remove();
      },
    );
  }
}

class _DiamondRewardFlashOverlay extends StatefulWidget {
  const _DiamondRewardFlashOverlay({
    required this.diamonds,
    required this.onFinished,
  });

  final int diamonds;
  final VoidCallback onFinished;

  @override
  State<_DiamondRewardFlashOverlay> createState() =>
      _DiamondRewardFlashOverlayState();
}

class _DiamondRewardFlashOverlayState extends State<_DiamondRewardFlashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: DiamondRewardFlash._duration,
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.55, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.08),
        weight: 52,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.08, end: 0.92)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_controller);

    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_controller);

    _glow = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.2, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 0.0), weight: 30),
    ]).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    unawaited(_run());
  }

  Future<void> _run() async {
    await _controller.forward();
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final r = ResponsiveLayout.of(context);
    final message = lang
        .t('daily_quest_reward_flash')
        .replaceAll('{diamonds}', '${widget.diamonds}');

    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _opacity.value,
                child: Transform.scale(
                  scale: _scale.value,
                  child: child,
                ),
              );
            },
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: r.w(24)),
              padding: EdgeInsets.symmetric(
                horizontal: r.w(22),
                vertical: r.w(18),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0A1A2A).withValues(alpha: 0.96),
                    const Color(0xFF102040).withValues(alpha: 0.94),
                  ],
                ),
                border: Border.all(
                  color: kDiamondColor.withValues(alpha: 0.55),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: kDiamondColor
                        .withValues(alpha: 0.28 * _glow.value),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: kDiamondColor.withValues(alpha: 0.22 * _glow.value),
                    blurRadius: 36,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _glow,
                    builder: (context, _) {
                      return Container(
                        width: r.sp(56),
                        height: r.sp(56),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              kDiamondColor
                                  .withValues(alpha: 0.35 * _glow.value),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: DiamondIcon(
                          size: r.sp(40),
                          color: kDiamondColor,
                        ),
                      );
                    },
                  ),
                  SizedBox(height: r.h(10)),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.sp(17),
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      shadows: [
                        Shadow(
                          color: kDiamondColor.withValues(alpha: 0.35),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.h(6)),
                  DiamondAmount(
                    amount: widget.diamonds,
                    prefix: '+',
                    fontSize: r.sp(24),
                    fontWeight: FontWeight.w900,
                    textColor: kDiamondColor,
                    iconColor: kDiamondColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
