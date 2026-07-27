import 'package:flutter/material.dart';
import '../../utils/lang_scope.dart';

import '../../utils/responsive_layout.dart';
import '../daily_chest_lobby_button.dart';
import '../profile_avatar.dart';
import 'lobby_cosmic_chrome.dart';

/// Single-row lobby header — profile, brand, economy, quick actions.
class LobbyCompactHeader extends StatelessWidget {
  const LobbyCompactHeader({
    super.key,
    required this.diamonds,
    this.matchDayEarned,
    this.matchDayCap,
    this.onlineCount,
    required this.avatarUrl,
    required this.loading,
    required this.unreadMessages,
    required this.dailyChestAvailable,
    this.dailyChestNextAvailableAt,
    required this.onDailyChestTap,
    required this.onMessagesTap,
    required this.onSettingsTap,
    required this.onMenuTap,
    required this.onProfileTap,
  });

  final int diamonds;
  final int? matchDayEarned;
  final int? matchDayCap;
  final int? onlineCount;
  final String? avatarUrl;
  final bool loading;
  final int unreadMessages;
  final bool? dailyChestAvailable;
  final DateTime? dailyChestNextAvailableAt;
  final VoidCallback onDailyChestTap;
  final VoidCallback onMessagesTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onMenuTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final r = ResponsiveLayout.of(context);
    final compact = r.isCompact;
    final showMatchDay = !loading &&
        matchDayEarned != null &&
        matchDayCap != null &&
        matchDayCap! > 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        r.w(compact ? 10 : 14),
        r.w(compact ? 6 : 8),
        r.w(compact ? 10 : 14),
        r.w(4),
      ),
      child: LobbyCosmicPanel(
        borderRadius: 16,
        padding: EdgeInsets.fromLTRB(
          r.w(compact ? 8 : 10),
          r.w(compact ? 8 : 10),
          r.w(compact ? 6 : 8),
          r.w(compact ? 8 : 10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _ProfileTap(
                  avatarUrl: avatarUrl,
                  loading: loading,
                  onTap: onProfileTap,
                ),
                SizedBox(width: r.w(8)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BrandMark(compact: compact),
                      SizedBox(height: r.h(2)),
                      _OnlineChip(count: onlineCount, compact: compact),
                    ],
                  ),
                ),
                _DiamondChip(
                  value: loading ? '—' : '$diamonds',
                  compact: compact,
                ),
                SizedBox(width: r.w(6)),
                DailyChestLobbyButton(
                  available: !loading && dailyChestAvailable == true,
                  nextAvailableAt: dailyChestNextAvailableAt,
                  onTap: loading ? null : onDailyChestTap,
                  compact: true,
                ),
                _HeaderIconButton(
                  tooltip: lang.t('msg_player_title'),
                  onTap: onMessagesTap,
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.mail_outline_rounded,
                        color: const Color(0xFF00F0FF),
                        size: r.sp(compact ? 18 : 20),
                      ),
                      if (unreadMessages > 0)
                        Positioned(
                          right: -6,
                          top: -5,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 14),
                            height: 14,
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4466),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF4466)
                                      .withValues(alpha: 0.45),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Text(
                              unreadMessages > 99 ? '99+' : '$unreadMessages',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _HeaderIconButton(
                  tooltip: lang.t('settings_title'),
                  onTap: onSettingsTap,
                  icon: Icon(
                    Icons.tune_rounded,
                    color: const Color(0xFF00F0FF),
                    size: r.sp(compact ? 18 : 20),
                  ),
                ),
                _HeaderIconButton(
                  tooltip: lang.t('lobby_menu_more'),
                  onTap: onMenuTap,
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: const Color(0xFF00F0FF),
                    size: r.sp(compact ? 20 : 22),
                  ),
                ),
              ],
            ),
            if (showMatchDay) ...[
              SizedBox(height: r.h(8)),
              _MatchDayStrip(earned: matchDayEarned!, cap: matchDayCap!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileTap extends StatelessWidget {
  const _ProfileTap({
    required this.avatarUrl,
    required this.loading,
    required this.onTap,
  });

  final String? avatarUrl;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF00F0FF), Color(0xFFFF00AA)],
            ),
          ),
          child: ProfileAvatar(
            avatarUrl: avatarUrl,
            radius: r.sp(r.isCompact ? 15 : 17),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    final fontSize = r.sp(compact ? 15 : 17);
    const cyan = Color(0xFF00F0FF);
    const magenta = Color(0xFFFF2D95);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Text(
          'Quasar.io',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: Colors.transparent,
            shadows: [
              Shadow(color: cyan.withValues(alpha: 0.35), blurRadius: 10),
              Shadow(color: magenta.withValues(alpha: 0.2), blurRadius: 14),
            ],
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return const LinearGradient(
              colors: [cyan, Color(0xFF80E8FF), magenta],
              stops: [0.0, 0.55, 1.0],
            ).createShader(bounds);
          },
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Quasar',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
                TextSpan(
                  text: '.io',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OnlineChip extends StatelessWidget {
  const _OnlineChip({required this.count, required this.compact});

  final int? count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final r = ResponsiveLayout.of(context);
    final label = count == null
        ? '—'
        : (count! > 9999 ? '9999+' : '$count');

    return Tooltip(
      message: lang.t('lobby_online_tooltip'),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: r.w(6),
          vertical: r.w(2),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: const Color(0xFF22FFAA).withValues(alpha: 0.08),
          border: Border.all(
            color: const Color(0xFF22FFAA).withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF22FFAA),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22FFAA).withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            SizedBox(width: r.w(4)),
            Text(
              '$label ${lang.t('lobby_online_label').toLowerCase()}',
              style: TextStyle(
                color: const Color(0xFF22FFAA).withValues(alpha: 0.9),
                fontSize: r.sp(compact ? 10 : 11),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiamondChip extends StatelessWidget {
  const _DiamondChip({required this.value, required this.compact});

  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.w(compact ? 7 : 9),
        vertical: r.w(compact ? 5 : 6),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00F0FF).withValues(alpha: 0.18),
            const Color(0xFF00F0FF).withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF00F0FF).withValues(alpha: 0.38),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00F0FF).withValues(alpha: 0.12),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.diamond_outlined,
            color: const Color(0xFF00F0FF),
            size: r.sp(compact ? 14 : 16),
          ),
          SizedBox(width: r.w(4)),
          Text(
            value,
            style: TextStyle(
              color: const Color(0xFF00F0FF),
              fontWeight: FontWeight.w800,
              fontSize: r.sp(compact ? 12 : 13.5),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.onTap,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: r.w(34),
            height: r.w(34),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFF00F0FF).withValues(alpha: 0.06),
              border: Border.all(
                color: const Color(0xFF00F0FF).withValues(alpha: 0.18),
              ),
            ),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}

class _MatchDayStrip extends StatelessWidget {
  const _MatchDayStrip({required this.earned, required this.cap});

  final int earned;
  final int cap;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final r = ResponsiveLayout.of(context);
    final progress = (earned / cap).clamp(0.0, 1.0);
    final full = progress >= 1.0;
    final color = full
        ? const Color(0xFFFF6688)
        : progress >= 0.75
            ? const Color(0xFFFFD24A)
            : const Color(0xFF00F0FF);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.w(10),
        vertical: r.w(7),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.diamond_rounded, size: 12, color: color),
          SizedBox(width: r.w(6)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                color: color,
              ),
            ),
          ),
          SizedBox(width: r.w(8)),
          Text(
            lang
                .t('match_day_diamond_progress')
                .replaceAll('{earned}', '$earned')
                .replaceAll('{cap}', '$cap'),
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontSize: r.sp(10),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
