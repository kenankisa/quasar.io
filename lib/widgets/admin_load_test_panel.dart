import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game_screen.dart';
import '../services/admin_load_test_service.dart';
import '../services/admin_stats_service.dart';
import '../services/analytics_play_tracker.dart';
import '../services/lang_service.dart';
import '../services/player_session_service.dart';
import '../services/room_matchmaking_service.dart';

/// Yönetim paneli — eşzamanlı oyuncu yük testi.
class AdminLoadTestPanel extends StatefulWidget {
  const AdminLoadTestPanel({super.key});

  @override
  State<AdminLoadTestPanel> createState() => _AdminLoadTestPanelState();
}

class _AdminLoadTestPanelState extends State<AdminLoadTestPanel> {
  final _service = AdminLoadTestService.instance;
  final _countController = TextEditingController(text: '3');

  final Set<RoomType> _selectedRooms = {RoomType.normal};
  double _sliderCount = 3;
  bool _joining = false;

  static const _testableRooms = [
    RoomType.normal,
    RoomType.elite,
    RoomType.unique,
  ];

  static const _countPresets = [10, 25, 50, 100, 150, 200, 300, 400];

  @override
  void initState() {
    super.initState();
    if (!_service.status.isRunning && !_service.loading) {
      unawaited(_service.refresh());
    }
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  void _setCount(double value) {
    final clamped = value.round().clamp(1, AdminLoadTestService.defaultMaxPlayers);
    setState(() {
      _sliderCount = clamped.toDouble();
      _countController.text = '$clamped';
    });
  }

  int get _requestedCount {
    final parsed = int.tryParse(_countController.text.trim());
    if (parsed == null) return _sliderCount.round();
    return parsed.clamp(1, AdminLoadTestService.defaultMaxPlayers);
  }

  void _toggleRoom(RoomType type) {
    setState(() {
      if (_selectedRooms.contains(type)) {
        if (_selectedRooms.length == 1) return; // en az bir evren
        _selectedRooms.remove(type);
      } else {
        _selectedRooms.add(type);
      }
    });
  }

  Future<void> _start() async {
    FocusScope.of(context).unfocus();
    if (_selectedRooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LanguageService.instance.t('admin_load_test_no_universe'),
          ),
          backgroundColor: const Color(0xFF2A1018),
        ),
      );
      return;
    }
    final result = await _service.start(
      count: _requestedCount,
      roomTypes: _selectedRooms,
    );
    if (!mounted) return;
    final lang = LanguageService.instance;
    if (result != null) {
      unawaited(AdminStatsService.instance.refresh());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang
                .t('admin_load_test_started_ok')
                .replaceAll('{count}', '${result.started}')
                .replaceAll('{rooms}', '${result.roomsUsed}')
                .replaceAll('{universes}', result.roomTypeSummary),
          ),
          backgroundColor: const Color(0xFF0A2A22),
        ),
      );
      return;
    }

    final err = _service.error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err == null
              ? lang.t('admin_load_test_start_failed')
              : _formatError(lang, err),
        ),
        backgroundColor: const Color(0xFF2A1018),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _stop() async {
    final stopped = await _service.stop();
    if (!mounted || stopped == null) return;
    unawaited(AdminStatsService.instance.refresh());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          LanguageService.instance
              .t('admin_load_test_stopped_ok')
              .replaceAll('{count}', '$stopped'),
        ),
        backgroundColor: const Color(0xFF1A1020),
      ),
    );
  }

  Future<void> _joinSimRoom(AdminLoadTestJoinTarget target) async {
    if (_joining) return;
    setState(() => _joining = true);
    final lang = LanguageService.instance;
    try {
      await PlayerSessionService.instance.setInGame(target.roomType);
      await AnalyticsPlayTracker.instance.begin(target.roomType);
      final instance = await RoomMatchmakingService.instance.joinRoomInstance(
        target.roomInstanceId,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameScreen(
            roomType: target.roomType,
            roomInstance: instance,
          ),
        ),
      );
    } on RoomMatchmakingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${lang.t('admin_load_test_join_failed')}\n$e',
          ),
          backgroundColor: const Color(0xFF2A1018),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${lang.t('admin_load_test_join_failed')}\n$e',
          ),
          backgroundColor: const Color(0xFF2A1018),
        ),
      );
    } finally {
      await AnalyticsPlayTracker.instance.end(roomType: target.roomType);
      await PlayerSessionService.instance.setInLobby();
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([_service, lang]),
      builder: (context, _) {
        final status = _service.status;
        final busy = _service.busy;
        final accent = const Color(0xFF00F0FF);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                color: const Color(0xFF0A0A1A).withValues(alpha: 0.88),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    lang.t('admin_load_test_how_title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lang
                        .t('admin_load_test_how_body')
                        .replaceAll(
                          '{max}',
                          '${AdminLoadTestService.defaultMaxPlayers}',
                        ),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (_service.error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFF4466).withValues(alpha: 0.45),
                  ),
                  color: const Color(0xFFFF4466).withValues(alpha: 0.08),
                ),
                child: Text(
                  _formatError(lang, _service.error!),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: status.isRunning
                      ? const Color(0xFF22FFAA).withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.08),
                ),
                color: const Color(0xFF0A0A1A).withValues(alpha: 0.88),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lang.t('admin_load_test_active'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (_service.loading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF00F0FF),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${status.activePlayers}',
                    style: TextStyle(
                      color: status.isRunning
                          ? const Color(0xFF22FFAA)
                          : Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (status.byRoom.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final row in status.byRoom)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          lang
                              .t('admin_load_test_room_line')
                              .replaceAll('{room}', row.roomType)
                              .replaceAll('{players}', '${row.players}')
                              .replaceAll('{rooms}', '${row.rooms}'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                  if (_service.joinTargets.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      lang.t('admin_load_test_join_title'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lang.t('admin_load_test_join_hint'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final target in _service.joinTargets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: FilledButton.tonalIcon(
                          onPressed: busy || _joining
                              ? null
                              : () => unawaited(_joinSimRoom(target)),
                          icon: _joining
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login_rounded, size: 18),
                          label: Text(
                            lang
                                .t('admin_load_test_join_button')
                                .replaceAll(
                                  '{room}',
                                  target.roomType.instanceTitle(
                                    lang.t,
                                    number: target.instanceNumber,
                                    isLoadTest: true,
                                  ),
                                )
                                .replaceAll('{players}', '${target.players}'),
                          ),
                          style: FilledButton.styleFrom(
                            foregroundColor: const Color(0xFF22FFAA),
                            backgroundColor:
                                const Color(0xFF22FFAA).withValues(alpha: 0.1),
                            alignment: Alignment.centerLeft,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                color: const Color(0xFF0A0A1A).withValues(alpha: 0.88),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    lang.t('admin_load_test_count_label'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _sliderCount.clamp(
                            1,
                            AdminLoadTestService.defaultMaxPlayers.toDouble(),
                          ),
                          min: 1,
                          max: AdminLoadTestService.defaultMaxPlayers.toDouble(),
                          // 5'er adım — slider'ı aşırı ağırlaştırmaz
                          divisions: AdminLoadTestService.defaultMaxPlayers ~/ 5,
                          activeColor: accent,
                          inactiveColor: Colors.white.withValues(alpha: 0.12),
                          onChanged: busy ? null : _setCount,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 72,
                        child: TextField(
                          controller: _countController,
                          enabled: !busy,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.06),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: accent.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            final parsed = int.tryParse(value);
                            if (parsed == null) return;
                            setState(() {
                              _sliderCount = parsed
                                  .clamp(
                                    1,
                                    AdminLoadTestService.defaultMaxPlayers,
                                  )
                                  .toDouble();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lang
                        .t('admin_load_test_count_hint')
                        .replaceAll(
                          '{max}',
                          '${AdminLoadTestService.defaultMaxPlayers}',
                        ),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final preset in _countPresets)
                        ActionChip(
                          label: Text(
                            '$preset',
                            style: TextStyle(
                              color: _sliderCount.round() == preset
                                  ? accent
                                  : Colors.white.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          onPressed: busy ? null : () => _setCount(preset.toDouble()),
                          backgroundColor: _sliderCount.round() == preset
                              ? accent.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.04),
                          side: BorderSide(
                            color: _sliderCount.round() == preset
                                ? accent.withValues(alpha: 0.45)
                                : Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    lang.t('admin_load_test_room_label'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lang.t('admin_load_test_room_multi_hint'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final type in _testableRooms)
                        FilterChip(
                          label: Text(_roomLabel(lang, type)),
                          selected: _selectedRooms.contains(type),
                          onSelected:
                              busy ? null : (_) => _toggleRoom(type),
                          selectedColor: accent.withValues(alpha: 0.22),
                          checkmarkColor: accent,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.05),
                          labelStyle: TextStyle(
                            color: _selectedRooms.contains(type)
                                ? accent
                                : Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: _selectedRooms.contains(type)
                                ? accent.withValues(alpha: 0.55)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: busy ? null : () => unawaited(_start()),
                          icon: busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(Icons.play_arrow_rounded),
                          label: Text(lang.t('admin_load_test_start')),
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: busy || !status.isRunning
                              ? null
                              : () => unawaited(_stop()),
                          icon: const Icon(Icons.stop_rounded),
                          label: Text(lang.t('admin_load_test_stop')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF6688),
                            side: BorderSide(
                              color: const Color(0xFFFF6688)
                                  .withValues(alpha: 0.55),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _roomLabel(LanguageService lang, RoomType type) {
    return switch (type) {
      RoomType.normal => lang.t('room_normal_title'),
      RoomType.elite => lang.t('room_elite_title'),
      RoomType.unique => lang.t('room_unique_title'),
      RoomType.simple => lang.t('room_simple_title'),
    };
  }

  String _formatError(LanguageService lang, String error) {
    const detailSep = '|';
    final pipe = error.indexOf(detailSep);
    final key = pipe < 0 ? error : error.substring(0, pipe);
    final detail = pipe < 0 ? null : error.substring(pipe + 1);

    if (key == 'admin_load_test_forbidden') {
      return switch (detail) {
        'mint' => lang.t('admin_load_test_forbidden_mint'),
        'rpc' => lang.t('admin_load_test_forbidden_rpc'),
        'session' => lang.t('admin_load_test_forbidden_session'),
        _ => lang.t('admin_load_test_forbidden'),
      };
    }
    if (key == 'admin_load_test_auth_rate_limit') {
      return lang
          .t('admin_load_test_auth_rate_limit')
          .replaceAll('{alive}', detail ?? '?');
    }
    if (key == 'admin_load_test_connection_ceiling') {
      final alive = detail ?? '${_service.status.activePlayers}';
      return lang
          .t('admin_load_test_connection_ceiling')
          .replaceAll('{alive}', alive);
    }
    if (key == 'admin_load_test_start_failed' && detail != null) {
      return '${lang.t('admin_load_test_start_failed')}\n$detail';
    }
    return lang.t(key);
  }
}
