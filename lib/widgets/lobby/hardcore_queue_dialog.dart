import 'dart:async';

import 'package:flutter/material.dart';
import '../../utils/lang_scope.dart';

import '../../utils/lang_rebuild.dart';
import '../../game/models/room_instance.dart';
import '../../services/room_matchmaking_service.dart';

/// Full-screen wait UI while hardcore (max 20) is full.
class HardcoreQueueDialog extends StatefulWidget {
  const HardcoreQueueDialog({
    super.key,
    required this.initialPosition,
  });

  final int initialPosition;

  /// Returns admitted [RoomInstance], or null if cancelled.
  static Future<RoomInstance?> show(
    BuildContext context, {
    required int initialPosition,
  }) {
    return showGeneralDialog<RoomInstance>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Hardcore Queue',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return LangRebuild(
          child: HardcoreQueueDialog(initialPosition: initialPosition),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curve),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<HardcoreQueueDialog> createState() => _HardcoreQueueDialogState();
}

class _HardcoreQueueDialogState extends State<HardcoreQueueDialog> {
  late int _position;
  Timer? _poll;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
    unawaited(_tick());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    if (!mounted || _leaving) return;
    final status =
        await RoomMatchmakingService.instance.getHardcoreQueueStatus();
    if (!mounted || _leaving) return;

    if (status.isAdmitted && status.instance != null) {
      _poll?.cancel();
      // Clear admission row client-side after taking seat.
      unawaited(RoomMatchmakingService.instance.leaveHardcoreQueue());
      if (!mounted) return;
      Navigator.of(context).pop(status.instance);
      return;
    }

    if (status.isQueued && status.position != null) {
      if (status.position != _position) {
        setState(() => _position = status.position!);
      }
      return;
    }

    // Idle unexpectedly — leave dialog.
    if (status.status == 'idle') {
      _poll?.cancel();
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  Future<void> _cancel() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    _poll?.cancel();
    await RoomMatchmakingService.instance.leaveHardcoreQueue();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    const accent = Color(0xFFFF3355);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.sizeOf(context).width * 0.88,
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A0810), Color(0xFF0A0408)],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 28,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.whatshot, color: accent, size: 36),
              const SizedBox(height: 14),
              Text(
                lang.t('hardcore_queue_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                lang.t('hardcore_queue_body'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                lang
                    .t('hardcore_queue_position')
                    .replaceAll('{n}', '$_position'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: accent,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lang.t('hardcore_queue_waiting'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _leaving ? null : _cancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(lang.t('hardcore_queue_cancel')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
