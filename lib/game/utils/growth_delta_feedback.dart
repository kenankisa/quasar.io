import 'package:flame/components.dart';

import '../../services/settings_service.dart';
import '../orbit_game.dart';

/// Spawns floating +/- growth popups when the local player gains or loses mass.
class GrowthDeltaFeedback {
  GrowthDeltaFeedback._();

  static void maybeEmit(
    Component? from,
    Vector2 worldPosition,
    double amount,
    double holeRadius,
  ) {
    if (!SettingsService.instance.showGrowthNumbers) return;
    final delta = amount.round();
    if (delta == 0) return;
    final game = from?.findGame() as OrbitGame?;
    if (game == null || !identical(from, game.player)) return;
    game.spawnGrowthDeltaPopup(worldPosition, delta, holeRadius);
  }
}
