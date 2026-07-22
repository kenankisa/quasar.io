import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Paints static starfield scenery for one world-space tile rect.
typedef StarfieldTilePainter = void Function(Canvas canvas, Rect worldRect);

/// Lazy world-tile bake cache: PictureRecorder → [ui.Image], LRU-capped.
///
/// Used on mobile/web ([CanvasEffects.mobileLiteMode]) so dim stars / nebulae
/// are drawn once per tile instead of every frame.
class StarfieldTileBaker {
  StarfieldTileBaker({
    required this.worldSize,
    required this.gridSize,
    required this.pixelSize,
    required this.painter,
    int? maxCachedTiles,
  })  : assert(gridSize >= 1),
        assert(pixelSize >= 64),
        tileWorldSize = worldSize / gridSize,
        maxCachedTiles = maxCachedTiles ?? (gridSize * gridSize);

  final double worldSize;
  final int gridSize;
  final int pixelSize;
  final StarfieldTilePainter painter;
  final double tileWorldSize;
  final int maxCachedTiles;

  final _images = <int, ui.Image>{};
  final _lru = <int>{};
  final _inflight = <int, Future<void>>{};
  final _paint = Paint()..filterQuality = FilterQuality.low;

  int _key(int tx, int ty) => ty * gridSize + tx;

  (int, int) _tileAt(double worldX, double worldY) {
    final tx = (worldX / tileWorldSize).floor().clamp(0, gridSize - 1);
    final ty = (worldY / tileWorldSize).floor().clamp(0, gridSize - 1);
    return (tx, ty);
  }

  Rect worldRectForTile(int tx, int ty) {
    return Rect.fromLTWH(
      tx * tileWorldSize,
      ty * tileWorldSize,
      tileWorldSize,
      tileWorldSize,
    );
  }

  /// Ensures tiles covering [visible] (plus a small halo) are baking / ready.
  void ensureVisible(Rect visible) {
    for (final (tx, ty) in _tilesForVisible(visible)) {
      _requestTile(tx, ty);
    }
  }

  /// Like [ensureVisible], but waits until those tiles are in the cache.
  Future<void> warmUp(Rect visible) async {
    final pending = <Future<void>>[];
    for (final (tx, ty) in _tilesForVisible(visible)) {
      final future = _requestTile(tx, ty);
      if (future != null) pending.add(future);
    }
    if (pending.isNotEmpty) {
      await Future.wait(pending);
    }
  }

  List<(int, int)> _tilesForVisible(Rect visible) {
    if (visible.isEmpty) return const [];
    final padded = visible.inflate(tileWorldSize * 0.15);
    final (minTx, minTy) = _tileAt(padded.left, padded.top);
    final (maxTx, maxTy) = _tileAt(padded.right, padded.bottom);

    // Bake center of view first for smoother first paint.
    final cx = ((minTx + maxTx) / 2).round().clamp(0, gridSize - 1);
    final cy = ((minTy + maxTy) / 2).round().clamp(0, gridSize - 1);
    final ordered = <(int, int)>[];
    for (var ty = minTy; ty <= maxTy; ty++) {
      for (var tx = minTx; tx <= maxTx; tx++) {
        ordered.add((tx, ty));
      }
    }
    ordered.sort((a, b) {
      final da = (a.$1 - cx).abs() + (a.$2 - cy).abs();
      final db = (b.$1 - cx).abs() + (b.$2 - cy).abs();
      return da.compareTo(db);
    });
    return ordered;
  }

  /// Returns a future while baking; null if already cached or already inflight.
  Future<void>? _requestTile(int tx, int ty) {
    final key = _key(tx, ty);
    if (_images.containsKey(key)) {
      _touch(key);
      return null;
    }
    final inflight = _inflight[key];
    if (inflight != null) {
      return inflight;
    }
    final done = _bakeTile(tx, ty).then((image) {
      _inflight.remove(key);
      if (_disposed) {
        image.dispose();
        return;
      }
      if (_images.containsKey(key)) {
        image.dispose();
        return;
      }
      _images[key] = image;
      _touch(key);
      _evictIfNeeded();
    }).catchError((Object e, StackTrace st) {
      _inflight.remove(key);
      debugPrint('StarfieldTileBaker: bake failed ($tx,$ty): $e\n$st');
    });
    _inflight[key] = done;
    return done;
  }

  Future<ui.Image> _bakeTile(int tx, int ty) async {
    final worldRect = worldRectForTile(tx, ty);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final scale = pixelSize / tileWorldSize;
    canvas.scale(scale, scale);
    canvas.translate(-worldRect.left, -worldRect.top);
    painter(canvas, worldRect);
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(pixelSize, pixelSize);
    } finally {
      picture.dispose();
    }
  }

  void _touch(int key) {
    _lru.remove(key);
    _lru.add(key);
  }

  void _evictIfNeeded() {
    while (_images.length > maxCachedTiles && _lru.isNotEmpty) {
      final oldest = _lru.first;
      _lru.remove(oldest);
      final image = _images.remove(oldest);
      image?.dispose();
    }
  }

  /// Draws every ready tile that intersects [visible].
  void draw(Canvas canvas, Rect visible) {
    if (visible.isEmpty || _images.isEmpty) return;
    final padded = visible.inflate(2);
    final (minTx, minTy) = _tileAt(padded.left, padded.top);
    final (maxTx, maxTy) = _tileAt(padded.right, padded.bottom);

    for (var ty = minTy; ty <= maxTy; ty++) {
      for (var tx = minTx; tx <= maxTx; tx++) {
        final key = _key(tx, ty);
        final image = _images[key];
        if (image == null) continue;
        _touch(key);
        final dst = worldRectForTile(tx, ty);
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, pixelSize.toDouble(), pixelSize.toDouble()),
          dst,
          _paint,
        );
      }
    }
  }

  bool _disposed = false;

  void dispose() {
    _disposed = true;
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    _lru.clear();
    _inflight.clear();
  }
}
