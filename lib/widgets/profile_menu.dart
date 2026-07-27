import 'package:flutter/material.dart';

import '../utils/lang_rebuild.dart';
import '../utils/lang_scope.dart';
import '../services/profile_service.dart';
import '../utils/player_rank.dart';
import 'bot_name_badge.dart';
import 'edit_profile_dialog.dart';
import 'global_rank_dialog.dart';
import 'profile/profile_cosmic_ui.dart';
import 'rank_system_dialog.dart';
import 'universe_trophies_dialog.dart';

class ProfileMenu extends StatefulWidget {
  const ProfileMenu({
    super.key,
    required this.profile,
    required this.onProfileChanged,
  });

  final PlayerProfile profile;
  final VoidCallback onProfileChanged;

  static Future<void> show(
    BuildContext context, {
    required PlayerProfile profile,
    required VoidCallback onProfileChanged,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Profile',
      barrierColor: Colors.black.withValues(alpha: 0.62),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return LangRebuild(
          child: ProfileMenu(
            profile: profile,
            onProfileChanged: onProfileChanged,
          ),
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
            scale: Tween<double>(begin: 0.92, end: 1).animate(curve),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<ProfileMenu> createState() => _ProfileMenuState();
}

class _ProfileMenuState extends State<ProfileMenu> {
  late PlayerProfile _profile;
  int? _globalRank;
  bool _loadingRank = true;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    ProfileService.instance.profileNotifier.addListener(_onProfileNotifierChanged);
    _loadRank();
  }

  void _onProfileNotifierChanged() {
    final updated = ProfileService.instance.profileNotifier.value;
    if (updated != null && mounted) {
      setState(() => _profile = updated);
    }
  }

  @override
  void dispose() {
    ProfileService.instance.profileNotifier
        .removeListener(_onProfileNotifierChanged);
    super.dispose();
  }

  Future<void> _loadRank() async {
    final rank = await ProfileService.instance.fetchGlobalRank();
    if (mounted) {
      setState(() {
        _globalRank = rank;
        _loadingRank = false;
      });
    }
  }

  void _handleProfileChanged() async {
    widget.onProfileChanged();
    final updated = await ProfileService.instance.fetchProfile();
    if (updated != null && mounted) {
      setState(() => _profile = updated);
    }
  }

  Future<void> _openEditProfile() async {
    final saved = await EditProfileDialog.show(context, _profile);
    if (saved == true) {
      _handleProfileChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;

    return ProfileCosmicDialogFrame(
      child: Column(
        children: [
          ProfileCosmicHeader(
            title: lang.t('profile_stats_tab'),
            onClose: () => Navigator.of(context).pop(),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0x2244DDEE)),
          Expanded(
            child: _StatsTab(
              profile: _profile,
              globalRank: _globalRank,
              loadingRank: _loadingRank,
              onEditProfile: _openEditProfile,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsTab extends StatelessWidget {
  const _StatsTab({
    required this.profile,
    required this.globalRank,
    required this.loadingRank,
    required this.onEditProfile,
  });

  final PlayerProfile profile;
  final int? globalRank;
  final bool loadingRank;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final tier = playerRankForPoints(
      profile.rankPoints,
      username: profile.username,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        children: [
          ProfileOrbitAvatar(
            avatarUrl: profile.avatarUrl,
            onTap: onEditProfile,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: ProfileCosmicTitle(
                  text: profile.username,
                  fontSize: 22,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF00F0FF)),
                tooltip: lang.t('profile_edit'),
                onPressed: onEditProfile,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 6),
          PlayerRankBadge(tier: tier, size: 14, compact: true),
          const SizedBox(height: 24),
          ProfileCosmicStatTile(
            icon: Icons.emoji_events_outlined,
            label: lang.t('profile_games_won'),
            value: '${profile.gamesWon}',
            accent: const Color(0xFFFFAA00),
            secondary: const Color(0xFFFF6B18),
          ),
          const SizedBox(height: 10),
          ProfileCosmicStatTile(
            icon: Icons.whatshot_rounded,
            label: lang.t('profile_hardcore_points'),
            value: '${profile.hardcorePoints}',
            accent: const Color(0xFFFF3355),
            secondary: const Color(0xFFFF6B18),
          ),
          const SizedBox(height: 10),
          _UniverseTrophiesCard(profile: profile),
          const SizedBox(height: 10),
          ProfileCosmicStatTile(
            icon: Icons.public_rounded,
            label: lang.t('profile_global_rank'),
            value: loadingRank
                ? '...'
                : globalRank != null
                    ? '#$globalRank'
                    : '—',
            accent: const Color(0xFF00F0FF),
            highlighted: true,
            onTap: () => GlobalRankDialog.show(context),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF00F0FF),
              size: 22,
            ),
          ),
          const SizedBox(height: 10),
          _RankSystemCard(
            rankPoints: profile.rankPoints,
            username: profile.username,
            onTap: () => RankSystemDialog.show(
              context,
              playerRankPoints: profile.rankPoints,
              username: profile.username,
            ),
          ),
          const SizedBox(height: 22),
          ProfileCosmicCurrencyPill(
            value: '${profile.diamonds}',
            label: lang.t('lobby_diamonds'),
          ),
        ],
      ),
    );
  }
}

class _UniverseTrophiesCard extends StatelessWidget {
  const _UniverseTrophiesCard({required this.profile});

  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final earned = profile.totalUniverseTrophies;
    final cap = PlayerProfile.hardcoreTrophyRequirement;
    final progress = (earned / cap).clamp(0.0, 1.0);
    final cupsComplete = profile.hasHardcoreTrophyUnlock;
    const accent = Color(0xFFFFD54F);
    final fill = cupsComplete ? const Color(0xFF22FFAA) : accent;
    final hint = cupsComplete
        ? lang.t('profile_hardcore_unlocked')
        : lang
            .t('profile_hardcore_locked')
            .replaceAll('{remaining}', '${(cap - earned).clamp(0, cap)}')
            .replaceAll('{cap}', '$cap');

    return ProfileCosmicStatTile(
      icon: Icons.emoji_events_rounded,
      label: lang.t('profile_universe_trophies'),
      value: '$earned / $cap',
      accent: fill,
      secondary: const Color(0xFFFFAA00),
      onTap: () => UniverseTrophiesDialog.show(context, profile: profile),
      trailing: Icon(Icons.chevron_right_rounded, color: fill, size: 22),
      child: Tooltip(
        message: lang
            .t('profile_universe_trophies_tooltip')
            .replaceAll('{earned}', '$earned')
            .replaceAll('{cap}', '$cap'),
        waitDuration: const Duration(milliseconds: 280),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ProfileTrophyCup(active: earned > 0, unlocked: false),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lang.t('profile_universe_trophies'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$earned / $cap',
                  style: TextStyle(
                    color: fill,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, color: fill, size: 22),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                color: fill,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTrophyCup extends StatelessWidget {
  const _ProfileTrophyCup({
    required this.active,
    required this.unlocked,
  });

  final bool active;
  final bool unlocked;

  static const _litGold = Color(0xFFFFD54F);

  @override
  Widget build(BuildContext context) {
    final color = active
        ? (unlocked ? const Color(0xFF7CFFB2) : _litGold)
        : Colors.white.withValues(alpha: 0.22);
    final ring = active
        ? (unlocked
            ? const Color(0xFF7CFFB2).withValues(alpha: 0.65)
            : _litGold.withValues(alpha: 0.65))
        : Colors.white.withValues(alpha: 0.28);
    final bg = active
        ? (unlocked
            ? const Color(0xFF7CFFB2).withValues(alpha: 0.16)
            : _litGold.withValues(alpha: 0.16))
        : Colors.white.withValues(alpha: 0.04);

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: ring),
      ),
      child: Icon(Icons.emoji_events_rounded, size: 17, color: color),
    );
  }
}

class _RankSystemCard extends StatelessWidget {
  const _RankSystemCard({
    required this.rankPoints,
    required this.username,
    required this.onTap,
  });

  final int rankPoints;
  final String username;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final tier = playerRankForPoints(rankPoints, username: username);

    return ProfileCosmicStatTile(
      icon: Icons.military_tech_rounded,
      label: lang.t('profile_rank_system'),
      value: '',
      accent: tier.glowColor,
      secondary: const Color(0xFFFFD54F),
      onTap: onTap,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: tier.glowColor,
        size: 22,
      ),
      child: Row(
        children: [
          PlayerRankBadge(tier: tier, size: 18, compact: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.t('profile_rank_system'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tier.localizedName(lang),
                  style: TextStyle(
                    color: tier.letterColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: tier.glowColor, size: 22),
        ],
      ),
    );
  }
}
