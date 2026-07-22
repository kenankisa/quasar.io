import 'package:flutter/material.dart';

import '../game/components/cosmic_event_manager.dart';
import '../game/orbit_game.dart';
import 'game_hud_overlay.dart';

/// Full-screen flash and banner for active cosmic events.
///
/// Rebuilds on [OrbitGame.hudTick] — event state (warning countdowns, flash
/// pulses) changes every frame inside the game loop, not via widget phases.
class CosmicEventOverlay extends StatelessWidget {
  const CosmicEventOverlay({super.key, required this.game});

  final OrbitGame game;

  @override
  Widget build(BuildContext context) {
    if (!game.isReady) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<int>(
      valueListenable: game.hudTick,
      builder: (context, _, _) => _CosmicEventOverlayBody(game: game),
    );
  }
}

class _CosmicEventOverlayBody extends StatelessWidget {
  const _CosmicEventOverlayBody({required this.game});

  final OrbitGame game;

  @override
  Widget build(BuildContext context) {
    final manager = game.eventManager;
    // Only pre-event countdowns (meteor / supernova). No merger stage banners.
    final banner = manager.bannerText;
    final flash = manager.flashIntensity;
    final isSupernovaWarning =
        manager.activeEvent == CosmicEventType.supernovaWarning;
    final isEventWarning = manager.isWarningActive;

    return IgnorePointer(
      child: Stack(
        children: [
          if (flash > 0.01)
            Positioned.fill(
              child: ColoredBox(
                color: Color.lerp(
                  Colors.transparent,
                  const Color(0xFFFF1100),
                  (flash * (isSupernovaWarning ? 0.55 : 0.35)).clamp(0.0, 0.75),
                )!,
              ),
            ),
          if (banner != null)
            ValueListenableBuilder<double>(
              valueListenable: GameHudMetrics.toolbarHeight,
              builder: (context, _, _) {
                final screenW = MediaQuery.sizeOf(context).width;
                // Leave side lanes for kill feed (left) / HUD clutter (right).
                final sideGutter = (screenW * 0.22).clamp(72.0, 120.0);
                return Positioned(
                  top: GameHudMetrics.totalTopInset(context) + 6,
                  left: sideGutter,
                  right: sideGutter,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _EventBanner(
                      text: banner,
                      countdown: isEventWarning
                          ? manager.warningCountdownSeconds
                          : null,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _EventBanner extends StatelessWidget {
  const _EventBanner({required this.text, this.countdown});

  final String text;
  final int? countdown;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xD9180508),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFFF3344).withValues(alpha: 0.75),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF2200).withValues(alpha: 0.28),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                countdown != null
                    ? Icons.warning_amber_rounded
                    : Icons.local_fire_department,
                color: const Color(0xFFFF5566),
                size: 16,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFEEAA),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    height: 1.2,
                  ),
                ),
              ),
              if (countdown != null) ...[
                const SizedBox(width: 8),
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF2200).withValues(alpha: 0.22),
                    border: Border.all(
                      color: const Color(0xFFFF5566).withValues(alpha: 0.9),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '$countdown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
