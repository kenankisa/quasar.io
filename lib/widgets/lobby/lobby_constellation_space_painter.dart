import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../game/room_type.dart';
import '../../utils/scientific_star_field.dart';
import 'lobby_constellation_metrics.dart';

/// Deep-space starfield for the lobby play area.
class LobbyConstellationSpacePainter extends CustomPainter {
  LobbyConstellationSpacePainter({
    required this.time,
    this.portalCenters = const [],
    this.richness = 1,
    this.isCompact = false,
  });

  final double time;
  final List<Offset> portalCenters;
  final double richness;
  final bool isCompact;

  late final List<ScientificStar> _tinyStars = ScientificStarField.buildTinyField(
    seed: 314_159,
    count: (220 + richness * 160).round(),
  );
  late final List<ScientificStar> _dimStars = ScientificStarField.buildField(
    seed: 42_001,
    count: (72 + richness * 52).round(),
  );
  late final List<ScientificStar> _brightStars = ScientificStarField.buildField(
    seed: 123_456,
    count: (3 + richness * 2).round(),
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final rect = Offset.zero & size;
    final drift = time * math.pi * 2;

    canvas.drawRect(rect, Paint()..color = const Color(0xFF000000));
    _paintDepthGradient(canvas, rect);
    _paintTinyWhiteStars(canvas, size, drift);
    _paintStarLayer(canvas, size, _dimStars, drift, 0.95, 0.58);
    _paintStarLayer(canvas, size, _brightStars, drift, 1.1, 0.68);
    final wells = portalCenters.isNotEmpty
        ? portalCenters
        : _anchorPortalCenters(size);
    if (wells.isNotEmpty) {
      _paintPortalWells(canvas, size, wells);
    }
    _paintEdgeVignette(canvas, rect);
  }

  /// Softer star density over portal labels and wormhole gates.
  double _readabilityAttenuation(double nx, double ny) {
    var factor = 1.0;

    final dx = (nx - 0.5) / 0.24;
    final dy = (ny - 0.76) / 0.15;
    final hardcoreDist2 = dx * dx + dy * dy;
    if (hardcoreDist2 < 1) {
      factor = math.min(factor, 0.15 + hardcoreDist2 * 0.85);
    }

    factor = math.min(factor, _portalAttenuation(nx, ny));
    return factor;
  }

  List<Offset> _anchorPortalCenters(Size size) {
    return LobbyConstellationMetrics.anchors.map((anchor) {
      final ay = isCompact && anchor.compactY != null
          ? anchor.compactY!
          : anchor.y;
      return Offset(anchor.x * size.width, ay * size.height);
    }).toList();
  }

  /// Push stars away from wormhole portals so gates read clearly.
  double _portalAttenuation(double nx, double ny) {
    var factor = 1.0;
    for (final anchor in LobbyConstellationMetrics.anchors) {
      final ax = anchor.x;
      final ay = isCompact && anchor.compactY != null
          ? anchor.compactY!
          : anchor.y;
      final radiusX = anchor.roomType == RoomType.hardcore ? 0.16 : 0.12;
      final radiusY = anchor.roomType == RoomType.hardcore ? 0.14 : 0.11;
      final dx = (nx - ax) / radiusX;
      final dy = (ny - ay) / radiusY;
      final dist2 = dx * dx + dy * dy;
      if (dist2 < 1) {
        factor = math.min(factor, 0.04 + dist2 * 0.96);
      }
    }
    return factor;
  }

  void _paintDepthGradient(Canvas canvas, Rect rect) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.08),
          radius: 0.92,
          colors: [
            const Color(0xFF121C2C).withValues(alpha: 0.28),
            const Color(0xFF0A1018).withValues(alpha: 0.1),
            Colors.transparent,
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(rect),
    );
  }

  double _hash2(double x, double y) {
    final v = math.sin(x * 127.1 + y * 311.7) * 43758.5453;
    return v - v.floor();
  }

  bool _starTwinkles(double x, double y) => _hash2(x, y) < 0.1;

  double _twinkleFactor(double x, double y, double drift) {
    final phase = x * 41.2 + y * 29.7;
    final speed = 0.45 + _hash2(y, x) * 1.1;
    final wave = math.sin(drift * speed + phase);
    final pulse = (wave * 0.5 + 0.5);
    return 0.38 + pulse * 0.62;
  }

  void _paintTinyWhiteStars(Canvas canvas, Size size, double drift) {
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final star in _tinyStars) {
      final x = star.x * size.width;
      final y = star.y * size.height;
      var alpha = (0.2 + star.alpha * 0.18).clamp(0.16, 0.42);
      alpha *= _readabilityAttenuation(star.x, star.y);
      if (alpha < 0.06) continue;
      if (_starTwinkles(star.x, star.y)) {
        alpha *= _twinkleFactor(star.x, star.y, drift);
      }
      final radius = math.max(0.45, star.radius * 0.62);

      fill.color = Colors.white.withValues(alpha: alpha.clamp(0.08, 0.45));
      canvas.drawCircle(Offset(x, y), radius, fill);
    }
  }

  void _paintStarLayer(
    Canvas canvas,
    Size size,
    List<ScientificStar> stars,
    double drift,
    double sizeScale,
    double brightness,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    for (final star in stars) {
      final px = math.sin(drift * 0.35 + star.x * 12) * 0.006;
      final py = math.cos(drift * 0.28 + star.y * 9) * 0.006;
      final x = (star.x + px) * size.width;
      final y = (star.y + py) * size.height;
      var alpha = (star.alpha * brightness * 0.42).clamp(0.18, 0.58);
      alpha *= _readabilityAttenuation(star.x, star.y);
      if (alpha < 0.06) continue;
      if (_starTwinkles(star.x, star.y) || star.diffractionSpikes) {
        alpha *= _twinkleFactor(star.x, star.y, drift);
      }
      final radius = math.max(0.65, star.radius * sizeScale);
      final center = Offset(x, y);

      paint.color = star.color.withValues(alpha: alpha.clamp(0.1, 0.62));
      canvas.drawCircle(center, radius, paint);

      if (star.diffractionSpikes && star.alpha > 0.88 && alpha > 0.35) {
        _paintSpikes(canvas, center, radius, star.color, alpha);
      }
    }
  }

  void _paintSpikes(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double alpha,
  ) {
    if (radius < 1.2) return;
    final spike = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.55
      ..isAntiAlias = true;
    final len = radius * 3.6;
    final a = alpha * 0.35;

    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final end = center + Offset(math.cos(angle) * len, math.sin(angle) * len);
      spike.shader = ui.Gradient.linear(
        center,
        end,
        [
          color.withValues(alpha: a),
          color.withValues(alpha: a * 0.25),
          Colors.transparent,
        ],
        const [0.0, 0.4, 1.0],
      );
      canvas.drawLine(center, end, spike);
    }
  }

  void _paintPortalWells(Canvas canvas, Size size, List<Offset> centers) {
    final base = math.min(size.width, size.height);
    for (final c in centers) {
      final wellRadius = base * 0.15;
      canvas.drawCircle(
        c,
        wellRadius,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            wellRadius,
            [
              const Color(0xFF000000).withValues(alpha: 0.34),
              const Color(0xFF000000).withValues(alpha: 0.18),
              const Color(0xFF304060).withValues(alpha: 0.04),
              Colors.transparent,
            ],
            const [0.0, 0.42, 0.72, 1.0],
          ),
      );
    }
  }

  void _paintEdgeVignette(Canvas canvas, Rect rect) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.02),
          radius: 1.1,
          colors: [
            Colors.transparent,
            Colors.transparent,
            const Color(0xFF000000).withValues(alpha: 0.18),
            const Color(0xFF000000).withValues(alpha: 0.42),
          ],
          stops: const [0.55, 0.8, 0.92, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant LobbyConstellationSpacePainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.richness != richness ||
        oldDelegate.isCompact != isCompact ||
        !_sameCenters(oldDelegate.portalCenters, portalCenters);
  }

  bool _sameCenters(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
