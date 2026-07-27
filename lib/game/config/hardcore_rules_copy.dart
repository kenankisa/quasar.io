import '../../services/app_economy_config_service.dart';
import '../../services/lang_service.dart';
import 'hardcore_rules.dart';

/// One Hardcore rules bullet (shared by lobby sheet + first-match overlay).
class HardcoreRulesStep {
  const HardcoreRulesStep({
    required this.titleKey,
    required this.bodyKey,
  });

  final String titleKey;
  final String bodyKey;
}

const hardcoreRulesSteps = <HardcoreRulesStep>[
  HardcoreRulesStep(
    titleKey: 'hardcore_onboarding_modes_title',
    bodyKey: 'hardcore_onboarding_modes_body',
  ),
  HardcoreRulesStep(
    titleKey: 'hardcore_onboarding_cap_title',
    bodyKey: 'hardcore_onboarding_cap_body',
  ),
  HardcoreRulesStep(
    titleKey: 'hardcore_onboarding_victory_title',
    bodyKey: 'hardcore_onboarding_victory_body',
  ),
];

Map<String, String> hardcoreRulesPlaceholders() {
  final econ = AppEconomyConfigService.instance.config;
  return {
    '{minAlive}': '${econ.hardcoreArenaMinAlive}',
    '{cap}': '${HardcoreRules.liveLowPopRadiusCap.round()}',
    '{victory}': '${HardcoreRules.victoryRadius.round()}',
    '{kill}': '${econ.rewardHardcoreKill}',
    '{elim}': '${econ.penaltyHardcore}',
    '{winDiamonds}': '${econ.rewardHardcore1}',
  };
}

String fillHardcoreRulesCopy(String template) {
  var out = template;
  for (final e in hardcoreRulesPlaceholders().entries) {
    out = out.replaceAll(e.key, e.value);
  }
  return out;
}

String hardcoreRulesText(String key) =>
    fillHardcoreRulesCopy(LanguageService.instance.t(key));
