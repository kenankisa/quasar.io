import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/lang_scope.dart';

import '../services/ad_service.dart';
import '../services/admin_access.dart';
import '../services/auth_service.dart';
import '../services/player_session_service.dart';
import '../services/profile_service.dart';
import '../utils/responsive_layout.dart';
import '../utils/diamond_ui.dart';
import 'cosmic_chest_icon.dart';

/// Lobby daily chest — open for configured amounts (server RNG, once per UTC day).
/// Optional rewarded ad doubles the roll (10 / 20 / 30).
class DailyChestDialog extends StatefulWidget {
  const DailyChestDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => const DailyChestDialog(),
    );
  }

  @override
  State<DailyChestDialog> createState() => _DailyChestDialogState();
}

class _DailyChestDialogState extends State<DailyChestDialog>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _claiming = false;
  bool _claimingDouble = false;
  bool _available = false;
  bool _adminBypass = false;
  int? _awarded;
  bool _doubled = false;
  String? _errorKey;
  String? _statusKey;
  late final AnimationController _pulse;

  bool get _adsOk => AdService.instance.adsSupported;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    unawaited(AdService.instance.init());
    unawaited(_loadStatus());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final status = await ProfileService.instance.fetchDailyChestStatus();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _available = status?.available ?? false;
      _adminBypass = status?.adminBypass ?? false;
      if (status == null) {
        _errorKey = 'daily_chest_error';
      }
    });
  }

  void _resetForAdminRetry() {
    setState(() {
      _awarded = null;
      _doubled = false;
      _available = true;
      _statusKey = null;
      _errorKey = null;
      _claiming = false;
      _claimingDouble = false;
    });
  }

  Future<void> _claim({required bool doubled}) async {
    if (_claiming || !_available || _awarded != null) return;
    PlayerSessionService.instance.noteActivity();
    setState(() {
      _claiming = true;
      _claimingDouble = doubled;
      _errorKey = null;
      _statusKey = null;
    });

    var wantDouble = doubled;
    if (wantDouble) {
      if (!_adsOk) {
        // Desktop/web: AdMob yok. Admin QA için 2× reklamsız; diğerleri engellenir.
        if (AdminAccess.isCurrentUserAdmin || _adminBypass) {
          if (mounted) {
            setState(() => _statusKey = 'daily_chest_admin_skip_ad');
          }
        } else {
          if (mounted) {
            setState(() {
              _claiming = false;
              _claimingDouble = false;
              _statusKey = 'daily_chest_ad_unavailable';
            });
          }
          return;
        }
      } else {
        setState(() => _statusKey = 'daily_chest_ad_loading');
        PlayerSessionService.instance.setMatchIdlePaused(true);
        bool earned = false;
        try {
          if (AdService.instance.isUsingTestDoubleAdUnit) {
            debugPrint(
              'DailyChestDialog: showing TEST AdMob unit — '
              'use dart_defines.prod.json for store builds',
            );
          }
          earned = await AdService.instance.showRewardedDoubleAd(
            ssvUserId: AuthService.instance.currentUser?.id,
          );
        } finally {
          PlayerSessionService.instance.setMatchIdlePaused(false);
        }

        if (!earned) {
          if (mounted) {
            setState(() {
              _claiming = false;
              _claimingDouble = false;
              _statusKey = 'daily_chest_ad_failed';
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() => _statusKey = 'daily_chest_opening');
      }
    }

    final result = await ProfileService.instance.claimDailyLobbyChest(
      doubled: wantDouble,
    );
    if (!mounted) return;

    if (result.ok && result.awarded != null) {
      setState(() {
        _claiming = false;
        _claimingDouble = false;
        _available = result.adminBypass;
        _adminBypass = result.adminBypass;
        _awarded = result.awarded;
        _doubled = result.doubled;
        _statusKey = null;
      });
      return;
    }

    setState(() {
      _claiming = false;
      _claimingDouble = false;
      _available = false;
      _statusKey = null;
      _errorKey = result.reason == 'already_claimed'
          ? 'daily_chest_already'
          : 'daily_chest_error';
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final r = ResponsiveLayout.of(context);
    final accent = const Color(0xFFFFD24A);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: r.w(28)),
      child: Container(
        padding: EdgeInsets.fromLTRB(r.w(22), r.h(22), r.w(22), r.h(18)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF0A0A1A).withValues(alpha: 0.96),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final ready = _available && _awarded == null;
                final blink = ready ? (0.45 + _pulse.value * 0.55) : 0.55;
                final glow = ready ? (0.3 + _pulse.value * 0.55) : 0.08;
                return Container(
                  width: r.w(88),
                  height: r.w(88),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFD24A).withValues(
                      alpha: ready ? 0.08 + _pulse.value * 0.08 : 0.04,
                    ),
                    border: Border.all(
                      color: const Color(0xFFFFD24A).withValues(
                        alpha: ready ? 0.35 + _pulse.value * 0.4 : 0.14,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD24A).withValues(alpha: glow),
                        blurRadius: ready ? 24 : 8,
                      ),
                    ],
                  ),
                  child: CosmicChestIcon(
                    size: r.w(54),
                    lit: ready || _awarded != null,
                    opacity: blink,
                  ),
                );
              },
            ),
            SizedBox(height: r.h(16)),
            Text(
              lang.t('daily_chest_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: r.sp(18),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            SizedBox(height: r.h(8)),
            Text(
              _awarded != null
                  ? lang
                      .t(
                        _doubled
                            ? 'daily_chest_opened_doubled'
                            : 'daily_chest_opened',
                      )
                      .replaceAll('{diamonds}', '${_awarded!}')
                  : _available
                      ? lang.t('daily_chest_body')
                      : lang.t(
                          _errorKey == 'daily_chest_error'
                              ? 'daily_chest_error'
                              : 'daily_chest_already',
                        ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: r.sp(13),
                height: 1.35,
              ),
            ),
            if (_available && _awarded == null) ...[
              SizedBox(height: r.h(10)),
              Text(
                lang.t('daily_chest_double_hint'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accent.withValues(alpha: 0.9),
                  fontSize: r.sp(12),
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_statusKey != null) ...[
              SizedBox(height: r.h(8)),
              Text(
                lang.t(_statusKey!),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: r.sp(11),
                ),
              ),
            ],
            if (_awarded != null) ...[
              SizedBox(height: r.h(14)),
              DiamondAmount(
                amount: _awarded!,
                prefix: '+',
                fontSize: r.sp(36),
                fontWeight: FontWeight.w900,
                iconSize: r.sp(38),
                spacing: r.w(6),
              ),
              Text(
                lang.t('lobby_diamonds'),
                style: TextStyle(
                  color: kDiamondColor.withValues(alpha: 0.7),
                  fontSize: r.sp(11),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
            SizedBox(height: r.h(18)),
            if (_loading)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Color(0xFFFFD24A),
                ),
              )
            else if (_awarded != null) ...[
              if (_adminBypass) ...[
                _ChestActionButton(
                  label: lang.t('daily_chest_admin_again'),
                  filled: true,
                  onTap: _resetForAdminRetry,
                ),
                SizedBox(height: r.h(8)),
              ],
              _ChestActionButton(
                label: lang.t('daily_chest_close'),
                filled: false,
                onTap: () => Navigator.of(context).pop(),
              ),
            ]
            else if (_available) ...[
              _ChestActionButton(
                label: _claiming && _claimingDouble
                    ? lang.t('daily_chest_opening')
                    : lang.t('daily_chest_open_double'),
                filled: true,
                busy: _claiming && _claimingDouble,
                onTap: _claiming ? null : () => _claim(doubled: true),
              ),
              SizedBox(height: r.h(8)),
              _ChestActionButton(
                label: _claiming && !_claimingDouble
                    ? lang.t('daily_chest_opening')
                    : lang.t('daily_chest_open_normal'),
                filled: false,
                busy: _claiming && !_claimingDouble,
                onTap: _claiming ? null : () => _claim(doubled: false),
              ),
            ] else
              _ChestActionButton(
                label: lang.t('daily_chest_close'),
                filled: false,
                onTap: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChestActionButton extends StatelessWidget {
  const _ChestActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final bool filled;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    final accent = const Color(0xFFFFD24A);
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: r.h(12)),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: filled
                  ? accent.withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: filled
                    ? accent
                    : Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: filled ? Colors.black : accent,
                    ),
                  )
                : Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: filled ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: r.sp(13),
                      letterSpacing: 0.4,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
