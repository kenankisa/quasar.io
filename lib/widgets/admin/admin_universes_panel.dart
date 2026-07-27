import 'package:flutter/material.dart';
import '../../utils/lang_scope.dart';

import '../../game/models/admin_stats.dart';
import '../../game/room_type.dart';
import '../../services/lang_service.dart';
import '../../services/room_tuning_service.dart';
import '../admin_room_tuning_editor.dart';
import 'admin_theme.dart';

Color accentForRoom(RoomType type) => switch (type) {
      RoomType.simple => const Color(0xFF7AD7FF),
      RoomType.normal => const Color(0xFF00D4E8),
      RoomType.elite => const Color(0xFFFFC857),
      RoomType.unique => const Color(0xFFFF00AA),
      RoomType.hardcore => const Color(0xFFFF3355),
    };

String roomTitle(LanguageService lang, RoomType type) {
  final title = lang.t(type.instanceTitleKey).replaceAll('{number}', '').trim();
  return title.isEmpty ? type.name : title;
}

/// Universe master–detail tuning with players-only Hardcore support.
class AdminUniversesTuningPanel extends StatefulWidget {
  const AdminUniversesTuningPanel({
    super.key,
    required this.stats,
    this.showSectionChrome = true,
  });

  final AdminStatsSnapshot stats;
  final bool showSectionChrome;

  @override
  State<AdminUniversesTuningPanel> createState() =>
      _AdminUniversesTuningPanelState();
}

class _AdminUniversesTuningPanelState extends State<AdminUniversesTuningPanel> {
  RoomType _selected = RoomType.normal;
  AdminTuningCategory _category = AdminTuningCategory.world;
  bool _showLive = false;

  void _selectRoom(RoomType type) {
    setState(() {
      _selected = type;
      _showLive = false;
      if (!type.allowsBots && _category == AdminTuningCategory.bots) {
        _category = AdminTuningCategory.hardcoreRules;
      }
      if (type.allowsBots && _category == AdminTuningCategory.hardcoreRules) {
        _category = AdminTuningCategory.world;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final tier = widget.stats.tiers[_selected] ??
        AdminUniverseTierStats.empty(_selected);
    final accent = accentForRoom(_selected);
    final tuning = RoomTuningService.instance.tuningFor(_selected);
    final saving = RoomTuningService.instance.saving;
    final playersOnly = _selected.isPlayersOnly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (saving)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AdminTheme.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  lang.t('admin_tune_saving'),
                  style: const TextStyle(
                    color: AdminTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        _UniverseSelector(
          selected: _selected,
          stats: widget.stats,
          onSelected: _selectRoom,
        ),
        const SizedBox(height: 14),
        Container(
          decoration: AdminTheme.softPanel(accentColor: accent),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            roomTitle(lang, _selected),
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _MetaPill(
                                label: lang.t('admin_difficulty'),
                                value: lang.t(tier.difficultyLabelKey),
                                color: accent,
                              ),
                              _MetaPill(
                                label: lang.t('admin_tune_world_size'),
                                value: tuning.worldSize.round().toString(),
                                color: accent,
                              ),
                              _MetaPill(
                                label: lang.t('admin_tune_max_players_short'),
                                value: '${tuning.maxPlayers}',
                                color: accent,
                              ),
                              if (playersOnly) ...[
                                _MetaPill(
                                  label: lang.t('admin_tune_mode'),
                                  value: lang.t('admin_tune_players_only'),
                                  color: const Color(0xFFFF3355),
                                ),
                                _MetaPill(
                                  label: lang.t('admin_tune_victory_radius'),
                                  value: tuning.victoryRadius.round().toString(),
                                  color: const Color(0xFFFF3355),
                                ),
                              ] else
                                _MetaPill(
                                  label: lang.t('admin_hunt_priority_short'),
                                  value:
                                      '${(tuning.huntPriority * 100).round()}%',
                                  color: accent,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: saving
                          ? null
                          : () => RoomTuningService.instance
                              .resetRoomToDefaults(_selected),
                      child: Text(
                        lang.t('admin_room_tuning_reset_one'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _LiveSnapshotRow(
                  tier: tier,
                  accent: accent,
                  playersOnly: playersOnly,
                  maxPlayers: tuning.maxPlayers,
                  worldSize: tuning.worldSize.round(),
                ),
              ),
              if (!playersOnly)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: AdminUniverseDifficultyPresets(
                    roomType: _selected,
                    accent: accent,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(AdminTheme.radiusSm),
                      color: accent.withValues(alpha: 0.08),
                      border: Border.all(color: accent.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.whatshot, color: accent, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            lang.t('admin_tune_hardcore_banner'),
                            style: TextStyle(
                              color: accent.withValues(alpha: 0.9),
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: _CategoryBar(
                  accent: accent,
                  category: _category,
                  showLive: _showLive,
                  liveCount: tier.instances.length,
                  allowBots: _selected.allowsBots,
                  playersOnly: playersOnly,
                  onCategory: (c) => setState(() {
                    _category = c;
                    _showLive = false;
                  }),
                  onLive: () => setState(() => _showLive = true),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                child: _showLive
                    ? _LiveInstancesList(
                        tier: tier,
                        accent: accent,
                        playersOnly: playersOnly,
                      )
                    : AdminRoomTuningEditor(
                        roomType: _selected,
                        accent: accent,
                        category: _category,
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => RoomTuningService.instance.resetToDefaults(),
              child: Text(
                lang.t('admin_room_tuning_reset'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed:
                  (saving || !RoomTuningService.instance.hasUnsavedChanges)
                      ? null
                      : () => RoomTuningService.instance.save(),
              icon: const Icon(Icons.save_rounded, size: 18),
              label: Text(lang.t('admin_room_tuning_save')),
              style: FilledButton.styleFrom(
                backgroundColor: AdminTheme.accent,
                foregroundColor: AdminTheme.bg,
                disabledBackgroundColor:
                    AdminTheme.accent.withValues(alpha: 0.2),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _UniverseSelector extends StatelessWidget {
  const _UniverseSelector({
    required this.selected,
    required this.stats,
    required this.onSelected,
  });

  final RoomType selected;
  final AdminStatsSnapshot stats;
  final ValueChanged<RoomType> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final children = RoomType.values
            .where((type) => type != RoomType.hardcore)
            .map((type) {
          final tier = stats.tiers[type] ?? AdminUniverseTierStats.empty(type);
          return _UniversePickTile(
            type: type,
            tier: tier,
            selected: selected == type,
            onTap: () => onSelected(type),
          );
        }).toList();

        if (wide) {
          return Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: children[i]),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final child in children)
              SizedBox(
                width: (constraints.maxWidth - 8) / 2,
                child: child,
              ),
          ],
        );
      },
    );
  }
}

class _UniversePickTile extends StatelessWidget {
  const _UniversePickTile({
    required this.type,
    required this.tier,
    required this.selected,
    required this.onTap,
  });

  final RoomType type;
  final AdminUniverseTierStats tier;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final accent = accentForRoom(type);
    final tuning = RoomTuningService.instance.tuningFor(type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AdminTheme.radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AdminTheme.radius),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.8)
                  : accent.withValues(alpha: 0.22),
              width: selected ? 1.6 : 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: selected ? 0.22 : 0.07),
                AdminTheme.surface.withValues(alpha: 0.95),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      roomTitle(lang, type),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (type.isPlayersOnly)
                    Icon(Icons.person_rounded, size: 14, color: accent),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                type.isPlayersOnly
                    ? lang.t('admin_tune_players_only')
                    : lang.t(tier.difficultyLabelKey),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _MiniCount(
                    icon: Icons.public_rounded,
                    value: '${tier.activeUniverses}',
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  _MiniCount(
                    icon: Icons.person_rounded,
                    value: '${tier.players}',
                    color: AdminTheme.accent,
                  ),
                  if (type.allowsBots) ...[
                    const SizedBox(width: 8),
                    _MiniCount(
                      icon: Icons.smart_toy_outlined,
                      value: '${tier.bots}',
                      color: const Color(0xFFFF00AA),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '${tuning.maxPlayers}',
                    style: TextStyle(
                      color: accent.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniCount extends StatelessWidget {
  const _MiniCount({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color.withValues(alpha: 0.75)),
        const SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveSnapshotRow extends StatelessWidget {
  const _LiveSnapshotRow({
    required this.tier,
    required this.accent,
    required this.playersOnly,
    required this.maxPlayers,
    required this.worldSize,
  });

  final AdminUniverseTierStats tier;
  final Color accent;
  final bool playersOnly;
  final int maxPlayers;
  final int worldSize;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AdminTheme.radiusSm),
        color: Colors.white.withValues(alpha: 0.03),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SnapshotCell(
              label: lang.t('lobby_stat_universes_short'),
              value: '${tier.activeUniverses}',
              color: accent,
            ),
          ),
          Expanded(
            child: _SnapshotCell(
              label: lang.t('lobby_stat_players_short'),
              value: '${tier.players}',
              color: AdminTheme.accent,
            ),
          ),
          Expanded(
            child: _SnapshotCell(
              label: lang.t('admin_tune_max_players_short'),
              value: '$maxPlayers',
              color: AdminTheme.accentSoft,
            ),
          ),
          Expanded(
            child: _SnapshotCell(
              label: lang.t('admin_tune_world_size_short'),
              value: '$worldSize',
              color: AdminTheme.warning,
            ),
          ),
          if (!playersOnly)
            Expanded(
              child: _SnapshotCell(
                label: lang.t('lobby_stat_bots_short'),
                value: '${tier.bots}',
                color: const Color(0xFFFF00AA),
              ),
            ),
        ],
      ),
    );
  }
}

class _SnapshotCell extends StatelessWidget {
  const _SnapshotCell({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.accent,
    required this.category,
    required this.showLive,
    required this.liveCount,
    required this.allowBots,
    required this.playersOnly,
    required this.onCategory,
    required this.onLive,
  });

  final Color accent;
  final AdminTuningCategory category;
  final bool showLive;
  final int liveCount;
  final bool allowBots;
  final bool playersOnly;
  final ValueChanged<AdminTuningCategory> onCategory;
  final VoidCallback onLive;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final items = <({Object id, String label})>[
      (id: AdminTuningCategory.world, label: lang.t('admin_tune_tab_world')),
      (id: AdminTuningCategory.tempo, label: lang.t('admin_tune_tab_tempo')),
      (id: AdminTuningCategory.objects, label: lang.t('admin_tune_tab_objects')),
      (id: AdminTuningCategory.events, label: lang.t('admin_tune_tab_events')),
      (
        id: AdminTuningCategory.radiation,
        label: lang.t('admin_tune_tab_radiation'),
      ),
      if (allowBots)
        (id: AdminTuningCategory.bots, label: lang.t('admin_tune_tab_bots')),
      if (playersOnly)
        (
          id: AdminTuningCategory.hardcoreRules,
          label: lang.t('admin_tune_tab_hardcore_rules'),
        ),
      (
        id: 'live',
        label:
            '${lang.t('admin_tune_tab_live')}${liveCount > 0 ? ' · $liveCount' : ''}',
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items) ...[
            _CategoryChip(
              label: item.label,
              selected: item.id == 'live'
                  ? showLive
                  : (!showLive && item.id == category),
              accent: accent,
              onTap: () {
                if (item.id == 'live') {
                  onLive();
                } else {
                  onCategory(item.id as AdminTuningCategory);
                }
              },
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected
                ? accent.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? accent : Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveInstancesList extends StatelessWidget {
  const _LiveInstancesList({
    required this.tier,
    required this.accent,
    required this.playersOnly,
  });

  final AdminUniverseTierStats tier;
  final Color accent;
  final bool playersOnly;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    if (tier.instances.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          lang.t('admin_no_active_universes'),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 13,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          lang.t('admin_live_instances'),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...tier.instances.map(
          (instance) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _InstanceRow(
              instance: instance,
              accent: accent,
              playersOnly: playersOnly,
            ),
          ),
        ),
      ],
    );
  }
}

class _InstanceRow extends StatelessWidget {
  const _InstanceRow({
    required this.instance,
    required this.accent,
    required this.playersOnly,
  });

  final AdminUniverseInstance instance;
  final Color accent;
  final bool playersOnly;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final name = instance.roomType.instanceTitle(
      lang.t,
      number: instance.instanceNumber,
      isLoadTest: instance.isLoadTest,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          _MiniStat(
            icon: Icons.person_rounded,
            value: '${instance.players}',
            color: AdminTheme.accent,
          ),
          if (!playersOnly) ...[
            const SizedBox(width: 10),
            _MiniStat(
              icon: Icons.smart_toy_outlined,
              value: '${instance.bots}',
              color: const Color(0xFFFF00AA),
            ),
          ],
          const SizedBox(width: 10),
          _MiniStat(
            icon: Icons.radar_rounded,
            value: '${instance.leaderRadius}',
            color: accent,
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
