import 'package:flutter_test/flutter_test.dart';
import 'package:quasar_io/game/models/bot_sync_state.dart';

void main() {
  group('BotSnapshot', () {
    test('round-trips host id and bot poses', () {
      const original = BotSnapshot(
        hostId: 'user-aaa',
        bots: [
          BotSyncState(
            id: 'bot_0',
            displayName: 'Nebula-X',
            x: 120,
            y: 340,
            radius: 42,
            activeSkin: 'pulsar',
            accentHue: 216,
            boost: true,
            shield: false,
          ),
          BotSyncState(
            id: 'bot_1',
            displayName: 'Void Prime',
            x: 800,
            y: 100,
            radius: 28,
            activeSkin: 'default',
            accentHue: 36,
          ),
        ],
      );

      final restored = BotSnapshot.fromMap(original.toMap());

      expect(restored.hostId, 'user-aaa');
      expect(restored.bots, hasLength(2));
      expect(restored.bots[0].id, 'bot_0');
      expect(restored.bots[0].x, 120);
      expect(restored.bots[0].y, 340);
      expect(restored.bots[0].radius, 42);
      expect(restored.bots[0].boost, isTrue);
      expect(restored.bots[1].id, 'bot_1');
      expect(restored.bots[1].accentHue, 36);
    });

    test('skips bots with empty ids', () {
      final restored = BotSnapshot.fromMap({
        'host_id': 'host',
        'bots': [
          {'id': '', 'x': 1, 'y': 2, 'radius': 3},
          {'id': 'bot_9', 'x': 4, 'y': 5, 'radius': 6, 'display_name': 'Ok'},
        ],
      });
      expect(restored.bots, hasLength(1));
      expect(restored.bots.single.id, 'bot_9');
    });
  });
}
