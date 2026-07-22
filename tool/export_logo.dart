import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Exports the preferred Quasar.io logo with a truly transparent background.
Future<void> main() async {
  final iconDir = Directory('assets/icon')..createSync(recursive: true);

  final sourceCandidates = [
    File('assets/quasar_logo_transparent_source.png'),
    File('assets/quasar_logo_transparent.png'),
    File(r'C:\Users\shado\.cursor\projects\c-flutter-uygulamalar-Quasar-io-quasar-io\assets\quasar_logo_transparent.png'),
  ];

  File? source;
  for (final file in sourceCandidates) {
    if (file.existsSync()) {
      source = file;
      break;
    }
  }

  if (source == null) {
    stderr.writeln('Source logo not found (assets/quasar_logo_transparent.png).');
    exit(1);
  }

  final bytes = await source.readAsBytes();
  final decoded = img.decodePng(bytes);
  if (decoded == null) {
    stderr.writeln('Failed to decode source PNG.');
    exit(1);
  }

  final image = decoded.numChannels == 4
      ? decoded.clone()
      : decoded.convert(numChannels: 4);

  _removeBackground(image);

  final encoded = img.encodePng(image, level: 6);
  // In-app brand mark only — do NOT overwrite launcher app_icon.png.
  await File('${iconDir.path}/logo.png').writeAsBytes(encoded);

  // Keep the source asset in sync for future exports.
  await File('assets/quasar_logo_transparent.png').writeAsBytes(encoded);

  var transparent = 0;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (image.getPixel(x, y).a < 10) transparent++;
    }
  }
  stdout.writeln(
    'Exported logo PNG (${encoded.length} bytes, $transparent transparent pixels)',
  );
}

void _removeBackground(img.Image image) {
  final w = image.width;
  final h = image.height;
  final cx = w ~/ 2;
  final cy = h ~/ 2;
  final visited = List.generate(h, (_) => List.filled(w, false));
  final queue = Queue<(int, int)>();

  void trySeed(int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h || visited[y][x]) return;
    final p = image.getPixel(x, y);
    if (!_isRemovableBackground(p.r.toInt(), p.g.toInt(), p.b.toInt())) return;
    visited[y][x] = true;
    queue.add((x, y));
  }

  for (var x = 0; x < w; x++) {
    trySeed(x, 0);
    trySeed(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    trySeed(0, y);
    trySeed(w - 1, y);
  }

  const neighbors = [(1, 0), (-1, 0), (0, 1), (0, -1)];

  while (queue.isNotEmpty) {
    final (x, y) = queue.removeFirst();
    image.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));

    for (final (dx, dy) in neighbors) {
      final nx = x + dx;
      final ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= w || ny >= h || visited[ny][nx]) continue;

      final p = image.getPixel(nx, ny);
      if (!_isRemovableBackground(p.r.toInt(), p.g.toInt(), p.b.toInt())) {
        continue;
      }

      visited[ny][nx] = true;
      queue.add((nx, ny));
    }
  }

  // Protect the bright core so enclosed matte pixels can be removed safely.
  final protectedPixels = List.generate(h, (_) => List.filled(w, false));
  final protectQueue = Queue<(int, int)>();
  final center = image.getPixel(cx, cy);
  if (_isCoreTone(center.r.toInt(), center.g.toInt(), center.b.toInt())) {
    protectedPixels[cy][cx] = true;
    protectQueue.add((cx, cy));
  }

  while (protectQueue.isNotEmpty) {
    final (x, y) = protectQueue.removeFirst();
    for (final (dx, dy) in neighbors) {
      final nx = x + dx;
      final ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= w || ny >= h || protectedPixels[ny][nx]) {
        continue;
      }

      final p = image.getPixel(nx, ny);
      if (p.a < 10) continue;
      if (!_isCoreTone(p.r.toInt(), p.g.toInt(), p.b.toInt())) continue;

      protectedPixels[ny][nx] = true;
      protectQueue.add((nx, ny));
    }
  }

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (protectedPixels[y][x]) continue;
      final p = image.getPixel(x, y);
      if (p.a < 10) continue;

      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();
      if (_isRemovableBackground(r, g, b)) {
        image.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
      }
    }
  }

  // Soften any leftover neutral fringe around the logo edges.
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = image.getPixel(x, y);
      if (p.a < 10) continue;

      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();
      if (!_isNeutralFringe(r, g, b)) continue;

      var transparentNeighbors = 0;
      for (final (dx, dy) in neighbors) {
        final nx = x + dx;
        final ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        if (image.getPixel(nx, ny).a < 10) transparentNeighbors++;
      }

      if (transparentNeighbors >= 2) {
        image.setPixel(x, y, img.ColorRgba8(r, g, b, 0));
      }
    }
  }
}

bool _isRemovableBackground(int r, int g, int b) {
  final maxC = math.max(r, math.max(g, b));
  final minC = math.min(r, math.min(g, b));
  final sat = maxC == 0 ? 0.0 : (maxC - minC) / maxC;
  final lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;

  // Checkerboard matte + white backdrop from the generated source image.
  return sat < 0.14 && lum > 0.52;
}

bool _isCoreTone(int r, int g, int b) {
  final maxC = math.max(r, math.max(g, b));
  final minC = math.min(r, math.min(g, b));
  final sat = maxC == 0 ? 0.0 : (maxC - minC) / maxC;
  final lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
  return sat < 0.12 && lum > 0.78;
}

bool _isNeutralFringe(int r, int g, int b) {
  final maxC = math.max(r, math.max(g, b));
  final minC = math.min(r, math.min(g, b));
  final sat = maxC == 0 ? 0.0 : (maxC - minC) / maxC;
  return sat < 0.1 && r > 170;
}
