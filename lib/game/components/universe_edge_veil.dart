import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config/room_visual_theme.dart';
import '../config/universe_palette.dart';
import '../orbit_game.dart';
import '../room_type.dart';
import '../utils/canvas_effects.dart';
import '../utils/viewport_cull.dart';

/// Stable cosmic arena border — always-readable rim + soft exterior void.
///
/// Avoids heavy pulsing fog and hard corner L-arm cuts that made entities look
/// like they vanished when approaching the map edge.
class UniverseEdgeVeil extends Component with HasGameReference<OrbitGame> {
  UniverseEdgeVeil({required this.roomType});

  final RoomType roomType;

  double _time = 0;

  /// How far the exterior void slab extends past the world bounds.
  static const double _exteriorPad = 140.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Above starfield (-20), below gameplay entities (0).
    priority = -5;
  }

  @override
  void update(double dt) {
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    if (!game.isReady) return;

    final worldSize = game.worldSize;
    final visible = ViewportCull.visibleWorldRect(game);
    if (visible.width <= 0 || visible.height <= 0) return;

    final theme = RoomVisualTheme.forRoom(roomType);
    final voidDeep = UniversePalette.backdropColors(roomType).last;
    final accent = theme.accent;
    final secondary = theme.secondaryAccent;

    final halfExtent = ViewportCull.viewportHalfExtent(game);
    final band = math
        .max(260.0, math.min(worldSize * 0.065, halfExtent * 0.85))
        .clamp(240.0, 440.0);

    final player = game.player;
    final px = player.position.x;
    final py = player.position.y;

    // Soft approach — camera proximity also counts so the rim stays visible
    // when the viewfinder is clamped against the wall.
    final left = math.max(
      _approach(px, band),
      _approach(visible.left, band) * 0.85,
    );
    final right = math.max(
      _approach(worldSize - px, band),
      _approach(worldSize - visible.right, band) * 0.85,
    );
    final top = math.max(
      _approach(py, band),
      _approach(visible.top, band) * 0.85,
    );
    final bottom = math.max(
      _approach(worldSize - py, band),
      _approach(worldSize - visible.bottom, band) * 0.85,
    );

    // Subtle rim shimmer only — never modulates fog opacity.
    final rimPulse = 0.96 + 0.04 * math.sin(_time * 1.6);

    for (final edge in _Edge.values) {
      final strength = switch (edge) {
        _Edge.left => left,
        _Edge.right => right,
        _Edge.top => top,
        _Edge.bottom => bottom,
      };
      _paintEdge(
        canvas,
        edge: edge,
        visible: visible,
        worldSize: worldSize,
        band: band,
        strength: strength,
        voidDeep: voidDeep,
        accent: accent,
        secondary: secondary,
        rimPulse: rimPulse,
      );
    }
  }

  static double _approach(double distanceToEdge, double band) {
    if (distanceToEdge >= band) return 0;
    final t = (1.0 - distanceToEdge / band).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  void _paintEdge(
    Canvas canvas, {
    required _Edge edge,
    required Rect visible,
    required double worldSize,
    required double band,
    required double strength,
    required Color voidDeep,
    required Color accent,
    required Color secondary,
    required double rimPulse,
  }) {
    // Always draw a faint rim when the edge intersects the view, so the arena
    // boundary never "pops in" suddenly.
    final visibleStrength = math.max(strength, 0.14);
    if (!_edgeIntersectsView(edge, visible, worldSize, band)) return;

    final along = _alongSpan(edge, visible, worldSize);
    if (along.$2 - along.$1 < 4) return;

    final lite = CanvasEffects.mobileLiteMode;

    // 1) Exterior void slab — fills the gap past the world so the cut isn't a
    // hard starfield cliff under a soft fog.
    final exterior = switch (edge) {
      _Edge.left => Rect.fromLTRB(
          -_exteriorPad,
          along.$1,
          0,
          along.$2,
        ),
      _Edge.right => Rect.fromLTRB(
          worldSize,
          along.$1,
          worldSize + _exteriorPad,
          along.$2,
        ),
      _Edge.top => Rect.fromLTRB(
          along.$1,
          -_exteriorPad,
          along.$2,
          0,
        ),
      _Edge.bottom => Rect.fromLTRB(
          along.$1,
          worldSize,
          along.$2,
          worldSize + _exteriorPad,
        ),
    };
    canvas.drawRect(
      exterior,
      Paint()..color = voidDeep.withValues(alpha: 0.92),
    );

    // 2) Soft inward fog — capped so gameplay entities stay readable.
    final fogAlpha = 0.10 + 0.32 * visibleStrength;
    final fogRect = switch (edge) {
      _Edge.left => Rect.fromLTRB(0, along.$1, band, along.$2),
      _Edge.right =>
        Rect.fromLTRB(worldSize - band, along.$1, worldSize, along.$2),
      _Edge.top => Rect.fromLTRB(along.$1, 0, along.$2, band),
      _Edge.bottom =>
        Rect.fromLTRB(along.$1, worldSize - band, along.$2, worldSize),
    };

    canvas.drawRect(
      fogRect,
      Paint()
        ..shader = ui.Gradient.linear(
          _gradientStart(fogRect, edge),
          _gradientEnd(fogRect, edge),
          [
            voidDeep.withValues(alpha: fogAlpha),
            voidDeep.withValues(alpha: fogAlpha * 0.45),
            voidDeep.withValues(alpha: fogAlpha * 0.12),
            Colors.transparent,
          ],
          lite ? const [0.0, 0.28, 0.62, 1.0] : const [0.0, 0.22, 0.55, 1.0],
        ),
    );

    // 3) Luminous energy rim just inside the boundary.
    final rimDepth = band * (lite ? 0.22 : 0.28);
    final rimAlpha = (0.22 + 0.48 * visibleStrength) * rimPulse;
    final rimRect = switch (edge) {
      _Edge.left => Rect.fromLTRB(0, fogRect.top, rimDepth, fogRect.bottom),
      _Edge.right => Rect.fromLTRB(
          worldSize - rimDepth,
          fogRect.top,
          worldSize,
          fogRect.bottom,
        ),
      _Edge.top => Rect.fromLTRB(fogRect.left, 0, fogRect.right, rimDepth),
      _Edge.bottom => Rect.fromLTRB(
          fogRect.left,
          worldSize - rimDepth,
          fogRect.right,
          worldSize,
        ),
    };

    final begin = switch (edge) {
      _Edge.left => Alignment.centerLeft,
      _Edge.right => Alignment.centerRight,
      _Edge.top => Alignment.topCenter,
      _Edge.bottom => Alignment.bottomCenter,
    };
    final end = switch (edge) {
      _Edge.left => Alignment.centerRight,
      _Edge.right => Alignment.centerLeft,
      _Edge.top => Alignment.bottomCenter,
      _Edge.bottom => Alignment.topCenter,
    };

    canvas.drawRect(
      rimRect,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = LinearGradient(
          begin: begin,
          end: end,
          colors: [
            accent.withValues(alpha: rimAlpha * 0.9),
            secondary.withValues(alpha: rimAlpha * 0.32),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(rimRect),
    );

    // 4) Clean boundary stroke — professional "end of arena" cue.
    final lineAlpha = (0.28 + 0.5 * visibleStrength) * rimPulse;
    final glowPaint = Paint()
      ..color = accent.withValues(alpha: lineAlpha * 0.35)
      ..strokeWidth = lite ? 5.5 : 7.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final linePaint = Paint()
      ..color = accent.withValues(alpha: lineAlpha)
      ..strokeWidth = lite ? 1.6 : 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final innerPaint = Paint()
      ..color = Colors.white.withValues(alpha: lineAlpha * 0.35)
      ..strokeWidth = lite ? 0.7 : 0.9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final (a, b) = switch (edge) {
      _Edge.left => (Offset(0, along.$1), Offset(0, along.$2)),
      _Edge.right => (
          Offset(worldSize, along.$1),
          Offset(worldSize, along.$2),
        ),
      _Edge.top => (Offset(along.$1, 0), Offset(along.$2, 0)),
      _Edge.bottom => (
          Offset(along.$1, worldSize),
          Offset(along.$2, worldSize),
        ),
    };

    if (!lite) {
      canvas.drawLine(a, b, glowPaint);
    }
    canvas.drawLine(a, b, linePaint);
    canvas.drawLine(a, b, innerPaint);
  }

  static bool _edgeIntersectsView(
    _Edge edge,
    Rect visible,
    double worldSize,
    double band,
  ) {
    final probe = switch (edge) {
      _Edge.left => Rect.fromLTRB(
          -_exteriorPad,
          visible.top - 40,
          band,
          visible.bottom + 40,
        ),
      _Edge.right => Rect.fromLTRB(
          worldSize - band,
          visible.top - 40,
          worldSize + _exteriorPad,
          visible.bottom + 40,
        ),
      _Edge.top => Rect.fromLTRB(
          visible.left - 40,
          -_exteriorPad,
          visible.right + 40,
          band,
        ),
      _Edge.bottom => Rect.fromLTRB(
          visible.left - 40,
          worldSize - band,
          visible.right + 40,
          worldSize + _exteriorPad,
        ),
    };
    return visible.inflate(80).overlaps(probe);
  }

  /// Full visible span along the edge — no hard corner L-arm clipping.
  static (double, double) _alongSpan(
    _Edge edge,
    Rect visible,
    double worldSize,
  ) {
    const pad = 100.0;
    switch (edge) {
      case _Edge.left:
      case _Edge.right:
        return (
          (visible.top - pad).clamp(-_exteriorPad, worldSize + _exteriorPad),
          (visible.bottom + pad)
              .clamp(-_exteriorPad, worldSize + _exteriorPad),
        );
      case _Edge.top:
      case _Edge.bottom:
        return (
          (visible.left - pad).clamp(-_exteriorPad, worldSize + _exteriorPad),
          (visible.right + pad)
              .clamp(-_exteriorPad, worldSize + _exteriorPad),
        );
    }
  }

  static Offset _gradientStart(Rect rect, _Edge edge) => switch (edge) {
        _Edge.left => Offset(rect.left, rect.center.dy),
        _Edge.right => Offset(rect.right, rect.center.dy),
        _Edge.top => Offset(rect.center.dx, rect.top),
        _Edge.bottom => Offset(rect.center.dx, rect.bottom),
      };

  static Offset _gradientEnd(Rect rect, _Edge edge) => switch (edge) {
        _Edge.left => Offset(rect.right, rect.center.dy),
        _Edge.right => Offset(rect.left, rect.center.dy),
        _Edge.top => Offset(rect.center.dx, rect.bottom),
        _Edge.bottom => Offset(rect.center.dx, rect.top),
      };
}

enum _Edge { left, right, top, bottom }
