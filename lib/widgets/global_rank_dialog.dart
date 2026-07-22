import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/lang_service.dart';
import '../services/profile_service.dart';
import 'bot_name_badge.dart';

class GlobalRankDialog extends StatefulWidget {
  const GlobalRankDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Global Rank',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const GlobalRankDialog();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curve),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<GlobalRankDialog> createState() => _GlobalRankDialogState();
}

class _GlobalRankDialogState extends State<GlobalRankDialog> {
  GlobalLeaderboardSort _sort = GlobalLeaderboardSort.rank;
  final Map<GlobalLeaderboardSort, GlobalLeaderboardSnapshot> _cache = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(force: true);
  }

  Future<void> _load({bool force = false}) async {
    if (!force && _cache.containsKey(_sort)) {
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await ProfileService.instance.fetchGlobalLeaderboard(
        sort: _sort,
      );
      if (!mounted) return;
      if (snapshot != null) {
        _cache[_sort] = snapshot;
      }
      setState(() {
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = LanguageService.instance.t('global_rank_error');
        _loading = false;
      });
    }
  }

  Future<void> _selectSort(GlobalLeaderboardSort sort) async {
    if (_sort == sort) return;
    setState(() => _sort = sort);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final size = MediaQuery.sizeOf(context);
    final accent = _sort == GlobalLeaderboardSort.rank
        ? const Color(0xFFFFD54F)
        : const Color(0xFF00F0FF);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: size.width * 0.92,
          height: size.height * 0.78,
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF12122A).withValues(alpha: 0.95),
                const Color(0xFF0A0A1A).withValues(alpha: 0.98),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.14),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                    child: Row(
                      children: [
                        Icon(Icons.public, color: accent, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            lang.t('profile_global_rank'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _SortTabs(
                      sort: _sort,
                      onSelect: _selectSort,
                      lang: lang,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        lang.t(
                          _sort == GlobalLeaderboardSort.rank
                              ? 'global_rank_blurb_rank'
                              : 'global_rank_blurb_wealth',
                        ),
                        key: ValueKey(_sort),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _HeaderRow(lang: lang, sort: _sort),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Colors.white12),
                  Expanded(child: _buildBody(lang)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(LanguageService lang) {
    if (_loading && !_cache.containsKey(_sort)) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00F0FF)),
      );
    }
    if (_error != null && !_cache.containsKey(_sort)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _load(force: true),
                child: Text(lang.t('global_rank_retry')),
              ),
            ],
          ),
        ),
      );
    }

    final snapshot = _cache[_sort];
    if (snapshot == null || snapshot.topPlayers.isEmpty) {
      return Center(
        child: Text(
          lang.t('global_rank_empty'),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        ),
      );
    }

    final localOutside = snapshot.localPlayer;

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: ListView.separated(
                  key: ValueKey(_sort),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  itemCount: snapshot.topPlayers.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    return _RankRow(
                      entry: snapshot.topPlayers[index],
                      sort: _sort,
                    );
                  },
                ),
              ),
            ),
            if (localOutside != null) ...[
              const Divider(height: 1, color: Colors.white24),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Text(
                  lang.t('global_rank_your_position'),
                  style: TextStyle(
                    color: (_sort == GlobalLeaderboardSort.rank
                            ? const Color(0xFFFFD54F)
                            : const Color(0xFF00F0FF))
                        .withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                child: _RankRow(
                  entry: localOutside,
                  sort: _sort,
                  emphasized: true,
                ),
              ),
            ],
          ],
        ),
        if (_loading)
          Positioned(
            top: 8,
            right: 16,
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ),
      ],
    );
  }
}

class _SortTabs extends StatelessWidget {
  const _SortTabs({
    required this.sort,
    required this.onSelect,
    required this.lang,
  });

  final GlobalLeaderboardSort sort;
  final ValueChanged<GlobalLeaderboardSort> onSelect;
  final LanguageService lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabChip(
              label: lang.t('global_rank_tab_rank'),
              icon: Icons.military_tech_outlined,
              selected: sort == GlobalLeaderboardSort.rank,
              activeColor: const Color(0xFFFFD54F),
              onTap: () => onSelect(GlobalLeaderboardSort.rank),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TabChip(
              label: lang.t('global_rank_tab_wealth'),
              icon: Icons.diamond_outlined,
              selected: sort == GlobalLeaderboardSort.wealth,
              activeColor: const Color(0xFF00F0FF),
              onTap: () => onSelect(GlobalLeaderboardSort.wealth),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            color: selected
                ? activeColor.withValues(alpha: 0.16)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? activeColor.withValues(alpha: 0.55)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected
                    ? activeColor
                    : Colors.white.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.55),
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.lang, required this.sort});

  final LanguageService lang;
  final GlobalLeaderboardSort sort;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Colors.white.withValues(alpha: 0.45),
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );

    // Secondary mid, primary sort key always on the right.
    final midLabel = lang.t('global_rank_wins');
    final rightLabel = sort == GlobalLeaderboardSort.rank
        ? lang.t('global_rank_points')
        : lang.t('lobby_diamonds');

    return Row(
      children: [
        SizedBox(width: 40, child: Text('#', style: style)),
        Expanded(child: Text(lang.t('global_rank_player'), style: style)),
        SizedBox(
          width: 56,
          child: Text(midLabel, style: style, textAlign: TextAlign.end),
        ),
        SizedBox(
          width: 64,
          child: Text(rightLabel, style: style, textAlign: TextAlign.end),
        ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.entry,
    required this.sort,
    this.emphasized = false,
  });

  final GlobalLeaderboardEntry entry;
  final GlobalLeaderboardSort sort;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final isLocal = entry.isLocal;
    final highlight = isLocal || emphasized;
    const diamondColor = Color(0xFF00F0FF);
    const winColor = Color(0xFFFFD54F);
    final accent = sort == GlobalLeaderboardSort.rank
        ? winColor
        : diamondColor;

    final rankStyle = TextStyle(
      color: _medalColor(entry.rank) ?? (highlight ? accent : Colors.white70),
      fontWeight: FontWeight.bold,
      fontSize: highlight ? 17 : 15,
    );

    final nameStyle = TextStyle(
      color: highlight ? Colors.white : Colors.white.withValues(alpha: 0.88),
      fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
      fontSize: highlight ? 15 : 14,
    );

    final name = isLocal
        ? '${lang.t('leaderboard_you')} · ${entry.username}'
        : entry.username;

    // Mid = secondary (wins). Right = primary sort key.
    final midIcon = Icons.emoji_events_outlined;
    const midColor = Color(0xFFFFB74D);
    final rightValue =
        sort == GlobalLeaderboardSort.rank ? entry.rankPoints : entry.diamonds;
    final rightIcon = sort == GlobalLeaderboardSort.rank
        ? Icons.star_rounded
        : Icons.diamond_outlined;
    final rightColor =
        sort == GlobalLeaderboardSort.rank ? winColor : diamondColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: highlight
            ? LinearGradient(
                colors: [
                  accent.withValues(alpha: emphasized ? 0.22 : 0.16),
                  const Color(0xFF0A0A1A).withValues(alpha: 0.5),
                ],
              )
            : null,
        color: highlight
            ? null
            : Colors.white.withValues(alpha: entry.rank.isOdd ? 0.03 : 0.06),
        border: highlight
            ? Border.all(color: accent.withValues(alpha: 0.55), width: 1.5)
            : Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text('#${entry.rank}', style: rankStyle),
          ),
          Expanded(
            child: BotNameLabel(
              name: name,
              rankPoints: entry.rankPoints,
              style: nameStyle,
              textAlign: TextAlign.start,
              maxLines: 1,
              badgeSize: highlight ? 12 : 11,
              compactBadge: true,
            ),
          ),
          SizedBox(
            width: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  midIcon,
                  size: 14,
                  color: midColor.withValues(alpha: highlight ? 0.95 : 0.7),
                ),
                const SizedBox(width: 3),
                Text(
                  '${entry.gamesWon}',
                  style: TextStyle(
                    color: midColor.withValues(alpha: highlight ? 1 : 0.85),
                    fontWeight: FontWeight.w700,
                    fontSize: highlight ? 14 : 13,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  rightIcon,
                  size: 14,
                  color: rightColor.withValues(alpha: highlight ? 1 : 0.7),
                ),
                const SizedBox(width: 3),
                Text(
                  '$rightValue',
                  style: TextStyle(
                    color: rightColor.withValues(alpha: highlight ? 1 : 0.85),
                    fontWeight: FontWeight.bold,
                    fontSize: highlight ? 15 : 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color? _medalColor(int rank) {
    return switch (rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => null,
    };
  }
}
