import 'dart:math' as math;

import 'package:flame/components.dart';

/// Uniform grid for broad-phase spatial queries over world entities.
///
/// Rebuild each frame (or on mutation) via [clear] + [insert], then query with
/// [forEachNear]. Cell size should be roughly the typical query radius.
class WorldSpatialIndex<T> {
  WorldSpatialIndex({
    required double worldSize,
    this.cellSize = 512,
  })  : _cols = math.max(1, (worldSize / cellSize).ceil()),
        _rows = math.max(1, (worldSize / cellSize).ceil()) {
    _buckets = List.generate(_cols * _rows, (_) => <int>[]);
  }

  final double cellSize;
  final int _cols;
  final int _rows;

  late final List<List<int>> _buckets;
  final List<({Vector2 position, T item})> _entries = [];

  void clear() {
    _entries.clear();
    for (final bucket in _buckets) {
      bucket.clear();
    }
  }

  void insert(Vector2 position, T item) {
    final index = _entries.length;
    _entries.add((position: position, item: item));
    final cx = (position.x / cellSize).floor().clamp(0, _cols - 1);
    final cy = (position.y / cellSize).floor().clamp(0, _rows - 1);
    _buckets[cy * _cols + cx].add(index);
  }

  /// Visits items whose cell overlaps the query circle (exact distance check).
  void forEachNear(
    Vector2 center,
    double radius,
    void Function(T item, Vector2 position) visit,
  ) {
    if (_entries.isEmpty) return;

    final minX = ((center.x - radius) / cellSize).floor().clamp(0, _cols - 1);
    final maxX = ((center.x + radius) / cellSize).floor().clamp(0, _cols - 1);
    final minY = ((center.y - radius) / cellSize).floor().clamp(0, _rows - 1);
    final maxY = ((center.y + radius) / cellSize).floor().clamp(0, _rows - 1);
    final radiusSq = radius * radius;

    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        for (final index in _buckets[y * _cols + x]) {
          final entry = _entries[index];
          final dx = entry.position.x - center.x;
          final dy = entry.position.y - center.y;
          if (dx * dx + dy * dy <= radiusSq) {
            visit(entry.item, entry.position);
          }
        }
      }
    }
  }
}
