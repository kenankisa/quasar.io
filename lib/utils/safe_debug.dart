import 'package:flutter/foundation.dart';

/// Debug log helper that redacts secrets before printing.
void safeDebugPrint(String message) {
  if (!kDebugMode) return;
  debugPrint(_redactSecrets(message));
}

String _redactSecrets(String input) {
  var out = input;
  // JWT / bearer
  out = out.replaceAllMapped(
    RegExp(r'(Bearer\s+)[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
    (m) => '${m[1]}***',
  );
  out = out.replaceAllMapped(
    RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
    (_) => 'eyJ***.***.***',
  );
  // Common secret field shapes in maps / errors
  out = out.replaceAllMapped(
    RegExp(
      r'''(['"]?(?:password|passwd|secret|token|access_token|refresh_token|api_key|apikey)['"]?\s*[:=]\s*)(['"]?)([^'",\s}]+)(['"]?)''',
      caseSensitive: false,
    ),
    (m) => '${m[1]}${m[2]}***${m[4]}',
  );
  // Sim mint style passwords
  out = out.replaceAllMapped(
    RegExp(r'SimLt_[A-Za-z0-9_]+'),
    (_) => 'SimLt_***',
  );
  // Publishable / anon key-ish blobs
  out = out.replaceAllMapped(
    RegExp(r'sb_publishable_[A-Za-z0-9_]+'),
    (_) => 'sb_publishable_***',
  );
  return out;
}
