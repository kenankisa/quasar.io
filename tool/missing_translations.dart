// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final used = <String>{};
  final importRe = RegExp(r"""\.t\(['"]([^'"]+)['"]\)""");
  for (final f in Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    final text = f.readAsStringSync();
    for (final m in importRe.allMatches(text)) {
      used.add(m.group(1)!);
    }
  }

  // Also pick up string literal keys passed to LanguageService.instance.t(key).
  final keyLiteralRe = RegExp(
    r"(?:titleKey|bodyKey|labelKey|lockKey|errorKey|statusKey|descKey):\s*'([^']+)'",
  );
  for (final f in Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    final text = f.readAsStringSync();
    for (final m in keyLiteralRe.allMatches(text)) {
      used.add(m.group(1)!);
    }
  }

  String loadKeys(String path) {
    return File(path).readAsStringSync();
  }

  final enText = loadKeys('lib/services/lang/translations_en.dart');
  final enSup = loadKeys('lib/services/lang/translations_supplement_en.dart');
  final defined = <String>{
    ...RegExp(r"'([^']+)':")
        .allMatches(enText)
        .map((m) => m.group(1)!),
    ...RegExp(r"'([^']+)':")
        .allMatches(enSup)
        .map((m) => m.group(1)!),
  };

  final missing = used.difference(defined).toList()..sort();
  print('Used: ${used.length}, Defined: ${defined.length}, Missing: ${missing.length}');
  for (final k in missing) {
    print(k);
  }
}
