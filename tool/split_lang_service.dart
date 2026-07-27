// ignore_for_file: avoid_print

import 'dart:io';

/// Splits [lib/services/lang_service.dart] translations into per-locale files.
void main() {
  final root = Directory.current;
  final source = File('${root.path}/lib/services/lang_service.dart');
  if (!source.existsSync()) {
    stderr.writeln('lang_service.dart not found — restore from git first.');
    exit(1);
  }

  final lines = source.readAsLinesSync();
  if (!lines.any((l) => l.contains("static const Map<String, Map<String, String>> _translations"))) {
    stderr.writeln(
      'lang_service.dart already split. Restore original from git to re-run.',
    );
    exit(1);
  }

  const locales = ['en', 'tr', 'de', 'ru', 'es', 'fr'];
  final starts = <String, int>{};
  for (var i = 0; i < lines.length; i++) {
    for (final code in locales) {
      if (lines[i].trim() == "'$code': {") {
        starts[code] = i + 1;
      }
    }
  }

  final outDir = Directory('${root.path}/lib/services/lang');
  outDir.createSync(recursive: true);

  for (final code in locales) {
    final start = starts[code];
    if (start == null) {
      stderr.writeln('Missing locale start: $code');
      exit(1);
    }
    final end = _localeEndLine(lines, start);
    final body = lines.sublist(start, end + 1).join('\n');
    final constName = 'k${code[0].toUpperCase()}${code.substring(1)}Translations';

    File('${outDir.path}/translations_$code.dart').writeAsStringSync('''
/// $code locale strings for [LanguageService].
const Map<String, String> $constName = {
$body
};
''');
    print('Wrote translations_$code.dart (${end - start + 1} lines)');
  }
}

int _localeEndLine(List<String> lines, int start) {
  for (var i = start; i < lines.length; i++) {
    if (lines[i] == '    },') return i - 1;
  }
  throw StateError('Locale end not found from line $start');
}
