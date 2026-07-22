import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quasar_io/game/utils/gravity_scaling.dart';
import 'package:quasar_io/game/utils/gravity_visual.dart';

void main() {
  group('Roche disruption distance', () {
    test('equal-density bodies: d ≈ 2^(1/3) · R_source', () {
      const r = 25.0;
      final roche = GravityScaling.rocheDisruptionDistance(
        sourceRadius: r,
        entityRadius: r,
      );
      expect(roche, closeTo(r * math.pow(2, 1 / 3), 0.01));
    });

    test('smaller prey has larger Roche distance', () {
      final roche = GravityScaling.rocheDisruptionDistance(
        sourceRadius: 50,
        entityRadius: 25,
      );
      expect(roche, greaterThan(50 * math.pow(2, 1 / 3)));
    });
  });

  group('consumable tidal onset', () {
    test('no visual deformation below visual onset intensity', () {
      const source = 25.0;
      const entity = 3.0;
      final roche = GravityScaling.consumableTidalVisualReferenceRoche(
        sourceRadius: source,
        entityRadius: entity,
      );
      final tooFar = roche / math.pow(0.57, 1 / 3);
      final deform = GravityVisual.tidalDeformForConsumable(
        entityWorldPosition: Vector2(tooFar, 0),
        sourceWorldPosition: Vector2.zero(),
        sourceRadius: source,
        entityRadius: entity,
      );
      expect(deform, isNull);
    });

    test('visible deformation inside visual tidal band', () {
      const source = 25.0;
      const entity = 3.0;
      final roche = GravityScaling.consumableTidalVisualReferenceRoche(
        sourceRadius: source,
        entityRadius: entity,
      );
      final atOnset = roche / math.pow(0.59, 1 / 3);
      final deform = GravityVisual.tidalDeformForConsumable(
        entityWorldPosition: Vector2(atOnset, 0),
        sourceWorldPosition: Vector2.zero(),
        sourceRadius: source,
        entityRadius: entity,
      );
      expect(deform, isNotNull);
      expect(deform!.stretch, greaterThan(1.08));
      expect(deform.stretch, lessThan(1.5));
    });

    test('huge hole does not spaghetti food far across the map', () {
      const source = 100.0;
      const entity = 7.0;
      final farDist = source * 3.5;
      final deform = GravityVisual.tidalDeformForConsumable(
        entityWorldPosition: Vector2(farDist, 0),
        sourceWorldPosition: Vector2.zero(),
        sourceRadius: source,
        entityRadius: entity,
      );
      expect(deform, isNull);
    });

    test('physics tidal can remain while visual VFX is off', () {
      const source = 100.0;
      const entity = 7.0;
      const dist = source * 3.0;
      final physics = GravityScaling.consumableTidalIntensity(
        sourceRadius: source,
        entityRadius: entity,
        distance: dist,
      );
      final visual = GravityScaling.consumableTidalVisualIntensity(
        sourceRadius: source,
        entityRadius: entity,
        distance: dist,
      );
      expect(physics, greaterThan(0.4));
      expect(visual, 0);
    });

    test('old 0.04 threshold distance is rejected', () {
      const source = 25.0;
      const entity = 3.0;
      final roche = GravityScaling.rocheDisruptionDistance(
        sourceRadius: source,
        entityRadius: entity,
      );
      final oldThresholdDist = roche / math.pow(0.04, 1 / 3);
      final deform = GravityVisual.tidalDeformForConsumable(
        entityWorldPosition: Vector2(oldThresholdDist, 0),
        sourceWorldPosition: Vector2.zero(),
        sourceRadius: source,
        entityRadius: entity,
      );
      expect(deform, isNull);
    });
  });

  group('hole inspiral speed', () {
    test('no assist before inspiral onset', () {
      expect(
        GravityScaling.holeInspiralSpeed(
          predatorRadius: 80,
          preyRadius: 20,
          proximity: 0.20,
          locked: false,
        ),
        0,
      );
    });

    test('faster for larger mass ratio', () {
      final mild = GravityScaling.holeInspiralSpeed(
        predatorRadius: 40,
        preyRadius: 30,
        proximity: 0.8,
        locked: true,
      );
      final extreme = GravityScaling.holeInspiralSpeed(
        predatorRadius: 80,
        preyRadius: 20,
        proximity: 0.8,
        locked: true,
      );
      expect(extreme, greaterThan(mild));
    });

    test('locked inspiral faster than approach assist', () {
      final approach = GravityScaling.holeInspiralSpeed(
        predatorRadius: 50,
        preyRadius: 25,
        proximity: 0.5,
        locked: false,
      );
      final locked = GravityScaling.holeInspiralSpeed(
        predatorRadius: 50,
        preyRadius: 25,
        proximity: 0.5,
        locked: true,
      );
      expect(locked, greaterThan(approach));
    });
  });

  group('hole-to-hole influence cap', () {
    test('huge predator does not pull from across the map', () {
      final uncapped = GravityScaling.influenceRadius(100);
      final capped = GravityScaling.holeToHoleInfluenceRadius(
        holeRadiusA: 100,
        holeRadiusB: 25,
      );
      expect(capped, lessThan(uncapped * 0.5));
      expect(capped, lessThan(uncapped));
    });

    test('cap tracks Roche swallow band', () {
      const larger = 80.0;
      const smaller = 22.0;
      final band = GravityScaling.holeSwallowPhysicsApproachDistance(
        largerRadius: larger,
        smallerRadius: smaller,
      );
      final cap = GravityScaling.holeToHoleInfluenceRadius(
        holeRadiusA: larger,
        holeRadiusB: smaller,
      );
      expect(cap, closeTo(band * GravityScaling.holeToHoleInfluenceBandMargin, 1.0));
    });

    test('tiny prey physics band much shorter than Roche blow-up', () {
      const larger = 100.0;
      const smaller = 8.0;
      final full = GravityScaling.holeSwallowApproachDistance(
        largerRadius: larger,
        smallerRadius: smaller,
      );
      final physics = GravityScaling.holeSwallowPhysicsApproachDistance(
        largerRadius: larger,
        smallerRadius: smaller,
      );
      final pull = GravityScaling.holeToHolePullInfluenceRadius(
        sourceRadius: larger,
        targetRadius: smaller,
      );
      expect(physics, lessThan(full * 0.45));
      expect(pull, lessThan(larger * 6));
      expect(pull, lessThan(full * 0.45));
    });

    test('small source cannot tug giant from predator swallow band', () {
      const giant = 100.0;
      const tiny = 8.0;
      final giantOnTiny = GravityScaling.holeToHolePullInfluenceRadius(
        sourceRadius: giant,
        targetRadius: tiny,
      );
      final tinyOnGiant = GravityScaling.holeToHolePullInfluenceRadius(
        sourceRadius: tiny,
        targetRadius: giant,
      );
      expect(tinyOnGiant, lessThan(giantOnTiny * 0.25));
      expect(tinyOnGiant, lessThan(GravityScaling.influenceRadius(tiny) * 1.05));
    });
  });

  group('hole swallow warning band', () {
    test('warning distance extends beyond physics approach', () {
      const larger = 80.0;
      const smaller = 22.0;
      final approach = GravityScaling.holeSwallowApproachDistance(
        largerRadius: larger,
        smallerRadius: smaller,
      );
      final warning = GravityScaling.holeSwallowWarningDistance(
        largerRadius: larger,
        smallerRadius: smaller,
      );
      final physics = GravityScaling.holeToHoleInfluenceRadius(
        holeRadiusA: larger,
        holeRadiusB: smaller,
      );
      expect(warning, greaterThan(approach));
      expect(warning, greaterThan(physics));
    });

    test('visual proximity in warning band before danger physics', () {
      const larger = 80.0;
      const smaller = 22.0;
      final approach = GravityScaling.holeSwallowApproachDistance(
        largerRadius: larger,
        smallerRadius: smaller,
      );
      final warning = GravityScaling.holeSwallowWarningDistance(
        largerRadius: larger,
        smallerRadius: smaller,
      );
      final midWarning = (approach + warning) * 0.5;
      final visual = GravityVisual.swallowVisualProximity(
        largerRadius: larger,
        smallerRadius: smaller,
        distance: midWarning,
      );
      final danger = GravityVisual.swallowProximity(
        largerRadius: larger,
        smallerRadius: smaller,
        distance: midWarning,
      );
      expect(visual, greaterThan(0));
      expect(danger, 0);
    });
  });

  group('hole swallow proximity', () {
    test('no VFX beyond approach distance', () {
      const larger = 25.0;
      const smaller = 25.0;
      final approach = GravityScaling.holeSwallowApproachDistance(
        largerRadius: larger,
        smallerRadius: smaller,
      );
      final proximity = GravityVisual.swallowProximity(
        largerRadius: larger,
        smallerRadius: smaller,
        distance: approach + 1,
      );
      expect(proximity, 0);
    });

    test('full proximity at capture distance', () {
      const larger = 50.0;
      const smaller = 25.0;
      final capture = GravityScaling.holeCaptureDistance(
        largerRadius: larger,
        smallerRadius: smaller,
      );
      expect(capture, greaterThan(0));
      final proximity = GravityVisual.swallowProximity(
        largerRadius: larger,
        smallerRadius: smaller,
        distance: capture,
      );
      expect(proximity, 1.0);
    });

    test('approach tracks Roche, not arbitrary multiplier', () {
      const larger = 50.0;
      const smaller = 25.0;
      final roche = GravityScaling.rocheDisruptionDistance(
        sourceRadius: larger,
        entityRadius: smaller,
      );
      final approach = GravityScaling.holeSwallowApproachDistance(
        largerRadius: larger,
        smallerRadius: smaller,
      );
      expect(approach, closeTo(roche * GravityScaling.holeSwallowApproachRocheFactor, 0.5));
    });
  });

  group('consumable tidal LOD', () {
    test('streak LOD off for tiny low-stress entities', () {
      expect(GravityVisual.consumableStreakLodFromScreen(3.5), 0);
    });

    test('streak LOD ramps and reaches full size', () {
      final mid = GravityVisual.consumableStreakLodFromScreen(6.5);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));
      expect(GravityVisual.consumableStreakLodFromScreen(10), 1.0);
    });

    test('high tidal intensity keeps streak on small screen dots', () {
      expect(
        GravityVisual.consumableStreakLodFromScreen(3, tidalIntensity: 0.82),
        greaterThan(0.45),
      );
    });

    test('min screen threshold eases under strong tidal stress', () {
      expect(
        GravityVisual.consumableTidalMinScreenForIntensity(0.8),
        lessThan(GravityVisual.consumableTidalMinScreenPx),
      );
    });
  });

  group('tidal locking', () {
    test('spin fully damped at Roche intensity', () {
      expect(GravityVisual.tidalSpinRetain(1.0), 0.0);
    });

    test('spin mostly gone before full disruption', () {
      expect(GravityVisual.tidalSpinRetain(0.8), lessThan(0.08));
    });

    test('smoothed axis eases toward target', () {
      const key = 42;
      GravityVisual.clearTidalAxis(key);
      final first = GravityVisual.smoothedTidalAngle(
        axisKey: key,
        targetAngle: 1.0,
        intensity: 0.6,
      );
      expect(first, 1.0);
      final second = GravityVisual.smoothedTidalAngle(
        axisKey: key,
        targetAngle: 2.0,
        intensity: 0.6,
      );
      expect(second, greaterThan(1.0));
      expect(second, lessThan(2.0));
      GravityVisual.clearTidalAxis(key);
    });
  });
}
