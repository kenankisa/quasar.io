import 'dart:ui';

import 'package:flutter/material.dart';

import '../game/config/skill_tree_config.dart';
import '../services/lang_service.dart';
import '../services/profile_service.dart';
import '../utils/responsive_layout.dart';

class SkillTreeDialog extends StatefulWidget {
  const SkillTreeDialog({super.key, required this.profile});

  final PlayerProfile profile;

  static Future<void> show(BuildContext context, PlayerProfile profile) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'SkillTree',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SkillTreeDialog(profile: profile);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curve),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<SkillTreeDialog> createState() => _SkillTreeDialogState();
}

class _SkillTreeDialogState extends State<SkillTreeDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late PlayerProfile _profile;
  SkillNodeId? _spending;
  String? _errorKey;

  static const _accent = Color(0xFF00F0FF);
  static const _magenta = Color(0xFFFF2D95);
  static const _panel = Color(0xE6080A14);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: SkillBranch.values.length, vsync: this);
    _profile = widget.profile;
    ProfileService.instance.profileNotifier.addListener(_onProfile);
  }

  void _onProfile() {
    final updated = ProfileService.instance.profileNotifier.value;
    if (updated != null && mounted) {
      setState(() => _profile = updated);
    }
  }

  @override
  void dispose() {
    ProfileService.instance.profileNotifier.removeListener(_onProfile);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _upgrade(SkillNodeDef node) async {
    if (_spending != null) return;
    if (_profile.availableSkillPoints <= 0) {
      setState(() => _errorKey = 'skill_error_no_sp');
      return;
    }
    if (_profile.skillLevel(node.id) >= AbilityLoadout.maxLevel) {
      setState(() => _errorKey = 'skill_error_max');
      return;
    }

    setState(() {
      _spending = node.id;
      _errorKey = null;
    });

    try {
      final updated = await ProfileService.instance.spendSkillPoint(node.id);
      if (!mounted) return;
      if (updated != null) {
        setState(() => _profile = updated);
      }
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() {
        _errorKey = switch (e.message) {
          'insufficient_skill_points' => 'skill_error_no_sp',
          'skill_max_level' => 'skill_error_max',
          _ => 'skill_error_generic',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorKey = 'skill_error_generic');
    } finally {
      if (mounted) setState(() => _spending = null);
    }
  }

  Color _branchColor(SkillBranch branch) => switch (branch) {
        SkillBranch.boost => const Color(0xFFFFB020),
        SkillBranch.teleport => const Color(0xFF7B6CFF),
        SkillBranch.shield => const Color(0xFF00E5A8),
        SkillBranch.shockwave => const Color(0xFFFF4D6A),
      };

  String _branchTitle(LanguageService lang, SkillBranch branch) =>
      switch (branch) {
        SkillBranch.boost => lang.t('skill_branch_boost'),
        SkillBranch.teleport => lang.t('skill_branch_teleport'),
        SkillBranch.shield => lang.t('skill_branch_shield'),
        SkillBranch.shockwave => lang.t('skill_branch_shockwave'),
      };

  IconData _branchIcon(SkillBranch branch) => switch (branch) {
        SkillBranch.boost => Icons.rocket_launch_outlined,
        SkillBranch.teleport => Icons.blur_on,
        SkillBranch.shield => Icons.shield_outlined,
        SkillBranch.shockwave => Icons.waves,
      };

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final r = ResponsiveLayout.of(context);
    final media = MediaQuery.sizeOf(context);
    final nextSp = AbilityLoadout.diamondsToNextSp(_profile.peakDiamonds);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: media.width.clamp(320, 520),
              height: media.height * 0.82,
              constraints: BoxConstraints(maxHeight: r.h(640)),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _accent.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.12),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(r.w(18), r.h(16), r.w(8), 0),
                    child: Row(
                      children: [
                        Icon(Icons.account_tree_outlined,
                            color: _accent, size: r.sp(22)),
                        SizedBox(width: r.w(8)),
                        Expanded(
                          child: Text(
                            lang.t('skill_tree_title'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: r.sp(18),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: r.w(18)),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(r.w(12)),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          colors: [
                            _accent.withValues(alpha: 0.12),
                            _magenta.withValues(alpha: 0.08),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _SpChip(
                                label: lang.t('skill_sp_available'),
                                value: '${_profile.availableSkillPoints}',
                                accent: _accent,
                              ),
                              SizedBox(width: r.w(8)),
                              _SpChip(
                                label: lang.t('skill_sp_earned'),
                                value:
                                    '${_profile.spentSkillPoints}/${_profile.earnedSkillPoints}',
                                accent: _magenta,
                              ),
                            ],
                          ),
                          SizedBox(height: r.h(8)),
                          Text(
                            lang
                                .t('skill_sp_rules')
                                .replaceAll(
                                  '{n}',
                                  '${AbilityLoadout.diamondsPerSp}',
                                )
                                .replaceAll('{next}', '$nextSp'),
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: r.sp(11),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_errorKey != null) ...[
                    SizedBox(height: r.h(8)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: r.w(18)),
                      child: Text(
                        lang.t(_errorKey!),
                        style: TextStyle(
                          color: const Color(0xFFFF6B6B),
                          fontSize: r.sp(12),
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: r.h(10)),
                  TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: _accent,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: TextStyle(
                      fontSize: r.sp(12),
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: [
                      for (final branch in SkillBranch.values)
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _branchIcon(branch),
                                size: 16,
                                color: _branchColor(branch),
                              ),
                              const SizedBox(width: 6),
                              Text(_branchTitle(lang, branch)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        for (final branch in SkillBranch.values)
                          _BranchPanel(
                            branch: branch,
                            accent: _branchColor(branch),
                            profile: _profile,
                            spending: _spending,
                            onUpgrade: _upgrade,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpChip extends StatelessWidget {
  const _SpChip({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: accent.withValues(alpha: 0.1),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: accent.withValues(alpha: 0.85),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchPanel extends StatelessWidget {
  const _BranchPanel({
    required this.branch,
    required this.accent,
    required this.profile,
    required this.spending,
    required this.onUpgrade,
  });

  final SkillBranch branch;
  final Color accent;
  final PlayerProfile profile;
  final SkillNodeId? spending;
  final Future<void> Function(SkillNodeDef node) onUpgrade;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final nodes = AbilityLoadout.nodesFor(branch);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      itemCount: nodes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final node = nodes[index];
        final level = profile.skillLevel(node.id);
        final maxed = level >= AbilityLoadout.maxLevel;
        final canAfford = profile.availableSkillPoints > 0 && !maxed;
        final busy = spending == node.id;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.03),
            border: Border.all(
              color: accent.withValues(alpha: maxed ? 0.45 : 0.22),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lang.t(node.titleKey),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${lang.t('skill_level')} $level/${AbilityLoadout.maxLevel}',
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                lang.t(node.descKey),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              _LevelPips(level: level, accent: accent),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      maxed
                          ? '${lang.t('skill_value_now')}: ${node.formatValue(level)}'
                          : '${node.formatValue(level)}  →  ${node.formatValue(level + 1)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: (!canAfford || busy)
                        ? null
                        : () => onUpgrade(node),
                    style: TextButton.styleFrom(
                      backgroundColor: accent.withValues(alpha: 0.18),
                      foregroundColor: accent,
                      disabledForegroundColor: Colors.white30,
                      disabledBackgroundColor:
                          Colors.white.withValues(alpha: 0.04),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: canAfford
                              ? accent.withValues(alpha: 0.55)
                              : Colors.white12,
                        ),
                      ),
                    ),
                    child: busy
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accent,
                            ),
                          )
                        : Text(
                            maxed
                                ? lang.t('skill_maxed')
                                : lang.t('skill_upgrade'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LevelPips extends StatelessWidget {
  const _LevelPips({required this.level, required this.accent});

  final int level;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(AbilityLoadout.maxLevel, (i) {
        final filled = i < level;
        return Expanded(
          child: Container(
            height: 5,
            margin: EdgeInsets.only(right: i == AbilityLoadout.maxLevel - 1 ? 0 : 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: filled ? accent : Colors.white.withValues(alpha: 0.08),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}
