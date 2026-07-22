import 'package:flutter/material.dart';

import '../../services/lang_service.dart';
import '../../utils/responsive_layout.dart';
import '../profile_avatar.dart';

class LobbyTopBar extends StatelessWidget {
  const LobbyTopBar({
    super.key,
    required this.glowAnimation,
    required this.diamonds,
    required this.avatarUrl,
    required this.loading,
    required this.signingOut,
    required this.musicEnabled,
    required this.showAdminPanel,
    required this.unreadMessages,
    required this.onAdminPanelTap,
    required this.onMessagesTap,
    required this.onSoundTap,
    required this.onSettingsTap,
    required this.onSignOutTap,
    required this.onProfileTap,
  });

  final Animation<double> glowAnimation;
  final int diamonds;
  final String? avatarUrl;
  final bool loading;
  final bool signingOut;
  final bool musicEnabled;
  final bool showAdminPanel;
  final int unreadMessages;
  final VoidCallback onAdminPanelTap;
  final VoidCallback onMessagesTap;
  final VoidCallback onSoundTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onSignOutTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final r = ResponsiveLayout.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(r.w(12), r.w(8), r.w(12), r.w(4)),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Container(
                padding: EdgeInsets.all(r.w(4)),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withValues(alpha: 0.035),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: glowAnimation,
                      builder: (context, _) {
                        return LobbyNeonCounter(
                          icon: Icons.diamond_outlined,
                          value: loading ? '—' : '$diamonds',
                          label: lang.t('lobby_diamonds'),
                          glowColor: const Color(0xFF00F0FF),
                          glowIntensity: 0.35 + glowAnimation.value * 0.35,
                          compact: r.isCompact,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: r.w(8)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: r.w(4),
              vertical: r.w(3),
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF0A0A1A).withValues(alpha: 0.72),
              border: Border.all(
                color: const Color(0xFF00F0FF).withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showAdminPanel) ...[
                  LobbyAdminPanelChip(onTap: onAdminPanelTap),
                  SizedBox(width: r.w(2)),
                ],
                LobbyIconButton(
                  tooltip: lang.t('msg_player_title'),
                  onPressed: onMessagesTap,
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.mail_outline_rounded,
                        color: const Color(0xFF00F0FF),
                        size: r.sp(20),
                      ),
                      if (unreadMessages > 0)
                        Positioned(
                          right: -5,
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
                              unreadMessages > 99
                                  ? '99+'
                                  : '$unreadMessages',
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
                LobbyIconButton(
                  tooltip: lang.t('settings_sound_title'),
                  onPressed: onSoundTap,
                  icon: Icon(
                    musicEnabled
                        ? Icons.graphic_eq_rounded
                        : Icons.volume_off_rounded,
                    color: musicEnabled
                        ? const Color(0xFF00F0FF)
                        : Colors.white.withValues(alpha: 0.4),
                    size: r.sp(20),
                  ),
                ),
                LobbyIconButton(
                  tooltip: lang.t('settings_title'),
                  onPressed: onSettingsTap,
                  icon: Icon(
                    Icons.tune_rounded,
                    color: const Color(0xFF00F0FF),
                    size: r.sp(20),
                  ),
                ),
                LobbyIconButton(
                  tooltip: lang.t('sign_out'),
                  onPressed: signingOut ? null : onSignOutTap,
                  icon: signingOut
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: const Color(0xFFFF6688)
                                .withValues(alpha: 0.8),
                          ),
                        )
                      : Icon(
                          Icons.logout_rounded,
                          color:
                              const Color(0xFFFF6688).withValues(alpha: 0.8),
                          size: r.sp(20),
                        ),
                ),
                SizedBox(width: r.w(2)),
                LobbyProfileButton(
                  avatarUrl: avatarUrl,
                  onTap: loading ? null : onProfileTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LobbyAdminPanelChip extends StatelessWidget {
  const LobbyAdminPanelChip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final r = ResponsiveLayout.of(context);
    final compact = r.isCompact;

    return Tooltip(
      message: lang.t('admin_open_panel'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 7 : 9,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF22FFAA).withValues(alpha: 0.45),
              ),
              color: const Color(0xFF22FFAA).withValues(alpha: 0.1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.space_dashboard_outlined,
                  size: 15,
                  color: Color(0xFF22FFAA),
                ),
                if (!compact) ...[
                  const SizedBox(width: 4),
                  Text(
                    lang.t('admin_open_panel'),
                    style: const TextStyle(
                      color: Color(0xFF22FFAA),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LobbyIconButton extends StatelessWidget {
  const LobbyIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: r.w(36),
            height: r.w(36),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}

class LobbyNeonCounter extends StatelessWidget {
  const LobbyNeonCounter({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.glowColor,
    required this.glowIntensity,
    this.compact = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color glowColor;
  final double glowIntensity;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.w(compact ? 8 : 10),
        vertical: r.w(compact ? 5 : 7),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: glowColor.withValues(alpha: 0.07),
        border: Border.all(color: glowColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: glowColor, size: r.sp(compact ? 16 : 18)),
          SizedBox(width: r.w(5)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: glowColor,
                  fontWeight: FontWeight.w800,
                  fontSize: r.sp(compact ? 13 : 15),
                  height: 1.05,
                  letterSpacing: 0.3,
                  shadows: [
                    Shadow(
                      color: glowColor.withValues(alpha: glowIntensity * 0.7),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              if (!compact)
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: glowColor.withValues(alpha: 0.55),
                    fontSize: r.sp(8),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class LobbyProfileButton extends StatelessWidget {
  const LobbyProfileButton({
    super.key,
    required this.avatarUrl,
    required this.onTap,
  });

  final String? avatarUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF00F0FF), Color(0xFFFF00AA)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00F0FF).withValues(alpha: 0.28),
                blurRadius: 10,
              ),
            ],
          ),
          child: ProfileAvatar(
            avatarUrl: avatarUrl,
            radius: r.sp(18),
          ),
        ),
      ),
    );
  }
}
