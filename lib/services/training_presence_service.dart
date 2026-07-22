import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

/// Eğitim evrenindeki aktif oyuncuları lobide göstermek için presence.
class TrainingPresenceService {
  TrainingPresenceService._();
  static final TrainingPresenceService instance = TrainingPresenceService._();

  static const channelName = 'quasar_lobby_training';

  RealtimeChannel? _channel;
  Future<void>? _operation;

  SupabaseClient get _client => AuthService.instance.client;

  Future<void> enter(String userId) async {
    await _run(() async {
      await _leaveInternal();
      final channel = _client.channel(channelName);
      _channel = channel;

      final subscribed = Completer<void>();
      channel.subscribe((status, error) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          try {
            await channel.track({'user_id': userId});
          } catch (e, stackTrace) {
            debugPrint('TrainingPresenceService track failed: $e\n$stackTrace');
          }
          if (!subscribed.isCompleted) subscribed.complete();
        } else if (status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) {
          if (!subscribed.isCompleted) {
            subscribed.completeError(error ?? status);
          }
        }
      });

      try {
        await subscribed.future.timeout(const Duration(seconds: 8));
      } on TimeoutException {
        debugPrint('TrainingPresenceService subscribe timed out');
      }
    });
  }

  Future<void> leave() => _run(_leaveInternal);

  Future<void> _leaveInternal() async {
    final channel = _channel;
    if (channel == null) return;
    _channel = null;

    try {
      await channel.untrack();
    } catch (e, stackTrace) {
      debugPrint('TrainingPresenceService untrack failed: $e\n$stackTrace');
    }

    try {
      await _client.removeChannel(channel);
    } catch (e, stackTrace) {
      debugPrint('TrainingPresenceService removeChannel failed: $e\n$stackTrace');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_operation != null) {
      await _operation;
    }
    _operation = action();
    try {
      await _operation;
    } finally {
      _operation = null;
    }
  }
}

/// Lobi tarafında eğitim presence sayımı.
int countTrainingPresence(RealtimeChannel channel) {
  var total = 0;
  for (final state in channel.presenceState()) {
    total += state.presences.length;
  }
  return total;
}
