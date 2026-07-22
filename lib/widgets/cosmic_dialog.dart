import 'dart:ui';

import 'package:flutter/material.dart';

/// Blurred cosmic dialog shell used across settings screens.
class CosmicDialog {
  CosmicDialog._();

  static Future<void> show({
    required BuildContext context,
    required String barrierLabel,
    required Widget child,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: barrierLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) => child,
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
}

class CosmicDialogPanel extends StatelessWidget {
  const CosmicDialogPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.maxWidth = 420,
    this.scrollable = true,
    this.expandBody = false,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;
  final double maxWidth;
  final bool scrollable;
  final bool expandBody;

  @override
  Widget build(BuildContext context) {
    final header = Row(
      children: [
        Icon(icon, color: const Color(0xFF00F0FF)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF00F0FF),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.close,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );

    final column = Column(
      mainAxisSize: expandBody ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: 8),
        ...children,
      ],
    );

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      child: scrollable && !expandBody
          ? SingleChildScrollView(child: column)
          : column,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: const Color(0xFF0A0A1A).withValues(alpha: 0.92),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                child: expandBody
                    ? SizedBox(
                        height: MediaQuery.of(context).size.height * 0.88,
                        child: content,
                      )
                    : content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
