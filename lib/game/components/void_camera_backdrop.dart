import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config/universe_palette.dart';
import '../orbit_game.dart';
import '../room_type.dart';

/// Screen-space void fill behind the world — stays visible even if starfield
/// culls. Colors come from [UniversePalette]; starfield only adds a light wash.
class VoidCameraBackdrop extends Component with HasGameReference<OrbitGame> {
  VoidCameraBackdrop({required this.roomType});

  final RoomType roomType;

  Size? _cachedSize;
  Paint? _voidPaint;
  Paint? _vignettePaint;

  void _ensurePaints(Size size) {
    if (_cachedSize == size && _voidPaint != null && _vignettePaint != null) {
      return;
    }
    _cachedSize = size;
    final rect = Offset.zero & size;
    final colors = UniversePalette.backdropColors(roomType);

    _voidPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.12),
        radius: 1.2,
        colors: colors,
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);

    _vignettePaint = Paint()
      ..shader = RadialGradient(
        radius: 1.35,
        colors: [
          Colors.transparent,
          Colors.transparent,
          Colors.black.withValues(
            alpha: UniversePalette.vignetteAlpha(roomType),
          ),
        ],
        stops: const [0.0, 0.62, 1.0],
      ).createShader(rect);
  }

  @override
  void render(Canvas canvas) {
    final size = game.camera.viewport.virtualSize;
    if (size.x <= 0 || size.y <= 0) return;

    final logical = Size(size.x, size.y);
    _ensurePaints(logical);
    final rect = Rect.fromLTWH(0, 0, logical.width, logical.height);
    canvas.drawRect(rect, _voidPaint!);
    canvas.drawRect(rect, _vignettePaint!);
  }
}
