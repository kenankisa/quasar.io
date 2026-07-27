import 'package:flutter/material.dart';

import '../game/models/live_announcement.dart';
import '../services/lang_service.dart';
import '../services/live_announcement_service.dart';
import '../utils/player_name.dart';

/// Maç/lobi kontrollerini engellemeyen üst duyuru balonları.
/// Aynı anda en fazla [LiveAnnouncementService.maxVisible] (fazlası sırada).
class LiveAnnouncementOverlay extends StatelessWidget {
  const LiveAnnouncementOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        LiveAnnouncementService.instance,
        LanguageService.instance,
      ]),
      builder: (context, _) {
        final items = LiveAnnouncementService.instance.visible;

        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (items.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < items.length; i++) ...[
                            if (i > 0) const SizedBox(height: 6),
                            _AnnouncementBubble(
                              key: ValueKey(items[i].id),
                              announcement: items[i],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AnnouncementBubble extends StatefulWidget {
  const _AnnouncementBubble({super.key, required this.announcement});

  final LiveAnnouncement announcement;

  @override
  State<_AnnouncementBubble> createState() => _AnnouncementBubbleState();
}

class _AnnouncementBubbleState extends State<_AnnouncementBubble>
    with TickerProviderStateMixin {
  static const _adminAccent = Color(0xFFFFC857);
  static const _hardcoreAccent = Color(0xFFFF5A6A);

  late final AnimationController _enter;
  late final AnimationController _progress;
  late final AnimationController _pulse;

  late final Animation<double> _enterScale;
  late final Animation<double> _enterFade;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _enterScale = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0, 0.85, curve: Curves.easeOutBack),
    );
    _enterFade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0, 0.55, curve: Curves.easeOut),
    );

    final remaining = widget.announcement.remaining;
    _progress = AnimationController(
      vsync: this,
      duration: remaining > Duration.zero
          ? remaining
          : const Duration(milliseconds: 1),
    )..value = 1;

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _enter.forward();
    if (remaining > Duration.zero) {
      _progress.animateTo(0, curve: Curves.linear);
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _progress.dispose();
    _pulse.dispose();
    super.dispose();
  }

  String _resolvedBody() {
    final winner = widget.announcement.hardcoreWinnerName;
    if (winner != null) {
      return LanguageService.instance
          .t('live_announce_hardcore_win')
          .replaceAll('{name}', clampPlayerName(winner));
    }
    return widget.announcement.body;
  }

  @override
  Widget build(BuildContext context) {
    final body = _resolvedBody();
    final isHc = widget.announcement.isHardcoreWin;
    final accent = isHc ? _hardcoreAccent : _adminAccent;

    return Align(
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _enterFade,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(_enterScale),
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AnimatedBuilder(
              animation: Listenable.merge([_progress, _pulse]),
              builder: (context, _) {
                final pulse = 0.35 + _pulse.value * 0.45;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF141018).withValues(alpha: 0.94),
                        const Color(0xFF0A0A1A).withValues(alpha: 0.9),
                      ],
                    ),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.42 + pulse * 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.12 + pulse * 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accent.withValues(alpha: 0.12),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.35),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withValues(
                                        alpha: 0.15 + pulse * 0.2,
                                      ),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isHc
                                      ? Icons.workspace_premium_rounded
                                      : Icons.campaign_rounded,
                                  color: accent.withValues(
                                    alpha: 0.75 + pulse * 0.25,
                                  ),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  body,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 3,
                          child: LinearProgressIndicator(
                            value: _progress.value.clamp(0.0, 1.0),
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.06),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              accent.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
