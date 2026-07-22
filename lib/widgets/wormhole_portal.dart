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
  });

  final RoomType roomType;
  final Animation<double> spin;
  final bool locked;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = RoomVisualTheme.forRoom(roomType);
    final washA = UniversePalette.washA(roomType);
    final washB = UniversePalette.washB(roomType);

    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              washA.withValues(alpha: locked ? 0.38 : 0.58),
              const Color(0xFF010106),
              washB.withValues(alpha: locked ? 0.3 : 0.48),
            ],
          ),
          border: Border(
            right: BorderSide(
              color: theme.accent.withValues(alpha: locked ? 0.18 : 0.34),
            ),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Soft depth wash behind the throat.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.05, -0.05),
                  radius: 0.85,
                  colors: [
                    theme.accent.withValues(alpha: locked ? 0.08 : 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            AnimatedBuilder(
              animation: spin,
              builder: (context, child) {
                return Transform.rotate(
                  // Slow drift — one turn per particle loop ≈ 25s.
                  angle: spin.value * math.pi * 2 * 1.05,
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
    Duration diveDuration = const Duration(milliseconds: 620),
  }) =>
      _state.complete(diveDuration);

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

  bool _diving = false;
  bool _aborting = false;

  @override
  void initState() {
    super.initState();
    widget.holder.state = this;
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 12000),
    )..repeat();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
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
    _dive.stop();
    _fadeOut.duration = duration;
    await _fadeOut.reverse(from: 1);
  }

  @override
  void dispose() {
    if (widget.holder.state == this) widget.holder.state = null;
    _spin.dispose();
    _breathe.dispose();
    _dive.dispose();
    _fadeOut.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = RoomVisualTheme.forRoom(widget.roomType);
    final washA = UniversePalette.washA(widget.roomType);
    final washB = UniversePalette.washB(widget.roomType);

    return IgnorePointer(
      child: FadeTransition(
        opacity: _fadeOut,
        child: AnimatedBuilder(
          animation: Listenable.merge([_spin, _breathe, _dive]),
          builder: (context, child) {
            final diveT = Curves.easeInCubic.transform(_dive.value);
            final breath = 0.88 + _breathe.value * 0.14;
            final travelScale = _diving ? 1.0 : breath;
            final scale = travelScale + diveT * 3.6;
            final veil = (diveT * 1.2).clamp(0.0, 1.0);
            final spinAngle =
                _spin.value * math.pi * 2 + diveT * math.pi * 1.15;

            return ColoredBox(
              color: Color.lerp(
                const Color(0xF0020208),
                Colors.black,
                veil,
              )!,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 1.15 - diveT * 0.45,
                        colors: [
                          washA.withValues(
                            alpha: 0.34 * (1 - diveT * 0.8),
                          ),
                          washB.withValues(alpha: 0.16 * (1 - diveT)),
                          const Color(0xFF020208),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Transform.scale(
                      scale: scale,
                      child: Transform.rotate(
                        angle: spinAngle,
                        child: child,
                      ),
                    ),
                  ),
                  if (veil > 0)
                    Opacity(
                      opacity: veil,
                      child: const ColoredBox(color: Colors.black),
                    ),
                ],
              ),
            );
          },
          child: RepaintBoundary(
            child: SizedBox(
              width: 150,
              height: 150,
              child: CustomPaint(
                painter: StaticWormholePainter(
                  accent: theme.accent,
                  secondary: theme.secondaryAccent,
                  locked: false,
                  bloom: washA,
                ),
              ),
            ),
          ),
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
  });

  final Color accent;
  final Color secondary;
  final bool locked;
  final Color? bloom;
  final bool rich;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * (rich ? 0.44 : 0.36);
    final alpha = locked ? 0.4 : 1.0;
    final bloomColor = bloom ?? accent;

    // Outer gravitational glow.
    final haloR = radius * (rich ? 1.55 : 1.4);
    canvas.drawCircle(
      center,
      haloR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            bloomColor.withValues(alpha: (rich ? 0.34 : 0.26) * alpha),
            accent.withValues(alpha: 0.12 * alpha),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: haloR)),
    );

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
              accent.withValues(alpha: 0.22 * alpha),
              secondary.withValues(alpha: 0.1 * alpha),
              Colors.transparent,
            ],
            stops: const [0.15, 0.55, 1.0],
          ).createShader(
            Rect.fromCircle(center: Offset.zero, radius: radius * 1.05),
          ),
      );
      canvas.restore();

      // Distant field stars (static, deterministic).
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
      ];
      for (var i = 0; i < stars.length; i++) {
        final p = center + stars[i] * radius * 1.35;
        canvas.drawCircle(p, i.isEven ? 1.1 : 0.7, starPaint);
      }
    }

    // Tilted accretion rings.
    final ringCount = rich ? 5 : 3;
    final ringPaint = Paint()..style = PaintingStyle.stroke;
    for (var i = 0; i < ringCount; i++) {
      final t = ringCount == 1 ? 0.0 : i / (ringCount - 1);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(0.32 + i * 0.38);
      canvas.scale(1.0, 0.5 + t * 0.12);
      ringPaint
        ..strokeWidth = rich ? (1.6 - t * 0.5) : 1.2
        ..color = Color.lerp(accent, secondary, t)!
            .withValues(alpha: (0.62 - t * 0.28) * alpha);
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
          ..strokeWidth = 2.2
          ..color = Colors.white.withValues(alpha: 0.22 * alpha),
      );
      canvas.drawCircle(
        center,
        radius * 0.46,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.15
          ..color = accent.withValues(alpha: 0.85 * alpha),
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
            const Color(0xFF0A0A14),
            accent.withValues(alpha: 0.45 * alpha),
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
        ..strokeWidth = rich ? 1.8 : 1.5
        ..color = accent.withValues(alpha: 0.82 * alpha),
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
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.28 * alpha),
      );
      canvas.restore();
    }

    if (!locked) {
      canvas.drawCircle(
        center,
        rich ? 2.2 : 1.8,
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(covariant StaticWormholePainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.secondary != secondary ||
        oldDelegate.locked != locked ||
        oldDelegate.bloom != bloom ||
        oldDelegate.rich != rich;
  }
}
