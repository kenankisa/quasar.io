import 'package:flame/components.dart';

import '../orbit_game.dart';
import '../utils/viewport_cull.dart';

/// Self-removing [ParticleSystemComponent] so bursts do not pile up on mobile.
class TimedParticleBurst extends ParticleSystemComponent {
  TimedParticleBurst({
    required super.particle,
    required this.lifespan,
  }) : super(anchor: Anchor.center);

  final double lifespan;
  double _elapsed = 0;

  @override
  void update(double dt) {
    _elapsed += dt;
    if (_elapsed >= lifespan) {
      removeFromParent();
      return;
    }
    final game = findGame() as OrbitGame?;
    // Far: expire on schedule without simulating particles.
    if (game != null &&
        ViewportCull.isFarFromView(game, absolutePosition, margin: 220)) {
      return;
    }
    super.update(dt);
  }
}
