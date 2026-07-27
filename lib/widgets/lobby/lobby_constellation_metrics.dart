import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/room_type.dart';
import '../../utils/responsive_layout.dart';

/// Fractional anchor for a universe wormhole on the lobby constellation field.
class ConstellationPortalAnchor {
  const ConstellationPortalAnchor({
    required this.roomType,
    required this.x,
    required this.y,
    required this.sizeFactor,
    required this.zIndex,
    this.depthOpacity = 1,
    this.landscapeX,
    this.landscapeY,
    this.compactY,
  });

  final RoomType roomType;
  final double x;
  final double y;
  final double sizeFactor;
  final int zIndex;
  final double depthOpacity;

  /// Optional overrides when width > height.
  final double? landscapeX;
  final double? landscapeY;

  /// Optional Y override on narrow / short phones.
  final double? compactY;
}

/// Resolved pixel layout for one portal on the constellation field.
class ResolvedPortalSlot {
  const ResolvedPortalSlot({
    required this.anchor,
    required this.center,
    required this.portalDiameter,
    required this.hitDiameter,
    required this.labelMaxWidth,
    required this.depthOpacity,
  });

  final ConstellationPortalAnchor anchor;
  final Offset center;
  final double portalDiameter;
  final double hitDiameter;
  final double labelMaxWidth;
  final double depthOpacity;
}

/// Maps design anchors to device pixels — keeps portals inside safe bounds.
abstract final class LobbyConstellationMetrics {
  LobbyConstellationMetrics._();

  /// Scattered constellation — entry gates aloft, tiers flank mid-field,
  /// hardcore abyss anchors the bottom.
  static const anchors = <ConstellationPortalAnchor>[
    ConstellationPortalAnchor(
      roomType: RoomType.simple,
      x: 0.26,
      y: 0.14,
      sizeFactor: 0.26,
      zIndex: 2,
      compactY: 0.12,
      landscapeX: 0.24,
      landscapeY: 0.14,
    ),
    ConstellationPortalAnchor(
      roomType: RoomType.normal,
      x: 0.77,
      y: 0.17,
      sizeFactor: 0.286,
      zIndex: 1,
      depthOpacity: 0.94,
      compactY: 0.14,
      landscapeX: 0.78,
      landscapeY: 0.16,
    ),
    ConstellationPortalAnchor(
      roomType: RoomType.elite,
      x: 0.16,
      y: 0.48,
      sizeFactor: 0.299,
      zIndex: 0,
      depthOpacity: 0.9,
      compactY: 0.46,
      landscapeX: 0.17,
      landscapeY: 0.46,
    ),
    ConstellationPortalAnchor(
      roomType: RoomType.unique,
      x: 0.74,
      y: 0.47,
      sizeFactor: 0.33,
      zIndex: 3,
      compactY: 0.45,
      landscapeX: 0.75,
      landscapeY: 0.44,
    ),
    ConstellationPortalAnchor(
      roomType: RoomType.hardcore,
      x: 0.46,
      y: 0.74,
      sizeFactor: 0.44,
      zIndex: 4,
      compactY: 0.71,
      landscapeX: 0.46,
      landscapeY: 0.70,
    ),
  ];

  static List<ResolvedPortalSlot> resolve({
    required Size area,
    required ResponsiveLayout responsive,
  }) {
    if (area.width <= 0 || area.height <= 0) return const [];

    final isLandscape = area.width > area.height * 1.08;
    final shortField = area.height < 460;
    final compact = responsive.isCompact || shortField;

    final base = math.min(area.width, area.height);
    final widthScale = (area.width / ResponsiveLayout.designWidth)
        .clamp(0.82, 1.14);
    final heightScale = (area.height / 520).clamp(0.78, 1.08);
    final fieldScale = math.min(widthScale, heightScale);
    final compactScale = compact ? 0.9 : 1.0;

    final verticalSqueeze = shortField
        ? (area.height / 520).clamp(0.72, 1.0)
        : 1.0;

    final horizontalPad = area.width * 0.06;
    final topPad = area.height * 0.04;
    final bottomPad = area.height * 0.03;

    final slots = <ResolvedPortalSlot>[];

    for (final anchor in anchors) {
      var ax = isLandscape ? (anchor.landscapeX ?? anchor.x) : anchor.x;
      var ay = isLandscape ? (anchor.landscapeY ?? anchor.y) : anchor.y;
      if (compact && anchor.compactY != null) {
        ay = anchor.compactY!;
      }

      ay = 0.5 + (ay - 0.5) * verticalSqueeze;

      final maxFrac = anchor.roomType == RoomType.hardcore
          ? 0.51
          : anchor.roomType == RoomType.simple
              ? 0.39
              : anchor.roomType == RoomType.unique
                  ? 0.42
                  : anchor.roomType == RoomType.normal ||
                          anchor.roomType == RoomType.elite
                      ? 0.47
                      : 0.36;
      final minD = switch (anchor.roomType) {
        RoomType.simple => 80.0,
        RoomType.normal || RoomType.elite => 94.0,
        RoomType.unique || RoomType.hardcore => 87.0,
      };
      final diameter = (base * anchor.sizeFactor * fieldScale * compactScale)
          .clamp(minD, base * maxFrac);
      final hit = math.max(diameter, 48.0 * responsive.scale);
      final labelMax = math.min(area.width * 0.42, diameter * 1.55);

      var cx = horizontalPad + ax * (area.width - horizontalPad * 2);
      var cy = topPad + ay * (area.height - topPad - bottomPad);

      final halfHit = hit / 2;
      final labelReserve = 42.0 * responsive.scale;
      cx = cx.clamp(halfHit, area.width - halfHit);
      cy = cy.clamp(
        halfHit,
        area.height - halfHit - labelReserve,
      );

      slots.add(
        ResolvedPortalSlot(
          anchor: anchor,
          center: Offset(cx, cy),
          portalDiameter: diameter,
          hitDiameter: hit,
          labelMaxWidth: labelMax,
          depthOpacity: anchor.depthOpacity,
        ),
      );
    }

    slots.sort((a, b) => a.anchor.zIndex.compareTo(b.anchor.zIndex));
    return slots;
  }
}
