import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/config/room_visual_theme.dart';
import '../game/config/universe_palette.dart';
import '../game/room_type.dart';

/// Lobby card wormhole chamber — larger glyph, painted once, spun cheaply.
class WormholeGateBadge extends StatelessWidget {
  const WormholeGateBadge({
    super.key,
    required this.roomType,
    required this.spin,
    this.locked = false,
    this.width = 118,
    this.overlay = false,
  });

  final RoomType roomType;
  final Animation<double> spin;
  final bool locked;
  final double width;

  /// Photo shows through — glyph floats on a soft vignette (banner cards).
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    final theme = RoomVisualTheme.forRoom(roomType);
    final washA = UniversePalette.washA(roomType);
    final washB = UniversePalette.washB(roomType);
    final tier = UniversePalette.tierIndex(roomType);

    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: overlay
            ? const BoxDecoration()
            : BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    washA.withValues(
                      alpha: locked ? 0.34 : 0.62 + tier * 0.04,
                    ),
                    const Color(0xFF010106),
                    washB.withValues(
                      alpha: locked ? 0.26 : 0.44 + tier * 0.04,
                    ),
                  ],
                ),
                border: Border(
                  right: BorderSide(
                    color: theme.accent.withValues(
                      alpha: locked ? 0.18 : 0.28 + tier * 0.06,
                    ),
                    width: tier >= 2 ? 1.25 : 1,
                  ),
                ),
              ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (overlay)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.18,
                    colors: [
                      theme.accent.withValues(
                        alpha: locked ? 0.06 : 0.1 + tier * 0.015,
                      ),
                      theme.secondaryAccent.withValues(
                        alpha: locked ? 0.03 : 0.05 + tier * 0.01,
                      ),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            if (overlay)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        theme.secondaryAccent.withValues(
                          alpha: locked ? 0.02 : 0.03 + tier * 0.008,
                        ),
                        Colors.black.withValues(
                          alpha: locked ? 0.03 : 0.05 + tier * 0.008,
                        ),
                      ],
                      stops: const [0.42, 0.78, 1.0],
                    ),
                  ),
                ),
              )
            else ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.05, -0.05),
                    radius: 0.85 + tier * 0.05,
                    colors: [
                      theme.accent.withValues(
                        alpha: locked ? 0.06 : 0.12 + tier * 0.04,
                      ),
                      theme.secondaryAccent.withValues(
                        alpha: locked ? 0.03 : 0.06 + tier * 0.02,
                      ),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.42, 1.0],
                  ),
                ),
              ),
              if (tier >= 2)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.7, 0.85),
                      radius: 0.65,
                      colors: [
                        theme.secondaryAccent.withValues(
                          alpha: locked ? 0.04 : 0.1 + tier * 0.03,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
            ],
            AnimatedBuilder(
              animation: spin,
              builder: (context, child) {
                return Transform.rotate(
                  // Slow drift — one turn per particle loop ≈ 25s.
                  angle: spin.value * math.pi * 2 * (1.0 + tier * 0.02),
                  child: child,
                );
              },
              child: RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 10,
                  ),
                  child: CustomPaint(
                    painter: StaticWormholePainter(
                      accent: theme.accent,
                      secondary: theme.secondaryAccent,
                      locked: locked,
                      bloom: washA,
                      rich: true,
                      ringCount: theme.wormholeRingCount,
                      richness: theme.wormholeRichness,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            if (locked)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.45),
                    border: Border.all(
                      color: theme.accent.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 18,
                    color: theme.accent.withValues(alpha: 0.9),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Continuous wormhole transit: travel while work runs, then dive when ready.
/// User never sees a loading spinner — the portal itself covers the wait.
class WormholeTransit {
  WormholeTransit._(this._entry, this._state);

  final OverlayEntry _entry;
  final _WormholeTransitOverlayState _state;

  /// Starts the portal immediately. Keep it up while matchmaking/load runs.
  static Future<WormholeTransit> begin(
    BuildContext context,
    RoomType roomType,
  ) async {
    final holder = _TransitStateHolder();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _WormholeTransitOverlay(
        roomType: roomType,
        holder: holder,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);

    // Wait until the overlay State is mounted and attached.
    await SchedulerBinding.instance.endOfFrame;
    var guard = 0;
    while (holder.state == null && guard < 8) {
      await SchedulerBinding.instance.endOfFrame;
      guard++;
    }
    final state = holder.state;
    if (state == null) {
      entry.remove();
      throw StateError('Wormhole transit overlay failed to mount');
    }
    return WormholeTransit._(entry, state);
  }

  /// Ends travel with a tunnel dive to black — call when load is ready.
  Future<void> complete({
    Duration? diveDuration,
  }) {
    final hardcore = _state.isHardcore;
    return _state.complete(
      diveDuration ??
          Duration(milliseconds: hardcore ? 1450 : 620),
    );
  }

  /// Soft abort if join failed.
  Future<void> abort({
    Duration duration = const Duration(milliseconds: 280),
  }) =>
      _state.abort(duration);

  void dispose() {
    if (_entry.mounted) _entry.remove();
  }
}

class _TransitStateHolder {
  _WormholeTransitOverlayState? state;
}

class _WormholeTransitOverlay extends StatefulWidget {
  const _WormholeTransitOverlay({
    required this.roomType,
    required this.holder,
  });

  final RoomType roomType;
  final _TransitStateHolder holder;

  @override
  State<_WormholeTransitOverlay> createState() =>
      _WormholeTransitOverlayState();
}

class _WormholeTransitOverlayState extends State<_WormholeTransitOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _breathe;
  late final AnimationController _dive;
  late final AnimationController _fadeOut;
  late final AnimationController _emberPulse;

  bool _diving = false;
  bool _aborting = false;

  bool get isHardcore => widget.roomType == RoomType.hardcore;

  @override
  void initState() {
    super.initState();
    widget.holder.state = this;
    _spin = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: isHardcore ? 5200 : 12000),
    )..repeat();
    _breathe = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: isHardcore ? 1600 : 3200),
    )..repeat(reverse: true);
    _emberPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (isHardcore) _emberPulse.repeat(reverse: true);
    _dive = AnimationController(vsync: this);
    _fadeOut = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: 1,
    );
  }

  Future<void> complete(Duration diveDuration) async {
    if (!mounted || _aborting) return;
    if (_diving) {
      if (_dive.isCompleted) return;
      await _dive.forward();
      return;
    }
    _diving = true;
    _breathe.stop();
    _dive.duration = diveDuration;
    await _dive.forward(from: 0);
  }

  Future<void> abort(Duration duration) async {
    if (!mounted || _aborting) return;
    _aborting = true;
    _breathe.stop();
    _spin.stop();
    _emberPulse.stop();
    _dive.stop();
    _fadeOut.duration = duration;
    await _fadeOut.reverse(from: 1);
  }

  @override
  void dispose() {
    if (widget.holder.state == this) widget.holder.state = null;
    _spin.dispose();
    _breathe.dispose();
    _emberPulse.dispose();
    _dive.dispose();
    _fadeOut.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = RoomVisualTheme.forRoom(widget.roomType);
    final washA = UniversePalette.washA(widget.roomType);
    final washB = UniversePalette.washB(widget.roomType);
    final hardcore = isHardcore;

    return IgnorePointer(
      child: FadeTransition(
        opacity: _fadeOut,
        child: AnimatedBuilder(
          animation: Listenable.merge([_spin, _breathe, _dive, _emberPulse]),
          builder: (context, child) {
            final diveT = Curves.easeInCubic.transform(_dive.value);
            final breath = hardcore
                ? 0.88 + _breathe.value * 0.28
                : 0.88 + _breathe.value * 0.14;
            final travelScale = _diving ? 1.0 : breath;
            final scale =
                travelScale + diveT * (hardcore ? 7.2 : 3.6);
            final veil = (diveT * (hardcore ? 1.45 : 1.2)).clamp(0.0, 1.0);
            final spinAngle = _spin.value * math.pi * 2 +
                diveT * math.pi * (hardcore ? 3.4 : 1.15);
            final ember = hardcore ? _emberPulse.value : 0.0;
            final shock = hardcore
                ? Curves.easeOutCubic.transform(
                    ((_dive.value - 0.08) / 0.55).clamp(0.0, 1.0),
                  )
                : 0.0;

            return ColoredBox(
              color: Color.lerp(
                hardcore
                    ? const Color(0xF0180502)
                    : const Color(0xF0020208),
                Colors.black,
                veil,
              )!,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 1.2 - diveT * 0.5,
                        colors: hardcore
                            ? [
                                const Color(0xFFFF2A0A).withValues(
                                  alpha: (0.52 + ember * 0.22) *
                                      (1 - diveT * 0.7),
                                ),
                                const Color(0xFFFF8A18).withValues(
                                  alpha: 0.28 * (1 - diveT),
                                ),
                                const Color(0xFFFFB020).withValues(
                                  alpha: 0.16 * (1 - diveT),
                                ),
                                washB.withValues(alpha: 0.2 * (1 - diveT)),
                                const Color(0xFF050100),
                              ]
                            : [
                                washA.withValues(
                                  alpha: 0.34 * (1 - diveT * 0.8),
                                ),
                                washB.withValues(alpha: 0.16 * (1 - diveT)),
                                const Color(0xFF020208),
                              ],
                      ),
                    ),
                  ),
                  if (hardcore)
                    Opacity(
                      opacity: (0.65 + ember * 0.35) * (1 - veil * 0.65),
                      child: CustomPaint(
                        painter: _HardcoreTransitEmberPainter(
                          progress: _spin.value,
                          pulse: ember,
                        ),
                      ),
                    ),
                  if (hardcore)
                    Opacity(
                      opacity: (0.55 + ember * 0.3) * (1 - veil * 0.8),
                      child: CustomPaint(
                        painter: _HardcoreTransitArcPainter(
                          progress: _spin.value,
                          pulse: ember,
                        ),
                      ),
                    ),
                  // Counter-rotating outer magma ring (hardcore only).
                  if (hardcore)
                    Center(
                      child: Transform.scale(
                        scale: scale * 1.08,
                        child: Transform.rotate(
                          angle: -spinAngle * 0.55,
                          child: Opacity(
                            opacity: (0.7 + ember * 0.25) * (1 - veil * 0.5),
                            child: SizedBox(
                              width: 260,
                              height: 260,
                              child: CustomPaint(
                                painter: _HardcoreOuterRingPainter(
                                  pulse: ember,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: Transform.scale(
                      scale: scale,
                      child: Transform.rotate(
                        angle: spinAngle,
                        child: SizedBox(
                          width: hardcore ? 220 : 150,
                          height: hardcore ? 220 : 150,
                          child: CustomPaint(
                            painter: hardcore
                                ? HardcoreWormholePainter(pulse: ember)
                                : StaticWormholePainter(
                                    accent: theme.accent,
                                    secondary: theme.secondaryAccent,
                                    locked: false,
                                    bloom: washA,
                                    rich: true,
                                    ringCount: theme.wormholeRingCount,
                                    richness: theme.wormholeRichness,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (hardcore && shock > 0)
                    Center(
                      child: Opacity(
                        opacity: (1 - shock) * 0.85,
                        child: Transform.scale(
                          scale: 0.4 + shock * 4.8,
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Color.lerp(
                                  const Color(0xFFFFE082),
                                  const Color(0xFFFF2A0A),
                                  shock,
                                )!
                                    .withValues(alpha: 0.75 * (1 - shock)),
                                width: 3.5 - shock * 2.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF3A1A)
                                      .withValues(alpha: 0.45 * (1 - shock)),
                                  blurRadius: 28,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (hardcore && !_diving)
                    Center(
                      child: Transform.scale(
                        scale: 1.45 + ember * 0.18,
                        child: Opacity(
                          opacity: 0.4 + ember * 0.3,
                          child: Container(
                            width: 260,
                            height: 260,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  theme.accent.withValues(alpha: 0.42),
                                  theme.secondaryAccent
                                      .withValues(alpha: 0.16),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (veil > 0)
                    Opacity(
                      opacity: veil,
                      child: ColoredBox(
                        color: hardcore
                            ? const Color(0xFF0A0200)
                            : Colors.black,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Painted once — richer disk/horizon detail, still phone-friendly.
class StaticWormholePainter extends CustomPainter {
  StaticWormholePainter({
    required this.accent,
    required this.secondary,
    required this.locked,
    this.bloom,
    this.rich = false,
    this.ringCount,
    this.richness = 0,
  });

  final Color accent;
  final Color secondary;
  final bool locked;
  final Color? bloom;
  final bool rich;
  final int? ringCount;
  final int richness;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * (rich ? 0.44 : 0.36);
    final alpha = locked ? 0.4 : 1.0;
    final bloomColor = bloom ?? accent;
    final tierBoost = 1.0 + richness * 0.08;

    // Outer gravitational glow — stronger on higher tiers.
    final haloR = radius * (rich ? 1.55 + richness * 0.08 : 1.4);
    canvas.drawCircle(
      center,
      haloR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            bloomColor.withValues(alpha: (rich ? 0.34 : 0.26) * alpha * tierBoost),
            accent.withValues(alpha: 0.14 * alpha * tierBoost),
            secondary.withValues(alpha: 0.06 * alpha),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: haloR)),
    );

    // Outer corona ring — elite / unique only (one cheap stroke).
    if (richness >= 2) {
      canvas.drawCircle(
        center,
        radius * (1.18 + richness * 0.04),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = richness >= 3 ? 2.2 : 1.6
          ..color = accent.withValues(alpha: 0.22 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
    }

    if (rich) {
      // Soft accretion slab (fills the disk, one draw).
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(0.55);
      canvas.scale(1.0, 0.52);
      canvas.drawCircle(
        Offset.zero,
        radius * 1.05,
        Paint()
          ..shader = RadialGradient(
            colors: [
              accent.withValues(alpha: 0.26 * alpha * tierBoost),
              secondary.withValues(alpha: 0.12 * alpha),
              Colors.transparent,
            ],
            stops: const [0.15, 0.55, 1.0],
          ).createShader(
            Rect.fromCircle(center: Offset.zero, radius: radius * 1.05),
          ),
      );
      canvas.restore();

      // Distant field stars (static, deterministic) — more on higher tiers.
      final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.35 * alpha);
      const stars = [
        Offset(-0.72, -0.55),
        Offset(0.68, -0.62),
        Offset(-0.55, 0.7),
        Offset(0.78, 0.42),
        Offset(-0.82, 0.12),
        Offset(0.5, 0.78),
        Offset(0.15, -0.85),
        Offset(-0.2, 0.88),
        Offset(-0.35, -0.78),
        Offset(0.92, -0.18),
        Offset(-0.65, 0.45),
        Offset(0.28, 0.92),
      ];
      final starCount = 6 + richness * 2;
      for (var i = 0; i < starCount && i < stars.length; i++) {
        final p = center + stars[i] * radius * 1.35;
        canvas.drawCircle(p, i.isEven ? 1.1 : 0.7, starPaint);
      }
    }

    // Tilted accretion rings.
    final resolvedRingCount = ringCount ?? (rich ? 5 : 3);
    final ringPaint = Paint()..style = PaintingStyle.stroke;
    for (var i = 0; i < resolvedRingCount; i++) {
      final t = resolvedRingCount == 1 ? 0.0 : i / (resolvedRingCount - 1);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(0.32 + i * 0.38);
      canvas.scale(1.0, 0.5 + t * 0.12);
      ringPaint
        ..strokeWidth = rich ? (1.8 - t * 0.5) : 1.2
        ..color = Color.lerp(accent, secondary, t)!
            .withValues(alpha: (0.68 - t * 0.28) * alpha * tierBoost);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 2 * (1.08 - t * 0.32),
          height: radius * 2 * (0.78 - t * 0.1),
        ),
        ringPaint,
      );
      canvas.restore();
    }

    if (rich) {
      // Photon ring — bright thin halo just outside the horizon.
      canvas.drawCircle(
        center,
        radius * 0.46,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 + richness * 0.15
          ..color = Colors.white.withValues(alpha: (0.22 + richness * 0.04) * alpha),
      );
      canvas.drawCircle(
        center,
        radius * 0.46,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.15
          ..color = accent.withValues(alpha: 0.88 * alpha),
      );
    }

    // Event horizon.
    final coreR = radius * (rich ? 0.4 : 0.34);
    canvas.drawCircle(
      center,
      coreR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black,
            const Color(0xFF030308),
            Color.lerp(const Color(0xFF0A0A14), secondary, 0.25)!,
            accent.withValues(alpha: 0.48 * alpha),
          ],
          stops: const [0.0, 0.45, 0.78, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: coreR)),
    );

    // Inner rim catch-light.
    canvas.drawCircle(
      center,
      coreR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rich ? 1.8 + richness * 0.1 : 1.5
        ..color = accent.withValues(alpha: 0.85 * alpha),
    );

    if (rich && !locked) {
      // Lensing crescent on the near side of the disk.
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-0.4);
      canvas.scale(1.0, 0.55);
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius * 0.92),
        -0.35,
        0.9,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 + richness * 0.2
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(
            alpha: (0.28 + richness * 0.06) * alpha,
          ),
      );
      canvas.restore();
    }

    // Static orbit sparks — unique tier only.
    if (richness >= 3 && !locked) {
      final sparkPaint = Paint()..style = PaintingStyle.fill;
      for (var i = 0; i < 6; i++) {
        final a = i * 1.047 + 0.3;
        final dist = radius * (0.92 + (i % 2) * 0.12);
        final p = center + Offset(math.cos(a) * dist, math.sin(a) * dist * 0.55);
        sparkPaint.color = Color.lerp(accent, Colors.white, i / 5)!
            .withValues(alpha: 0.55);
        canvas.drawCircle(p, i.isEven ? 1.4 : 0.9, sparkPaint);
      }
    }

    if (!locked) {
      canvas.drawCircle(
        center,
        rich ? 2.2 + richness * 0.15 : 1.8,
        Paint()..color = Colors.white.withValues(alpha: 0.55 + richness * 0.05),
      );
    }
  }

  @override
  bool shouldRepaint(covariant StaticWormholePainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.secondary != secondary ||
        oldDelegate.locked != locked ||
        oldDelegate.bloom != bloom ||
        oldDelegate.rich != rich ||
        oldDelegate.ringCount != ringCount ||
        oldDelegate.richness != richness;
  }
}

/// Infernal hardcore transit disk — magma rings, fire corona, scorched throat.
class HardcoreWormholePainter extends CustomPainter {
  const HardcoreWormholePainter({this.pulse = 0});

  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.44;
    final flare = 0.85 + pulse * 0.35;

    canvas.drawCircle(
      center,
      radius * (1.72 + pulse * 0.12),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF2A0A).withValues(alpha: 0.58 * flare),
            const Color(0xFFFF8A18).withValues(alpha: 0.28 * flare),
            const Color(0xFFFFB020).withValues(alpha: 0.14),
            Colors.transparent,
          ],
          stops: const [0.0, 0.28, 0.55, 1.0],
        ).createShader(
          Rect.fromCircle(
            center: center,
            radius: radius * (1.72 + pulse * 0.12),
          ),
        ),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(0.72);
    canvas.scale(1.0, 0.46);
    canvas.drawCircle(
      Offset.zero,
      radius * 1.25,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF6A20).withValues(alpha: 0.55 * flare),
            const Color(0xFFFF3A1A).withValues(alpha: 0.28),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(center: Offset.zero, radius: radius * 1.25),
        ),
    );
    canvas.restore();

    final ringPaint = Paint()..style = PaintingStyle.stroke;
    for (var i = 0; i < 9; i++) {
      final t = i / 8;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(0.28 + i * 0.36 + pulse * 0.08);
      canvas.scale(1.0, 0.44 + t * 0.18);
      ringPaint
        ..strokeWidth = 2.8 - t * 1.0
        ..color = Color.lerp(
          const Color(0xFFFF2A0A),
          const Color(0xFFFFF0A0),
          t,
        )!
            .withValues(alpha: (0.9 - t * 0.3) * flare);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 2 * (1.16 - t * 0.28),
          height: radius * 2 * (0.86 - t * 0.1),
        ),
        ringPaint,
      );
      canvas.restore();
    }

    // Photon fire ring.
    canvas.drawCircle(
      center,
      radius * 0.52,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..color = const Color(0xFFFFE082).withValues(alpha: 0.35 + pulse * 0.2),
    );
    canvas.drawCircle(
      center,
      radius * 0.52,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFFFF2A0A).withValues(alpha: 0.98),
    );

    final coreR = radius * 0.42;
    canvas.drawCircle(
      center,
      coreR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black,
            const Color(0xFF180301),
            const Color(0xFF4A0C04),
            const Color(0xFFFF3A1A).withValues(alpha: 0.75),
          ],
          stops: const [0.0, 0.38, 0.72, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: coreR)),
    );
    canvas.drawCircle(
      center,
      coreR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0xFFFFB020).withValues(alpha: 0.95),
    );
    canvas.drawCircle(
      center,
      3.0 + pulse * 1.2,
      Paint()..color = const Color(0xFFFFF6D0).withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant HardcoreWormholePainter oldDelegate) =>
      oldDelegate.pulse != pulse;
}

class _HardcoreOuterRingPainter extends CustomPainter {
  const _HardcoreOuterRingPainter({required this.pulse});

  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.46;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 + pulse * 1.4
      ..color = const Color(0xFFFF6A20).withValues(alpha: 0.45 + pulse * 0.25);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0, 0.55);
    canvas.drawCircle(Offset.zero, r, paint);
    paint
      ..strokeWidth = 1.2
      ..color = const Color(0xFFFFE082).withValues(alpha: 0.35 + pulse * 0.2);
    canvas.drawCircle(Offset.zero, r * 0.82, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HardcoreOuterRingPainter oldDelegate) =>
      oldDelegate.pulse != pulse;
}

class _HardcoreTransitArcPainter extends CustomPainter {
  const _HardcoreTransitArcPainter({
    required this.progress,
    required this.pulse,
  });

  final double progress;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a0 = progress * math.pi * 2 * (1.1 + i * 0.05) + i * 0.7;
      final sweep = 0.55 + (i % 3) * 0.18 + pulse * 0.12;
      final rad = size.shortestSide * (0.18 + i * 0.045);
      paint
        ..strokeWidth = 1.6 + (i.isEven ? 1.2 : 0.4)
        ..color = Color.lerp(
          const Color(0xFFFF3A1A),
          const Color(0xFFFFE082),
          i / 7,
        )!
            .withValues(alpha: 0.22 + pulse * 0.18);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: rad),
        a0,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HardcoreTransitArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.pulse != pulse;
  }
}

class _HardcoreTransitEmberPainter extends CustomPainter {
  const _HardcoreTransitEmberPainter({
    required this.progress,
    required this.pulse,
  });

  final double progress;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    const count = 64;
    for (var i = 0; i < count; i++) {
      final a = progress * math.pi * 2 * (1.6 + (i % 5) * 0.09) +
          i * 0.31;
      final dist = size.shortestSide *
          (0.1 + (i % 9) * 0.05 + pulse * 0.05);
      final p = center +
          Offset(math.cos(a) * dist, math.sin(a) * dist * 0.78);
      paint.color = Color.lerp(
        const Color(0xFFFF2A0A),
        const Color(0xFFFFF0A0),
        (i % 7) / 6,
      )!
          .withValues(alpha: 0.3 + (i % 5) * 0.08 + pulse * 0.15);
      canvas.drawCircle(p, i.isEven ? 2.8 : 1.4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HardcoreTransitEmberPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.pulse != pulse;
  }
}
