import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config/universe_palette.dart';
import '../orbit_game.dart';
import '../room_type.dart';
import '../utils/canvas_effects.dart';
import '../utils/star_lensing.dart';
import '../utils/starfield_tile_baker.dart';
import '../utils/viewport_cull.dart';

part 'starfield/star_models.dart';
part 'starfield/space_spec.dart';
part 'starfield/scenery_models.dart';

// ─────────────────────────────────────────────────────────────────────────
//  Component
// ─────────────────────────────────────────────────────────────────────────

class StarfieldBackground extends Component with HasGameReference<OrbitGame> {
  StarfieldBackground({required this.roomType});

  final RoomType roomType;

  late final _SpaceSpec _spec;
  late final List<_StarLayer> _layers;
  /// Dim layers baked into tiles when [_useTileBake] is on.
  late final List<_StarLayer> _bakeLayers;
  /// Twinkle + lensing — all layers on desktop, bright layers on mobile bake.
  late final List<_StarLayer> _liveLayers;
  late final List<_NebulaComplex> _nebulae;
  late final List<_Galaxy> _galaxies;
  late final List<_BandPatch> _bandPatches;
  late final List<_BandStar> _bandStars;
  late final List<_Pulsar> _pulsars;
  late final Offset _bandCenter;
  late final double _bandAngle;

  /// Mobile/web: static scenery + dim stars as GPU tiles (see plan).
  late final bool _useTileBake;
  StarfieldTileBaker? _tileBaker;

  // Cached wash only — void fill lives on [VoidCameraBackdrop] (no double paint).
  late final Paint _washPaint;
  Paint? _coreGlowPaint;
  late final double _coreGlowRadius;

  // Reused per-frame star paints (mutate color / maskFilter only).
  final _starPaint = Paint();
  final _starGlowPaint = Paint();
  final _sparklePaint = Paint()
    ..strokeWidth = 0.7
    ..strokeCap = StrokeCap.round;
  final _bandStarPaint = Paint();

  double _elapsed = 0;
  double _meteorTimer = 4.0;
  double _cometTimer = 8.0;
  double _supernovaTimer = 0;

  final List<_DecorMeteor> _meteors = [];
  final List<_Comet> _comets = [];
  final List<_Supernova> _supernovae = [];
  final _rng = math.Random(91);

  /// Star layers per tier — counts stay within the budgets the game was
  /// already tuned for (black-hole FX headroom on elite/unique).
  static List<_StarLayer> _layersFor(RoomType type) => switch (type) {
        RoomType.simple => [
            _StarLayer(
              count: 1800,
              minRadius: 0.28,
              maxRadius: 0.72,
              minAlpha: 0.12,
              maxAlpha: 0.42,
              seed: 3,
            ),
            _StarLayer(
              count: 1100,
              minRadius: 0.4,
              maxRadius: 1.05,
              minAlpha: 0.18,
              maxAlpha: 0.52,
              seed: 11,
            ),
            _StarLayer(
              count: 480,
              minRadius: 0.7,
              maxRadius: 1.65,
              minAlpha: 0.26,
              maxAlpha: 0.68,
              seed: 29,
              hotBias: 0.2,
            ),
            _StarLayer(
              count: 150,
              minRadius: 0.95,
              maxRadius: 2.1,
              minAlpha: 0.38,
              maxAlpha: 0.82,
              seed: 47,
              hotBias: 0.35,
            ),
          ],
        RoomType.normal => [
            _StarLayer(
              count: 2100,
              minRadius: 0.28,
              maxRadius: 0.75,
              minAlpha: 0.14,
              maxAlpha: 0.48,
              seed: 3,
            ),
            _StarLayer(
              count: 1350,
              minRadius: 0.42,
              maxRadius: 1.15,
              minAlpha: 0.2,
              maxAlpha: 0.58,
              seed: 11,
            ),
            _StarLayer(
              count: 620,
              minRadius: 0.75,
              maxRadius: 1.85,
              minAlpha: 0.3,
              maxAlpha: 0.74,
              seed: 29,
              hotBias: 0.25,
            ),
            _StarLayer(
              count: 200,
              minRadius: 1.0,
              maxRadius: 2.4,
              minAlpha: 0.42,
              maxAlpha: 0.88,
              seed: 47,
              hotBias: 0.4,
            ),
          ],
        RoomType.elite => [
            _StarLayer(
              count: 2450,
              minRadius: 0.28,
              maxRadius: 0.78,
              minAlpha: 0.16,
              maxAlpha: 0.52,
              seed: 3,
            ),
            _StarLayer(
              count: 1600,
              minRadius: 0.4,
              maxRadius: 1.2,
              minAlpha: 0.22,
              maxAlpha: 0.62,
              seed: 7,
            ),
            _StarLayer(
              count: 950,
              minRadius: 0.65,
              maxRadius: 1.75,
              minAlpha: 0.3,
              maxAlpha: 0.76,
              seed: 11,
              hotBias: 0.25,
            ),
            _StarLayer(
              count: 420,
              minRadius: 0.95,
              maxRadius: 2.35,
              minAlpha: 0.4,
              maxAlpha: 0.86,
              seed: 29,
              hotBias: 0.4,
            ),
            _StarLayer(
              count: 140,
              minRadius: 1.35,
              maxRadius: 3.1,
              minAlpha: 0.52,
              maxAlpha: 0.95,
              seed: 47,
              hotBias: 0.55,
            ),
          ],
        // Four layers (elite budget) — frees GPU for black-hole FX.
        RoomType.unique => [
            _StarLayer(
              count: 2450,
              minRadius: 0.28,
              maxRadius: 0.78,
              minAlpha: 0.16,
              maxAlpha: 0.52,
              seed: 3,
            ),
            _StarLayer(
              count: 1600,
              minRadius: 0.4,
              maxRadius: 1.2,
              minAlpha: 0.22,
              maxAlpha: 0.62,
              seed: 7,
            ),
            _StarLayer(
              count: 620,
              minRadius: 0.75,
              maxRadius: 1.85,
              minAlpha: 0.3,
              maxAlpha: 0.74,
              seed: 11,
              hotBias: 0.3,
            ),
            _StarLayer(
              count: 200,
              minRadius: 1.0,
              maxRadius: 2.4,
              minAlpha: 0.42,
              maxAlpha: 0.88,
              seed: 47,
              hotBias: 0.5,
            ),
          ],
      };

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _spec = _SpaceSpec.forRoom(roomType);
    _useTileBake = CanvasEffects.mobileLiteMode;
    _layers = _layersFor(roomType);
    final worldSize = game.worldSize;

    if (_useTileBake) {
      _bakeLayers = _layers.where((l) => !l.isLiveLayer).toList();
      _liveLayers = _layers.where((l) => l.isLiveLayer).toList();
      for (final layer in _bakeLayers) {
        layer.generate(worldSize, fullBudget: true);
      }
      for (final layer in _liveLayers) {
        layer.generate(worldSize);
      }
    } else {
      _bakeLayers = <_StarLayer>[];
      _liveLayers = _layers;
      for (final layer in _layers) {
        layer.generate(worldSize);
      }
    }
    _bandAngle = -0.42 + math.Random(roomType.index + 5).nextDouble() * 0.3;
    _bandCenter = Offset(worldSize * 0.5, worldSize * 0.5);

    _buildFramePaints();
    _nebulae = _buildNebulae(worldSize);
    _galaxies = _buildGalaxies(worldSize);
    _bandPatches = _buildBandPatches(worldSize);
    _bandStars = _buildBandStars(worldSize);
    _pulsars = _buildPulsars(worldSize);

    _supernovaTimer = _spec.supernovaInterval.$1 > 0
        ? _spec.supernovaInterval.$1 * (0.5 + _rng.nextDouble() * 0.5)
        : double.infinity;

    if (_useTileBake) {
      final baker = StarfieldTileBaker(
        worldSize: worldSize,
        gridSize: 4,
        pixelSize: 512,
        painter: _paintBakedTile,
      );
      _tileBaker = baker;
      // Warm spawn region so the first frames already have scenery.
      await baker.warmUp(
        Rect.fromCenter(
          center: Offset(worldSize * 0.5, worldSize * 0.5),
          width: worldSize * 0.4,
          height: worldSize * 0.4,
        ),
      );
    }

    priority = -20;
  }

  @override
  void onRemove() {
    _tileBaker?.dispose();
    _tileBaker = null;
    super.onRemove();
  }

  /// Static scenery for one tile — nebulae frozen (no drift), dim stars fixed.
  /// Large inflate so nebulae / band patches spanning tile edges stay seamless.
  void _paintBakedTile(Canvas canvas, Rect worldRect) {
    final query = worldRect.inflate(2200);
    _drawMilkyWay(canvas, query);
    _drawNebulae(canvas, query, frozen: true);
    _drawGalaxies(canvas, query);
    _drawBandStars(canvas, query);
    _drawBakedStars(canvas, worldRect.inflate(80));
  }

  void _drawBakedStars(Canvas canvas, Rect visible) {
    if (_bakeLayers.isEmpty) return;
    final paint = _starPaint;
    for (final layer in _bakeLayers) {
      layer.grid.forEachInRect(visible, (star) {
        // Mid twinkle — distant stars stay put on the tile texture.
        const twinkle = 0.72;
        final alpha = (star.alpha * twinkle).clamp(0.0, 1.0);
        if (alpha < 0.02) return;
        paint
          ..color = star.color.withValues(alpha: alpha)
          ..maskFilter = null;
        canvas.drawCircle(
          Offset(star.position.x, star.position.y),
          star.radius,
          paint,
        );
      });
    }
  }

  // ── Scene construction (all shaders created once, here) ────────────────

  void _buildFramePaints() {
    // Unit-space diagonal wash: (-0.5,-0.5) → (0.5,0.5).
    // Void gradient is owned by VoidCameraBackdrop — avoid double overdraw.
    _washPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(-0.5, -0.5),
        const Offset(0.5, 0.5),
        [
          _spec.washA.withValues(alpha: 0.045),
          Colors.transparent,
          _spec.washB.withValues(alpha: 0.04),
        ],
        const [0.0, 0.5, 1.0],
      );

    if (_spec.galacticCoreGlow) {
      _coreGlowRadius = game.worldSize * 0.26;
      _coreGlowPaint = Paint()
        ..shader = ui.Gradient.radial(
          _bandCenter,
          _coreGlowRadius,
          [
            const Color(0xFFFFD9A0).withValues(alpha: 0.07),
            const Color(0xFFE8A868).withValues(alpha: 0.03),
            Colors.transparent,
          ],
          const [0.0, 0.45, 1.0],
        );
    } else {
      _coreGlowRadius = 0;
    }
  }

  Paint _nebulaBlobPaint({
    required Offset offset,
    required double radius,
    required Color color,
    required double alpha,
    required bool dark,
  }) {
    final a = (alpha * _spec.nebulaAlpha).clamp(0.0, 1.0);
    final colors = dark
        ? [
            color.withValues(alpha: a),
            color.withValues(alpha: a * 0.45),
            Colors.transparent,
          ]
        : [
            color.withValues(alpha: a),
            color.withValues(alpha: a * 0.6),
            color.withValues(alpha: a * 0.3),
            color.withValues(alpha: a * 0.1),
            Colors.transparent,
          ];
    return Paint()
      ..shader = ui.Gradient.radial(
        offset,
        radius,
        colors,
        dark ? const [0.0, 0.5, 1.0] : const [0.0, 0.25, 0.5, 0.75, 1.0],
      );
  }

  List<_NebulaComplex> _buildNebulae(double worldSize) {
    final rng = math.Random(83);
    final lite = CanvasEffects.mobileLiteMode;
    final count = lite
        ? (_spec.nebulaCount * 0.62).round().clamp(3, _spec.nebulaCount)
        : _spec.nebulaCount;
    final palettes = _spec.nebulaPalettes;

    return List.generate(count, (i) {
      final (core, accent) = palettes[i % palettes.length];
      final baseRadius = switch (roomType) {
        RoomType.simple => 950 + rng.nextDouble() * 650,
        RoomType.normal => 1050 + rng.nextDouble() * 750,
        RoomType.elite => 950 + rng.nextDouble() * 800,
        RoomType.unique => 1150 + rng.nextDouble() * 900,
      };

      // Even spacing along X + jitter → every screenful holds some nebula.
      final band = (i + rng.nextDouble() * 0.85) / count;
      final position = Vector2(
        band * worldSize + (rng.nextDouble() - 0.5) * worldSize * 0.22,
        rng.nextDouble() * worldSize,
      );

      _NebulaBlob blob({
        required Offset offset,
        required double radius,
        required Color color,
        required double alpha,
        bool dark = false,
      }) =>
          _NebulaBlob(
            offset: offset,
            radius: radius,
            dark: dark,
            paint: _nebulaBlobPaint(
              offset: offset,
              radius: radius,
              color: color,
              alpha: alpha,
              dark: dark,
            ),
          );

      final blobs = <_NebulaBlob>[
        // Core glow.
        blob(
          offset: Offset.zero,
          radius: baseRadius,
          color: core,
          alpha: 0.5,
        ),
        // Bright inner emission knot, off-center.
        blob(
          offset: Offset(
            (rng.nextDouble() - 0.5) * baseRadius * 0.5,
            (rng.nextDouble() - 0.5) * baseRadius * 0.4,
          ),
          radius: baseRadius * (0.34 + rng.nextDouble() * 0.18),
          color: accent,
          alpha: 0.42,
        ),
      ];

      if (!lite) {
        // Secondary wisp — stretches the silhouette away from a plain circle.
        blobs.add(
          blob(
            offset: Offset(
              (rng.nextDouble() - 0.5) * baseRadius * 1.1,
              (rng.nextDouble() - 0.5) * baseRadius * 0.8,
            ),
            radius: baseRadius * (0.42 + rng.nextDouble() * 0.22),
            color: Color.lerp(core, accent, 0.55)!,
            alpha: 0.3,
          ),
        );
        // Dust lane — dark occluding cloud carving depth into the glow.
        blobs.add(
          blob(
            offset: Offset(
              (rng.nextDouble() - 0.5) * baseRadius * 0.7,
              (rng.nextDouble() - 0.3) * baseRadius * 0.5,
            ),
            radius: baseRadius * (0.3 + rng.nextDouble() * 0.2),
            color: const Color(0xFF050308),
            alpha: 0.32,
            dark: true,
          ),
        );
      }

      final stretchX = 0.85 + rng.nextDouble() * 0.9;
      final stretchY = 0.45 + rng.nextDouble() * 0.45;
      return _NebulaComplex(
        position: position,
        rotation: rng.nextDouble() * math.pi * 2,
        stretchX: stretchX,
        stretchY: stretchY,
        driftSpeed: 0.05 + rng.nextDouble() * 0.12,
        phase: rng.nextDouble() * math.pi * 2,
        blobs: blobs,
        boundRadius: baseRadius * 1.7 * math.max(stretchX, stretchY),
      );
    });
  }

  List<_Galaxy> _buildGalaxies(double worldSize) {
    final rng = math.Random(157);
    final count = CanvasEffects.mobileLiteMode
        ? (_spec.galaxyCount * 0.6).round().clamp(1, _spec.galaxyCount)
        : _spec.galaxyCount;

    const diskTints = [
      Color(0xFFC8D8F8),
      Color(0xFFE8D8C0),
      Color(0xFFD8C8F0),
      Color(0xFFC0E0E8),
    ];
    const coreColor = Color(0xFFFFF2DC);

    return List.generate(count, (i) {
      final radius = 90 + rng.nextDouble() * 130;
      final diskColor = diskTints[rng.nextInt(diskTints.length)];
      final spiral = roomType == RoomType.unique && i < 2;

      final diskPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          radius,
          [
            diskColor.withValues(alpha: 0.2),
            diskColor.withValues(alpha: 0.1),
            diskColor.withValues(alpha: 0.03),
            Colors.transparent,
          ],
          const [0.0, 0.35, 0.7, 1.0],
        );
      final corePaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          radius * 0.22,
          [
            coreColor.withValues(alpha: 0.75),
            coreColor.withValues(alpha: 0.2),
            Colors.transparent,
          ],
          const [0.0, 0.5, 1.0],
        );
      final armPaint = spiral
          ? (Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * 0.1
            ..color = diskColor.withValues(alpha: 0.12)
            ..strokeCap = StrokeCap.round)
          : null;

      return _Galaxy(
        position: Vector2(
          rng.nextDouble() * worldSize,
          rng.nextDouble() * worldSize,
        ),
        radius: radius,
        tilt: rng.nextDouble() * math.pi,
        aspect: 0.22 + rng.nextDouble() * 0.35,
        spiral: spiral,
        diskPaint: diskPaint,
        corePaint: corePaint,
        armPaint: armPaint,
      );
    });
  }

  Paint _bandPatchPaint({
    required double radius,
    required Color color,
    required double alpha,
    required bool dark,
  }) {
    final stops = dark ? const [0.0, 0.55, 1.0] : const [0.0, 0.4, 0.75, 1.0];
    final colors = dark
        ? [
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * 0.5),
            Colors.transparent,
          ]
        : [
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * 0.6),
            color.withValues(alpha: alpha * 0.22),
            Colors.transparent,
          ];
    return Paint()
      ..shader = ui.Gradient.radial(Offset.zero, radius, colors, stops);
  }

  List<_BandPatch> _buildBandPatches(double worldSize) {
    if (_spec.bandStrength <= 0) return const [];
    final rng = math.Random(211);
    final lite = CanvasEffects.mobileLiteMode;
    final patchCount = lite ? 9 : 14;
    final halfLen = worldSize * 0.72;
    final dir = Offset(math.cos(_bandAngle), math.sin(_bandAngle));
    final perp = Offset(-dir.dy, dir.dx);

    final glowColor = Color.lerp(
      const Color(0xFFB8CCE8),
      const Color(0xFFF0D8A8),
      _spec.bandWarmth,
    )!;

    final patches = <_BandPatch>[];
    for (var i = 0; i < patchCount; i++) {
      final t = (i / (patchCount - 1)) * 2 - 1;
      final along = _bandCenter + dir * (t * halfLen);
      final off = perp * ((rng.nextDouble() - 0.5) * worldSize * 0.05);
      // Bulge: patches near the center are wider and brighter.
      final bulge = 1.0 - t.abs() * 0.55;
      final radius = (520 + rng.nextDouble() * 380) * bulge;
      patches.add(
        _BandPatch(
          center: along + off,
          radius: radius,
          stretch: 2.4 + rng.nextDouble() * 1.4,
          rotation: _bandAngle + (rng.nextDouble() - 0.5) * 0.18,
          paint: _bandPatchPaint(
            radius: radius,
            color: glowColor,
            alpha: (0.035 + rng.nextDouble() * 0.03) *
                _spec.bandStrength *
                bulge,
            dark: false,
          ),
        ),
      );
    }

    if (!lite) {
      // Dark interstellar dust rifts snaking through the glow (Great Rift).
      final riftCount = roomType == RoomType.unique ? 6 : 4;
      for (var i = 0; i < riftCount; i++) {
        final t = (rng.nextDouble() * 1.6 - 0.8);
        final along = _bandCenter + dir * (t * halfLen);
        final off = perp * ((rng.nextDouble() - 0.5) * worldSize * 0.03);
        final radius = 260 + rng.nextDouble() * 260;
        patches.add(
          _BandPatch(
            center: along + off,
            radius: radius,
            stretch: 2.8 + rng.nextDouble() * 1.6,
            rotation: _bandAngle + (rng.nextDouble() - 0.5) * 0.24,
            paint: _bandPatchPaint(
              radius: radius,
              color: const Color(0xFF030205),
              alpha: (0.16 + rng.nextDouble() * 0.1) * _spec.bandStrength,
              dark: true,
            ),
          ),
        );
      }
    }
    return patches;
  }

  List<_BandStar> _buildBandStars(double worldSize) {
    if (_spec.bandStarCount <= 0) return const [];
    final rng = math.Random(223);
    final count = CanvasEffects.mobileLiteMode
        ? (_spec.bandStarCount * 0.5).round()
        : _spec.bandStarCount;
    final halfLen = worldSize * 0.72;
    final dir = Offset(math.cos(_bandAngle), math.sin(_bandAngle));
    final perp = Offset(-dir.dy, dir.dx);
    final sigma = worldSize * 0.045;

    return List.generate(count, (i) {
      final t = rng.nextDouble() * 2 - 1;
      // Approximate gaussian perpendicular spread (sum of uniforms).
      final g =
          (rng.nextDouble() + rng.nextDouble() + rng.nextDouble() - 1.5) / 1.5;
      final pos = _bandCenter + dir * (t * halfLen) + perp * (g * sigma);
      return _BandStar(
        pos,
        0.3 + rng.nextDouble() * 0.55,
        (0.1 + rng.nextDouble() * 0.2) * (1.0 - t.abs() * 0.4),
        rng.nextDouble() < _spec.bandWarmth
            ? const Color(0xFFFFE8C8)
            : const Color(0xFFDCE8FF),
      );
    });
  }

  List<_Pulsar> _buildPulsars(double worldSize) {
    if (_spec.pulsarCount <= 0) return const [];
    final rng = math.Random(307);
    return List.generate(_spec.pulsarCount, (i) {
      final glowPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          _Pulsar.glowBaseRadius,
          [
            const Color(0xFFE8F4FF).withValues(alpha: 0.7),
            const Color(0xFF88C4FF).withValues(alpha: 0.25),
            Colors.transparent,
          ],
          const [0.0, 0.4, 1.0],
        );
      return _Pulsar(
        position: Vector2(
          worldSize * (0.15 + rng.nextDouble() * 0.7),
          worldSize * (0.15 + rng.nextDouble() * 0.7),
        ),
        period: 1.4 + rng.nextDouble() * 1.6,
        phase: rng.nextDouble(),
        glowPaint: glowPaint,
      );
    });
  }

  // ── Update ──────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;

    if (_useTileBake) {
      final visible = _visibleRect();
      if (!visible.isEmpty) {
        _tileBaker?.ensureVisible(visible);
      }
    }

    _updateMeteors(dt);
    _updateComets(dt);
    _updateSupernovae(dt);
  }

  void _updateMeteors(double dt) {
    final (minI, maxI) = _spec.meteorInterval;
    if (maxI <= 0) return;
    _meteorTimer -= dt;
    if (_meteorTimer <= 0) {
      _spawnMeteor();
      _meteorTimer = minI + _rng.nextDouble() * (maxI - minI);
    }
    for (final m in _meteors) {
      m.life += dt;
    }
    _meteors.removeWhere((m) => m.isDead);
  }

  void _updateComets(double dt) {
    for (final c in _comets) {
      c.life += dt;
      c.position.add(c.velocity * dt);
    }
    _comets.removeWhere((c) => c.isDead);

    if (_spec.cometMax <= 0) return;
    _cometTimer -= dt;
    if (_cometTimer <= 0 && _comets.length < _spec.cometMax) {
      _spawnComet();
      final (minI, maxI) = _spec.cometInterval;
      _cometTimer = minI + _rng.nextDouble() * (maxI - minI);
    }
  }

  void _updateSupernovae(double dt) {
    for (final s in _supernovae) {
      s.life += dt;
    }
    _supernovae.removeWhere((s) => s.isDead);

    if (_supernovaTimer == double.infinity) return;
    _supernovaTimer -= dt;
    if (_supernovaTimer <= 0) {
      _spawnSupernova();
      final (minI, maxI) = _spec.supernovaInterval;
      _supernovaTimer = minI + _rng.nextDouble() * (maxI - minI);
    }
  }

  void _spawnMeteor() {
    final visible = _visibleRect();
    if (visible.isEmpty) return;
    final start = Vector2(
      visible.left + _rng.nextDouble() * visible.width,
      visible.top + _rng.nextDouble() * visible.height * 0.6,
    );
    final angle = 0.3 + _rng.nextDouble() * 0.5;
    final len = 200.0 + _rng.nextDouble() * 280;
    final flip = _rng.nextBool() ? 1.0 : -1.0;
    _meteors.add(
      _DecorMeteor(
        start: start,
        end: start +
            Vector2(math.cos(angle) * len * flip, math.sin(angle) * len),
        maxLife: 0.5 + _rng.nextDouble() * 0.35,
        color: _rng.nextDouble() < 0.25
            ? const Color(0xFFCCE8FF)
            : const Color(0xFFFFF4E0),
      ),
    );
  }

  void _spawnComet() {
    final visible = _visibleRect();
    if (visible.isEmpty) return;

    // Enter from one edge, drift across the view over tens of seconds.
    final edge = _rng.nextInt(4);
    const margin = 260.0;
    final target = Offset(
      visible.left + visible.width * (0.25 + _rng.nextDouble() * 0.5),
      visible.top + visible.height * (0.25 + _rng.nextDouble() * 0.5),
    );
    final start = switch (edge) {
      0 => Vector2(visible.left - margin,
          visible.top + _rng.nextDouble() * visible.height),
      1 => Vector2(visible.right + margin,
          visible.top + _rng.nextDouble() * visible.height),
      2 => Vector2(visible.left + _rng.nextDouble() * visible.width,
          visible.top - margin),
      _ => Vector2(visible.left + _rng.nextDouble() * visible.width,
          visible.bottom + margin),
    };
    final dir = (Vector2(target.dx, target.dy) - start)..normalize();
    if (dir.length2 < 0.5) return;
    final speed = 46.0 + _rng.nextDouble() * 50;
    final crossing = (visible.longestSide + margin * 2) /
        speed *
        (1.1 + _rng.nextDouble() * 0.4);

    final headRadius = 2.2 + _rng.nextDouble() * 1.6;
    final curl = (_rng.nextDouble() - 0.5) * 0.5;
    final ionLength = 190.0 + headRadius * 40;

    // Tail paints cached in comet-local frame (+X = travel direction).
    final ionEnd = Offset(-ionLength, curl * 14);
    final ionPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        ionEnd,
        [
          const Color(0xFF8CD4FF).withValues(alpha: 0.4),
          const Color(0xFF5A9CE8).withValues(alpha: 0.14),
          Colors.transparent,
        ],
        const [0.0, 0.45, 1.0],
      )
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final comaR = headRadius * 4.2;
    final comaPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        comaR,
        [
          const Color(0xFFCFEAFF).withValues(alpha: 0.3),
          const Color(0xFFCFEAFF).withValues(alpha: 0.1),
          Colors.transparent,
        ],
        const [0.0, 0.45, 1.0],
      );

    _comets.add(
      _Comet(
        position: start,
        velocity: dir * speed,
        maxLife: crossing.clamp(20.0, 70.0),
        curl: curl,
        headRadius: headRadius,
        angle: math.atan2(dir.y, dir.x),
        ionLength: ionLength,
        ionPaint: ionPaint,
        comaPaint: comaPaint,
      ),
    );
  }

  void _spawnSupernova() {
    final visible = _visibleRect();
    if (visible.isEmpty) return;
    // Off-center so the blast never covers the player's hole directly.
    final dx =
        0.5 + (0.2 + _rng.nextDouble() * 0.28) * (_rng.nextBool() ? 1 : -1);
    final dy =
        0.5 + (0.2 + _rng.nextDouble() * 0.28) * (_rng.nextBool() ? 1 : -1);
    _supernovae.add(
      _Supernova(
        position: Vector2(
          visible.left + visible.width * dx,
          visible.top + visible.height * dy,
        ),
        maxLife: 6.0 + _rng.nextDouble() * 2.5,
      ),
    );
  }

  // ── Shared helpers ──────────────────────────────────────────────────────

  /// Oyuncu merkezli görünür alan — web'de [visibleWorldRect] sarsıntı/zoom
  /// ile uyuşmayınca yıldızlar yanlışlıkla ekran dışı sayılıyordu.
  Rect _visibleRect() {
    final rect = ViewportCull.visibleWorldRect(game);
    if (rect.width > 0 && rect.height > 0) {
      return rect;
    }
    return Rect.zero;
  }

  bool get _dragging => game.isHoleDragActive;

  bool get _useBlur => CanvasEffects.blurEnabled && !_dragging;

  /// While the local player is locked in a merger on a lite-budget GPU
  /// (web / phone), skip decorative extras — the merger VFX own the frame.
  bool get _mergerBudgetCrunch =>
      CanvasEffects.mobileLiteMode &&
      game.isReady &&
      game.gravityPhysics.isMergerActive;

  // ── Color wash (void fill is VoidCameraBackdrop) ───────────────────────

  void _drawColorWash(Canvas canvas, Rect visible) {
    final expanded = visible.inflate(120);
    final center = expanded.center;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(expanded.width, expanded.height);
    canvas.drawRect(
      const Rect.fromLTWH(-0.5, -0.5, 1, 1),
      _washPaint,
    );
    canvas.restore();
  }

  // ── Milky Way band ──────────────────────────────────────────────────────

  void _drawMilkyWay(Canvas canvas, Rect visible) {
    if (_bandPatches.isEmpty) return;
    final expanded = visible.inflate(600);

    final corePaint = _coreGlowPaint;
    if (corePaint != null) {
      final coreBounds = Rect.fromCircle(
        center: _bandCenter,
        radius: _coreGlowRadius,
      );
      if (expanded.overlaps(coreBounds)) {
        canvas.drawCircle(_bandCenter, _coreGlowRadius, corePaint);
      }
    }

    for (final patch in _bandPatches) {
      final bound = patch.radius * patch.stretch;
      if (!expanded.overlaps(
        Rect.fromCircle(center: patch.center, radius: bound),
      )) {
        continue;
      }

      canvas.save();
      canvas.translate(patch.center.dx, patch.center.dy);
      canvas.rotate(patch.rotation);
      canvas.scale(patch.stretch, 1.0);
      canvas.drawCircle(Offset.zero, patch.radius, patch.paint);
      canvas.restore();
    }
  }

  void _drawBandStars(Canvas canvas, Rect visible) {
    if (_bandStars.isEmpty) return;
    final expanded = visible.inflate(60);
    final paint = _bandStarPaint;
    for (final star in _bandStars) {
      if (!expanded.contains(star.position)) continue;
      paint.color = star.color.withValues(alpha: star.alpha);
      canvas.drawCircle(star.position, star.radius, paint);
    }
  }

  // ── Nebulae ─────────────────────────────────────────────────────────────

  void _drawNebulae(
    Canvas canvas,
    Rect visible, {
    bool frozen = false,
  }) {
    if (_nebulae.isEmpty) return;
    final expanded = visible.inflate(450);

    for (final nebula in _nebulae) {
      final center = Offset(nebula.position.x, nebula.position.y);
      if (!expanded.overlaps(
        Rect.fromCircle(center: center, radius: nebula.boundRadius),
      )) {
        continue;
      }

      // Bake path freezes drift — tiles are static textures.
      final pulse = frozen
          ? 1.0
          : 0.9 + math.sin(_elapsed * nebula.driftSpeed + nebula.phase) * 0.1;
      final rotation = frozen
          ? nebula.rotation
          : nebula.rotation + _elapsed * nebula.driftSpeed * 0.015;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation);
      canvas.scale(nebula.stretchX * pulse, nebula.stretchY * pulse);

      for (final blob in nebula.blobs) {
        blob.paint.maskFilter = (!frozen && !blob.dark && _useBlur)
            ? CanvasEffects.blur(blob.radius * 0.08)
            : null;
        canvas.drawCircle(blob.offset, blob.radius, blob.paint);
      }
      canvas.restore();
    }
  }

  // ── Galaxies ────────────────────────────────────────────────────────────

  void _drawGalaxies(Canvas canvas, Rect visible) {
    if (_galaxies.isEmpty) return;
    final expanded = visible.inflate(250);

    for (final galaxy in _galaxies) {
      final center = Offset(galaxy.position.x, galaxy.position.y);
      if (!expanded.overlaps(
        Rect.fromCircle(center: center, radius: galaxy.radius * 1.4),
      )) {
        continue;
      }

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(galaxy.tilt);
      canvas.scale(1.0, galaxy.aspect);

      // Tilted disk.
      canvas.drawCircle(Offset.zero, galaxy.radius, galaxy.diskPaint);

      final armPaint = galaxy.armPaint;
      if (armPaint != null) {
        // Two faint trailing arms hinted with arc strokes.
        final armRect =
            Rect.fromCircle(center: Offset.zero, radius: galaxy.radius * 0.62);
        canvas.drawArc(armRect, 0.2, 2.4, false, armPaint);
        canvas.drawArc(armRect, math.pi + 0.2, 2.4, false, armPaint);
      }
      canvas.restore();

      // Bright compact core (drawn unscaled so it stays round).
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.drawCircle(Offset.zero, galaxy.radius * 0.1, galaxy.corePaint);
      canvas.restore();
    }
  }

  // ── Twinkling stars + lensing ───────────────────────────────────────────

  void _drawStars(Canvas canvas, Rect visible) {
    final expanded = visible.inflate(_dragging ? 140 : 100);
    final worldSize = game.worldSize;
    // Soft fade band near the arena rim — avoids hard pop as stars clip.
    const edgeFade = 90.0;

    final player = game.player;
    final lensingActive = StarLensing.enabledForLocalPlayer(
      playerAlive: !player.isEliminated,
      dragging: _dragging,
    );
    final holeCenter = lensingActive
        ? Offset(player.position.x, player.position.y)
        : null;
    final lensRadius = lensingActive
        ? StarLensing.lensExtentRadius(player.radius) + 80
        : 0.0;
    final zoomedOut = game.camera.viewfinder.zoom < 0.32;
    final lensHighDetail = lensingActive && !zoomedOut;
    final skipSparkle = zoomedOut || CanvasEffects.mobileLiteMode;
    final sparkleEnabled =
        roomType == RoomType.elite || roomType == RoomType.unique;

    // Include hole-near cells so lensed stars can enter the viewport.
    var queryRect = expanded;
    if (lensingActive && holeCenter != null) {
      queryRect = queryRect.expandToInclude(
        Rect.fromCircle(center: holeCenter, radius: lensRadius),
      );
    }

    double edgeAlpha(double x, double y) {
      if (x < 0 || y < 0 || x > worldSize || y > worldSize) return 0;
      final d = math.min(
        math.min(x, y),
        math.min(worldSize - x, worldSize - y),
      );
      if (d >= edgeFade) return 1;
      final t = (d / edgeFade).clamp(0.0, 1.0);
      return t * t * (3.0 - 2.0 * t);
    }

    for (final layer in _liveLayers) {
      layer.grid.forEachInRect(queryRect, (star) {
        final twinkle = star.twinkleFactor(_elapsed);
        var drawX = star.position.x;
        var drawY = star.position.y;
        var alpha = (star.alpha * twinkle).clamp(0.0, 1.0);
        var drawRadius = star.radius;
        if (alpha < 0.02) return;

        final rimFade = edgeAlpha(drawX, drawY);
        if (rimFade <= 0.02) return;
        alpha *= rimFade;

        Offset? echo;
        var echoAlpha = 0.0;

        if (lensingActive && holeCenter != null) {
          final starOffset = Offset(drawX, drawY);
          if ((starOffset - holeCenter).distance <= lensRadius) {
            final lensed = StarLensing.compute(
              star: starOffset,
              holeCenter: holeCenter,
              gameRadius: player.radius,
              highDetail: lensHighDetail,
            );
            if (lensed.inShadow) return;
            drawX = lensed.position.dx;
            drawY = lensed.position.dy;
            alpha = (alpha * lensed.alpha).clamp(0.0, 1.0);
            drawRadius = star.radius * lensed.radiusScale;
            echo = lensed.echo;
            echoAlpha = lensed.echoAlpha;
          }
        }

        if (!expanded.contains(Offset(drawX, drawY))) return;

        _drawSingleStar(
          canvas: canvas,
          center: Offset(drawX, drawY),
          radius: drawRadius,
          color: star.color,
          alpha: alpha,
          twinkle: twinkle,
          originalRadius: star.radius,
          sparkle: sparkleEnabled && !skipSparkle,
        );

        if (echo != null && echoAlpha > 0.03 && expanded.contains(echo)) {
          _drawSingleStar(
            canvas: canvas,
            center: echo,
            radius: drawRadius * 0.72,
            color: star.color,
            alpha: alpha * echoAlpha,
            twinkle: twinkle,
            originalRadius: star.radius,
            sparkle: false,
          );
        }
      });
    }
  }

  void _drawSingleStar({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required Color color,
    required double alpha,
    required double twinkle,
    required double originalRadius,
    bool sparkle = true,
  }) {
    final useStarBlur = _useBlur && radius > 1.2;
    final paint = _starPaint
      ..color = color.withValues(alpha: alpha)
      ..maskFilter = useStarBlur ? CanvasEffects.blur(radius * 0.35) : null;

    canvas.drawCircle(center, radius, paint);

    if (_useBlur &&
        radius > (CanvasEffects.mobileLiteMode ? 1.9 : 1.35) &&
        twinkle > 0.45) {
      final glowMul = radius > 2.0 ? 2.4 : 1.8;
      canvas.drawCircle(
        center,
        radius * glowMul,
        _starGlowPaint
          ..color = color.withValues(alpha: alpha * 0.14)
          ..maskFilter = CanvasEffects.blur(radius * 0.85),
      );
    }

    if (sparkle && originalRadius > 1.45 && twinkle > 0.55 && alpha > 0.35) {
      _drawStarSparkle(canvas, center, radius, color, alpha);
    }
  }

  void _drawStarSparkle(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double alpha,
  ) {
    final arm = radius * 2.6;
    final sparklePaint = _sparklePaint
      ..color = color.withValues(alpha: alpha * 0.32);

    canvas.drawLine(
      Offset(center.dx - arm, center.dy),
      Offset(center.dx + arm, center.dy),
      sparklePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - arm),
      Offset(center.dx, center.dy + arm),
      sparklePaint,
    );
  }

  // ── Pulsars ─────────────────────────────────────────────────────────────

  void _drawPulsars(Canvas canvas, Rect visible) {
    if (_pulsars.isEmpty) return;
    final expanded = visible.inflate(80);

    for (final pulsar in _pulsars) {
      final center = Offset(pulsar.position.x, pulsar.position.y);
      if (!expanded.contains(center)) continue;

      final t = (_elapsed / pulsar.period + pulsar.phase) % 1.0;
      final s = 0.5 + 0.5 * math.sin(t * math.pi * 2);
      final flash = math.pow(s, 14).toDouble();

      // Faint always-on core so the pulsar is findable between flashes.
      canvas.drawCircle(
        center,
        1.3,
        Paint()..color = const Color(0xFFCCE4FF).withValues(alpha: 0.45),
      );

      if (flash < 0.03) continue;

      // Cached gradient scaled to the flash radius; paint color alpha
      // modulates the shader so no gradient is rebuilt per frame.
      final glowR = 3.0 + flash * 9;
      final k = glowR / _Pulsar.glowBaseRadius;
      pulsar.glowPaint.color = Colors.white.withValues(alpha: flash);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(k, k);
      canvas.drawCircle(Offset.zero, _Pulsar.glowBaseRadius, pulsar.glowPaint);
      canvas.restore();

      // Beacon spikes — the lighthouse sweep signature.
      final arm = 10 + flash * 26;
      final spikePaint = Paint()
        ..color = const Color(0xFFD8ECFF).withValues(alpha: 0.5 * flash)
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(center.dx - arm, center.dy),
        Offset(center.dx + arm, center.dy),
        spikePaint,
      );
      canvas.drawLine(
        Offset(center.dx, center.dy - arm),
        Offset(center.dx, center.dy + arm),
        spikePaint,
      );
    }
  }

  // ── Supernovae ──────────────────────────────────────────────────────────

  void _drawSupernovae(Canvas canvas, Rect visible) {
    if (_supernovae.isEmpty) return;
    final expanded = visible.inflate(500);

    for (final nova in _supernovae) {
      final center = Offset(nova.position.x, nova.position.y);
      if (!expanded.contains(center)) continue;

      final p = nova.progress;
      const flashEnd = 0.1;

      if (p < flashEnd) {
        // Detonation flash — rapid white bloom.
        final i = p / flashEnd;
        final r = 24 + i * 60;
        canvas.drawCircle(
          center,
          r,
          Paint()
            ..shader = ui.Gradient.radial(
              center,
              r,
              [
                Colors.white.withValues(alpha: 0.85 * i),
                const Color(0xFFFFE0B0).withValues(alpha: 0.4 * i),
                Colors.transparent,
              ],
              const [0.0, 0.35, 1.0],
            ),
        );
        continue;
      }

      // Afterglow decays while the ejecta shell expands.
      final q = (p - flashEnd) / (1 - flashEnd);
      final fade = math.pow(1 - q, 1.7).toDouble();
      final emberColor = Color.lerp(
        Colors.white,
        const Color(0xFFFF9860),
        (q * 1.6).clamp(0.0, 1.0),
      )!;

      final glowR = 70.0 * (1 - q * 0.6);
      canvas.drawCircle(
        center,
        glowR,
        Paint()
          ..shader = ui.Gradient.radial(
            center,
            glowR,
            [
              emberColor.withValues(alpha: 0.55 * fade),
              emberColor.withValues(alpha: 0.18 * fade),
              Colors.transparent,
            ],
            const [0.0, 0.4, 1.0],
          ),
      );

      // Expanding remnant shell.
      final shellR = 30 + q * 420;
      canvas.drawCircle(
        center,
        shellR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (3.2 * (1 - q)).clamp(0.6, 3.2)
          ..color = const Color(0xFF9CD8FF).withValues(alpha: 0.3 * fade),
      );
      canvas.drawCircle(
        center,
        shellR * 0.82,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = emberColor.withValues(alpha: 0.16 * fade),
      );
    }
  }

  // ── Comets ──────────────────────────────────────────────────────────────

  void _drawComets(Canvas canvas, Rect visible) {
    if (_comets.isEmpty) return;
    final expanded = visible.inflate(450);
    final lite = CanvasEffects.mobileLiteMode;

    for (final comet in _comets) {
      final head = Offset(comet.position.x, comet.position.y);
      if (!expanded.contains(head)) continue;

      // Fade in/out at the ends of the crossing.
      final lifeT = comet.life / comet.maxLife;
      final fade = (math.min(lifeT, 1 - lifeT) * 8).clamp(0.0, 1.0);
      if (fade <= 0.01) continue;

      // All tail geometry lives in the comet-local frame (+X = travel dir),
      // so the cached gradients need no per-frame rebuild; the paint color's
      // alpha modulates the shader for the fade envelope.
      canvas.save();
      canvas.translate(head.dx, head.dy);
      canvas.rotate(comet.angle);

      // Ion tail — straight, thin, blue.
      comet.ionPaint.color = Colors.white.withValues(alpha: fade);
      canvas.drawLine(
        Offset.zero,
        Offset(-comet.ionLength, comet.curl * 14),
        comet.ionPaint,
      );

      // Dust tail — curved fan of fading puffs (plain colors, cheap).
      final segments = lite ? 8 : 14;
      const spacing = 13.0;
      final puffPaint = Paint();
      for (var i = 1; i <= segments; i++) {
        final t = i / segments;
        final puffR = comet.headRadius * (0.8 + t * 2.6);
        final alpha = 0.2 * (1 - t) * (1 - t) * fade;
        if (alpha < 0.008) continue;
        puffPaint.color = const Color(0xFFEADFC8).withValues(alpha: alpha);
        canvas.drawCircle(
          Offset(-i * spacing, comet.curl * i * i * 0.55),
          puffR,
          puffPaint,
        );
      }

      // Coma + nucleus.
      comet.comaPaint.color = Colors.white.withValues(alpha: fade);
      canvas.drawCircle(Offset.zero, comet.headRadius * 4.2, comet.comaPaint);
      canvas.drawCircle(
        Offset.zero,
        comet.headRadius,
        Paint()..color = Colors.white.withValues(alpha: 0.95 * fade),
      );

      canvas.restore();
    }
  }

  // ── Meteor streaks ──────────────────────────────────────────────────────

  Vector2 _lerp(Vector2 a, Vector2 b, double t) {
    return Vector2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
  }

  void _drawMeteors(Canvas canvas, Rect visible) {
    if (_meteors.isEmpty) return;
    final expanded = visible.inflate(120);

    for (final meteor in _meteors) {
      final head = _lerp(meteor.start, meteor.end, meteor.progress);
      final headOffset = Offset(head.x, head.y);
      if (!expanded.contains(headOffset)) continue;

      final tailProgress = (meteor.progress - 0.22).clamp(0.0, 1.0);
      final tail = _lerp(meteor.start, meteor.end, tailProgress);
      final tailOffset = Offset(tail.x, tail.y);
      final vis = (1 - meteor.progress).clamp(0.0, 1.0);

      canvas.drawLine(
        tailOffset,
        headOffset,
        Paint()
          ..shader = ui.Gradient.linear(
            tailOffset,
            headOffset,
            [
              Colors.transparent,
              meteor.color.withValues(alpha: 0.75 * vis),
            ],
          )
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        headOffset,
        1.9,
        Paint()..color = Colors.white.withValues(alpha: 0.9 * vis),
      );
    }
  }

  // ── Render ──────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final visible = _visibleRect();
    // Viewport-relative wash stays live (cheap); world scenery is tiled on bake.
    _drawColorWash(canvas, visible);

    final baker = _tileBaker;
    if (_useTileBake && baker != null) {
      baker.draw(canvas, visible);
    } else {
      _drawMilkyWay(canvas, visible);
      _drawNebulae(canvas, visible);
      _drawGalaxies(canvas, visible);
      _drawBandStars(canvas, visible);
    }

    _drawStars(canvas, visible);

    // Decorative extras pause while merger VFX peak on lite GPUs.
    if (_mergerBudgetCrunch) return;
    _drawPulsars(canvas, visible);
    _drawSupernovae(canvas, visible);
    _drawComets(canvas, visible);
    _drawMeteors(canvas, visible);
  }
}
