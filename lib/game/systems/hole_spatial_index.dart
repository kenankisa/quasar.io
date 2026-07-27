import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../components/black_hole_partner.dart';
import '../utils/world_spatial_index.dart';

/// Lightweight snapshot of an active black hole for spatial queries.
class HoleSnapshot {
  const HoleSnapshot({
    required this.partner,
    required this.position,
    required this.radius,
    this.accent = const Color(0xFFFFAA44),
    this.isLocalPlayer = false,
  });

  final BlackHolePartner partner;
  final Vector2 position;
  final double radius;
  final Color accent;
  final bool isLocalPlayer;
}

/// Per-frame spatial index of all alive holes — shared by bot AI, PvP gravity,
/// and swallow VFX so each subsystem skips distant entities.
class HoleSpatialIndex {
  HoleSpatialIndex({required double worldSize})
      : _grid = WorldSpatialIndex<HoleSnapshot>(worldSize: worldSize);

  final WorldSpatialIndex<HoleSnapshot> _grid;
  final List<HoleSnapshot> _entries = [];
  final Map<BlackHolePartner, int> _partnerIndex = {};

  List<HoleSnapshot> get entries => _entries;

  int? indexOf(BlackHolePartner partner) => _partnerIndex[partner];

  void rebuild(Iterable<HoleSnapshot> snapshots) {
    _entries.clear();
    _partnerIndex.clear();
    _grid.clear();

    for (final snapshot in snapshots) {
      if (snapshot.partner.isEliminated) continue;
      _partnerIndex[snapshot.partner] = _entries.length;
      _entries.add(snapshot);
      _grid.insert(snapshot.position, snapshot);
    }
  }

  void forEachNear(
    Vector2 center,
    double radius,
    void Function(HoleSnapshot hole) visit, {
    BlackHolePartner? exclude,
  }) {
    _grid.forEachNear(center, radius, (hole, _) {
      if (exclude != null && identical(hole.partner, exclude)) return;
      visit(hole);
    });
  }

  /// Visits [other] when its list index is greater than [sourceIndex] — avoids
  /// duplicate pair work in gravity / merger broad-phase.
  void forEachPairCandidate({
    required HoleSnapshot source,
    required int sourceIndex,
    required double queryRadius,
    required void Function(HoleSnapshot other, int otherIndex) visit,
  }) {
    _grid.forEachNear(source.position, queryRadius, (other, _) {
      if (identical(other.partner, source.partner)) return;
      final otherIndex = _partnerIndex[other.partner];
      if (otherIndex == null || otherIndex <= sourceIndex) return;
      visit(other, otherIndex);
    });
  }
}
