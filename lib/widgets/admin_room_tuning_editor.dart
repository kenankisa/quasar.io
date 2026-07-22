import 'package:flutter/material.dart';

import '../game/config/bot_difficulty.dart';
import '../game/config/universe_difficulty.dart';
import '../game/models/room_game_tuning.dart';
import '../game/room_type.dart';
import '../services/lang_service.dart';
import '../services/room_tuning_service.dart';

enum AdminTuningCategory {
  world,
  tempo,
  objects,
  events,
  radiation,
  bots,
}

/// Seçili evren için sekmeli denge editörü.
class AdminRoomTuningEditor extends StatelessWidget {
  const AdminRoomTuningEditor({
    super.key,
    required this.roomType,
    required this.accent,
    required this.category,
  });

  final RoomType roomType;
  final Color accent;
  final AdminTuningCategory category;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final tuning = RoomTuningService.instance.tuningFor(roomType);
    final saving = RoomTuningService.instance.saving;
    final defaults = RoomGameTuning.defaultsFor(roomType);

    return switch (category) {
      AdminTuningCategory.world => _WorldPane(
          roomType: roomType,
          tuning: tuning,
          defaults: defaults,
          saving: saving,
          accent: accent,
          lang: lang,
        ),
      AdminTuningCategory.tempo => _TempoPane(
          roomType: roomType,
          tuning: tuning,
          defaults: defaults,
          saving: saving,
          accent: accent,
          lang: lang,
        ),
      AdminTuningCategory.objects => _ObjectsPane(
          roomType: roomType,
          tuning: tuning,
          saving: saving,
          accent: accent,
          lang: lang,
        ),
      AdminTuningCategory.events => _EventsPane(
          roomType: roomType,
          tuning: tuning,
          defaults: defaults,
          saving: saving,
          accent: accent,
          lang: lang,
        ),
      AdminTuningCategory.radiation => _RadiationPane(
          roomType: roomType,
          tuning: tuning,
          defaults: defaults,
          saving: saving,
          accent: accent,
          lang: lang,
        ),
      AdminTuningCategory.bots => _BotsPane(
          roomType: roomType,
          tuning: tuning,
          defaults: defaults,
          saving: saving,
          accent: accent,
          lang: lang,
        ),
    };
  }

  static Future<void> patch(
    RoomType type,
    RoomGameTuning Function(RoomGameTuning) transform, [
    bool persist = false,
  ]) {
    return RoomTuningService.instance.updateTuning(
      type,
      transform,
      persist: persist,
    );
  }
}

class _WorldPane extends StatelessWidget {
  const _WorldPane({
    required this.roomType,
    required this.tuning,
    required this.defaults,
    required this.saving,
    required this.accent,
    required this.lang,
  });

  final RoomType roomType;
  final RoomGameTuning tuning;
  final RoomGameTuning defaults;
  final bool saving;
  final Color accent;
  final LanguageService lang;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CategoryIntro(
          text: lang.t('admin_tune_world_hint'),
          title: lang.t('admin_tune_tab_world'),
          helpKey: 'admin_help_world',
          accent: accent,
        ),
        const SizedBox(height: 10),
        _SliderRow(
          label: lang.t('admin_tune_victory_radius'),
          helpKey: 'admin_help_victory_radius',
          value: tuning.victoryRadius,
          min: 200,
          max: 900,
          divisions: 70,
          display: tuning.victoryRadius.round().toString(),
          defaultLabel: defaults.victoryRadius.round().toString(),
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(victoryRadius: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(victoryRadius: v),
          ),
        ),
        _SliderRow(
          label: lang.t('admin_tune_player_start_radius'),
          helpKey: 'admin_help_player_start_radius',
          value: tuning.playerStartRadius,
          min: 12,
          max: 45,
          divisions: 33,
          display: tuning.playerStartRadius.round().toString(),
          defaultLabel: defaults.playerStartRadius.round().toString(),
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(playerStartRadius: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(playerStartRadius: v),
          ),
        ),
        _SliderRow(
          label: lang.t('admin_tune_world_size'),
          helpKey: 'admin_help_world_size',
          value: tuning.worldSize,
          min: 4000,
          max: 12000,
          divisions: 80,
          display: tuning.worldSize.round().toString(),
          defaultLabel: defaults.worldSize.round().toString(),
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(worldSize: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(worldSize: v),
          ),
        ),
        _SliderRow(
          label: lang.t('admin_tune_food_growth'),
          helpKey: 'admin_help_food_growth',
          value: tuning.foodGrowthMultiplier,
          min: 0.3,
          max: 1.2,
          divisions: 90,
          display: tuning.foodGrowthMultiplier.toStringAsFixed(2),
          defaultLabel: defaults.foodGrowthMultiplier.toStringAsFixed(2),
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(foodGrowthMultiplier: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(foodGrowthMultiplier: v),
          ),
        ),
        _SliderRow(
          label: lang.t('admin_tune_gravity'),
          helpKey: 'admin_help_gravity',
          value: tuning.gravityMultiplier,
          min: 0.3,
          max: 2.0,
          divisions: 34,
          display: tuning.gravityMultiplier.toStringAsFixed(2),
          defaultLabel: defaults.gravityMultiplier.toStringAsFixed(2),
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(gravityMultiplier: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(gravityMultiplier: v),
          ),
        ),
      ],
    );
  }
}

class _TempoPane extends StatelessWidget {
  const _TempoPane({
    required this.roomType,
    required this.tuning,
    required this.defaults,
    required this.saving,
    required this.accent,
    required this.lang,
  });

  final RoomType roomType;
  final RoomGameTuning tuning;
  final RoomGameTuning defaults;
  final bool saving;
  final Color accent;
  final LanguageService lang;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CategoryIntro(
          text: lang.t('admin_tune_tempo_hint'),
          title: lang.t('admin_tune_tab_tempo'),
          helpKey: 'admin_help_tempo',
          accent: accent,
        ),
        const SizedBox(height: 10),
        _SliderRow(
          label: lang.t('admin_tune_target_min'),
          helpKey: 'admin_help_target_min',
          value: tuning.targetMinutesMin,
          min: 0.5,
          max: 20,
          divisions: 39,
          display: '${tuning.targetMinutesMin.toStringAsFixed(1)}m',
          defaultLabel: '${defaults.targetMinutesMin.toStringAsFixed(1)}m',
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(targetMinutesMin: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(targetMinutesMin: v),
          ),
        ),
        _SliderRow(
          label: lang.t('admin_tune_target_max'),
          helpKey: 'admin_help_target_max',
          value: tuning.targetMinutesMax,
          min: 0.5,
          max: 20,
          divisions: 39,
          display: '${tuning.targetMinutesMax.toStringAsFixed(1)}m',
          defaultLabel: '${defaults.targetMinutesMax.toStringAsFixed(1)}m',
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(targetMinutesMax: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(targetMinutesMax: v),
          ),
        ),
        _SliderRow(
          label: lang.t('admin_tune_early_duration'),
          helpKey: 'admin_help_early_duration',
          value: tuning.earlyGameDurationSeconds,
          min: 0,
          max: 180,
          divisions: 180,
          display: '${tuning.earlyGameDurationSeconds.round()}s',
          defaultLabel: '${defaults.earlyGameDurationSeconds.round()}s',
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(earlyGameDurationSeconds: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(earlyGameDurationSeconds: v),
          ),
        ),
        _SliderRow(
          label: lang.t('admin_tune_early_growth'),
          helpKey: 'admin_help_early_growth',
          value: tuning.earlyGamePlayerGrowthMultiplier,
          min: 0.8,
          max: 2.0,
          divisions: 24,
          display: tuning.earlyGamePlayerGrowthMultiplier.toStringAsFixed(2),
          defaultLabel:
              defaults.earlyGamePlayerGrowthMultiplier.toStringAsFixed(2),
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(earlyGamePlayerGrowthMultiplier: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(earlyGamePlayerGrowthMultiplier: v),
          ),
        ),
        _SliderRow(
          label: lang.t('admin_tune_respawn_delay'),
          helpKey: 'admin_help_respawn_delay',
          value: tuning.respawnDelayMultiplier,
          min: 0.4,
          max: 2.0,
          divisions: 32,
          display: tuning.respawnDelayMultiplier.toStringAsFixed(2),
          defaultLabel: defaults.respawnDelayMultiplier.toStringAsFixed(2),
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(respawnDelayMultiplier: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(respawnDelayMultiplier: v),
          ),
        ),
      ],
    );
  }
}

class _ObjectsPane extends StatelessWidget {
  const _ObjectsPane({
    required this.roomType,
    required this.tuning,
    required this.saving,
    required this.accent,
    required this.lang,
  });

  final RoomType roomType;
  final RoomGameTuning tuning;
  final bool saving;
  final Color accent;
  final LanguageService lang;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, int value, int max, void Function(int) set})>[
      (
        label: lang.t('admin_tune_asteroids'),
        value: tuning.asteroidCount,
        max: 800,
        set: (v) => AdminRoomTuningEditor.patch(
          roomType,
          (t) => t.copyWith(asteroidCount: v),
        ),
      ),
      (
        label: lang.t('admin_tune_meteorites'),
        value: tuning.meteoriteCount,
        max: 800,
        set: (v) => AdminRoomTuningEditor.patch(
          roomType,
          (t) => t.copyWith(meteoriteCount: v),
        ),
      ),
      (
        label: lang.t('admin_tune_planets'),
        value: tuning.planetCount,
        max: 800,
        set: (v) => AdminRoomTuningEditor.patch(
          roomType,
          (t) => t.copyWith(planetCount: v),
        ),
      ),
      (
        label: lang.t('admin_tune_quasar_fragments'),
        value: tuning.quasarFragmentCount,
        max: 800,
        set: (v) => AdminRoomTuningEditor.patch(
          roomType,
          (t) => t.copyWith(quasarFragmentCount: v),
        ),
      ),
      (
        label: lang.t('admin_tune_large_asteroids'),
        value: tuning.asteroidTier6Count,
        max: 800,
        set: (v) => AdminRoomTuningEditor.patch(
          roomType,
          (t) => t.copyWith(asteroidTier6Count: v),
        ),
      ),
      (
        label: lang.t('admin_tune_xlarge_asteroids'),
        value: tuning.asteroidTier7Count,
        max: 800,
        set: (v) => AdminRoomTuningEditor.patch(
          roomType,
          (t) => t.copyWith(asteroidTier7Count: v),
        ),
      ),
      (
        label: lang.t('admin_tune_giant_asteroids'),
        value: tuning.asteroidTier8Count,
        max: 800,
        set: (v) => AdminRoomTuningEditor.patch(
          roomType,
          (t) => t.copyWith(asteroidTier8Count: v),
        ),
      ),
      (
        label: lang.t('admin_tune_mines'),
        value: tuning.mineCount,
        max: 20,
        set: (v) => AdminRoomTuningEditor.patch(
          roomType,
          (t) => t.copyWith(mineCount: v),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CategoryIntro(
          text: lang.t('admin_tune_objects_hint'),
          title: lang.t('admin_tune_tab_objects'),
          helpKey: 'admin_help_objects',
          accent: accent,
        ),
        const SizedBox(height: 10),
        ...items.map(
          (item) => _ObjectCountTile(
            label: item.label,
            value: item.value,
            max: item.max,
            enabled: !saving,
            accent: accent,
            onChanged: item.set,
            helpKey: 'admin_help_object_count',
          ),
        ),
      ],
    );
  }
}

class _EventsPane extends StatelessWidget {
  const _EventsPane({
    required this.roomType,
    required this.tuning,
    required this.defaults,
    required this.saving,
    required this.accent,
    required this.lang,
  });

  final RoomType roomType;
  final RoomGameTuning tuning;
  final RoomGameTuning defaults;
  final bool saving;
  final Color accent;
  final LanguageService lang;

  @override
  Widget build(BuildContext context) {
    final eventsOn = tuning.cosmicEventsEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CategoryIntro(
          text: lang.t('admin_tune_events_enabled_hint'),
          title: lang.t('admin_tune_tab_events'),
          helpKey: 'admin_help_events',
          accent: accent,
        ),
        const SizedBox(height: 8),
        _ToggleCard(
          title: lang.t('admin_tune_events_enabled'),
          helpKey: 'admin_help_events_enabled',
          value: eventsOn,
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(cosmicEventsEnabled: v),
          ),
        ),
        const SizedBox(height: 12),
        IgnorePointer(
          ignoring: !eventsOn,
          child: Opacity(
            opacity: eventsOn ? 1 : 0.38,
            child: Column(
              children: [
                _SliderRow(
                  label: lang.t('admin_tune_supernova_interval'),
                  helpKey: 'admin_help_supernova_interval',
                  value: tuning.supernovaIntervalSeconds,
                  min: 0,
                  max: 180,
                  divisions: 180,
                  display: '${tuning.supernovaIntervalSeconds.round()}s',
                  defaultLabel:
                      '${defaults.supernovaIntervalSeconds.round()}s',
                  enabled: !saving && eventsOn,
                  accent: accent,
                  onChanged: (v) => AdminRoomTuningEditor.patch(
                    roomType,
                    (t) => t.copyWith(supernovaIntervalSeconds: v),
                    false,
                  ),
                  onChangeEnd: (v) => AdminRoomTuningEditor.patch(
                    roomType,
                    (t) => t.copyWith(supernovaIntervalSeconds: v),
                  ),
                ),
                _SliderRow(
                  label: lang.t('admin_tune_supernova_first'),
                  helpKey: 'admin_help_supernova_first',
                  value: tuning.supernovaFirstDelaySeconds,
                  min: 0,
                  max: 180,
                  divisions: 180,
                  display: '${tuning.supernovaFirstDelaySeconds.round()}s',
                  defaultLabel:
                      '${defaults.supernovaFirstDelaySeconds.round()}s',
                  enabled: !saving && eventsOn,
                  accent: accent,
                  onChanged: (v) => AdminRoomTuningEditor.patch(
                    roomType,
                    (t) => t.copyWith(supernovaFirstDelaySeconds: v),
                    false,
                  ),
                  onChangeEnd: (v) => AdminRoomTuningEditor.patch(
                    roomType,
                    (t) => t.copyWith(supernovaFirstDelaySeconds: v),
                  ),
                ),
                _SliderRow(
                  label: lang.t('admin_tune_meteor_cooldown'),
                  helpKey: 'admin_help_meteor_cooldown',
                  value: tuning.meteorShowerInitialCooldown,
                  min: 0,
                  max: 180,
                  divisions: 180,
                  display: '${tuning.meteorShowerInitialCooldown.round()}s',
                  defaultLabel:
                      '${defaults.meteorShowerInitialCooldown.round()}s',
                  enabled: !saving && eventsOn,
                  accent: accent,
                  onChanged: (v) => AdminRoomTuningEditor.patch(
                    roomType,
                    (t) => t.copyWith(meteorShowerInitialCooldown: v),
                    false,
                  ),
                  onChangeEnd: (v) => AdminRoomTuningEditor.patch(
                    roomType,
                    (t) => t.copyWith(meteorShowerInitialCooldown: v),
                  ),
                ),
                _SliderRow(
                  label: lang.t('admin_tune_event_growth_cap'),
                  helpKey: 'admin_help_event_growth_cap',
                  value: tuning.eventGrowthCapPerBurst,
                  min: 0,
                  max: 80,
                  divisions: 80,
                  display: tuning.eventGrowthCapPerBurst.toStringAsFixed(0),
                  defaultLabel:
                      defaults.eventGrowthCapPerBurst.toStringAsFixed(0),
                  enabled: !saving && eventsOn,
                  accent: accent,
                  onChanged: (v) => AdminRoomTuningEditor.patch(
                    roomType,
                    (t) => t.copyWith(eventGrowthCapPerBurst: v),
                    false,
                  ),
                  onChangeEnd: (v) => AdminRoomTuningEditor.patch(
                    roomType,
                    (t) => t.copyWith(eventGrowthCapPerBurst: v),
                  ),
                ),
                _ObjectCountTile(
                  label: lang.t('admin_tune_supernova_planets'),
                  helpKey: 'admin_help_supernova_planets',
                  value: tuning.supernovaPlanetCount,
                  max: 60,
                  enabled: !saving && eventsOn,
                  accent: accent,
                  onChanged: (v) => AdminRoomTuningEditor.patch(
                    roomType,
                    (t) => t.copyWith(supernovaPlanetCount: v),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RadiationPane extends StatelessWidget {
  const _RadiationPane({
    required this.roomType,
    required this.tuning,
    required this.defaults,
    required this.saving,
    required this.accent,
    required this.lang,
  });

  final RoomType roomType;
  final RoomGameTuning tuning;
  final RoomGameTuning defaults;
  final bool saving;
  final Color accent;
  final LanguageService lang;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CategoryIntro(
          text: lang.t('admin_tune_radiation_hint'),
          title: lang.t('admin_tune_tab_radiation'),
          helpKey: 'admin_help_radiation',
          accent: accent,
        ),
        const SizedBox(height: 10),
        _SliderRow(
          label: lang.t('admin_tune_radiation_radius'),
          helpKey: 'admin_help_radiation_radius',
          value: tuning.radiationRadius,
          min: 60,
          max: 300,
          divisions: 48,
          display: tuning.radiationRadius.round().toString(),
          defaultLabel: defaults.radiationRadius.round().toString(),
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(radiationRadius: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(radiationRadius: v),
          ),
        ),
        _SliderRow(
          label: lang.t('admin_tune_radiation_idle'),
          helpKey: 'admin_help_radiation_idle',
          value: tuning.radiationIdleSeconds,
          min: 4,
          max: 40,
          divisions: 36,
          display: '${tuning.radiationIdleSeconds.round()}s',
          defaultLabel: '${defaults.radiationIdleSeconds.round()}s',
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(radiationIdleSeconds: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(radiationIdleSeconds: v),
          ),
        ),
        _SliderRow(
          label: lang.t('admin_tune_late_radiation_radius'),
          helpKey: 'admin_help_late_radiation_radius',
          value: tuning.lateGameRadiationRadius,
          min: 200,
          max: 600,
          divisions: 40,
          display: tuning.lateGameRadiationRadius.round().toString(),
          defaultLabel: defaults.lateGameRadiationRadius.round().toString(),
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(lateGameRadiationRadius: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(lateGameRadiationRadius: v),
          ),
        ),
        _SliderRow(
          label: lang.t('admin_tune_late_radiation_idle'),
          helpKey: 'admin_help_late_radiation_idle',
          value: tuning.lateGameRadiationIdleSeconds,
          min: 3,
          max: 30,
          divisions: 27,
          display: '${tuning.lateGameRadiationIdleSeconds.round()}s',
          defaultLabel: '${defaults.lateGameRadiationIdleSeconds.round()}s',
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(lateGameRadiationIdleSeconds: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(lateGameRadiationIdleSeconds: v),
          ),
        ),
        _SliderRow(
          label: lang.t('admin_tune_late_radiation_shrink'),
          helpKey: 'admin_help_late_radiation_shrink',
          value: tuning.lateGameRadiationShrinkPerSecond,
          min: 0.4,
          max: 4.0,
          divisions: 36,
          display:
              tuning.lateGameRadiationShrinkPerSecond.toStringAsFixed(2),
          defaultLabel:
              defaults.lateGameRadiationShrinkPerSecond.toStringAsFixed(2),
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(lateGameRadiationShrinkPerSecond: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(lateGameRadiationShrinkPerSecond: v),
          ),
        ),
      ],
    );
  }
}

class _BotsPane extends StatelessWidget {
  const _BotsPane({
    required this.roomType,
    required this.tuning,
    required this.defaults,
    required this.saving,
    required this.accent,
    required this.lang,
  });

  final RoomType roomType;
  final RoomGameTuning tuning;
  final RoomGameTuning defaults;
  final bool saving;
  final Color accent;
  final LanguageService lang;

  @override
  Widget build(BuildContext context) {
    final huntPct = (tuning.huntPriority * 100).round();
    final defaultPct = (defaults.huntPriority * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CategoryIntro(
          text: lang.t('admin_tune_bots_human_intro'),
          title: lang.t('admin_tune_tab_bots'),
          helpKey: 'admin_help_bots',
          accent: accent,
        ),
        const SizedBox(height: 10),
        _BotPresetRow(
          roomType: roomType,
          tuning: tuning,
          saving: saving,
          accent: accent,
          lang: lang,
        ),
        const SizedBox(height: 12),
        _DifficultyMeter(
          accent: accent,
          percent: huntPct,
          label: lang.t('admin_difficulty'),
        ),
        const SizedBox(height: 10),
        _SliderRow(
          label: lang.t('admin_hunt_priority').replaceAll('{pct}', '$huntPct'),
          helpKey: 'admin_help_hunt_priority',
          value: tuning.huntPriority,
          min: 0,
          max: 1,
          divisions: 100,
          display: '$huntPct%',
          defaultLabel: '$defaultPct%',
          enabled: !saving,
          accent: accent,
          onChanged: (v) => RoomTuningService.instance.setHuntPriority(
            roomType,
            v,
            persist: false,
          ),
          onChangeEnd: (v) =>
              RoomTuningService.instance.setHuntPriority(roomType, v),
        ),
        _SliderRow(
          label: lang.t('admin_tune_bot_start_min'),
          helpKey: 'admin_help_bot_start_min',
          value: tuning.botStartRadiusMin,
          min: 12,
          max: 45,
          divisions: 33,
          display: tuning.botStartRadiusMin.round().toString(),
          defaultLabel: defaults.botStartRadiusMin.round().toString(),
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(botStartRadiusMin: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(botStartRadiusMin: v),
          ),
        ),
        _SliderRow(
          label: lang.t('admin_tune_bot_start_max'),
          helpKey: 'admin_help_bot_start_max',
          value: tuning.botStartRadiusMax,
          min: 12,
          max: 45,
          divisions: 33,
          display: tuning.botStartRadiusMax.round().toString(),
          defaultLabel: defaults.botStartRadiusMax.round().toString(),
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(botStartRadiusMax: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(botStartRadiusMax: v),
          ),
        ),
        const SizedBox(height: 8),
        _SectionLabel(
          lang.t('admin_tune_bot_ai'),
          accent,
          helpKey: 'admin_help_bot_ai',
        ),
        _Hint(lang.t('admin_tune_bot_ai_hint')),
        const SizedBox(height: 8),
        _SliderRow(
          label: lang.t('admin_tune_decision_min'),
          helpKey: 'admin_help_decision_min',
          value: tuning.decisionIntervalMin,
          min: 0.1,
          max: 1.0,
          divisions: 90,
          display: '${tuning.decisionIntervalMin.toStringAsFixed(2)}s',
          defaultLabel: '${defaults.decisionIntervalMin.toStringAsFixed(2)}s',
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(decisionIntervalMin: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(decisionIntervalMin: v),
          ),
        ),
        _SliderRow(
          label: lang.t('admin_tune_decision_max'),
          helpKey: 'admin_help_decision_max',
          value: tuning.decisionIntervalMax,
          min: 0.15,
          max: 1.2,
          divisions: 105,
          display: '${tuning.decisionIntervalMax.toStringAsFixed(2)}s',
          defaultLabel: '${defaults.decisionIntervalMax.toStringAsFixed(2)}s',
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(decisionIntervalMax: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(decisionIntervalMax: v),
          ),
        ),
        _SliderRow(
          label: lang.t('admin_tune_prey_ratio'),
          helpKey: 'admin_help_prey_ratio',
          value: tuning.preySizeRatio,
          min: 0.6,
          max: 0.98,
          divisions: 38,
          display: tuning.preySizeRatio.toStringAsFixed(2),
          defaultLabel: defaults.preySizeRatio.toStringAsFixed(2),
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(preySizeRatio: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(preySizeRatio: v),
          ),
        ),
        _SliderRow(
          label: lang.t('admin_tune_threat_ratio'),
          helpKey: 'admin_help_threat_ratio',
          value: tuning.threatSizeRatio,
          min: 0.95,
          max: 1.4,
          divisions: 45,
          display: tuning.threatSizeRatio.toStringAsFixed(2),
          defaultLabel: defaults.threatSizeRatio.toStringAsFixed(2),
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(threatSizeRatio: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(threatSizeRatio: v),
          ),
        ),
        _SliderRow(
          label: lang.t('admin_tune_prey_search'),
          helpKey: 'admin_help_prey_search',
          value: tuning.preySearchMultiplier,
          min: 2,
          max: 14,
          divisions: 24,
          display: tuning.preySearchMultiplier.toStringAsFixed(1),
          defaultLabel: defaults.preySearchMultiplier.toStringAsFixed(1),
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(preySearchMultiplier: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(preySearchMultiplier: v),
          ),
        ),
        _SliderRow(
          label: lang.t('admin_tune_food_search'),
          helpKey: 'admin_help_food_search',
          value: tuning.foodSearchMultiplier,
          min: 3,
          max: 20,
          divisions: 34,
          display: tuning.foodSearchMultiplier.toStringAsFixed(1),
          defaultLabel: defaults.foodSearchMultiplier.toStringAsFixed(1),
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(foodSearchMultiplier: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(foodSearchMultiplier: v),
          ),
        ),
        _SliderRow(
          label: lang.t('admin_tune_event_awareness'),
          helpKey: 'admin_help_event_awareness',
          value: tuning.eventAwareness,
          min: 0,
          max: 1,
          divisions: 100,
          display: '${(tuning.eventAwareness * 100).round()}%',
          defaultLabel: '${(defaults.eventAwareness * 100).round()}%',
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(eventAwareness: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(eventAwareness: v),
          ),
        ),
        _SliderRow(
          label: lang.t('admin_tune_mine_avoidance'),
          helpKey: 'admin_help_mine_avoidance',
          value: tuning.mineAvoidance,
          min: 0,
          max: 1,
          divisions: 100,
          display: '${(tuning.mineAvoidance * 100).round()}%',
          defaultLabel: '${(defaults.mineAvoidance * 100).round()}%',
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(mineAvoidance: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(mineAvoidance: v),
          ),
        ),
        _SliderRow(
          label: lang.t('admin_tune_min_hunt_radius'),
          helpKey: 'admin_help_min_hunt_radius',
          value: tuning.minHuntRadius,
          min: 15,
          max: 80,
          divisions: 65,
          display: tuning.minHuntRadius.round().toString(),
          defaultLabel: defaults.minHuntRadius.round().toString(),
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(minHuntRadius: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(minHuntRadius: v),
          ),
        ),
        _SliderRow(
          label: lang.t('admin_tune_player_bias'),
          helpKey: 'admin_help_player_bias',
          value: tuning.playerTargetBias,
          min: 0.8,
          max: 3.0,
          divisions: 44,
          display: tuning.playerTargetBias.toStringAsFixed(2),
          defaultLabel: defaults.playerTargetBias.toStringAsFixed(2),
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(playerTargetBias: v),
            false,
          ),
          onChangeEnd: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(playerTargetBias: v),
          ),
        ),
        const SizedBox(height: 4),
        _ToggleCard(
          title: lang.t('admin_tune_intercept_prey'),
          helpKey: 'admin_help_intercept_prey',
          value: tuning.interceptPrey,
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(interceptPrey: v),
          ),
        ),
        const SizedBox(height: 12),
        _SectionLabel(
          lang.t('admin_tune_personality'),
          accent,
          helpKey: 'admin_help_personality',
        ),
        _Hint(lang.t('admin_tune_personality_hint')),
        const SizedBox(height: 8),
        _ObjectCountTile(
          label: lang.t('admin_tune_personality_coward'),
          helpKey: 'admin_help_personality_coward',
          value: tuning.personalityCoward,
          max: 100,
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(personalityCoward: v),
          ),
        ),
        _ObjectCountTile(
          label: lang.t('admin_tune_personality_aggressive'),
          helpKey: 'admin_help_personality_aggressive',
          value: tuning.personalityAggressive,
          max: 100,
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(personalityAggressive: v),
          ),
        ),
        _ObjectCountTile(
          label: lang.t('admin_tune_personality_opportunist'),
          helpKey: 'admin_help_personality_opportunist',
          value: tuning.personalityOpportunist,
          max: 100,
          enabled: !saving,
          accent: accent,
          onChanged: (v) => AdminRoomTuningEditor.patch(
            roomType,
            (t) => t.copyWith(personalityOpportunist: v),
          ),
        ),
      ],
    );
  }
}

/// Universe-wide difficulty ladder (world + tempo + hazards + bots).
class AdminUniverseDifficultyPresets extends StatelessWidget {
  const AdminUniverseDifficultyPresets({
    super.key,
    required this.roomType,
    required this.accent,
  });

  final RoomType roomType;
  final Color accent;

  static const _presetLangKeys = <UniverseAdminPreset, String>{
    UniverseAdminPreset.training: 'admin_tune_universe_preset_training',
    UniverseAdminPreset.casual: 'admin_tune_universe_preset_casual',
    UniverseAdminPreset.ranked: 'admin_tune_universe_preset_ranked',
    UniverseAdminPreset.predator: 'admin_tune_universe_preset_predator',
    UniverseAdminPreset.apex: 'admin_tune_universe_preset_apex',
  };

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final service = RoomTuningService.instance;
    final tuning = service.tuningFor(roomType);
    final saving = service.saving;
    final active = UniverseDifficulty.matchingAdminPreset(roomType, tuning);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          lang.t('admin_tune_universe_presets'),
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          lang.t('admin_tune_universe_presets_hint'),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.52),
            fontSize: 11,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in UniverseAdminPreset.values)
              _AdminPresetChip(
                label: lang.t(_presetLangKeys[preset]!),
                enabled: !saving,
                accent: accent,
                highlighted: active == preset,
                onTap: () => service.applyUniversePreset(roomType, preset),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: saving
                ? null
                : () => service.applyBalancedUniverseDistribution(),
            icon: Icon(
              Icons.auto_awesome_outlined,
              size: 16,
              color: accent.withValues(alpha: saving ? 0.35 : 0.9),
            ),
            label: Text(
              lang.t('admin_tune_universe_balanced_distribute'),
              style: TextStyle(
                color: accent.withValues(alpha: saving ? 0.35 : 0.95),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Text(
          lang.t('admin_tune_universe_balanced_distribute_hint'),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),
            fontSize: 10.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _BotPresetRow extends StatelessWidget {
  const _BotPresetRow({
    required this.roomType,
    required this.tuning,
    required this.saving,
    required this.accent,
    required this.lang,
  });

  final RoomType roomType;
  final RoomGameTuning tuning;
  final bool saving;
  final Color accent;
  final LanguageService lang;

  static const _presetLangKeys = <BotAdminPreset, String>{
    BotAdminPreset.training: 'admin_tune_bot_preset_training',
    BotAdminPreset.casual: 'admin_tune_bot_preset_casual',
    BotAdminPreset.ranked: 'admin_tune_bot_preset_ranked',
    BotAdminPreset.predator: 'admin_tune_bot_preset_predator',
    BotAdminPreset.apex: 'admin_tune_bot_preset_apex',
  };

  Future<void> _apply(BotAdminPreset preset) {
    return AdminRoomTuningEditor.patch(
      roomType,
      (t) => t.withBotDifficulty(
        BotDifficulty.forAdminPreset(roomType, preset),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = BotDifficulty.matchingAdminPreset(
      roomType,
      tuning.toBotDifficulty(roomType),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(lang.t('admin_tune_bot_presets'), accent),
        _Hint(lang.t('admin_tune_bot_presets_hint')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in BotAdminPreset.values)
              _AdminPresetChip(
                label: lang.t(_presetLangKeys[preset]!),
                enabled: !saving,
                accent: accent,
                highlighted: active == preset,
                onTap: () => _apply(preset),
              ),
          ],
        ),
      ],
    );
  }
}

class _AdminPresetChip extends StatelessWidget {
  const _AdminPresetChip({
    required this.label,
    required this.enabled,
    required this.accent,
    required this.highlighted,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final Color accent;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = highlighted
        ? accent.withValues(alpha: 0.38)
        : accent.withValues(alpha: 0.08);
    final border = highlighted
        ? accent.withValues(alpha: 1)
        : accent.withValues(alpha: 0.32);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border, width: highlighted ? 1.6 : 1),
              boxShadow: highlighted
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: highlighted ? 1 : 0.72),
                fontSize: 12.5,
                fontWeight: highlighted ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: highlighted ? 0.2 : 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.42),
        fontSize: 12,
        height: 1.35,
      ),
    );
  }
}

/// Kısa özet + `!` ile tam rehber.
class _CategoryIntro extends StatelessWidget {
  const _CategoryIntro({
    required this.text,
    required this.title,
    required this.helpKey,
    required this.accent,
  });

  final String text;
  final String title;
  final String helpKey;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _Hint(text)),
        const SizedBox(width: 6),
        _HelpIcon(title: title, helpKey: helpKey, accent: accent),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.accent, {this.helpKey});

  final String text;
  final Color accent;
  final String? helpKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: accent.withValues(alpha: 0.95),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (helpKey != null) ...[
            const SizedBox(width: 4),
            _HelpIcon(title: text, helpKey: helpKey!, accent: accent),
          ],
        ],
      ),
    );
  }
}

class _HelpIcon extends StatelessWidget {
  const _HelpIcon({
    required this.title,
    required this.helpKey,
    required this.accent,
  });

  final String title;
  final String helpKey;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    return Tooltip(
      message: lang.t('admin_help_tooltip'),
      child: InkWell(
        onTap: () => _showAdminTuningHelp(
          context,
          title: title,
          helpKey: helpKey,
          accent: accent,
        ),
        borderRadius: BorderRadius.circular(99),
        child: Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.55)),
            color: accent.withValues(alpha: 0.12),
          ),
          child: Text(
            '!',
            style: TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

void _showAdminTuningHelp(
  BuildContext context, {
  required String title,
  required String helpKey,
  required Color accent,
}) {
  final lang = LanguageService.instance;
  final body = lang.t(helpKey);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.paddingOf(ctx).bottom + 12,
        ),
        child: Material(
          color: const Color(0xFF0A0A1A),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.16),
                        border: Border.all(color: accent.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        '!',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.45,
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      body,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      lang.t('admin_help_got_it'),
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _DifficultyMeter extends StatelessWidget {
  const _DifficultyMeter({
    required this.accent,
    required this.percent,
    required this.label,
  });

  final Color accent;
  final int percent;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '$percent%',
                style: TextStyle(
                  color: accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.title,
    required this.value,
    required this.enabled,
    required this.accent,
    required this.onChanged,
    this.helpKey,
  });

  final String title;
  final bool value;
  final bool enabled;
  final Color accent;
  final ValueChanged<bool> onChanged;
  final String? helpKey;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: enabled ? () => onChanged(!value) : null,
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: enabled ? 0.85 : 0.4),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (helpKey != null) ...[
              _HelpIcon(title: title, helpKey: helpKey!, accent: accent),
              const SizedBox(width: 6),
            ],
            Switch.adaptive(
              value: value,
              activeThumbColor: accent,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ObjectCountTile extends StatelessWidget {
  const _ObjectCountTile({
    required this.label,
    required this.value,
    required this.enabled,
    required this.accent,
    required this.onChanged,
    this.max = 800,
    this.helpKey,
  });

  final String label;
  final int value;
  final bool enabled;
  final Color accent;
  final ValueChanged<int> onChanged;
  final int max;
  final String? helpKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.035),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color:
                          Colors.white.withValues(alpha: enabled ? 0.72 : 0.3),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (helpKey != null) ...[
                  const SizedBox(width: 4),
                  _HelpIcon(title: label, helpKey: helpKey!, accent: accent),
                ],
              ],
            ),
          ),
          _StepButton(
            icon: Icons.remove_rounded,
            enabled: enabled && value > 0,
            accent: accent,
            onTap: () => onChanged(value - 1),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.white24,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            enabled: enabled && value < max,
            accent: accent,
            onTap: () => onChanged(value + 1),
          ),
          _StepButton(
            icon: Icons.keyboard_double_arrow_up_rounded,
            enabled: enabled && value < max,
            accent: accent,
            tooltip: '+10',
            onTap: () => onChanged((value + 10).clamp(0, max)),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.accent,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final bool enabled;
  final Color accent;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: enabled ? onTap : null,
      icon: Icon(
        icon,
        size: 18,
        color: accent.withValues(alpha: enabled ? 0.9 : 0.25),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.enabled,
    required this.accent,
    required this.onChanged,
    required this.onChangeEnd,
    this.defaultLabel,
    this.helpKey,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final String? defaultLabel;
  final String? helpKey;
  final bool enabled;
  final Color accent;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: Colors.white
                              .withValues(alpha: enabled ? 0.7 : 0.3),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (helpKey != null) ...[
                      const SizedBox(width: 4),
                      _HelpIcon(
                        title: label,
                        helpKey: helpKey!,
                        accent: accent,
                      ),
                    ],
                  ],
                ),
              ),
              if (defaultLabel != null) ...[
                Text(
                  lang
                      .t('admin_tune_default')
                      .replaceAll('{value}', defaultLabel!),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.28),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: accent.withValues(alpha: enabled ? 0.14 : 0.05),
                ),
                child: Text(
                  display,
                  style: TextStyle(
                    color: enabled ? accent : Colors.white24,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accent,
              inactiveTrackColor: Colors.white12,
              thumbColor: accent,
              overlayColor: accent.withValues(alpha: 0.18),
              trackHeight: 3.5,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: enabled ? onChanged : null,
              onChangeEnd: enabled ? onChangeEnd : null,
            ),
          ),
        ],
      ),
    );
  }
}
