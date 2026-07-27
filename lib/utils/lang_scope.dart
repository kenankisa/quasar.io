import 'package:flutter/material.dart';

import '../services/lang_service.dart';

/// Inherited language scope — widgets that read via [of] rebuild on locale change.
class LanguageScope extends InheritedNotifier<LanguageService> {
  LanguageScope({super.key, required super.child})
      : super(notifier: LanguageService.instance);

  static LanguageService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LanguageScope>();
    return scope?.notifier ?? LanguageService.instance;
  }
}

extension LangBuildContext on BuildContext {
  LanguageService get lang => LanguageScope.of(this);
}
