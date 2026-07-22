import 'dart:math' as math;

/// Shared shield and spawn-protection state for black-hole entities.
mixin EntityShieldMixin {
  bool isShieldActive = false;
  double shieldTimeRemaining = 0;

  void activateShield({double duration = 5}) {
    isShieldActive = true;
    shieldTimeRemaining = duration;
  }

  void tickShield(double dt) {
    if (!isShieldActive) return;
    shieldTimeRemaining -= dt;
    if (shieldTimeRemaining <= 0) {
      isShieldActive = false;
      shieldTimeRemaining = 0;
    }
  }
}

mixin EntitySpawnProtectionMixin {
  double spawnProtectionRemaining = 0;
  double spawnProtectionTotal = 0;

  bool get isSpawnProtected => spawnProtectionRemaining > 0;

  int get spawnProtectionCountdown =>
      isSpawnProtected ? spawnProtectionRemaining.ceil().clamp(1, 99) : 0;

  void activateSpawnProtection({
    required double duration,
    bool trackTotal = false,
  }) {
    if (trackTotal) {
      spawnProtectionTotal = duration;
    }
    spawnProtectionRemaining = duration;
  }

  void tickSpawnProtection(double dt) {
    if (spawnProtectionRemaining <= 0) return;
    spawnProtectionRemaining -= dt;
    if (spawnProtectionRemaining < 0) {
      spawnProtectionRemaining = 0;
    }
  }
}

/// Transient "Quasar Activation" state (reference Stage 4): after a hole
/// swallows a significant mass, its accretion disk briefly flares/expands
/// and twin relativistic jets fire from its poles.
mixin QuasarActivationMixin {
  /// 0 = dormant, 1 = full quasar flare. Decays back to 0 over ~1s.
  double quasarFlash = 0;

  void triggerQuasarActivation({double strength = 1.0}) {
    quasarFlash = math.max(quasarFlash, strength.clamp(0.0, 1.0));
  }

  void tickQuasarFlash(double dt) {
    if (quasarFlash <= 0) return;
    quasarFlash = math.max(0.0, quasarFlash - dt * 1.1);
  }
}
