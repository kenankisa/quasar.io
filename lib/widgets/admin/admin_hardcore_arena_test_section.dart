import 'dart:async';

import 'package:flutter/material.dart';
import '../../utils/lang_scope.dart';
import 'package:flutter/services.dart';

import '../../game/game_screen.dart';
import '../../game/models/admin_hardcore_arena_test.dart';
import '../../services/admin_hardcore_arena_test_service.dart';
import '../../services/analytics_play_tracker.dart';
import '../../services/player_session_service.dart';
import '../../services/room_matchmaking_service.dart';
import 'admin_player_radius_label.dart';
import 'admin_theme.dart';

const _accent = Color(0xFFFF3355);

/// Hardcore panel section: isolated Arena Test harness.
class AdminHardcoreArenaTestSection extends StatefulWidget {
  const AdminHardcoreArenaTestSection({super.key});

  @override
  State<AdminHardcoreArenaTestSection> createState() =>
      _AdminHardcoreArenaTestSectionState();
}

class _AdminHardcoreArenaTestSectionState
    extends State<AdminHardcoreArenaTestSection> {
  final _service = AdminHardcoreArenaTestService.instance;
  final _radiusController = TextEditingController(text: '600');

  String? _selectedUserId;
  String? _predatorId;
  String? _preyId;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _service.attach();
    _service.addListener(_onChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    _service.detach();
    _radiusController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _joinTestArena() async {
    if (_joining) return;
    setState(() => _joining = true);
    final lang = context.lang;
    _service.setAdminInArena(true);
    try {
      await PlayerSessionService.instance.setInGame(RoomType.hardcore);
      await AnalyticsPlayTracker.instance.begin(RoomType.hardcore);
      final instance =
          await RoomMatchmakingService.instance.joinHardcoreTestUniverse();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameScreen(
            roomType: RoomType.hardcore,
            roomInstance: instance,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${lang.t('admin_hc_test_join_failed')}\n$e'),
          backgroundColor: const Color(0xFF2A1018),
        ),
      );
    } finally {
      _service.setAdminInArena(false);
      await AnalyticsPlayTracker.instance.end(roomType: RoomType.hardcore);
      await PlayerSessionService.instance.setInLobby();
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _setRadius({double? fixed}) async {
    final userId = _selectedUserId;
    if (userId == null) return;
    final radius = fixed ??
        (double.tryParse(_radiusController.text.trim()) ?? 600).clamp(10, 900);
    final ok = await _service.forceSetRadius(userId: userId, radius: radius);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'OK · $radius' : (_service.error ?? 'failed')),
        backgroundColor: ok ? const Color(0xFF0A2A22) : const Color(0xFF2A1018),
      ),
    );
  }

  Future<void> _forceEat() async {
    final predator = _predatorId;
    final prey = _preyId;
    if (predator == null || prey == null || predator == prey) return;
    final ok = await _service.forceAbsorb(
      predatorId: predator,
      preyId: prey,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'OK' : (_service.error ?? 'failed')),
        backgroundColor: ok ? const Color(0xFF0A2A22) : const Color(0xFF2A1018),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final snap = _service.snapshot;
    final busy = _service.busy;
    final radii = _service.liveRadii;
    final players = snap.players;

    return Container(
      decoration: AdminTheme.softPanel(accentColor: _accent),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  lang.t('admin_hc_test_section'),
                  style: const TextStyle(
                    color: _accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.tealAccent.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  lang.t('admin_hc_test_economy_badge'),
                  style: TextStyle(
                    color: Colors.tealAccent.withValues(alpha: 0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            lang.t('admin_hc_test_hint'),
            style: const TextStyle(
              color: AdminTheme.textMuted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          if (_service.migrationMissing) ...[
            const SizedBox(height: 10),
            AdminErrorBanner(message: lang.t('admin_hc_test_migration_hint')),
          ],
          if (_service.error != null && !_service.migrationMissing) ...[
            const SizedBox(height: 10),
            AdminErrorBanner(
              message: _service.error!.startsWith('admin_')
                  ? lang.t(_service.error!)
                  : _service.error!,
            ),
          ],
          const SizedBox(height: 14),
          Text(
            lang.t('admin_hc_test_gates'),
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lang
                .t('admin_hc_test_gates_detail')
                .replaceAll('{size}', '${snap.victoryRadius}')
                .replaceAll('{alive}', '${snap.victoryMinAlive}')
                .replaceAll('{cap}', '${snap.lowPopRadiusCap.round()}')
                .replaceAll(
                  '{spawn}',
                  '${snap.spawnProtectionSeconds.round()}',
                )
                .replaceAll(
                  '{late}',
                  '${snap.lateFoodSoftcapRadius.round()}',
                )
                .replaceAll(
                  '{lateMult}',
                  '${(snap.lateFoodSoftcapMultiplier * 100).round()}',
                ),
            style: const TextStyle(
              color: AdminTheme.textMuted,
              fontSize: 11,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${lang.t('admin_hc_test_sims')} · '
            '${lang.t('admin_hc_test_active').replaceAll('{n}', '${_service.activeSimCount}')}'
            ' / ${_service.targetCount}'
            ' (max ${AdminHardcoreArenaTestService.maxPlayers}) · '
            '${lang.t('admin_hc_test_seats').replaceAll('{in}', '${snap.seatOccupancy}').replaceAll('{cap}', '${snap.maxPlayers}')}'
            '${_service.queuedSimCount > 0 ? ' · ${lang.t('admin_hc_test_queued').replaceAll('{n}', '${_service.queuedSimCount}')}' : ''}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionChip(
                label: lang.t('admin_hc_test_minus'),
                onPressed: busy
                    ? null
                    : () => unawaited(_service.decrementSims()),
              ),
              _ActionChip(
                label: lang.t('admin_hc_test_plus'),
                onPressed: busy
                    ? null
                    : () => unawaited(_service.incrementSims()),
              ),
              _ActionChip(
                label: lang.t('admin_hc_test_plus_10'),
                onPressed: busy
                    ? null
                    : () => unawaited(
                          _service.setSimCount(_service.targetCount + 10),
                        ),
              ),
              _ActionChip(
                label: lang.t('admin_hc_test_fill_50'),
                onPressed: busy
                    ? null
                    : () => unawaited(
                          _service.setSimCount(
                            AdminHardcoreArenaTestService.maxPlayers,
                          ),
                        ),
                primary: true,
              ),
              _ActionChip(
                label: lang.t('admin_hc_test_stop'),
                onPressed: _service.isStopping
                    ? null
                    : () => unawaited(_service.stopAll()),
                danger: true,
              ),
              _ActionChip(
                label: _joining
                    ? lang.t('admin_hc_test_joining')
                    : lang.t('admin_hc_test_join'),
                onPressed: busy || _joining
                    ? null
                    : () => unawaited(_joinTestArena()),
                primary: true,
              ),
              if (busy)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Text(
                    lang.t('admin_hc_test_busy'),
                    style: const TextStyle(
                      color: AdminTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            lang.t('admin_hc_test_events'),
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 140),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: _service.eventLog.isEmpty
                ? Text(
                    lang.t('admin_hc_test_events_empty'),
                    style: const TextStyle(
                      color: AdminTheme.textMuted,
                      fontSize: 11,
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _service.eventLog.length,
                    itemBuilder: (context, i) {
                      final line = _service.eventLog[i];
                      final isWin = line.contains(' won ');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          line,
                          style: TextStyle(
                            color: isWin
                                ? const Color(0xFFFFD54F)
                                : Colors.white70,
                            fontSize: 11,
                            fontWeight:
                                isWin ? FontWeight.w700 : FontWeight.w500,
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 640;
              final inside = _PlayerListCard(
                title: lang
                    .t('admin_hc_test_inside')
                    .replaceAll('{n}', '${players.length}'),
                empty: lang.t('admin_hc_test_empty_inside'),
                children: [
                  for (final p in players)
                    _PlayerTile(
                      player: p,
                      radius: radii[p.userId] ?? p.radius,
                      selected: _selectedUserId == p.userId,
                      onTap: () => setState(() {
                        _selectedUserId = p.userId;
                        _predatorId ??= p.userId;
                      }),
                    ),
                ],
              );
              final outside = _PlayerListCard(
                title: lang
                    .t('admin_hc_test_outside')
                    .replaceAll('{n}', '${snap.queueCount}'),
                empty: lang.t('admin_hc_test_empty_outside'),
                children: [
                  for (final q in snap.queue)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '#${q.position}  ${q.username}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: inside),
                    const SizedBox(width: 12),
                    Expanded(child: outside),
                  ],
                );
              }
              return Column(
                children: [
                  inside,
                  const SizedBox(height: 12),
                  outside,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            lang.t('admin_hc_test_select_player'),
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: _selectedUserId != null &&
                    players.any((p) => p.userId == _selectedUserId)
                ? _selectedUserId
                : null,
            decoration: _dropdownDecoration(),
            dropdownColor: const Color(0xFF1A1218),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            items: [
              for (final p in players)
                DropdownMenuItem(
                  value: p.userId,
                  child: Text(
                    '${p.username}${p.isSim ? ' · SIM' : ''}'
                    '${p.isAdmin ? ' · ADMIN' : ''}',
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _selectedUserId = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _radiusController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _dropdownDecoration().copyWith(
                    labelText: lang.t('admin_hc_test_set_radius'),
                    labelStyle: const TextStyle(
                      color: AdminTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ActionChip(
                label: lang.t('admin_hc_test_set_radius'),
                onPressed: _selectedUserId == null || busy
                    ? null
                    : () => unawaited(_setRadius()),
              ),
              const SizedBox(width: 8),
              _ActionChip(
                label: lang.t('admin_hc_test_radius_600'),
                onPressed: _selectedUserId == null || busy
                    ? null
                    : () => unawaited(_setRadius(fixed: 600)),
                primary: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            lang.t('admin_hc_test_force_eat'),
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _predatorId != null &&
                          players.any((p) => p.userId == _predatorId)
                      ? _predatorId
                      : null,
                  decoration: _dropdownDecoration().copyWith(
                    labelText: lang.t('admin_hc_test_predator'),
                    labelStyle: const TextStyle(
                      color: AdminTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  dropdownColor: const Color(0xFF1A1218),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: [
                    for (final p in players)
                      DropdownMenuItem(
                        value: p.userId,
                        child: Text(p.username),
                      ),
                  ],
                  onChanged: (v) => setState(() => _predatorId = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _preyId != null &&
                          players.any((p) => p.userId == _preyId)
                      ? _preyId
                      : null,
                  decoration: _dropdownDecoration().copyWith(
                    labelText: lang.t('admin_hc_test_prey'),
                    labelStyle: const TextStyle(
                      color: AdminTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  dropdownColor: const Color(0xFF1A1218),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: [
                    for (final p in players)
                      DropdownMenuItem(
                        value: p.userId,
                        child: Text(p.username),
                      ),
                  ],
                  onChanged: (v) => setState(() => _preyId = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: _ActionChip(
              label: lang.t('admin_hc_test_force_eat'),
              onPressed: busy ||
                      _predatorId == null ||
                      _preyId == null ||
                      _predatorId == _preyId
                  ? null
                  : () => unawaited(_forceEat()),
              danger: true,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.25),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? const Color(0xFF3A1520)
        : primary
            ? _accent.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.08);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              color: onPressed == null
                  ? Colors.white38
                  : Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerListCard extends StatelessWidget {
  const _PlayerListCard({
    required this.title,
    required this.empty,
    required this.children,
  });

  final String title;
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          if (children.isEmpty)
            Text(
              empty,
              style: const TextStyle(
                color: AdminTheme.textMuted,
                fontSize: 12,
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    required this.player,
    required this.onTap,
    this.radius,
    this.selected = false,
  });

  final AdminHardcoreArenaTestPlayer player;
  final double? radius;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Material(
      color: selected
          ? _accent.withValues(alpha: 0.18)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  player.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (player.isSim) ...[
                const SizedBox(width: 4),
                Text(
                  lang.t('admin_hc_test_sim_badge'),
                  style: TextStyle(
                    color: Colors.amber.withValues(alpha: 0.85),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              if (player.isAdmin) ...[
                const SizedBox(width: 4),
                Text(
                  lang.t('admin_hardcore_player_admin'),
                  style: TextStyle(
                    color: _accent.withValues(alpha: 0.9),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              if (radius != null && radius! > 0) ...[
                const SizedBox(width: 8),
                AdminPlayerRadiusLabel(radius: radius!, accent: _accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
