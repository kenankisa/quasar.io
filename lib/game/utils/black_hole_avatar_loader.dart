import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../utils/avatar_url.dart';

/// Cached network avatar loading for in-game black-hole portraits.
class BlackHoleAvatarLoader {
  BlackHoleAvatarLoader._();

  static final _cache = <String, ui.Image>{};
  static final _inFlight = <String, Future<ui.Image?>>{};

  static Future<ui.Image?> load(String? url) async {
    final safeUrl = AvatarUrl.sanitize(url);
    if (safeUrl == null) return null;

    final cached = _cache[safeUrl];
    if (cached != null) return cached;

    final pending = _inFlight[safeUrl];
    if (pending != null) return pending;

    final future = _fetch(safeUrl);
    _inFlight[safeUrl] = future;
    try {
      final image = await future;
      if (image != null) {
        _cache[safeUrl] = image;
      }
      return image;
    } finally {
      _inFlight.remove(safeUrl);
    }
  }

  static Future<ui.Image?> _fetch(String url) async {
    try {
      final completer = Completer<ui.Image>();
      final stream = NetworkImage(url).resolve(const ImageConfiguration());
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          completer.complete(info.image);
          stream.removeListener(listener);
        },
        onError: (error, stackTrace) {
          stream.removeListener(listener);
          completer.completeError(error, stackTrace);
        },
      );
      stream.addListener(listener);
      return await completer.future;
    } catch (_) {
      return null;
    }
  }
}
