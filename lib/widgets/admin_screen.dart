import 'dart:async';

import 'package:flutter/material.dart';

import '../game/models/admin_stats.dart';
import '../services/admin_access.dart';
import '../services/admin_analytics_service.dart';
import '../services/admin_game_trial_service.dart';
import '../services/admin_hardcore_arena_test_service.dart';
import '../services/admin_hardcore_live_service.dart';
import '../services/admin_load_test_service.dart';
import '../services/admin_messaging_service.dart';
import '../services/admin_stats_service.dart';
import '../services/app_economy_config_service.dart';
import '../services/app_idle_config_service.dart';
import '../services/app_rank_config_service.dart';
import '../services/auth_service.dart';
import '../services/lang_service.dart';
import '../utils/lang_rebuild.dart';
import '../utils/lang_scope.dart';
import '../services/player_session_service.dart';
import '../services/room_matchmaking_service.dart';
import '../services/room_tuning_service.dart';
import 'admin/admin_hardcore_panel.dart';
import 'admin/admin_nav.dart';
import 'admin/admin_overview_panel.dart';
import 'admin/admin_theme.dart';
import 'admin/admin_universes_panel.dart';
import 'admin_analytics_panel.dart';
import 'admin_economy_settings_panel.dart';
import 'admin_game_trial_panel.dart';
import 'admin_idle_settings_panel.dart';
import 'admin_load_test_panel.dart';
import 'admin_messages_panel.dart';
import 'admin_rank_settings_panel.dart';
import 'lobby_screen.dart';
import 'neon_space_particle_painter.dart';

/// Owner admin console — only [AdminAccess] may open this screen.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver, LangChangeListener {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final AnimationController _particleController;
  bool _signingOut = false;
  bool _verifying = true;
  bool _allowed = false;
  AdminNavSection _section = AdminNavSection.live;
  final Set<AdminNavSection> _loadedSections = {AdminNavSection.live};

  @override
  void onLangChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Defer — setIdleSuppressed notifies listeners; doing it mid-build throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PlayerSessionService.instance.setIdleSuppressed(true);
    });
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
    unawaited(_verifyAdminAccess());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_particleController.isAnimating &&
        state == AppLifecycleState.resumed) {
      _particleController.repeat();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _particleController.stop();
    }
  }

  Future<void> _verifyAdminAccess() async {
    final ok = await AdminAccess.refreshAdminStatus();
    if (!mounted) return;
    if (!ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LobbyScreen()),
      );
      return;
    }
    setState(() {
      _verifying = false;
      _allowed = true;
    });
    AdminStatsService.instance.attach();
    AdminHardcoreLiveService.instance.attach();
    unawaited(AdminMessagingService.instance.refreshUnreadCount());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Schedule after unlock — dispose runs while the tree is locked.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PlayerSessionService.instance.setIdleSuppressed(false);
    });
    _particleController.dispose();
    AdminStatsService.instance.detach();
    AdminHardcoreLiveService.instance.detach();
    super.dispose();
  }

  Future<void> _refreshCurrentSection() async {
    switch (_section) {
      case AdminNavSection.live:
      case AdminNavSection.players:
        await AdminStatsService.instance.refresh();
      case AdminNavSection.hardcore:
        await Future.wait([
          AdminHardcoreLiveService.instance.refresh(),
          AdminHardcoreArenaTestService.instance.refreshOps(),
          RoomTuningService.instance.refreshFromRemote(),
          AppEconomyConfigService.instance.refreshFromRemote(),
          AppIdleConfigService.instance.refreshFromRemote(),
        ]);
      case AdminNavSection.analytics:
        await AdminAnalyticsService.instance.refresh();
      case AdminNavSection.universes:
        await Future.wait([
          AdminStatsService.instance.refresh(),
          RoomTuningService.instance.refreshFromRemote(),
        ]);
      case AdminNavSection.idle:
        await AppIdleConfigService.instance.refreshFromRemote();
      case AdminNavSection.ranks:
        await AppRankConfigService.instance.refreshFromRemote();
      case AdminNavSection.economy:
        await AppEconomyConfigService.instance.refreshFromRemote();
      case AdminNavSection.loadTest:
        await Future.wait([
          AdminLoadTestService.instance.refresh(),
          AdminStatsService.instance.refresh(),
        ]);
      case AdminNavSection.gameTrial:
        await AdminGameTrialService.instance.refresh();
      case AdminNavSection.messages:
        await AdminMessagingService.instance.refresh();
    }
  }

  void _ensureSectionLoaded(AdminNavSection section) {
    if (!_loadedSections.add(section)) return;
    switch (section) {
      case AdminNavSection.live:
      case AdminNavSection.players:
        break;
      case AdminNavSection.hardcore:
        unawaited(Future.wait([
          AdminHardcoreLiveService.instance.refresh(),
          RoomTuningService.instance.refreshFromRemote(),
          AppEconomyConfigService.instance.refreshFromRemote(),
          AppIdleConfigService.instance.refreshFromRemote(),
        ]));
      case AdminNavSection.analytics:
        unawaited(AdminAnalyticsService.instance.refresh());
      case AdminNavSection.universes:
        unawaited(RoomTuningService.instance.refreshFromRemote());
      case AdminNavSection.idle:
        unawaited(AppIdleConfigService.instance.refreshFromRemote());
      case AdminNavSection.ranks:
        unawaited(AppRankConfigService.instance.refreshFromRemote());
      case AdminNavSection.economy:
        unawaited(AppEconomyConfigService.instance.refreshFromRemote());
      case AdminNavSection.loadTest:
        unawaited(AdminLoadTestService.instance.refresh());
      case AdminNavSection.gameTrial:
        unawaited(AdminGameTrialService.instance.refresh());
      case AdminNavSection.messages:
        unawaited(AdminMessagingService.instance.refresh());
    }
  }

  Future<void> _openLobby() async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LobbyScreen()),
    );
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await RoomMatchmakingService.instance.leaveActiveRoom();
      await PlayerSessionService.instance.release();
      await AuthService.instance.signOut();
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  void _selectSection(AdminNavSection section) {
    if (_section == section) return;
    setState(() => _section = section);
    _ensureSectionLoaded(section);
  }

  Listenable _listenableForSection(AdminNavSection section) {
    return switch (section) {
      AdminNavSection.live || AdminNavSection.players => Listenable.merge([
          AdminStatsService.instance,
          LanguageService.instance,
        ]),
      AdminNavSection.hardcore => Listenable.merge([
          AdminHardcoreLiveService.instance,
          AdminHardcoreArenaTestService.instance,
          AdminGameTrialService.instance,
          AdminStatsService.instance,
          RoomTuningService.instance,
          AppEconomyConfigService.instance,
          AppIdleConfigService.instance,
          LanguageService.instance,
        ]),
      AdminNavSection.analytics => Listenable.merge([
          AdminAnalyticsService.instance,
          LanguageService.instance,
        ]),
      AdminNavSection.universes => Listenable.merge([
          AdminStatsService.instance,
          RoomTuningService.instance,
          LanguageService.instance,
        ]),
      AdminNavSection.idle => Listenable.merge([
          AppIdleConfigService.instance,
          LanguageService.instance,
        ]),
      AdminNavSection.ranks => Listenable.merge([
          AppRankConfigService.instance,
          LanguageService.instance,
        ]),
      AdminNavSection.economy => Listenable.merge([
          AppEconomyConfigService.instance,
          LanguageService.instance,
        ]),
      AdminNavSection.loadTest => Listenable.merge([
          AdminLoadTestService.instance,
          LanguageService.instance,
        ]),
      AdminNavSection.gameTrial => Listenable.merge([
          AdminGameTrialService.instance,
          AdminStatsService.instance,
          AdminHardcoreLiveService.instance,
          LanguageService.instance,
        ]),
      AdminNavSection.messages => LanguageService.instance,
    };
  }

  bool _showInitialStatsGate() {
    if (_section != AdminNavSection.live &&
        _section != AdminNavSection.players) {
      return false;
    }
    final stats = AdminStatsService.instance.snapshot;
    return AdminStatsService.instance.loading && stats.registeredPlayers == 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_verifying || !_allowed) {
      return const Scaffold(
        backgroundColor: AdminTheme.bg,
        body: Center(
          child: CircularProgressIndicator(color: AdminTheme.accent),
        ),
      );
    }

    final size = MediaQuery.sizeOf(context);
    final email = AuthService.instance.currentUser?.email ?? '';
    final wide = size.width >= 980;
    final medium = size.width >= 720;
    final useDrawer = !medium;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AdminTheme.bg,
      drawer: useDrawer
          ? ListenableBuilder(
              listenable: Listenable.merge([
                AdminStatsService.instance,
                AdminHardcoreLiveService.instance,
                AdminMessagingService.instance,
                LanguageService.instance,
              ]),
              builder: (context, _) {
                final stats = AdminStatsService.instance.snapshot;
                return AdminNavDrawer(
                  selected: _section,
                  onSelected: _selectSection,
                  livePlayers: stats.totalPlayers,
                  hardcorePlayers:
                      AdminHardcoreLiveService.instance.snapshot.seatOccupancy,
                  activeSessions: stats.activeSessions,
                  unreadMessages: AdminMessagingService.instance.unreadCount,
                  email: email,
                );
              },
            )
          : null,
      body: Stack(
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) {
                return CustomPaint(
                  size: size,
                  painter: NeonSpaceParticlePainter(
                    progress: _particleController.value,
                    particleCount: 14,
                    seed: 91,
                    blurSigma: 2,
                    maxOpacity: 0.22,
                  ),
                );
              },
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.55, -0.85),
                radius: 1.25,
                colors: [
                  Color(0x2200D4E8),
                  AdminTheme.bg,
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListenableBuilder(
                  listenable: LanguageService.instance,
                  builder: (context, _) {
                    return AdminTopBar(
                      email: email,
                      signingOut: _signingOut,
                      section: _section,
                      showMenuButton: useDrawer,
                      onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                      onRefresh: () => unawaited(_refreshCurrentSection()),
                      onLobby: _openLobby,
                      onSignOut: _signOut,
                    );
                  },
                ),
                Expanded(
                  child: useDrawer
                      ? _buildSectionArea()
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListenableBuilder(
                              listenable: Listenable.merge([
                                AdminStatsService.instance,
                                AdminHardcoreLiveService.instance,
                                AdminMessagingService.instance,
                                LanguageService.instance,
                              ]),
                              builder: (context, _) {
                                final stats =
                                    AdminStatsService.instance.snapshot;
                                return AdminSideNav(
                                  selected: _section,
                                  onSelected: _selectSection,
                                  livePlayers: stats.totalPlayers,
                                  hardcorePlayers: AdminHardcoreLiveService
                                      .instance.snapshot.seatOccupancy,
                                  activeSessions: stats.activeSessions,
                                  unreadMessages: AdminMessagingService
                                      .instance.unreadCount,
                                  compact: !wide,
                                );
                              },
                            ),
                            Expanded(child: _buildSectionArea()),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionArea() {
    return ListenableBuilder(
      listenable: _listenableForSection(_section),
      builder: (context, _) {
        if (_showInitialStatsGate()) {
          return const Center(
            child: CircularProgressIndicator(color: AdminTheme.accent),
          );
        }

        final stats = AdminStatsService.instance.snapshot;
        return _AdminSectionBody(
          section: _section,
          stats: stats,
          error: AdminStatsService.instance.error,
          tuningError: RoomTuningService.instance.error,
          onRefresh: _refreshCurrentSection,
          formatTime: _formatTime,
        );
      },
    );
  }

  String _formatTime(DateTime utc) {
    final local = utc.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _AdminSectionBody extends StatelessWidget {
  const _AdminSectionBody({
    required this.section,
    required this.stats,
    required this.error,
    required this.tuningError,
    required this.onRefresh,
    required this.formatTime,
  });

  final AdminNavSection section;
  final AdminStatsSnapshot stats;
  final String? error;
  final String? tuningError;
  final Future<void> Function() onRefresh;
  final String Function(DateTime) formatTime;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;

    return RefreshIndicator(
      color: AdminTheme.accent,
      backgroundColor: AdminTheme.surface,
      onRefresh: onRefresh,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AdminTheme.contentMaxWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
            children: [
              AdminPageHeader(
                title: lang.t(section.titleKey),
                description: lang.t(section.descKey),
              ),
              if (error != null && section == AdminNavSection.live) ...[
                const SizedBox(height: 12),
                AdminErrorBanner(message: lang.t(error!)),
              ],
              if (tuningError != null &&
                  (section == AdminNavSection.universes ||
                      section == AdminNavSection.hardcore)) ...[
                const SizedBox(height: 12),
                AdminErrorBanner(message: lang.t(tuningError!)),
              ],
              const SizedBox(height: 18),
              ..._sectionChildren(),
              if (section == AdminNavSection.live ||
                  section == AdminNavSection.players ||
                  section == AdminNavSection.hardcore) ...[
                const SizedBox(height: 22),
                Text(
                  lang.t('admin_last_updated').replaceAll(
                        '{time}',
                        formatTime(
                          section == AdminNavSection.hardcore
                              ? AdminHardcoreLiveService
                                  .instance.snapshot.fetchedAt
                              : stats.fetchedAt,
                        ),
                      ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AdminTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _sectionChildren() {
    switch (section) {
      case AdminNavSection.live:
        return [
          AdminOverviewGrid(stats: stats),
          const SizedBox(height: 18),
          AdminLiveUniverseSummary(stats: stats),
        ];
      case AdminNavSection.hardcore:
        return const [
          AdminHardcorePanel(),
        ];
      case AdminNavSection.analytics:
        return const [AdminAnalyticsPanel()];
      case AdminNavSection.universes:
        return [
          AdminUniversesTuningPanel(stats: stats, showSectionChrome: false),
        ];
      case AdminNavSection.idle:
        return const [AdminIdleSettingsPanel()];
      case AdminNavSection.ranks:
        return const [AdminRankSettingsPanel()];
      case AdminNavSection.economy:
        return const [AdminEconomySettingsPanel()];
      case AdminNavSection.players:
        return [
          AdminPlayerStatsCard(stats: stats),
          const SizedBox(height: 12),
          AdminTopWinnersCard(winners: stats.topWinners),
        ];
      case AdminNavSection.loadTest:
        return const [AdminLoadTestPanel()];
      case AdminNavSection.gameTrial:
        return const [AdminGameTrialPanel()];
      case AdminNavSection.messages:
        return const [AdminMessagesPanel()];
    }
  }
}
