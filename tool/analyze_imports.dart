// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final root = Directory.current;
  final libDir = Directory('${root.path}/lib');
  final packageName = 'quasar_io';
  final importRe = RegExp(
    r"^(?:import|export)\s+['""]([^'""]+)['""]",
    multiLine: true,
  );

  final files = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  String toPackagePath(File f) {
    final normalized = f.path.replaceAll('\\', '/');
    final idx = normalized.indexOf('/lib/');
    if (idx == -1) return '';
    return 'package:$packageName/${normalized.substring(idx + 5)}';
  }

  String normPath(String p) =>
      p.replaceAll('\\', '/').toLowerCase();

  File? resolveRelative(File importer, String imp) {
    if (imp.startsWith('package:') || imp.startsWith('dart:')) return null;
    final base = importer.parent;
    var target = imp.startsWith('/')
        ? imp
        : '${base.path}${Platform.pathSeparator}$imp';
    if (!target.endsWith('.dart')) {
      target = '$target.dart';
    }
    final resolved = File(target).absolute;
    if (!resolved.existsSync()) return null;
    final libNorm = normPath(libDir.absolute.path);
    if (!normPath(resolved.path).startsWith('$libNorm/')) return null;
    // Match against canonical file list
    final key = normPath(resolved.path);
    for (final f in files) {
      if (normPath(f.absolute.path) == key) return f;
    }
    return resolved;
  }

  final fileToPkg = {for (final f in files) f: toPackagePath(f)};
  final pkgToFile = {for (final e in fileToPkg.entries) e.value: e.key};

  final fileImports = <File, Set<File>>{};
  final importedPkgs = <String>{};

  for (final f in files) {
    final text = f.readAsStringSync();
    final targets = <File>{};
    for (final m in importRe.allMatches(text)) {
      final imp = m.group(1)!;
      if (imp.startsWith('package:$packageName/')) {
        importedPkgs.add(imp);
        final t = pkgToFile[imp];
        if (t != null) targets.add(t);
      } else {
        final resolved = resolveRelative(f, imp);
        if (resolved != null) {
          targets.add(resolved);
          importedPkgs.add(toPackagePath(resolved));
        }
      }
    }
    fileImports[f] = targets;
  }

  final mainFiles = files.where((f) => f.uri.pathSegments.last == 'main.dart');
  final reachable = <File>{};
  final stack = mainFiles.toList();
  while (stack.isNotEmpty) {
    final f = stack.removeLast();
    if (!reachable.add(f)) continue;
    for (final t in fileImports[f] ?? {}) {
      if (!reachable.contains(t)) stack.add(t);
    }
  }

  final neverImported = <File>[];
  for (final f in files) {
    if (f.uri.pathSegments.last == 'main.dart') continue;
    if (!importedPkgs.contains(fileToPkg[f])) {
      neverImported.add(f);
    }
  }

  final unreachable = files.where((f) => !reachable.contains(f)).toList();

  final dirCounts = <String, int>{};
  for (final f in files) {
    final rel = f.path.replaceAll('\\', '/').split('/lib/').last;
    final parts = rel.split('/');
    final top = parts.length > 1 ? parts[0] : '(root)';
    dirCounts[top] = (dirCounts[top] ?? 0) + 1;
  }

  print('TOTAL_FILES=${files.length}');
  print('\n=== DIRECTORY COUNTS ===');
  for (final e in (dirCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)))) {
    print('  ${e.key}: ${e.value}');
  }

  print('\n=== NEVER IMPORTED (${neverImported.length}) ===');
  for (final f in neverImported) {
    print(f.path.replaceAll('\\', '/'));
  }

  print('\n=== UNREACHABLE FROM main.dart (${unreachable.length}) ===');
  for (final f in unreachable) {
    print(f.path.replaceAll('\\', '/'));
  }

  final ranked = <List<Object>>[];
  for (final f in files) {
    final text = f.readAsStringSync();
    final imports = importRe.allMatches(text).length;
    final lines = '\n'.allMatches(text).length + 1;
    ranked.add([imports, lines, f.path.replaceAll('\\', '/')]);
  }
  ranked.sort((a, b) => (b[1] as int).compareTo(a[1] as int));

  print('\n=== LARGEST FILES (top 25) ===');
  for (var i = 0; i < 25 && i < ranked.length; i++) {
    final r = ranked[i];
    print('  lines=${r[1]} imports=${r[0]}  ${r[2]}');
  }

  ranked.sort((a, b) => (b[0] as int).compareTo(a[0] as int));
  print('\n=== HEAVIEST IMPORT COUNTS (top 20) ===');
  for (var i = 0; i < 20 && i < ranked.length; i++) {
    final r = ranked[i];
    print('  imports=${r[0]} lines=${r[1]}  ${r[2]}');
  }
}
