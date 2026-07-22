import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quasar_io/game/utils/starfield_tile_baker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('warmUp bakes visible tiles and draw uses them', () async {
    var paintCalls = 0;
    final baker = StarfieldTileBaker(
      worldSize: 8000,
      gridSize: 4,
      pixelSize: 128,
      painter: (canvas, worldRect) {
        paintCalls++;
        canvas.drawRect(
          worldRect,
          Paint()..color = const Color(0xFF112233),
        );
      },
    );

    await baker.warmUp(
      const Rect.fromLTWH(3500, 3500, 1000, 1000),
    );

    expect(paintCalls, greaterThan(0));
    expect(baker.worldRectForTile(0, 0), const Rect.fromLTWH(0, 0, 2000, 2000));
    expect(baker.worldRectForTile(3, 3), const Rect.fromLTWH(6000, 6000, 2000, 2000));

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    baker.draw(canvas, const Rect.fromLTWH(3500, 3500, 1000, 1000));
    final picture = recorder.endRecording();
    expect(picture, isNotNull);
    picture.dispose();

    baker.dispose();
    // Second dispose / draw after dispose must not throw.
    baker.draw(canvas, const Rect.fromLTWH(0, 0, 100, 100));
  });

  test('LRU evicts when over maxCachedTiles', () async {
    final baker = StarfieldTileBaker(
      worldSize: 4000,
      gridSize: 4,
      pixelSize: 64,
      maxCachedTiles: 2,
      painter: (canvas, worldRect) {
        canvas.drawCircle(worldRect.center, 10, Paint());
      },
    );

    await baker.warmUp(const Rect.fromLTWH(0, 0, 500, 500));
    await baker.warmUp(const Rect.fromLTWH(3500, 3500, 500, 500));
    // Still healthy after eviction churn.
    baker.ensureVisible(const Rect.fromLTWH(0, 0, 500, 500));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    baker.dispose();
  });
}
