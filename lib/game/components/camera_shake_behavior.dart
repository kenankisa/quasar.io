import 'package:flame/camera.dart';
import 'package:flame/components.dart';

import '../orbit_game.dart';

/// Applies screen-shake offset after [FollowBehavior] updates the viewfinder.
class CameraShakeBehavior extends Component {
  CameraShakeBehavior(this.game);

  final OrbitGame game;

  double _lastShakeX = 0;
  double _lastShakeY = 0;

  @override
  int get priority => 100;

  @override
  void update(double dt) {
    super.update(dt);

    final viewfinder = parent;
    if (viewfinder is! Viewfinder) return;

    // Önceki karedeki sarsıntıyı geri al — follow ile çakışınca birikme olmasın.
    if (_lastShakeX != 0 || _lastShakeY != 0) {
      viewfinder.position = Vector2(
        viewfinder.position.x - _lastShakeX,
        viewfinder.position.y - _lastShakeY,
      );
      _lastShakeX = 0;
      _lastShakeY = 0;
    }

    final offset = game.consumeShakeOffset(dt);
    if (offset.length2 <= 0) return;

    _lastShakeX = offset.x;
    _lastShakeY = offset.y;
    viewfinder.position = Vector2(
      viewfinder.position.x + offset.x,
      viewfinder.position.y + offset.y,
    );
  }
}
