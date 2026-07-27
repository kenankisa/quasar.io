import 'first_match_tuning.dart';

enum InteractiveTutorialStep {
  move,
  absorb,
  boost,
  complete,
  hidden,
}

/// Step-by-step first-match tutorial: move → absorb → boost (~60s window).
class InteractiveTutorialController {
  InteractiveTutorialController({required this.isActive});

  final bool isActive;

  InteractiveTutorialStep step = InteractiveTutorialStep.move;
  double _startRadius = 25;
  bool _initialized = false;
  bool _boostPrimed = false;

  bool get isVisible =>
      isActive && step != InteractiveTutorialStep.hidden;

  bool get shouldHighlightBoost =>
      isActive && step == InteractiveTutorialStep.boost;

  int get currentStepNumber => switch (step) {
        InteractiveTutorialStep.move => 1,
        InteractiveTutorialStep.absorb => 2,
        InteractiveTutorialStep.boost => 3,
        InteractiveTutorialStep.complete => 3,
        InteractiveTutorialStep.hidden => 0,
      };

  String hintKeyForStep() => switch (step) {
        InteractiveTutorialStep.move => 'tutorial_step_move',
        InteractiveTutorialStep.absorb => 'tutorial_step_absorb',
        InteractiveTutorialStep.boost => 'tutorial_step_boost',
        InteractiveTutorialStep.complete => 'first_match_hint_grow',
        InteractiveTutorialStep.hidden => '',
      };

  InteractiveTutorialStep tick({
    required double matchElapsed,
    required double playerRadius,
    required bool isDragging,
    required double velocity,
    required bool boostActive,
    required bool boostUsed,
    required void Function() onPrimeBoost,
  }) {
    if (!isActive) {
      step = InteractiveTutorialStep.hidden;
      return step;
    }

    if (matchElapsed > FirstMatchTuning.tutorialDurationSeconds) {
      step = InteractiveTutorialStep.hidden;
      return step;
    }

    if (!_initialized) {
      _startRadius = playerRadius;
      step = InteractiveTutorialStep.move;
      _initialized = true;
      _boostPrimed = false;
    }

    if (step == InteractiveTutorialStep.move) {
      if (isDragging && velocity > 55) {
        step = InteractiveTutorialStep.absorb;
      }
    } else if (step == InteractiveTutorialStep.absorb) {
      if (playerRadius > _startRadius + 2) {
        step = InteractiveTutorialStep.boost;
        _boostPrimed = false;
      }
    } else if (step == InteractiveTutorialStep.boost) {
      if (!_boostPrimed) {
        onPrimeBoost();
        _boostPrimed = true;
      }
      if (boostUsed || boostActive) {
        step = InteractiveTutorialStep.complete;
      }
    }

    return step;
  }
}
