import 'package:flutter/material.dart';

/// [MaterialApp] kök navigator — oturum kapanınca stack temizliği için.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Maç / admin / diyalog vs. tüm üst route'ları kapatıp ilk giriş ekranını gösterir.
void popAppToRoot() {
  final nav = appNavigatorKey.currentState;
  if (nav == null || !nav.canPop()) return;
  nav.popUntil((route) => route.isFirst);
}
