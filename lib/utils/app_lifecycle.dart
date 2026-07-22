import 'package:flutter/widgets.dart';

/// Shared helpers for pausing work when the app is not foregrounded.
abstract final class AppLifecycle {
  AppLifecycle._();

  /// True when the OS has backgrounded / covered the app.
  /// Includes [inactive] so notification shade / app switcher also stop burn.
  static bool shouldPause(AppLifecycleState state) => switch (state) {
        AppLifecycleState.resumed => false,
        AppLifecycleState.inactive ||
        AppLifecycleState.hidden ||
        AppLifecycleState.paused ||
        AppLifecycleState.detached =>
          true,
      };
}
