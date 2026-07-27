import 'dart:ui';

import 'package:flutter/material.dart';

import '../../services/settings_service.dart';
import '../../utils/diamond_ui.dart';
import '../lobby/lobby_cosmic_chrome.dart';
import '../profile_avatar.dart';

/// Full-screen cosmic dialog shell — nebula wash, star dust, glass edge.
class ProfileCosmicDialogFrame extends StatelessWidget {
  const ProfileCosmicDialogFrame({
    super.key,
    required this.child,
    this.widthFactor = 0.9,
    this.heightFactor = 0.72,
    this.maxWidth = 420,
    this.maxHeight = 620,
    this.accent = const Color(0xFF00F0FF),
    this.secondary = const Color(0xFF8868FF),
    this.intrinsicHeight = false,
  });

  final Widget child;
  final double widthFactor;
  final double heightFactor;
  final double maxWidth;
  final double maxHeight;
  final Color accent;
  final Color secondary;

  /// When true, height follows content instead of [heightFactor].
  final bool intrinsicHeight;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final lowPerf = SettingsService.instance.lowPerformanceMode;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: size.width * widthFactor,
          height: intrinsicHeight ? null : size.height * heightFactor,
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accent.withValues(alpha: 0.32)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 32,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: secondary.withValues(alpha: 0.12),
                blurRadius: 48,
                spreadRadius: -4,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF0C1438).withValues(alpha: 0.94),
                          const Color(0xFF060818).withValues(alpha: 0.97),
                          const Color(0xFF120A28).withValues(alpha: 0.96),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -40,
                    top: -48,
                    child: _NebulaOrb(color: accent, size: 160, alpha: 0.16),
                  ),
                  Positioned(
                    left: -36,
                    bottom: -40,
                    child: _NebulaOrb(
                      color: secondary,
                      size: 130,
                      alpha: 0.12,
                    ),
                  ),
                  Positioned(
                    right: 40,
                    bottom: 80,
                    child: _NebulaOrb(
                      color: const Color(0xFFFF2D95),
                      size: 72,
                      alpha: 0.08,
                    ),
                  ),
                  if (!lowPerf)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: LobbyChromeStarDustPainter(accent: accent),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 0,
                    left: 20,
                    right: 20,
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            accent.withValues(alpha: 0.55),
                            secondary.withValues(alpha: 0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NebulaOrb extends StatelessWidget {
  const _NebulaOrb({
    required this.color,
    required this.size,
    required this.alpha,
  });

  final Color color;
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: alpha), Colors.transparent],
        ),
      ),
    );
  }
}

/// Dialog header row — cosmic title + close.
class ProfileCosmicHeader extends StatelessWidget {
  const ProfileCosmicHeader({
    super.key,
    required this.title,
    this.onClose,
    this.closeEnabled = true,
  });

  final String title;
  final VoidCallback? onClose;
  final bool closeEnabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 6, 0),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome,
            color: Color(0xFF00F0FF),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: ProfileCosmicTitle(text: title, fontSize: 16)),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: closeEnabled ? Colors.white54 : Colors.white24,
            ),
            onPressed: closeEnabled ? onClose : null,
          ),
        ],
      ),
    );
  }
}

/// Gradient glow title — matches lobby brand styling.
class ProfileCosmicTitle extends StatelessWidget {
  const ProfileCosmicTitle({
    super.key,
    required this.text,
    this.fontSize = 22,
  });

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF00F0FF);
    const magenta = Color(0xFFFF2D95);
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.4,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style.copyWith(
            color: Colors.transparent,
            shadows: [
              Shadow(color: cyan.withValues(alpha: 0.4), blurRadius: 10),
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
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// Avatar with orbital rings and cosmic glow.
class ProfileOrbitAvatar extends StatelessWidget {
  const ProfileOrbitAvatar({
    super.key,
    this.avatarUrl,
    this.radius = 52,
    this.onTap,
    this.editIcon = Icons.edit,
  });

  final String? avatarUrl;
  final double radius;
  final VoidCallback? onTap;
  final IconData editIcon;

  @override
  Widget build(BuildContext context) {
    final outer = radius * 2 + 28;

    Widget avatar = Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: outer,
          height: outer,
          child: CustomPaint(
            painter: _OrbitRingPainter(
              accent: const Color(0xFF00F0FF),
              secondary: const Color(0xFFFF2D95),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF00F0FF), Color(0xFFFF2D95)],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x6600F0FF),
                blurRadius: 22,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Color(0x44FF2D95),
                blurRadius: 28,
              ),
            ],
          ),
          child: ProfileAvatar(
            avatarUrl: avatarUrl,
            radius: radius,
            iconSize: radius * 0.92,
          ),
        ),
        if (onTap != null)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF00F0FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF060818), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00F0FF).withValues(alpha: 0.45),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(editIcon, size: 16, color: const Color(0xFF060818)),
            ),
          ),
      ],
    );

    if (onTap == null) return avatar;

    return GestureDetector(onTap: onTap, child: avatar);
  }
}

class _OrbitRingPainter extends CustomPainter {
  const _OrbitRingPainter({required this.accent, required this.secondary});

  final Color accent;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    ring.color = accent.withValues(alpha: 0.22);
    canvas.drawCircle(center, r, ring);

    ring.color = secondary.withValues(alpha: 0.14);
    canvas.drawCircle(center, r - 6, ring);

    final dot = Paint()..style = PaintingStyle.fill;
    dot.color = accent.withValues(alpha: 0.7);
    canvas.drawCircle(Offset(center.dx, center.dy - r + 1), 2.2, dot);

    dot.color = secondary.withValues(alpha: 0.55);
    canvas.drawCircle(Offset(center.dx + r * 0.72, center.dy + r * 0.35), 1.6, dot);
  }

  @override
  bool shouldRepaint(covariant _OrbitRingPainter oldDelegate) => false;
}

/// Stat / action tile on cosmic panel shell.
class ProfileCosmicStatTile extends StatelessWidget {
  const ProfileCosmicStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.secondary = const Color(0xFF8868FF),
    this.highlighted = false,
    this.onTap,
    this.trailing,
    this.subtitle,
    this.child,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color secondary;
  final bool highlighted;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? subtitle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final content = LobbyCosmicPanel(
      borderRadius: 14,
      accent: accent,
      secondary: secondary,
      glowStrength: highlighted ? 0.16 : 0.09,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: child ??
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.42),
                          fontSize: 11,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: accent,
                  fontSize: highlighted ? 24 : 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 2),
                trailing!,
              ],
            ],
          ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: content,
      ),
    );
  }
}

/// Centered diamond currency pill.
class ProfileCosmicCurrencyPill extends StatelessWidget {
  const ProfileCosmicCurrencyPill({
    super.key,
    required this.value,
    required this.label,
    this.color = const Color(0xFF00F0FF),
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LobbyCosmicPanel(
      borderRadius: 999,
      accent: color,
      secondary: const Color(0xFF8868FF),
      glowStrength: 0.14,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DiamondIcon(color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  height: 1,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cosmic-styled text field for edit profile.
class ProfileCosmicTextField extends StatelessWidget {
  const ProfileCosmicTextField({
    super.key,
    required this.controller,
    required this.enabled,
    this.maxLength,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final int? maxLength;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return LobbyCosmicPanel(
      borderRadius: 12,
      accent: const Color(0xFF00F0FF),
      secondary: const Color(0xFF8868FF),
      glowStrength: 0.06,
      showStars: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: TextField(
        controller: controller,
        enabled: enabled,
        maxLength: maxLength,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        cursorColor: const Color(0xFF00F0FF),
        decoration: InputDecoration(
          counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
