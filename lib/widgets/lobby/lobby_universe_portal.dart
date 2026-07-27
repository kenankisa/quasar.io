import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/config/room_visual_theme.dart';
import '../../game/config/universe_palette.dart';
import '../../game/room_type.dart';
import '../../utils/responsive_layout.dart';
import '../wormhole_portal.dart';
import 'lobby_universe_cards.dart';
import 'lobby_wormhole_painter.dart';

/// Clickable wormhole entry — painted portal + minimal HUD label.
class LobbyUniversePortal extends StatefulWidget {
  const LobbyUniversePortal({
    super.key,
    required this.roomType,
    required this.diameter,
    required this.hitDiameter,
    required this.labelMaxWidth,
    required this.title,
    required this.playerLabel,
    required this.portalAnimation,
    required this.onInfo,
    this.locked = false,
    this.recommended = false,
    this.subtitle,
    this.trophyLit = 0,
    this.trophySlots = 0,
    this.depthOpacity = 1,
    this.onEnter,
  });

  final RoomType roomType;
  final double diameter;
  final double hitDiameter;
  final double labelMaxWidth;
  final String title;
  final String playerLabel;
  final Animation<double> portalAnimation;
  final VoidCallback onInfo;
  final bool locked;
  final bool recommended;
  final String? subtitle;
  final int trophyLit;
  final int trophySlots;
  final double depthOpacity;
  final Future<void> Function(WormholePortalFocal focal)? onEnter;

  @override
  State<LobbyUniversePortal> createState() => _LobbyUniversePortalState();
}

class _LobbyUniversePortalState extends State<LobbyUniversePortal>
    with TickerProviderStateMixin {
  late final AnimationController _approachCtrl;
  late final Animation<double> _approachAnim;
  late final AnimationController _entryCtrl;
  double _viewerAngle = 0;

  @override
  void initState() {
    super.initState();
    _approachCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 520),
    );
    _approachAnim = CurvedAnimation(
      parent: _approachCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
  }

  @override
  void dispose() {
    _approachCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    _resetPortalMotion();
    super.deactivate();
  }

  bool get _interactive => !widget.locked && widget.onEnter != null;

  Future<void> _handleEnter() async {
    if (!_interactive) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    HapticFeedback.mediumImpact();
    _entryCtrl.forward(from: 0);

    final portalDiscCenter = Offset(box.size.width / 2, widget.hitDiameter / 2);
    final global = box.localToGlobal(portalDiscCenter);
    try {
      await widget.onEnter!(
        WormholePortalFocal(center: global, diameter: widget.diameter),
      );
    } finally {
      _resetPortalMotion();
    }
  }

  void _resetPortalMotion() {
    if (!mounted) return;
    _entryCtrl.stop();
    _entryCtrl.value = 0;
    _approachCtrl.stop();
    _approachCtrl.value = 0;
  }

  void _updateProximity(Offset local) {
    if (!_interactive) return;
    final center = Offset(widget.hitDiameter / 2, widget.hitDiameter / 2);
    final delta = local - center;
    _viewerAngle = math.atan2(delta.dy, delta.dx);

    final dist = delta.distance;
    final outer = widget.hitDiameter * 0.58;
    final inner = widget.diameter * 0.08;
    final range = math.max(outer - inner, 1.0);
    final norm = ((dist - inner) / range).clamp(0.0, 1.0);
    // Inverse-square gravitational falloff — mass accelerates near the well.
    final invSq = (1 - norm) * (1 - norm);
    final target = invSq * (0.72 + invSq * 0.28);

    _approachCtrl.animateTo(
      target,
      duration: Duration(
        milliseconds: target > _approachAnim.value ? 280 : 620,
      ),
      curve: target > _approachAnim.value
          ? Curves.easeOutQuad
          : Curves.easeOutCubic,
    );
  }

  void _clearProximity() {
    if (!_interactive) return;
    _approachCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    final theme = RoomVisualTheme.forRoom(widget.roomType);
    final washA = UniversePalette.washA(widget.roomType);
    final hardcore = widget.roomType == RoomType.hardcore;
    final muted = widget.locked || widget.onEnter == null;

    return Opacity(
      opacity: widget.depthOpacity * (muted ? 0.72 : 1),
      child: MouseRegion(
        onExit: _interactive ? (_) => _clearProximity() : null,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerHover: _interactive
              ? (e) => _updateProximity(e.localPosition)
              : null,
          onPointerMove: _interactive
              ? (e) => _updateProximity(e.localPosition)
              : null,
          onPointerDown: _interactive
              ? (e) {
                  _updateProximity(e.localPosition);
                  HapticFeedback.selectionClick();
                }
              : null,
          onPointerUp: _interactive ? (_) => _clearProximity() : null,
          onPointerCancel: _interactive ? (_) => _clearProximity() : null,
          child: GestureDetector(
            onTap: () => _handleEnter(),
            onLongPress: () {
              HapticFeedback.lightImpact();
              widget.onInfo();
            },
            child: SizedBox(
              width: widget.hitDiameter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: widget.hitDiameter,
                    height: widget.hitDiameter,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          widget.portalAnimation,
                          _approachAnim,
                          _entryCtrl,
                        ]),
                        builder: (context, _) {
                          final entryApproach = math.max(
                            _approachAnim.value,
                            Curves.easeInCubic.transform(_entryCtrl.value),
                          );
                          final tidalPull =
                              1.0 + _approachAnim.value * 0.065;
                          return Transform.scale(
                            scale: tidalPull,
                            child: _PortalDisc(
                              roomType: widget.roomType,
                              diameter: widget.diameter,
                              locked: widget.locked,
                              portalAnimation: widget.portalAnimation,
                              approach: entryApproach,
                              viewerAngle: _viewerAngle,
                              theme: theme,
                              washA: washA,
                              hardcore: hardcore,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, -r.h(8)),
                    child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: widget.labelMaxWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: muted
                                ? Colors.white.withValues(alpha: 0.55)
                                : theme.accent,
                            fontSize: r.sp(hardcore ? 10.5 : 10),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.55,
                            height: 1.1,
                            shadows: muted
                                ? null
                                : [
                                    Shadow(
                                      color:
                                          theme.accent.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                    ),
                                  ],
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          SizedBox(height: r.h(2)),
                          Text(
                            widget.subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: r.sp(8.5),
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                            ),
                          ),
                        ],
                        SizedBox(height: r.h(3)),
                        if (hardcore && widget.trophySlots > 5) ...[
                          SizedBox(
                            width: widget.labelMaxWidth,
                            child: Center(
                              child: LobbyMiniTrophies(
                                lit: widget.trophyLit,
                                slots: widget.trophySlots,
                                accent: theme.accent,
                                locked: muted,
                                size: 8.5,
                              ),
                            ),
                          ),
                          SizedBox(height: r.h(2)),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LobbyPlayerCountPill(
                              label: widget.playerLabel,
                              accent: theme.accent,
                              locked: muted,
                              inferno: hardcore,
                              compact: true,
                            ),
                            if (widget.trophySlots > 0 &&
                                !(hardcore && widget.trophySlots > 5)) ...[
                              SizedBox(width: r.w(4)),
                              LobbyMiniTrophies(
                                lit: widget.trophyLit,
                                slots: widget.trophySlots,
                                accent: theme.accent,
                                locked: muted,
                                size: 9,
                              ),
                            ],
                            SizedBox(width: r.w(3)),
                            GestureDetector(
                              onTap: widget.onInfo,
                              behavior: HitTestBehavior.opaque,
                              child: Icon(
                                Icons.info_outline_rounded,
                                size: r.sp(14),
                                color: Colors.white.withValues(alpha: 0.42),
                              ),
                            ),
                          ],
                        ),
                        if (widget.recommended) ...[
                          SizedBox(height: r.h(4)),
                          LobbyRecommendedChip(accent: theme.accent),
                        ],
                      ],
                    ),
                  ),
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

class _PortalDisc extends StatelessWidget {
  const _PortalDisc({
    required this.roomType,
    required this.diameter,
    required this.locked,
    required this.portalAnimation,
    required this.approach,
    required this.viewerAngle,
    required this.theme,
    required this.washA,
    required this.hardcore,
  });

  final RoomType roomType;
  final double diameter;
  final bool locked;
  final Animation<double> portalAnimation;
  final double approach;
  final double viewerAngle;
  final RoomVisualTheme theme;
  final Color washA;
  final bool hardcore;

  @override
  Widget build(BuildContext context) {
    final paintSize = diameter * 1.45;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: paintSize,
          height: paintSize,
          child: CustomPaint(
            painter: LobbyWormholePainter(
              accent: theme.accent,
              secondary: theme.secondaryAccent,
              locked: locked,
              bloom: washA,
              richness: theme.wormholeRichness,
              ringCount: theme.wormholeRingCount,
              time: portalAnimation.value,
              approach: approach,
              viewerAngle: viewerAngle,
              hardcore: hardcore,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        if (locked)
          Container(
            width: diameter * 0.34,
            height: diameter * 0.34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.5),
              border: Border.all(
                color: theme.accent.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(
              Icons.lock_rounded,
              size: diameter * 0.16,
              color: theme.accent.withValues(alpha: 0.92),
            ),
          ),
      ],
    );
  }
}
