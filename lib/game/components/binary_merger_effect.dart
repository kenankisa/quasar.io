import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../utils/canvas_effects.dart';
import '../utils/cosmic_particle_presets.dart';
import '../utils/gravity_scaling.dart';
import 'timed_particle_burst.dart';

/// Binary black-hole merger visuals, staged after the reference infographic:
///
/// * Stage 1 — Gravitational Inspiral: dashed orbital paths around the
///   common barycenter while the pair slowly draws closer.
/// * Stage 2 — Tidal Deformation & Mass Transfer: a mutual S-shaped
///   "binary accretion bridge" with matter flowing both ways.
/// * Stage 3 — The Dance: the bridge tightens white-hot while the pair
///   spirals; gravitational-wave ripples are emitted by the physics manager.
///
/// Purely visual — all gameplay motion lives in [GravityPhysicsManager].
class BinaryMergerEffect extends PositionComponent {
  BinaryMergerEffect() : super(priority: -2, anchor: Anchor.topLeft);

  final Vector2 _posA = Vector2.zero();
  final Vector2 _posB = Vector2.zero();
  double _radiusA = 0;
  double _radiusB = 0;
  Color _accentA = const Color(0xFFFFAA44);
  Color _accentB = const Color(0xFF55AAFF);
  int _stage = 1;
  double _intensity = 0;
  double _phase = 0;
  bool _hasState = false;

  _StreamEmitter? _emitterAB;
  _StreamEmitter? _emitterBA;

  /// Called every frame by the physics manager while the pair is active.
  void updateState({
    required Vector2 posA,
    required Vector2 posB,
    required double radiusA,
    required double radiusB,
    required Color accentA,
    required Color accentB,
    required int stage,
    required double intensity,
  }) {
    _posA.setFrom(posA);
    _posB.setFrom(posB);
    _radiusA = radiusA;
    _radiusB = radiusB;
    _accentA = accentA;
    _accentB = accentB;
    _stage = stage;
    _intensity = intensity.clamp(0.0, 1.0);
    _hasState = true;

    position.setFrom((posA + posB) / 2);
    _syncEmitters();
  }

  void _syncEmitters() {
    if (_stage < 2) {
      _emitterAB?.removeFromParent();
      _emitterBA?.removeFromParent();
      _emitterAB = null;
      _emitterBA = null;
      return;
    }

    _emitterAB ??= _mountEmitter();
    _emitterBA ??= _mountEmitter();

    _configureEmitter(
      _emitterAB!,
      from: _posA,
      to: _posB,
      fromRadius: _radiusA,
      toRadius: _radiusB,
      fromAccent: _accentA,
      toAccent: _accentB,
    );
    _configureEmitter(
      _emitterBA!,
      from: _posB,
      to: _posA,
      fromRadius: _radiusB,
      toRadius: _radiusA,
      fromAccent: _accentB,
      toAccent: _accentA,
    );
  }

  _StreamEmitter _mountEmitter() {
    final emitter = _StreamEmitter();
    add(emitter);
    return emitter;
  }

  void _configureEmitter(
    _StreamEmitter emitter, {
    required Vector2 from,
    required Vector2 to,
    required double fromRadius,
    required double toRadius,
    required Color fromAccent,
    required Color toAccent,
  }) {
    final delta = to - from;
    final distance = delta.length;
    if (distance < 1) return;

    final dir = delta / distance;
    final photonR =
        toRadius * GravityScaling.schwarzschildFraction * GravityScaling.shadowBoundaryRatio;
    final start = from + dir * fromRadius * 0.55;
    final end = to - dir * photonR * 0.92;
    final bridge = end - start;
    final bridgeLen = bridge.length;
    if (bridgeLen < 1) return;

    emitter.position.setFrom((start + end) / 2 - position);
    emitter.angle = math.atan2(bridge.y, bridge.x);
    emitter.configure(
      bridgeLength: bridgeLen,
      sourceRadius: fromRadius,
      sourceAccent: fromAccent,
      targetAccent: toAccent,
      intensity: _intensity * (_stage >= 3 ? 1.0 : 0.75),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _phase += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!_hasState) return;

    canvas.save();
    final localA = Offset(_posA.x - position.x, _posA.y - position.y);
    final localB = Offset(_posB.x - position.x, _posB.y - position.y);

    if (_stage == 1) {
      _renderOrbitPaths(canvas, localA, localB);
    } else {
      _renderBinaryBridge(canvas, localA, localB);
    }

    canvas.restore();
  }

  /// Stage 1 — dashed orbits around the shared barycenter (M ∝ r³ weighting).
  void _renderOrbitPaths(Canvas canvas, Offset localA, Offset localB) {
    final massA = math.pow(math.max(_radiusA, 1), 3).toDouble();
    final massB = math.pow(math.max(_radiusB, 1), 3).toDouble();
    final total = massA + massB;
    final center = Offset(
      (localA.dx * massA + localB.dx * massB) / total,
      (localA.dy * massA + localB.dy * massB) / total,
    );

    final alpha = (0.10 + _intensity * 0.22).clamp(0.0, 0.32);
    _drawDashedOrbit(canvas, center, (localA - center).distance, _accentA, alpha);
    _drawDashedOrbit(canvas, center, (localB - center).distance, _accentB, alpha);

    // Barycenter marker — the invisible pivot both holes fall toward.
    canvas.drawCircle(
      center,
      2.5,
      Paint()..color = Colors.white.withValues(alpha: alpha * 0.8),
    );
  }

  void _drawDashedOrbit(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double alpha,
  ) {
    if (radius < 4) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = color.withValues(alpha: alpha);

    const dashCount = 36;
    const dashFraction = 0.55;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final spin = _phase * 0.25;
    for (var i = 0; i < dashCount; i++) {
      final startAngle = spin + (i / dashCount) * math.pi * 2;
      canvas.drawArc(
        rect,
        startAngle,
        (math.pi * 2 / dashCount) * dashFraction,
        false,
        paint,
      );
    }
  }

  /// Stage 2–3 — mutual S-shaped accretion bridge (matter flows both ways).
  void _renderBinaryBridge(Canvas canvas, Offset localA, Offset localB) {
    final p = _intensity;
    final hot = _stage >= 3;
    final pulse = 0.88 + math.sin(_phase * (hot ? 7.5 : 5.0)) * 0.12;
    final alpha = ((hot ? 0.30 : 0.16) + p * 0.5).clamp(0.0, 0.85) * pulse;
    final pop = CanvasEffects.isNativeMobile ? 1.15 : 1.0;

    _drawStream(
      canvas,
      from: localA,
      to: localB,
      fromRadius: _radiusA,
      toRadius: _radiusB,
      fromAccent: _accentA,
      alpha: alpha * pop,
      hot: hot,
      bendSign: 1,
    );
    _drawStream(
      canvas,
      from: localB,
      to: localA,
      fromRadius: _radiusB,
      toRadius: _radiusA,
      fromAccent: _accentB,
      alpha: alpha * pop,
      hot: hot,
      bendSign: 1,
    );

    if (hot) {
      // Extreme tidal interaction — shared plasma sheath around both horizons.
      final mid = Offset(
        (localA.dx + localB.dx) / 2,
        (localA.dy + localB.dy) / 2,
      );
      final sheathR = ((localA - localB).distance / 2) +
          math.max(_radiusA, _radiusB) * 0.9;
      canvas.drawCircle(
        mid,
        sheathR,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: alpha * 0.10),
              _accentA.withValues(alpha: alpha * 0.06),
              Colors.transparent,
            ],
            stops: const [0.0, 0.6, 1.0],
          ).createShader(Rect.fromCircle(center: mid, radius: sheathR))
          ..blendMode = BlendMode.plus,
      );
    }
  }

  void _drawStream(
    Canvas canvas, {
    required Offset from,
    required Offset to,
    required double fromRadius,
    required double toRadius,
    required Color fromAccent,
    required double alpha,
    required bool hot,
    required double bendSign,
  }) {
    final delta = to - from;
    final distance = delta.distance;
    if (distance < 1) return;

    final dir = delta / distance;
    final normal = Offset(-dir.dy, dir.dx) * bendSign;
    final photonR =
        toRadius * GravityScaling.schwarzschildFraction * GravityScaling.shadowBoundaryRatio;

    // Both streams bend to the same relative side of their own travel
    // direction — together they form the S / yin-yang of the reference image.
    final start = from + dir * fromRadius * 0.6 + normal * fromRadius * 0.35;
    final end = to - dir * photonR * 0.9 - normal * toRadius * 0.30;
    final bend = normal * (distance * (hot ? 0.16 : 0.24) + fromRadius * 0.4);
    final control = Offset(
      (start.dx + end.dx) / 2 + bend.dx,
      (start.dy + end.dy) / 2 + bend.dy,
    );

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

    final streamW =
        math.max(1.4, fromRadius * 0.10) * (0.5 + _intensity * 0.9);

    // Redshifted outer sheath.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = streamW * 2.6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF441100).withValues(alpha: alpha * 0.16),
    );

    // Hot synchrotron channel: source accent → white toward the sink.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = streamW * (0.85 + _intensity * 0.4)
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          begin: Alignment(-dir.dx.clamp(-1.0, 1.0), -dir.dy.clamp(-1.0, 1.0)),
          end: Alignment(dir.dx.clamp(-1.0, 1.0), dir.dy.clamp(-1.0, 1.0)),
          colors: [
            fromAccent.withValues(alpha: alpha * 0.30),
            Color.lerp(const Color(0xFFFFE8CC), Colors.white, _intensity * 0.7)!
                .withValues(alpha: alpha * 0.55),
            Colors.white.withValues(alpha: alpha * (hot ? 0.8 : 0.6)),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(path.getBounds().inflate(streamW)),
    );

    // Matter beads flowing along the stream toward the sink. Evaluated
    // directly on the quadratic Bézier — path.computeMetrics() every frame
    // allocates contour measures and stalls CanvasKit on web.
    final beadCount = hot ? 5 : 3;
    final beadPaint = Paint()..blendMode = BlendMode.plus;
    for (var i = 0; i < beadCount; i++) {
      final t = ((_phase * (hot ? 0.9 : 0.55) + i / beadCount) % 1.0);
      final mt = 1 - t;
      final pos = Offset(
        mt * mt * start.dx + 2 * mt * t * control.dx + t * t * end.dx,
        mt * mt * start.dy + 2 * mt * t * control.dy + t * t * end.dy,
      );
      beadPaint.color =
          Colors.white.withValues(alpha: alpha * (0.35 + t * 0.45));
      canvas.drawCircle(pos, streamW * (0.45 + t * 0.35), beadPaint);
    }

    // Accretion entry glow where the stream feeds the companion.
    final entryR = streamW * (1.0 + _intensity * 0.6);
    canvas.drawCircle(
      end,
      entryR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: alpha * 0.8),
            fromAccent.withValues(alpha: alpha * 0.3),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: end, radius: entryR * 1.6)),
    );
  }
}

/// Rotated particle spawner reusing the swallow-bridge presets along one
/// direction of the binary bridge.
class _StreamEmitter extends PositionComponent {
  _StreamEmitter() : super(anchor: Anchor.center, priority: -2);

  double _bridgeLength = 0;
  double _sourceRadius = 0;
  Color _sourceAccent = Colors.white;
  Color _targetAccent = Colors.white;
  double _intensity = 0;
  double _spawnTimer = 0;
  int _burstSeed = 0;

  void configure({
    required double bridgeLength,
    required double sourceRadius,
    required Color sourceAccent,
    required Color targetAccent,
    required double intensity,
  }) {
    _bridgeLength = bridgeLength;
    _sourceRadius = sourceRadius;
    _sourceAccent = sourceAccent;
    _targetAccent = targetAccent;
    _intensity = intensity;
    size = Vector2(bridgeLength, sourceRadius * 1.6);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_bridgeLength < 1 || _intensity <= 0.05) return;

    _spawnTimer -= dt;
    final lite = CanvasEffects.mobileLiteMode;
    final interval =
        ((lite ? 0.14 : 0.08) - _intensity * 0.03).clamp(0.05, 0.16);
    if (_spawnTimer > 0) return;
    _spawnTimer = interval;

    // Particle budget: skip spawning while full instead of force-removing —
    // removeFromParent() is deferred in Flame, so a `while (children.length…)`
    // drain loop never sees the count drop and spins forever (game freeze).
    final maxChildren = lite ? 4 : 8;
    var alive = 0;
    for (final child in children) {
      if (!child.isRemoving) alive++;
    }
    if (alive >= maxChildren) return;

    _burstSeed++;
    final seed = (_burstSeed * 73856093) ^ position.x.round();
    final lifespan = (0.5 + _intensity * 0.3).clamp(0.45, 0.85);
    final streamW = math.max(1.2, _sourceRadius * 0.05) *
        (0.5 + _intensity * 0.9);

    add(
      TimedParticleBurst(
        particle: CosmicParticlePresets.swallowBridgeFilament(
          bridgeLength: _bridgeLength,
          streamWidth: streamW,
          preyAccent: _sourceAccent,
          predatorAccent: _targetAccent,
          intensity: _intensity,
          seed: seed,
        ),
        lifespan: lifespan,
      ),
    );

    if (_intensity > 0.3 && _burstSeed % 3 == 0 && alive + 1 < maxChildren) {
      add(
        TimedParticleBurst(
          particle: CosmicParticlePresets.swallowBridgeStripping(
            preyRadius: _sourceRadius,
            preyAccent: _sourceAccent,
            intensity: _intensity,
            seed: seed,
          ),
          lifespan: lifespan * 0.85,
        ),
      );
    }
  }
}
