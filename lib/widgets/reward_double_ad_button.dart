import 'dart:async';

import 'package:flutter/material.dart';

import '../services/ad_service.dart';
import '../services/lang_service.dart';
import '../services/player_session_service.dart';
import '../services/profile_service.dart';

/// Rewarded ad CTA that doubles an already-claimed match diamond reward.
class RewardDoubleAdButton extends StatefulWidget {
  const RewardDoubleAdButton({
    super.key,
    required this.baseDiamonds,
    required this.ensureBaseClaimed,
    required this.prepareSession,
    required this.attestSession,
    required this.claimDouble,
    this.primaryColor = const Color(0xFFFFD700),
    this.foregroundColor = Colors.black,
  });

  final int baseDiamonds;
  final Future<bool> Function() ensureBaseClaimed;
  final Future<String?> Function() prepareSession;
  final Future<bool> Function(String sessionId) attestSession;
  final Future<PlayerProfile?> Function(String sessionId) claimDouble;
  final Color primaryColor;
  final Color foregroundColor;

  @override
  State<RewardDoubleAdButton> createState() => _RewardDoubleAdButtonState();
}

class _RewardDoubleAdButtonState extends State<RewardDoubleAdButton> {
  @override
  void initState() {
    super.initState();
    unawaited(AdService.instance.init());
  }

  bool _busy = false;
  bool _doubled = false;
  bool _pendingGrant = false;
  String? _sessionId;
  String? _statusKey;

  int get _total => widget.baseDiamonds * 2;

  Future<void> _onPressed() async {
    if (_busy || _doubled || widget.baseDiamonds <= 0) return;
    PlayerSessionService.instance.noteActivity();
    setState(() {
      _busy = true;
      _statusKey = null;
    });

    try {
      if (!_pendingGrant) {
        final claimed = await widget.ensureBaseClaimed();
        if (!claimed) {
          if (mounted) {
            setState(() => _statusKey = 'reward_double_claim_wait');
          }
          return;
        }

        if (!AdService.instance.adsSupported) {
          if (mounted) {
            setState(() => _statusKey = 'reward_double_unavailable');
          }
          return;
        }

        if (mounted) {
          setState(() => _statusKey = 'reward_double_loading');
        }

        final sessionId = await widget.prepareSession();
        if (sessionId == null || sessionId.isEmpty) {
          if (mounted) {
            setState(() => _statusKey = 'reward_double_grant_failed');
          }
          return;
        }
        _sessionId = sessionId;

        PlayerSessionService.instance.setMatchIdlePaused(true);
        bool earned = false;
        try {
          earned = await AdService.instance.showRewardedDoubleAd();
        } finally {
          PlayerSessionService.instance.setMatchIdlePaused(false);
        }
        if (!earned) {
          if (mounted) {
            setState(() => _statusKey = 'reward_double_ad_failed');
          }
          return;
        }

        final attested = await widget.attestSession(sessionId);
        if (!attested) {
          if (mounted) {
            setState(() => _statusKey = 'reward_double_grant_failed');
          }
          return;
        }
        _pendingGrant = true;
      }

      final sessionId = _sessionId;
      if (sessionId == null || sessionId.isEmpty) {
        if (mounted) {
          setState(() {
            _pendingGrant = false;
            _statusKey = 'reward_double_grant_failed';
          });
        }
        return;
      }

      if (mounted) {
        setState(() => _statusKey = 'reward_double_claiming');
      }

      final profile = await widget.claimDouble(sessionId);
      if (profile != null) {
        _pendingGrant = false;
        _sessionId = null;
        if (mounted) {
          setState(() {
            _doubled = true;
            _statusKey = null;
          });
        }
        return;
      }

      if (mounted) {
        setState(() => _statusKey = 'reward_double_grant_failed');
      }
    } catch (e, st) {
      debugPrint('RewardDoubleAdButton: $e\n$st');
      PlayerSessionService.instance.setMatchIdlePaused(false);
      final msg = e.toString().toLowerCase();
      String key = _pendingGrant
          ? 'reward_double_grant_failed'
          : 'reward_double_ad_failed';
      if (msg.contains('ad_watch_too_short') ||
          msg.contains('ad_not_attested')) {
        key = 'reward_double_claim_wait';
      } else if (msg.contains('ad_double_daily_limit') ||
          msg.contains('ad_session') ||
          msg.contains('ad_double_expired')) {
        key = 'reward_double_grant_failed';
      }
      if (mounted) {
        setState(() => _statusKey = key);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      } else {
        _busy = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final total = _total;
    final extra = widget.baseDiamonds;

    if (_doubled) {
      return Column(
        children: [
          Text(
            lang
                .t('reward_double_done')
                .replaceAll('{total}', '$total'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    final label = _pendingGrant
        ? lang.t('reward_double_retry_grant')
        : lang.t('reward_double_cta');

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy ? null : _onPressed,
            icon: _busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.foregroundColor,
                    ),
                  )
                : const Icon(Icons.ondemand_video_rounded, size: 20),
            label: Text(label),
            style: FilledButton.styleFrom(
              backgroundColor: widget.primaryColor,
              foregroundColor: widget.foregroundColor,
              disabledBackgroundColor:
                  widget.primaryColor.withValues(alpha: 0.45),
              disabledForegroundColor:
                  widget.foregroundColor.withValues(alpha: 0.7),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          lang
              .t('reward_double_micro')
              .replaceAll('{extra}', '$extra')
              .replaceAll('{total}', '$total'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 12,
            height: 1.3,
          ),
        ),
        if (_statusKey != null) ...[
          const SizedBox(height: 8),
          Text(
            lang.t(_statusKey!),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFFFF00AA).withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
