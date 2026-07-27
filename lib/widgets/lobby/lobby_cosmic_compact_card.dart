import 'package:flutter/material.dart';

import '../../game/config/room_visual_theme.dart';
import '../../game/config/universe_palette.dart';
import '../../game/room_type.dart';
import '../../services/settings_service.dart';
import '../wormhole_portal.dart';
import 'universe_card_photo_background.dart';

/// Compact lobby universe row — cosmic shell with tier glow, nebula wash, wormhole gate.
class LobbyCosmicCompactCard extends StatelessWidget {
  const LobbyCosmicCompactCard({
    super.key,
    required this.roomType,
    required this.locked,
    required this.portalAnimation,
    required this.onTap,
    required this.leadingContent,
    required this.trailing,
    this.hardcoreEmber,
    this.infernoStyle = false,
  });

  final RoomType roomType;
  final bool locked;
  final Animation<double> portalAnimation;
  final VoidCallback? onTap;
  final Widget leadingContent;
  final Widget trailing;

  /// Optional warm highlight for hardcore (title / accents).
  final Color? hardcoreEmber;

  /// Hellfire palette + ember atmosphere for Hardcore arena.
  final bool infernoStyle;

  static const _radius = 16.0;

  @override
  Widget build(BuildContext context) {
    final theme = RoomVisualTheme.forRoom(roomType);
    final tier = UniversePalette.tierIndex(roomType);
    final backdrop = UniversePalette.backdropColors(roomType);
    final accent = hardcoreEmber ?? theme.accent;
    final inferno = infernoStyle || roomType == RoomType.hardcore;
    final glow = locked ? 0.0 : UniversePalette.cardGlowStrength(roomType);
    final borderAlpha = UniversePalette.cardBorderAlpha(roomType, locked: locked);
    final lowPerf = SettingsService.instance.lowPerformanceMode;
    const infernoRed = Color(0xFFFF2A10);
    const infernoOrange = Color(0xFFFF6B18);
    const infernoEmber = Color(0xFFFFB020);
    final borderColor = inferno
        ? Color.lerp(infernoRed, infernoOrange, locked ? 0.3 : 0.65)!
        : accent.withValues(alpha: borderAlpha);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_radius),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: locked ? 0.78 : 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(
                color: borderColor,
                width: inferno ? 1.6 : (tier >= 3 ? 1.35 : 1),
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
                          BoxShadow(
                            color: infernoEmber.withValues(alpha: 0.12),
                            blurRadius: 32,
                            spreadRadius: -6,
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
                              color: theme.secondaryAccent.withValues(
                                alpha: glow * 0.4,
                              ),
                              blurRadius: 18,
                              spreadRadius: -3,
                            ),
                        ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_radius - 1),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    WormholeGateBadge(
                      roomType: roomType,
                      spin: portalAnimation,
                      locked: locked,
                      width: 58,
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: lowPerf
                                ? DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: inferno
                                            ? [
                                                const Color(0xFF4A0C08).withValues(
                                                  alpha: locked ? 0.55 : 0.95,
                                                ),
                                                const Color(0xFF1E0604),
                                                const Color(0xFF0A0202),
                                              ]
                                            : [
                                                backdrop[0].withValues(
                                                  alpha: locked ? 0.5 : 0.92,
                                                ),
                                                backdrop[1],
                                                backdrop[2],
                                              ],
                                      ),
                                    ),
                                  )
                                : UniverseCardPhotoBackground(
                                    roomType: roomType,
                                    locked: locked,
                                    infernoTint: inferno,
                                  ),
                          ),
                          if (inferno && !locked)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: 28,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      infernoOrange.withValues(alpha: 0.22),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if ((tier >= 2 && !locked) || (inferno && !locked))
                            Positioned(
                              top: 0,
                              left: 12,
                              right: 12,
                              child: Container(
                                height: inferno ? 1.5 : 1,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: LinearGradient(
                                    colors: inferno
                                        ? [
                                            Colors.transparent,
                                            infernoEmber.withValues(alpha: 0.7),
                                            infernoRed.withValues(alpha: 0.55),
                                            Colors.transparent,
                                          ]
                                        : [
                                            Colors.transparent,
                                            accent.withValues(alpha: 0.5),
                                            theme.secondaryAccent.withValues(
                                              alpha: 0.3,
                                            ),
                                            Colors.transparent,
                                          ],
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                            child: Row(
                              children: [
                                Expanded(child: leadingContent),
                                const SizedBox(width: 6),
                                trailing,
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CompactUniverseTitle extends StatelessWidget {
  const CompactUniverseTitle({
    super.key,
    required this.text,
    required this.roomType,
    required this.locked,
    required this.fontSize,
  });

  final String text;
  final RoomType roomType;
  final bool locked;
  final double fontSize;

  TextStyle get _baseTitleStyle => TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
        height: 1.0,
      );

  @override
  Widget build(BuildContext context) {
    final theme = RoomVisualTheme.forRoom(roomType);
    final inferno = roomType == RoomType.hardcore;
    final useGradient = theme.lobbyGradientTitle || inferno;
    final textStyle = inferno
        ? _baseTitleStyle.copyWith(letterSpacing: 0.5)
        : _baseTitleStyle;

    if (!useGradient) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textStyle.copyWith(
          color: locked ? Colors.white.withValues(alpha: 0.5) : Colors.white,
        ),
      );
    }

    final accent = theme.accent;
    final end = inferno
        ? const Color(0xFFFF2A10)
        : (theme.titleGradientEnd ?? theme.secondaryAccent);

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        if (!locked)
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle.copyWith(
              color: Colors.transparent,
              shadows: [
                Shadow(
                  color: (inferno ? const Color(0xFFFF6B18) : accent)
                      .withValues(alpha: inferno ? 0.55 : 0.3),
                  blurRadius: inferno ? 14 : 8,
                ),
                if (inferno)
                  Shadow(
                    color: const Color(0xFFFF2A10).withValues(alpha: 0.35),
                    blurRadius: 20,
                  ),
              ],
            ),
          ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: locked
                  ? inferno
                      ? [
                          const Color(0xFFFFB020).withValues(alpha: 0.35),
                          const Color(0xFFFF2A10).withValues(alpha: 0.22),
                        ]
                      : [
                          accent.withValues(alpha: 0.4),
                          end.withValues(alpha: 0.26),
                        ]
                  : inferno
                      ? const [
                          Color(0xFFFFF8E8),
                          Color(0xFFFFD060),
                          Color(0xFFFF6B18),
                          Color(0xFFFF2A10),
                        ]
                      : [
                          Colors.white,
                          end,
                          accent,
                        ],
              stops: locked
                  ? null
                  : (inferno
                      ? const [0.0, 0.28, 0.62, 1.0]
                      : const [0.0, 0.45, 1.0]),
            ).createShader(bounds);
          },
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
