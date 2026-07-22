import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quasar_io/game/utils/black_hole_renderer.dart';
import 'package:quasar_io/game/utils/black_hole_shader_renderer.dart';
import 'package:quasar_io/game/utils/black_hole_shader_service.dart';
import 'package:quasar_io/game/utils/canvas_effects.dart';

double _lumaAt(Uint8List bytes, int width, int x, int y) {
  final i = (y * width + x) * 4;
  final r = bytes[i];
  final g = bytes[i + 1];
  final b = bytes[i + 2];
  return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
}

Future<Uint8List> _renderToRgba({
  required void Function(Canvas canvas) paintHole,
}) async {
  const canvasSize = 512;
  final center = canvasSize ~/ 2;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 512, 512),
    Paint()..color = const Color(0xFF050510),
  );
  canvas.save();
  canvas.translate(center.toDouble(), center.toDouble());
  paintHole(canvas);
  canvas.restore();

  final image = await recorder.endRecording().toImage(canvasSize, canvasSize);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  expect(data, isNotNull);
  return data!.buffer.asUint8List();
}

void _configureShader(
  ui.FragmentShader shader, {
  required double side,
  required double gameRadius,
  required double rs,
  required double diskR,
}) {
  shader.setFloat(0, side);
  shader.setFloat(1, side);
  shader.setFloat(2, rs);
  shader.setFloat(3, BlackHoleRenderer.shadowBoundaryRadius(gameRadius));
  shader.setFloat(4, diskR);
  shader.setFloat(5, 0.4);
  shader.setFloat(6, 1.2);
  shader.setFloat(7, 1.0);
  shader.setFloat(8, 0);
  shader.setFloat(21, 1.1);
  shader.setFloat(22, 2);
  shader.setFloat(23, 0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await BlackHoleShaderService.preload();
  });

  test('GPU shader loads on native runner', () {
    expect(BlackHoleShaderService.isReady, isTrue);
    expect(CanvasEffects.shaderBlackHoleEnabled, isTrue);
    expect(kIsWeb, isFalse);
  });

  test('BlackHoleShaderRenderer draws visible symmetric hole', () async {
    const gameRadius = 25.0;
    final rs = BlackHoleRenderer.visualCoreRadius(gameRadius);
    final diskR = BlackHoleRenderer.visualDiskRadius(gameRadius);
    final palette = BlackHoleRenderer.plasmaPalette(skin: 'pulsar');

    final plain = await _renderToRgba(paintHole: (_) {});
    final bytes = await _renderToRgba(
      paintHole: (canvas) {
        BlackHoleShaderRenderer.beginFrame();
        expect(
          BlackHoleShaderRenderer.paint(
            canvas: canvas,
            gameRadius: gameRadius,
            rs: rs,
            diskR: diskR,
            spin: 0.4,
            boostMul: 1.0,
            intensity: 1.2,
            swallowCharge: 0,
            hot: palette.hot,
            cool: palette.cool,
            lod: 2,
            time: 1.1,
            isLocal: true,
          ),
          isTrue,
        );
      },
    );

    const center = 256;
    // Photon ring — brightest feature in the reference look (center itself is
    // the pure-black event horizon, so sample the rim instead).
    final ringX =
        center + BlackHoleRenderer.shadowBoundaryRadius(gameRadius).round();
    final bgLuma = _lumaAt(plain, 512, ringX, center);
    final ringLuma = _lumaAt(bytes, 512, ringX, center);

    expect(
      (ringLuma - bgLuma).abs(),
      greaterThan(0.25),
      reason: 'Shader must visibly change the framebuffer',
    );

    // Event horizon must stay near-black (reference art: solid void center).
    final centerLuma = _lumaAt(bytes, 512, center, center);
    expect(centerLuma, lessThan(0.3));

    // Photon-ring samples in all 4 directions — the ring circles the whole
    // shadow, so every direction must be lit (guards the quarter-disc bug).
    // Doppler beaming makes sides unequal by design, so only require that
    // no direction stays at background level.
    final shadowPx =
        BlackHoleRenderer.shadowBoundaryRadius(gameRadius).round();
    final ring = [
      _lumaAt(bytes, 512, center + shadowPx, center),
      _lumaAt(bytes, 512, center - shadowPx, center),
      _lumaAt(bytes, 512, center, center + shadowPx),
      _lumaAt(bytes, 512, center, center - shadowPx),
    ];
    final minRing = ring.reduce((a, b) => a < b ? a : b);
    expect(
      minRing,
      greaterThan(bgLuma + 0.1),
      reason: 'Photon ring must be lit in all quadrants: $ring',
    );
  });

  test(
    'LTWH+translate differs from fromCenter on Skia desktop runner',
    () async {
      if (CanvasEffects.isNativeMobile) return;

      const gameRadius = 25.0;
      final side = BlackHoleRenderer.visualExtentRadius(gameRadius) * 2;
      final rs = BlackHoleRenderer.visualCoreRadius(gameRadius);
      final diskR = BlackHoleRenderer.visualDiskRadius(gameRadius);

      final fixed = await _renderToRgba(
        paintHole: (canvas) {
          canvas.save();
          canvas.translate(-side * 0.5, -side * 0.5);
          final shader = BlackHoleShaderService.borrowShader()!;
          _configureShader(
            shader,
            side: side,
            gameRadius: gameRadius,
            rs: rs,
            diskR: diskR,
          );
          canvas.drawRect(
            Rect.fromLTWH(0, 0, side, side),
            Paint()..shader = shader,
          );
          canvas.restore();
        },
      );

      final broken = await _renderToRgba(
        paintHole: (canvas) {
          final shader = BlackHoleShaderService.borrowShader()!;
          _configureShader(
            shader,
            side: side,
            gameRadius: gameRadius,
            rs: rs,
            diskR: diskR,
          );
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: side, height: side),
            Paint()..shader = shader,
          );
        },
      );

      const center = 256;
      final fixedLuma = _lumaAt(fixed, 512, center, center);
      final brokenLuma = _lumaAt(broken, 512, center, center);

      // Skia: fromCenter leaves the framebuffer at background level.
      expect(fixedLuma, greaterThan(0.5));
      expect(brokenLuma, lessThan(0.08));
    },
    skip: 'Skia-only regression — behavior differs on Impeller',
  );

  test(
    'Android/iOS Impeller: fromCenter clips to one quadrant',
    () async {
      final isMobile = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      if (!isMobile) return;

      // Run on a connected phone/emulator only.
      const gameRadius = 25.0;
      final side = BlackHoleRenderer.visualExtentRadius(gameRadius) * 2;
      final rs = BlackHoleRenderer.visualCoreRadius(gameRadius);
      final diskR = BlackHoleRenderer.visualDiskRadius(gameRadius);

      final bytes = await _renderToRgba(
        paintHole: (canvas) {
          final shader = BlackHoleShaderService.borrowShader()!;
          _configureShader(
            shader,
            side: side,
            gameRadius: gameRadius,
            rs: rs,
            diskR: diskR,
          );
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: side, height: side),
            Paint()..shader = shader,
          );
        },
      );

      const center = 256;
      final ring = [
        _lumaAt(bytes, 512, center + 40, center - 40),
        _lumaAt(bytes, 512, center - 40, center - 40),
        _lumaAt(bytes, 512, center + 40, center + 40),
        _lumaAt(bytes, 512, center - 40, center + 40),
      ];
      expect(ring.where((v) => v > 0.12).length, lessThanOrEqualTo(2));
    },
    skip: 'Needs Android/iOS device — Impeller quarter-disc not reproducible on Windows Skia',
  );
}
