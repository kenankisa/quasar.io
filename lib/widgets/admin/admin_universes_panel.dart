import 'package:flutter/material.dart';

import '../../game/models/admin_stats.dart';
import '../../game/room_type.dart';
import '../../services/lang_service.dart';
import '../../services/room_tuning_service.dart';
import '../admin_room_tuning_editor.dart';
import 'admin_section_title.dart';

Color _accentForRoom(RoomType type) => switch (type) {
      RoomType.simple => const Color(0xFF7AD7FF),
      RoomType.normal => const Color(0xFF00F0FF),
      RoomType.elite => const Color(0xFFFFC857),
      RoomType.unique => const Color(0xFFFF00AA),
    };

String _roomTitle(LanguageService lang, RoomType type) {
  final title = lang.t(type.instanceTitleKey).replaceAll('{number}', '').trim();
  return title.isEmpty ? type.name : title;
}

/// Evren seçici + sekmeli ayar paneli (master–detail).
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

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final tier = widget.stats.tiers[_selected] ??
        AdminUniverseTierStats.empty(_selected);
    final accent = _accentForRoom(_selected);
    final tuning = RoomTuningService.instance.tuningFor(_selected);
    final saving = RoomTuningService.instance.saving;
    final huntPct = (tuning.huntPriority * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showSectionChrome) ...[
          Row(
            children: [
              Expanded(
                child: AdminSectionTitle(title: lang.t('admin_universes_section')),
              ),
              if (saving)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF00F0FF),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lang.t('admin_tune_saving'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            lang.t('admin_room_tuning_howto'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
        ] else if (saving) ...[
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00F0FF),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  lang.t('admin_tune_saving'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        _UniverseSelector(
          selected: _selected,
          stats: widget.stats,
          onSelected: (type) => setState(() {
            _selected = type;
            _showLive = false;
          }),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.32)),
            color: const Color(0xFF0A0A1A).withValues(alpha: 0.82),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _roomTitle(lang, _selected),
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
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
                                label: lang.t('admin_hunt_priority_short'),
                                value: '$huntPct%',
                                color: accent,
                              ),
                              _MetaPill(
                                label: lang.t('admin_tune_events_short'),
                                value: tuning.cosmicEventsEnabled
                                    ? lang.t('admin_tune_on')
                                    : lang.t('admin_tune_off'),
                                color: tuning.cosmicEventsEnabled
                                    ? const Color(0xFFFFC857)
                                    : Colors.white38,
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
                child: _LiveSnapshotRow(tier: tier, accent: accent),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: AdminUniverseDifficultyPresets(
                  roomType: _selected,
                  accent: accent,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: _CategoryBar(
                  accent: accent,
                  category: _category,
                  showLive: _showLive,
                  liveCount: tier.instances.length,
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
                    ? _LiveInstancesList(tier: tier, accent: accent)
                    : AdminRoomTuningEditor(
                        roomType: _selected,
                        accent: accent,
                        category: _category,
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
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
            if (saving)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF00F0FF),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      lang.t('admin_tune_saving'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            FilledButton.icon(
              onPressed: (saving || !RoomTuningService.instance.hasUnsavedChanges)
                  ? null
                  : () => RoomTuningService.instance.save(),
              icon: const Icon(Icons.save_rounded, size: 18),
              label: Text(lang.t('admin_room_tuning_save')),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00F0FF),
                foregroundColor: const Color(0xFF020208),
                disabledBackgroundColor:
                    const Color(0xFF00F0FF).withValues(alpha: 0.2),
                disabledForegroundColor:
                    Colors.white.withValues(alpha: 0.4),
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
        final wide = constraints.maxWidth >= 560;
        final children = RoomType.values.map((type) {
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

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: children[0]),
                const SizedBox(width: 8),
                Expanded(child: children[1]),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: children[2]),
                const SizedBox(width: 8),
                Expanded(child: children[3]),
              ],
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
    final lang = LanguageService.instance;
    final accent = _accentForRoom(type);
    final huntPct =
        (RoomTuningService.instance.tuningFor(type).huntPriority * 100)
            .round();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.75)
                  : accent.withValues(alpha: 0.22),
              width: selected ? 1.6 : 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: selected ? 0.2 : 0.07),
                const Color(0xFF0A0A1A).withValues(alpha: 0.92),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _roomTitle(lang, type),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                lang.t(tier.difficultyLabelKey),
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
                    color: const Color(0xFF00F0FF),
                  ),
                  const SizedBox(width: 8),
                  _MiniCount(
                    icon: Icons.smart_toy_outlined,
                    value: '${tier.bots}',
                    color: const Color(0xFFFF00AA),
                  ),
                  const Spacer(),
                  Text(
                    '$huntPct%',
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
  const _LiveSnapshotRow({required this.tier, required this.accent});

  final AdminUniverseTierStats tier;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
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
              color: const Color(0xFF00F0FF),
            ),
          ),
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
            fontSize: 18,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
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
    required this.onCategory,
    required this.onLive,
  });

  final Color accent;
  final AdminTuningCategory category;
  final bool showLive;
  final int liveCount;
  final ValueChanged<AdminTuningCategory> onCategory;
  final VoidCallback onLive;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final items = <({Object id, String label})>[
      (id: AdminTuningCategory.world, label: lang.t('admin_tune_tab_world')),
      (id: AdminTuningCategory.tempo, label: lang.t('admin_tune_tab_tempo')),
      (id: AdminTuningCategory.objects, label: lang.t('admin_tune_tab_objects')),
      (id: AdminTuningCategory.events, label: lang.t('admin_tune_tab_events')),
      (
        id: AdminTuningCategory.radiation,
        label: lang.t('admin_tune_tab_radiation'),
      ),
      (id: AdminTuningCategory.bots, label: lang.t('admin_tune_tab_bots')),
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
  const _LiveInstancesList({required this.tier, required this.accent});

  final AdminUniverseTierStats tier;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
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
            child: _InstanceRow(instance: instance, accent: accent),
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
  });

  final AdminUniverseInstance instance;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
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
            color: const Color(0xFF00F0FF),
          ),
          const SizedBox(width: 10),
          _MiniStat(
            icon: Icons.smart_toy_outlined,
            value: '${instance.bots}',
            color: const Color(0xFFFF00AA),
          ),
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
