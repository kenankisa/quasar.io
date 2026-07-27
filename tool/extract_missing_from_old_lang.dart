// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final oldText = File(r'C:\Users\shado\AppData\Local\Temp\old_lang_utf8.dart')
      .readAsStringSync();
  final locales = ['en', 'tr', 'de', 'ru', 'es', 'fr'];

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

  final enNew = File('lib/services/lang/translations_en.dart').readAsStringSync();
  final enDefined = RegExp(r"'([^']+)':")
      .allMatches(enNew)
      .map((m) => m.group(1)!)
      .toSet();
  final missing = used.difference(enDefined).toList()..sort();

  for (final locale in locales) {
    final localeRe = RegExp(
      "'$locale':\\s*\\{([\\s\\S]*?)\\n\\s*\\},",
      multiLine: true,
    );
    final match = localeRe.firstMatch(oldText);
    if (match == null) {
      print('No locale block for $locale');
      continue;
    }
    final block = match.group(1)!;
    // Parse multiline values manually
    final oldKeys = <String, String>{};
    final lines = block.split('\n');
    String? currentKey;
    final buffer = StringBuffer();
    var inString = false;
    for (final line in lines) {
      final keyMatch = RegExp(r"^\s+'([^']+)':\s*(.*)$").firstMatch(line);
      if (keyMatch != null && !inString) {
        if (currentKey != null) {
          oldKeys[currentKey] = buffer.toString();
          buffer.clear();
        }
        currentKey = keyMatch.group(1);
        final rest = keyMatch.group(2)!.trim();
        if (rest.startsWith("'") && rest.endsWith("',")) {
          oldKeys[currentKey!] =
              rest.substring(1, rest.length - 2).replaceAll(r"\'", "'");
          currentKey = null;
        } else if (rest == "'") {
          inString = true;
          buffer.clear();
        } else if (rest.startsWith("'")) {
          inString = true;
          buffer.write(rest.substring(1));
        }
      } else if (inString && currentKey != null) {
        final trimmed = line.trim();
        if (trimmed.endsWith("',")) {
          buffer.write(trimmed.substring(0, trimmed.length - 2));
          oldKeys[currentKey] = buffer.toString().replaceAll(r"\'", "'");
          currentKey = null;
          inString = false;
          buffer.clear();
        } else {
          buffer.write(line.trim());
          buffer.write(' ');
        }
      }
    }

    final out = StringBuffer();
    var found = 0;
    var notFound = 0;
    for (final key in missing) {
      final val = oldKeys[key];
      if (val != null) {
        found++;
        out.writeln("      '$key':");
        if (val.contains('\n')) {
          final parts = val.split('\n');
          out.writeln("          '${parts.first}'");
          for (var i = 1; i < parts.length; i++) {
            out.writeln("          '${parts[i]}'");
          }
          out.writeln(',');
        } else {
          out.writeln("          '${val.replaceAll("'", r"\'")}',");
        }
      } else {
        notFound++;
      }
    }
    File('tool/missing_$locale.txt').writeAsStringSync(out.toString());
    print('$locale: found $found / ${missing.length}, not found $notFound');
  }
}
