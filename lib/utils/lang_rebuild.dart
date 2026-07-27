import 'package:flutter/material.dart';

import '../services/lang_service.dart';

/// Rebuilds [child] whenever [LanguageService] changes.
class LangRebuild extends StatelessWidget {
  const LangRebuild({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService.instance,
      builder: (context, _) => child,
    );
  }
}

/// Registers a language-change listener that calls [onChanged] (typically setState).
mixin LangChangeListener<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    LanguageService.instance.addListener(_handleLangChange);
  }

  @override
  void dispose() {
    LanguageService.instance.removeListener(_handleLangChange);
    super.dispose();
  }

  void _handleLangChange() {
    if (mounted) onLangChanged();
  }

  void onLangChanged();
}
