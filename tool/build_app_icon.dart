import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Builds a polished 1024 launcher icon from the generated brand mark.
///
/// - Solid deep-space background (#080A1A) for iOS / splash / in-app
/// - Safe inset so Android adaptive masks don't crop the Q
Future<void> main(List<String> args) async {
  final candidates = [
    File(r'C:\Users\shado\.cursor\projects\c-flutter-uygulamalar-Quasar-io-quasar-io\assets\app_icon_source.png'),
    File('assets/app_icon_source.png'),
    File('assets/icon/app_icon_source.png'),
  ];

  File? sourceFile;
  for (final f in candidates) {
    if (f.existsSync()) {
      sourceFile = f;
      break;
    }
  }
  if (sourceFile == null) {
    stderr.writeln('Source icon not found.');
    exit(1);
  }

  final decoded = img.decodeImage(await sourceFile.readAsBytes());
  if (decoded == null) {
    stderr.writeln('Failed to decode source.');
    exit(1);
  }

  const size = 1024;
  const bgR = 0x08, bgG = 0x0A, bgB = 0x1A;
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(bgR, bgG, bgB, 255));

  // Trim near-black matte edges from generator vignette, keep neon mark.
  final trimmed = _trimDarkMatte(decoded);
  final mark = img.copyResize(
    trimmed,
    width: (size * 0.78).round(),
    height: (size * 0.78).round(),
    interpolation: img.Interpolation.cubic,
  );

  final ox = (size - mark.width) ~/ 2;
  final oy = (size - mark.height) ~/ 2;
  img.compositeImage(canvas, mark, dstX: ox, dstY: oy);

  // Soft vignette so edges match launcher masks cleanly.
  _applyEdgeVignette(canvas, bgR, bgG, bgB);

  final outDir = Directory('assets/icon')..createSync(recursive: true);
  final outPath = '${outDir.path}/app_icon.png';
  await File(outPath).writeAsBytes(img.encodePng(canvas, level: 6));

  // Adaptive foreground: same mark on transparent canvas (Android).
  final fg = img.Image(width: size, height: size, numChannels: 4);
  img.fill(fg, color: img.ColorRgba8(0, 0, 0, 0));
  final fgMark = img.copyResize(
    trimmed,
    width: (size * 0.72).round(),
    height: (size * 0.72).round(),
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(
    fg,
    fgMark,
    dstX: (size - fgMark.width) ~/ 2,
    dstY: (size - fgMark.height) ~/ 2,
  );
  final fgPath = '${outDir.path}/app_icon_foreground.png';
  await File(fgPath).writeAsBytes(img.encodePng(fg, level: 6));

  stdout.writeln('Wrote $outPath and $fgPath');
}

img.Image _trimDarkMatte(img.Image src) {
  var minX = src.width;
  var minY = src.height;
  var maxX = 0;
  var maxY = 0;

  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();
      final lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      final maxC = math.max(r, math.max(g, b));
      final minC = math.min(r, math.min(g, b));
      final sat = maxC == 0 ? 0.0 : (maxC - minC) / maxC;
      // Keep neon / bright core; drop near-black vignette.
      if (lum < 18 && sat < 0.2) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }

  if (maxX <= minX || maxY <= minY) return src;

  final pad = ((maxX - minX) * 0.04).round().clamp(4, 40);
  minX = (minX - pad).clamp(0, src.width - 1);
  minY = (minY - pad).clamp(0, src.height - 1);
  maxX = (maxX + pad).clamp(0, src.width - 1);
  maxY = (maxY + pad).clamp(0, src.height - 1);

  return img.copyCrop(
    src,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
}

void _applyEdgeVignette(img.Image image, int bgR, int bgG, int bgB) {
  final cx = image.width / 2;
  final cy = image.height / 2;
  final maxR = math.sqrt(cx * cx + cy * cy);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final dx = x - cx;
      final dy = y - cy;
      final d = math.sqrt(dx * dx + dy * dy) / maxR;
      if (d < 0.78) continue;
      final t = ((d - 0.78) / 0.22).clamp(0.0, 1.0);
      final soft = t * t * (3 - 2 * t);
      final p = image.getPixel(x, y);
      final r = (p.r.toInt() + (bgR - p.r.toInt()) * soft).round();
      final g = (p.g.toInt() + (bgG - p.g.toInt()) * soft).round();
      final b = (p.b.toInt() + (bgB - p.b.toInt()) * soft).round();
      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }
}
