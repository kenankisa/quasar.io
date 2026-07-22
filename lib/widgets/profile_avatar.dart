import 'package:flutter/material.dart';

import '../utils/avatar_url.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    this.avatarUrl,
    required this.radius,
    this.iconSize,
    this.backgroundColor = const Color(0xFF1A1A3A),
    this.iconColor = const Color(0xFF00F0FF),
  });

  final String? avatarUrl;
  final double radius;
  final double? iconSize;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;

    Widget fallback() {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person,
          size: iconSize ?? radius,
          color: iconColor,
        ),
      );
    }

    final url = AvatarUrl.sanitize(avatarUrl);
    if (url == null) {
      return fallback();
    }

    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: size,
            height: size,
            color: backgroundColor,
            alignment: Alignment.center,
            child: SizedBox(
              width: radius * 0.6,
              height: radius * 0.6,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: iconColor,
              ),
            ),
          );
        },
      ),
    );
  }
}
