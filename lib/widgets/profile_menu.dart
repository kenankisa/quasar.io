import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/lang_service.dart';
import '../services/profile_service.dart';
import '../utils/player_rank.dart';
import 'bot_name_badge.dart';
import 'edit_profile_dialog.dart';
import 'global_rank_dialog.dart';
import 'profile_avatar.dart';
import 'rank_system_dialog.dart';

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
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ProfileMenu(
          profile: profile,
          onProfileChanged: onProfileChanged,
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
    final lang = LanguageService.instance;
    final size = MediaQuery.sizeOf(context);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: size.width * 0.9,
          height: size.height * 0.72,
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF12122A).withValues(alpha: 0.95),
                const Color(0xFF0A0A1A).withValues(alpha: 0.98),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF00F0FF).withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00F0FF).withValues(alpha: 0.15),
                blurRadius: 30,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: const Color(0xFFFF00AA).withValues(alpha: 0.1),
                blurRadius: 40,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            lang.t('profile_stats_tab'),
                            style: const TextStyle(
                              color: Color(0xFF00F0FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white12),
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
            ),
          ),
        ),
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
    final lang = LanguageService.instance;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          GestureDetector(
            onTap: onEditProfile,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _AvatarGlow(avatarUrl: profile.avatarUrl),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00F0FF),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF0A0A1A),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.edit,
                      size: 16,
                      color: Color(0xFF0A0A1A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  profile.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF00F0FF)),
                tooltip: lang.t('profile_edit'),
                onPressed: onEditProfile,
              ),
            ],
          ),
          const SizedBox(height: 28),
          _StatCard(
            icon: Icons.emoji_events_outlined,
            label: lang.t('profile_games_won'),
            value: '${profile.gamesWon}',
            accentColor: const Color(0xFFFFAA00),
          ),
          const SizedBox(height: 12),
          _StatCard(
            icon: Icons.public,
            label: lang.t('profile_global_rank'),
            value: loadingRank
                ? '...'
                : globalRank != null
                    ? '#$globalRank'
                    : '—',
            accentColor: const Color(0xFF00F0FF),
            isHighlighted: true,
            onTap: () => GlobalRankDialog.show(context),
            trailing: const Icon(
              Icons.chevron_right,
              color: Color(0xFF00F0FF),
              size: 22,
            ),
          ),
          const SizedBox(height: 12),
          _RankSystemCard(
            rankPoints: profile.rankPoints,
            onTap: () => RankSystemDialog.show(
              context,
              playerRankPoints: profile.rankPoints,
            ),
          ),
          const SizedBox(height: 24),
          _MiniCurrency(
            icon: Icons.diamond_outlined,
            value: '${profile.diamonds}',
            color: const Color(0xFF00F0FF),
            label: lang.t('lobby_diamonds'),
          ),
        ],
      ),
    );
  }
}

class _RankSystemCard extends StatelessWidget {
  const _RankSystemCard({
    required this.rankPoints,
    required this.onTap,
  });

  final int rankPoints;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final tier = playerRankForPoints(rankPoints);
    const accent = Color(0xFFFFD54F);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                tier.glowColor.withValues(alpha: 0.16),
                const Color(0xFF0A0A1A).withValues(alpha: 0.6),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.12),
                blurRadius: 16,
              ),
            ],
          ),
          child: Row(
            children: [
              PlayerRankBadge(tier: tier, size: 18, compact: false),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.t('profile_rank_system'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tier.localizedName(lang),
                      style: TextStyle(
                        color: tier.letterColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: accent,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarGlow extends StatelessWidget {
  const _AvatarGlow({this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00F0FF).withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: const Color(0xFFFF00AA).withValues(alpha: 0.2),
            blurRadius: 32,
          ),
        ],
      ),
      child: ProfileAvatar(
        avatarUrl: avatarUrl,
        radius: 52,
        iconSize: 48,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
    this.isHighlighted = false,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;
  final bool isHighlighted;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: isHighlighted ? 0.15 : 0.08),
            const Color(0xFF0A0A1A).withValues(alpha: 0.6),
          ],
        ),
        border: Border.all(
          color: accentColor.withValues(alpha: isHighlighted ? 0.5 : 0.25),
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.15),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: accentColor,
              fontSize: isHighlighted ? 26 : 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

class _MiniCurrency extends StatelessWidget {
  const _MiniCurrency({
    required this.icon,
    required this.value,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final String value;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
