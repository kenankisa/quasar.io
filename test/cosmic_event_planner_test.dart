import 'package:flutter_test/flutter_test.dart';
import 'package:quasar_io/game/config/match_pacing.dart';
import 'package:quasar_io/game/models/cosmic_event_cue.dart';
import 'package:quasar_io/game/room_type.dart';
import 'package:quasar_io/game/utils/cosmic_event_planner.dart';

void main() {
  test('same seed yields identical shared cosmic schedule', () {
    final pacing = MatchPacing.forRoom(RoomType.normal);
    final a = CosmicEventPlanner(
      seed: 424242,
      pacing: pacing,
      worldSize: 8000,
    );
    final b = CosmicEventPlanner(
      seed: 424242,
      pacing: pacing,
      worldSize: 8000,
    );

    expect(a.cues.length, greaterThan(2));
    expect(a.cues.length, b.cues.length);

    for (var i = 0; i < a.cues.length; i++) {
      final left = a.cues[i];
      final right = b.cues[i];
      expect(left.kind, right.kind);
      expect(left.warnAt, right.warnAt);
      expect(left.startAt, right.startAt);
      expect(left.endAt, right.endAt);
      expect(left.center.x, right.center.x);
      expect(left.center.y, right.center.y);
      expect(left.regionRadius, right.regionRadius);
      expect(left.spawnSeed, right.spawnSeed);
    }
  });

  test('supernova and meteor cues do not overlap', () {
    final planner = CosmicEventPlanner(
      seed: 99,
      pacing: MatchPacing.forRoom(RoomType.elite),
      worldSize: 9000,
    );

    for (var i = 1; i < planner.cues.length; i++) {
      final prev = planner.cues[i - 1];
      final next = planner.cues[i];
      expect(next.warnAt, greaterThanOrEqualTo(prev.endAt));
    }

    expect(
      planner.cues.any((c) => c.kind == CosmicEventKind.supernova),
      isTrue,
    );
    expect(
      planner.cues.any((c) => c.kind == CosmicEventKind.meteorShower),
      isTrue,
    );
  });
}
