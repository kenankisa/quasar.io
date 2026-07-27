import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/config/room_visual_theme.dart';
import '../../game/config/universe_palette.dart';
import '../../game/room_type.dart';
import '../../services/lang_service.dart';
import '../../services/settings_service.dart';
import '../../utils/responsive_layout.dart';
import '../wormhole_portal.dart';
import 'lobby_cosmic_compact_card.dart';
import 'universe_card_photo_background.dart';

// ── Shared atoms ─────────────────────────────────────────────────────────────

class LobbyRecommendedChip extends StatelessWidget {
  const LobbyRecommendedChip({super.key, required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.2), blurRadius: 6),
        ],
      ),
      child: Text(
        LanguageService.instance.t('lobby_recommended_room').toUpperCase(),
        style: TextStyle(
          color: accent,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class LobbyPlayerCountPill extends StatelessWidget {
  const LobbyPlayerCountPill({
    super.key,
    required this.label,
    required this.accent,
    required this.locked,
    this.inferno = false,
    this.compact = false,
  });

  final String label;
  final Color accent;
  final bool locked;
  final bool inferno;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.w(compact ? 5 : 7),
        vertical: r.w(compact ? 2 : 3),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: inferno
            ? LinearGradient(
                colors: [
                  const Color(0xFFFF6B18)
                      .withValues(alpha: locked ? 0.1 : 0.28),
                  const Color(0xFFFF2A10)
                      .withValues(alpha: locked ? 0.06 : 0.16),
                ],
              )
            : null,
        color: inferno
            ? null
            : accent.withValues(alpha: locked ? 0.06 : 0.14),
        border: Border.all(
          color: inferno
              ? const Color(0xFFFFB020).withValues(alpha: locked ? 0.25 : 0.55)
              : accent.withValues(alpha: locked ? 0.2 : 0.38),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_rounded,
            size: compact ? 9 : 11,
            color: accent.withValues(alpha: locked ? 0.45 : 0.9),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: locked ? 0.4 : 0.82),
              fontSize: r.sp(compact ? 9.5 : 11),
              fontWeight: FontWeight.w700,
              height: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class LobbyMiniTrophies extends StatelessWidget {
  const LobbyMiniTrophies({
    super.key,
    required this.lit,
    required this.slots,
    required this.accent,
    required this.locked,
    this.showAll = false,
    this.size = 11,
  });

  final int lit;
  final int slots;
  final Color accent;
  final bool locked;
  final bool showAll;
  final double size;

  @override
  Widget build(BuildContext context) {
    final filled = lit.clamp(0, slots);
    final show = showAll ? slots : math.min(slots, 5);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < show; i++)
            Padding(
              padding: EdgeInsets.only(right: i < show - 1 ? 2 : 0),
              child: Icon(
                Icons.emoji_events_rounded,
                size: size,
                color: i < filled
                    ? const Color(0xFFFFD54F)
                        .withValues(alpha: locked ? 0.45 : 1)
                    : accent.withValues(alpha: locked ? 0.12 : 0.25),
              ),
            ),
          if (!showAll && slots > show)
            Text(
              '+${slots - show}',
              style: TextStyle(
                color: accent.withValues(alpha: 0.5),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class LobbyPlayChip extends StatelessWidget {
  const LobbyPlayChip({
    super.key,
    required this.accent,
    required this.label,
    this.onTap,
    this.inferno = false,
    this.expanded = false,
    this.compact = false,
  });

  final Color accent;
  final String label;
  final VoidCallback? onTap;
  final bool inferno;
  final bool expanded;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    final chip = Container(
      width: expanded ? double.infinity : null,
      padding: EdgeInsets.symmetric(
        horizontal: r.w(compact ? 10 : 12),
        vertical: r.w(compact ? 6 : 8),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: inferno
              ? const [
                  Color(0xFFFFD060),
                  Color(0xFFFF6B18),
                  Color(0xFFFF2A10),
                ]
              : [
                  Color.lerp(accent, Colors.white, 0.15)!,
                  accent.withValues(alpha: 0.95),
                ],
        ),
        border: Border.all(
          color: inferno
              ? const Color(0xFFFFF0C2).withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.22),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: (inferno ? const Color(0xFFFF2A10) : accent)
                .withValues(alpha: inferno ? 0.45 : 0.35),
            blurRadius: inferno ? 12 : 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label.toUpperCase(),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: inferno ? const Color(0xFF1A0402) : const Color(0xFF05050C),
          fontSize: r.sp(compact ? 10 : 11),
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );

    if (onTap == null) return chip;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        child: expanded ? chip : Center(child: chip),
      ),
    );
  }
}

class LobbyLockChip extends StatelessWidget {
  const LobbyLockChip({super.key, required this.accent, this.compact = false});

  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Icon(
        Icons.lock_outline_rounded,
        color: accent.withValues(alpha: 0.85),
        size: compact ? 15 : 18,
      ),
    );
  }
}

class LobbySectorTag extends StatelessWidget {
  const LobbySectorTag({
    super.key,
    required this.code,
    required this.accent,
  });

  final String code;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    return Text(
      code,
      style: TextStyle(
        color: accent.withValues(alpha: 0.55),
        fontSize: r.sp(8.5),
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

// ── Shell helpers ────────────────────────────────────────────────────────────

BoxDecoration _universeGlowDecoration({
  required RoomType roomType,
  required bool locked,
  required double borderRadius,
  bool inferno = false,
  Color? accentOverride,
}) {
  final theme = RoomVisualTheme.forRoom(roomType);
  final tier = UniversePalette.tierIndex(roomType);
  final accent = accentOverride ?? theme.accent;
  final infernoRed = const Color(0xFFFF2A10);
  final infernoOrange = const Color(0xFFFF6B18);
  final borderColor = inferno
      ? Color.lerp(infernoRed, infernoOrange, locked ? 0.3 : 0.65)!
      : accent.withValues(
          alpha: UniversePalette.cardBorderAlpha(roomType, locked: locked),
        );
  final glow = locked ? 0.0 : UniversePalette.cardGlowStrength(roomType);

  return BoxDecoration(
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(
      color: borderColor,
      width: inferno ? 1.6 : (tier >= 3 ? 1.4 : 1),
    ),
    boxShadow: locked
        ? null
        : inferno
            ? [
                BoxShadow(
                  color: infernoRed.withValues(alpha: 0.38),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: infernoOrange.withValues(alpha: 0.28),
                  blurRadius: 24,
                  spreadRadius: -2,
                ),
              ]
            : [
                BoxShadow(
                  color: accent.withValues(alpha: glow),
                  blurRadius: 12 + tier * 3,
                  offset: const Offset(0, 4),
                ),
                if (tier >= 2)
                  BoxShadow(
                    color: theme.secondaryAccent.withValues(alpha: glow * 0.4),
                    blurRadius: 18,
                    spreadRadius: -3,
                  ),
              ],
  );
}

Widget _photoLayer({
  required RoomType roomType,
  required bool locked,
  bool inferno = false,
  bool fullBleed = false,
}) {
  final lowPerf = SettingsService.instance.lowPerformanceMode;
  final backdrop = UniversePalette.backdropColors(roomType);
  if (lowPerf) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: inferno
              ? [
                  const Color(0xFF4A0C08).withValues(alpha: locked ? 0.55 : 0.95),
                  const Color(0xFF1E0604),
                  const Color(0xFF0A0202),
                ]
              : [
                  backdrop[0].withValues(alpha: locked ? 0.5 : 0.92),
                  backdrop[1],
                  backdrop[2],
                ],
        ),
      ),
    );
  }
  return UniverseCardPhotoBackground(
    roomType: roomType,
    locked: locked,
    infernoTint: inferno,
    fullBleed: fullBleed,
  );
}

/// Left-to-right scrim for full-bleed banner cards — photo stays visible on the right.
Widget _bannerReadabilityVeil({double clearRightFraction = 0}) {
  final clear = clearRightFraction.clamp(0.0, 0.3);
  if (clear <= 0) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.black.withValues(alpha: 0.62),
            Colors.black.withValues(alpha: 0.5),
            Colors.black.withValues(alpha: 0.36),
            Colors.black.withValues(alpha: 0.22),
          ],
          stops: const [0.0, 0.24, 0.58, 1.0],
        ),
      ),
    );
  }

  final leftFlex = ((1 - clear) * 100).round().clamp(1, 100);
  final rightFlex = (clear * 100).round().clamp(1, 30);
  return Row(
    children: [
      Expanded(
        flex: leftFlex,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.black.withValues(alpha: 0.84),
                Colors.black.withValues(alpha: 0.46),
                Colors.black.withValues(alpha: 0.18),
              ],
            ),
          ),
        ),
      ),
      Expanded(
        flex: rightFlex,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.black.withValues(alpha: 0.18),
                Colors.black.withValues(alpha: 0.28),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

// ── 1. Dock — training launch rail ───────────────────────────────────────────

/// Slim horizontal capsule — entry dock for training universe.
class LobbyDockUniverseCard extends StatelessWidget {
  const LobbyDockUniverseCard({
    super.key,
    required this.roomType,
    required this.title,
    required this.locked,
    required this.portalAnimation,
    required this.playerLabel,
    required this.trophyLit,
    required this.trophySlots,
    required this.playLabel,
    this.recommended = false,
    this.lockText,
    this.onInfo,
    this.onPlay,
  });

  final RoomType roomType;
  final String title;
  final bool locked;
  final Animation<double> portalAnimation;
  final String playerLabel;
  final int trophyLit;
  final int trophySlots;
  final String playLabel;
  final bool recommended;
  final String? lockText;
  final VoidCallback? onInfo;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = RoomVisualTheme.forRoom(roomType);
    final accent = theme.accent;
    final r = ResponsiveLayout.of(context);
    final cardHeight = r.h(lockText != null ? 88 : 80);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onInfo,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: locked ? 0.78 : 1,
          child: Container(
            height: cardHeight,
            decoration: _universeGlowDecoration(
              roomType: roomType,
              locked: locked,
              borderRadius: 999,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: _photoLayer(
                      roomType: roomType,
                      locked: locked,
                      fullBleed: true,
                    ),
                  ),
                  Positioned.fill(child: _bannerReadabilityVeil()),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 56,
                        child: WormholeGateBadge(
                          roomType: roomType,
                          spin: portalAnimation,
                          locked: locked,
                          width: 56,
                          overlay: true,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(6, 6, 4, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CompactUniverseTitle(
                                text: title,
                                roomType: roomType,
                                locked: locked,
                                fontSize: r.sp(13),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  LobbySectorTag(
                                    code: 'DOCK-α',
                                    accent: accent,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        LobbyPlayerCountPill(
                                          label: playerLabel,
                                          accent: accent,
                                          locked: locked,
                                          compact: true,
                                        ),
                                        if (trophySlots > 0) ...[
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: LobbyMiniTrophies(
                                              lit: trophyLit,
                                              slots: trophySlots,
                                              accent: accent,
                                              locked: locked,
                                              size: 10,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (lockText != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  lockText!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: accent.withValues(alpha: 0.75),
                                    fontSize: r.sp(9),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 8, 10, 8),
                        child: Center(
                          child: locked
                              ? LobbyLockChip(accent: accent, compact: true)
                              : LobbyPlayChip(
                                  accent: accent,
                                  label: playLabel,
                                  onTap: onPlay,
                                  compact: true,
                                ),
                        ),
                      ),
                    ],
                  ),
                  if (recommended)
                    Positioned(
                      top: 6,
                      right: 54,
                      child: LobbyRecommendedChip(accent: accent),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 2. Sector — twin scan tiles (normal / elite) ─────────────────────────────

/// Vertical sector tile — star-map quadrant for mid-tier universes.
class LobbySectorUniverseCard extends StatelessWidget {
  const LobbySectorUniverseCard({
    super.key,
    required this.roomType,
    required this.title,
    required this.sectorCode,
    required this.locked,
    required this.portalAnimation,
    required this.playerLabel,
    required this.trophyLit,
    required this.trophySlots,
    required this.playLabel,
    this.lockText,
    this.onInfo,
    this.onPlay,
  });

  final RoomType roomType;
  final String title;
  final String sectorCode;
  final bool locked;
  final Animation<double> portalAnimation;
  final String playerLabel;
  final int trophyLit;
  final int trophySlots;
  final String playLabel;
  final String? lockText;
  final VoidCallback? onInfo;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = RoomVisualTheme.forRoom(roomType);
    final accent = theme.accent;
    final tier = UniversePalette.tierIndex(roomType);
    final r = ResponsiveLayout.of(context);
    const radius = 16.0;
    final wormholeH = r.h(46);
    final cardH = r.h(168);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onInfo,
        borderRadius: BorderRadius.circular(radius),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: locked ? 0.78 : 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 132;
              final titleSize = r.sp(narrow ? 10.5 : 12);
              return SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : cardH,
                child: DecoratedBox(
                  decoration: _universeGlowDecoration(
                    roomType: roomType,
                    locked: locked,
                    borderRadius: radius,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius - 1),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                      _photoLayer(roomType: roomType, locked: locked),
                      if (!SettingsService.instance.lowPerformanceMode)
                        CustomPaint(
                          painter: _SectorGridPainter(accent: accent),
                        ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.06),
                              Colors.black.withValues(alpha: 0.3),
                              Colors.black.withValues(alpha: 0.62),
                            ],
                            stops: const [0.0, 0.48, 1.0],
                          ),
                        ),
                      ),
                      if (tier >= 2 && !locked)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: CustomPaint(
                            size: const Size(28, 28),
                            painter: _CornerBracketPainter(accent: accent),
                          ),
                        ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: wormholeH,
                            child: WormholeGateBadge(
                              roomType: roomType,
                              spin: portalAnimation,
                              locked: locked,
                              width: double.infinity,
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                narrow ? 7 : 9,
                                3,
                                narrow ? 7 : 9,
                                8,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  LobbySectorTag(
                                    code: sectorCode,
                                    accent: accent,
                                  ),
                                  const SizedBox(height: 2),
                                  SizedBox(
                                    height: titleSize * 1.2,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: CompactUniverseTitle(
                                        text: title,
                                        roomType: roomType,
                                        locked: locked,
                                        fontSize: titleSize,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (narrow) ...[
                                    LobbyPlayerCountPill(
                                      label: playerLabel,
                                      accent: accent,
                                      locked: locked,
                                      compact: true,
                                    ),
                                    if (trophySlots > 0) ...[
                                      const SizedBox(height: 4),
                                      LobbyMiniTrophies(
                                        lit: trophyLit,
                                        slots: trophySlots,
                                        accent: accent,
                                        locked: locked,
                                        size: 9,
                                      ),
                                    ],
                                  ] else
                                    Row(
                                      children: [
                                        Flexible(
                                          child: LobbyPlayerCountPill(
                                            label: playerLabel,
                                            accent: accent,
                                            locked: locked,
                                            compact: true,
                                          ),
                                        ),
                                        if (trophySlots > 0) ...[
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: LobbyMiniTrophies(
                                              lit: trophyLit,
                                              slots: trophySlots,
                                              accent: accent,
                                              locked: locked,
                                              size: 10,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  if (lockText != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      lockText!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: accent.withValues(alpha: 0.75),
                                        fontSize: r.sp(8),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 5),
                                  locked
                                      ? Center(
                                          child: LobbyLockChip(
                                            accent: accent,
                                            compact: true,
                                          ),
                                        )
                                      : LobbyPlayChip(
                                          accent: accent,
                                          label: playLabel,
                                          onTap: onPlay,
                                          expanded: true,
                                          compact: true,
                                        ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
            },
          ),
        ),
      ),
    );
  }
}

// ── 3. Anomaly — wide banner (unique) ────────────────────────────────────────

/// Cinematic anomaly sweep — unique universe full-width banner.
class LobbyAnomalyUniverseCard extends StatelessWidget {
  const LobbyAnomalyUniverseCard({
    super.key,
    required this.roomType,
    required this.title,
    required this.locked,
    required this.portalAnimation,
    required this.playerLabel,
    required this.trophyLit,
    required this.trophySlots,
    required this.playLabel,
    this.lockText,
    this.onInfo,
    this.onPlay,
  });

  final RoomType roomType;
  final String title;
  final bool locked;
  final Animation<double> portalAnimation;
  final String playerLabel;
  final int trophyLit;
  final int trophySlots;
  final String playLabel;
  final String? lockText;
  final VoidCallback? onInfo;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = RoomVisualTheme.forRoom(roomType);
    final accent = theme.accent;
    final r = ResponsiveLayout.of(context);
    const radius = 14.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onInfo,
        borderRadius: BorderRadius.circular(radius),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: locked ? 0.78 : 1,
          child: Container(
            height: r.h(112),
            decoration: _universeGlowDecoration(
              roomType: roomType,
              locked: locked,
              borderRadius: radius,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius - 1),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: _photoLayer(
                      roomType: roomType,
                      locked: locked,
                      fullBleed: true,
                    ),
                  ),
                  if (!SettingsService.instance.lowPerformanceMode)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ScanLinePainter(accent: accent),
                      ),
                    ),
                  Positioned.fill(
                    child: _bannerReadabilityVeil(),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      WormholeGateBadge(
                        roomType: roomType,
                        spin: portalAnimation,
                        locked: locked,
                        width: 60,
                        overlay: true,
                      ),
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: 18,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      accent.withValues(alpha: 0.06),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
                              child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LobbySectorTag(
                                code: 'ANOMALY-Ω',
                                accent: accent,
                              ),
                              const SizedBox(height: 3),
                              SizedBox(
                                height: r.sp(16) * 1.2,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: CompactUniverseTitle(
                                    text: title,
                                    roomType: roomType,
                                    locked: locked,
                                    fontSize: r.sp(15),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  LobbyPlayerCountPill(
                                    label: playerLabel,
                                    accent: accent,
                                    locked: locked,
                                    compact: true,
                                  ),
                                  if (trophySlots > 0)
                                    LobbyMiniTrophies(
                                      lit: trophyLit,
                                      slots: trophySlots,
                                      accent: accent,
                                      locked: locked,
                                      size: 10,
                                    ),
                                ],
                              ),
                              if (lockText != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  lockText!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: accent.withValues(alpha: 0.75),
                                    fontSize: r.sp(9),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 0, 10, 0),
                        child: Center(
                          child: locked
                              ? LobbyLockChip(accent: accent, compact: true)
                              : LobbyPlayChip(
                                  accent: accent,
                                  label: playLabel,
                                  onTap: onPlay,
                                  compact: true,
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 4. Singularity — hardcore event horizon ────────────────────────────────────

/// Event-horizon command card — hardcore endgame portal.
class LobbySingularityUniverseCard extends StatelessWidget {
  const LobbySingularityUniverseCard({
    super.key,
    required this.title,
    required this.locked,
    required this.portalAnimation,
    required this.playerLabel,
    required this.trophyLit,
    required this.trophySlots,
    required this.playLabel,
    this.subtitle,
    this.onInfo,
    this.onPlay,
  });

  final String title;
  final bool locked;
  final Animation<double> portalAnimation;
  final String playerLabel;
  final int trophyLit;
  final int trophySlots;
  final String playLabel;
  final String? subtitle;
  final VoidCallback? onInfo;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF3A1A);
    const ember = Color(0xFFFFB020);
    final r = ResponsiveLayout.of(context);
    const radius = 14.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onInfo,
        borderRadius: BorderRadius.circular(radius),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: locked ? 0.78 : 1,
          child: Container(
            height: r.h(128),
            decoration: _universeGlowDecoration(
              roomType: RoomType.hardcore,
              locked: locked,
              borderRadius: radius,
              inferno: true,
              accentOverride: accent,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius - 1),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: _photoLayer(
                      roomType: RoomType.hardcore,
                      locked: locked,
                      inferno: true,
                      fullBleed: true,
                    ),
                  ),
                  if (!SettingsService.instance.lowPerformanceMode)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ScanLinePainter(
                          accent: accent,
                          dense: true,
                        ),
                      ),
                    ),
                  Positioned.fill(child: _bannerReadabilityVeil()),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 80,
                        child: WormholeGateBadge(
                          roomType: RoomType.hardcore,
                          spin: portalAnimation,
                          locked: locked,
                          width: 80,
                          overlay: true,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  LobbySectorTag(
                                    code: 'SINGULARITY',
                                    accent: ember,
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 14,
                                    color: ember.withValues(alpha: 0.8),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: r.sp(17) * 1.2,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: CompactUniverseTitle(
                                    text: title,
                                    roomType: RoomType.hardcore,
                                    locked: locked,
                                    fontSize: r.sp(17),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  LobbyPlayerCountPill(
                                    label: playerLabel,
                                    accent: accent,
                                    locked: locked,
                                    inferno: true,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: LobbyMiniTrophies(
                                      lit: trophyLit,
                                      slots: trophySlots,
                                      accent: accent,
                                      locked: locked,
                                      showAll: true,
                                      size: 10,
                                    ),
                                  ),
                                ],
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: accent.withValues(alpha: 0.85),
                                    fontSize: r.sp(10),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              locked
                                  ? Align(
                                      alignment: Alignment.centerRight,
                                      child: LobbyLockChip(accent: accent),
                                    )
                                  : LobbyPlayChip(
                                      accent: accent,
                                      label: playLabel,
                                      onTap: onPlay,
                                      inferno: true,
                                      expanded: true,
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Painters ───────────────────────────────────────────────────────────────────

class _SectorGridPainter extends CustomPainter {
  const _SectorGridPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent.withValues(alpha: 0.06)
      ..strokeWidth = 0.5;
    const step = 18.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final cross = Paint()
      ..color = accent.withValues(alpha: 0.12)
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(size.width * 0.5, 0),
      Offset(size.width * 0.5, size.height * 0.45),
      cross,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.45),
      Offset(size.width, size.height * 0.45),
      cross,
    );
  }

  @override
  bool shouldRepaint(covariant _SectorGridPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

class _CornerBracketPainter extends CustomPainter {
  const _CornerBracketPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent.withValues(alpha: 0.55)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    const len = 10.0;
    canvas.drawLine(const Offset(0, len), const Offset(0, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

class _ScanLinePainter extends CustomPainter {
  const _ScanLinePainter({required this.accent, this.dense = false});

  final Color accent;
  final bool dense;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = accent.withValues(alpha: dense ? 0.04 : 0.03);
    final step = dense ? 5.0 : 7.0;
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.dense != dense;
}

/// Breach divider before hardcore singularity.
class LobbySingularityBreachDivider extends StatelessWidget {
  const LobbySingularityBreachDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.h(6)),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    const Color(0xFFFF6B18).withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 13,
                  color: const Color(0xFFFFB020).withValues(alpha: 0.85),
                ),
                const SizedBox(width: 6),
                Text(
                  'EVENT HORIZON',
                  style: TextStyle(
                    color: const Color(0xFFFF6B18).withValues(alpha: 0.8),
                    fontSize: r.sp(9),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.warning_amber_rounded,
                  size: 13,
                  color: const Color(0xFFFFB020).withValues(alpha: 0.85),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF6B18).withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
