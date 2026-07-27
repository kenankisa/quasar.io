import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/game_screen.dart';
import '../game/models/room_instance.dart';
import '../services/admin_access.dart';
import '../services/analytics_play_tracker.dart';
import '../services/auth_service.dart';
import '../utils/lang_rebuild.dart';
import '../utils/lang_scope.dart';
import '../services/lang_service.dart';
import '../services/lobby_online_count_service.dart';
import '../services/lobby_room_stats_service.dart';
import '../services/player_inbox_service.dart';
import '../services/player_session_service.dart';
import '../services/profile_service.dart';
import '../services/room_matchmaking_service.dart';
import '../services/settings_service.dart';
import '../utils/app_lifecycle.dart';
import '../utils/hardcore_cooldown.dart';
import '../utils/responsive_layout.dart';
import 'admin_screen.dart' deferred as admin_screen;
import 'daily_chest_dialog.dart';
import 'how_to_play_dialog.dart';
import 'neon_space_particle_painter.dart';
import 'player_messages_dialog.dart';
import 'profile_menu.dart';
import 'settings_dialog.dart';
import 'skill_tree_dialog.dart';
import 'version_notes_dialog.dart';
import 'wormhole_portal.dart';
import '../services/lobby_chat_service.dart';
import 'lobby/lobby_compact_header.dart';
import 'lobby/lobby_compact_room_list.dart';
import 'lobby/lobby_cosmic_chrome.dart';
import 'lobby/lobby_match_entry.dart';
import 'lobby/lobby_menu_sheet.dart';
import 'lobby/lobby_social_tab.dart';
import 'lobby/hardcore_queue_dialog.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver, LangChangeListener {
  late final AnimationController _particleController;
  late final TabController _tabController;

  PlayerProfile? _profile;
  bool _loading = true;
  bool _signingOut = false;
  bool _enteringRoom = false;
  RealtimeChannel? _profileChannel;
  bool _suspendedForGameplay = false;

  @override
  void onLangChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
    _loadProfile();
    LobbyRoomStatsService.instance.attach();
    LobbyOnlineCountService.instance.attach();
    PlayerInboxService.instance.refreshUnreadCount();
    unawaited(LobbyChatService.instance.attach());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (AppLifecycle.shouldPause(state)) {
      _particleController.stop();
      LobbyRoomStatsService.instance.pauseForBackground();
      LobbyOnlineCountService.instance.pauseForBackground();
    } else if (!_suspendedForGameplay) {
      if (!_particleController.isAnimating) {
        _particleController.repeat();
      }
      LobbyRoomStatsService.instance.resumeFromBackground();
      LobbyOnlineCountService.instance.resumeFromBackground();
    }
  }

  /// Maç sırasında arka plandaki lobi animasyonları ve polling'i durdurur.
  void _suspendLobbyForGameplay() {
    if (_suspendedForGameplay) return;
    _suspendedForGameplay = true;
    _particleController.stop();
    LobbyRoomStatsService.instance.detach();
    LobbyOnlineCountService.instance.detach();
    unawaited(LobbyChatService.instance.detach());
  }

  /// Lobiye dönünce animasyonları ve servisleri yeniden başlatır.
  void _resumeLobbyForGameplay() {
    if (!_suspendedForGameplay) return;
    _suspendedForGameplay = false;
    if (!mounted) return;
    if (!_particleController.isAnimating) {
      _particleController.repeat();
    }
    LobbyRoomStatsService.instance.attach();
    LobbyOnlineCountService.instance.attach();
    unawaited(LobbyChatService.instance.attach());
  }

  @override
  void dispose() {
    _suspendedForGameplay = false;
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _particleController.dispose();
    LobbyRoomStatsService.instance.detach();
    LobbyOnlineCountService.instance.detach();
    unawaited(LobbyChatService.instance.detach());
    if (_profileChannel != null) {
      Supabase.instance.client.removeChannel(_profileChannel!);
    }
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ProfileService.instance.fetchProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile ?? _profile;
        _loading = false;
      });

      if (profile != null) {
        _profileChannel?.unsubscribe();
        _profileChannel = ProfileService.instance.subscribeToProfile((updated) {
          if (mounted) setState(() => _profile = updated);
        });
        unawaited(ProfileService.instance.fetchDailyChestStatus());
        unawaited(ProfileService.instance.refreshMatchDayDiamonds());
      }
      _maybeShowWhatsNew();
    } catch (e, stackTrace) {
      debugPrint('Lobby _loadProfile: $e\n$stackTrace');
      if (!mounted) return;
      setState(() => _loading = false);
      _maybeShowWhatsNew();
    }
  }

  void _maybeShowWhatsNew() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(VersionNotesDialog.showAutoIfNeeded(context));
    });
  }

  void _openProfileMenu() {
    if (_profile == null) return;
    ProfileMenu.show(
      context,
      profile: _profile!,
      onProfileChanged: _loadProfile,
    );
  }

  void _openMenu() {
    final profile =
        ProfileService.instance.profileNotifier.value ?? _profile;
    LobbyMenuSheet.show(
      context,
      freeSkillPoints: profile?.availableSkillPoints ?? 0,
      showAdminPanel: AdminAccess.isCurrentUserAdmin,
      signingOut: _signingOut,
      onHowToPlay: () => HowToPlayDialog.show(context),
      onSkills: () {
        if (profile == null) return;
        SkillTreeDialog.show(context, profile);
      },
      onVersionNotes: () => VersionNotesDialog.show(context),
      onAdminPanel: AdminAccess.isCurrentUserAdmin ? _openAdminPanel : null,
      onSignOut: _handleSignOut,
    );
  }

  /// Yalnızca sunucu onaylı admin — e-posta / client allowlist yok (L2).
  Future<void> _openAdminPanel() async {
    final ok = await AdminAccess.refreshAdminStatus();
    if (!ok || !mounted) return;
    await admin_screen.loadLibrary();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => admin_screen.AdminScreen()),
    );
  }

  Future<void> _handleSignOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);

    try {
      await RoomMatchmakingService.instance.leaveActiveRoom();
      await PlayerSessionService.instance.release();
      await AuthService.instance.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.lang.t('profile_update_error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Future<void> _showPlayerAlreadyActiveDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final lang = dialogContext.lang;
        return AlertDialog(
          backgroundColor: const Color(0xFF0A0A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: const Color(0xFFFF6688).withValues(alpha: 0.45),
            ),
          ),
          title: Text(
            lang.t('player_already_active_title'),
            style: const TextStyle(
              color: Color(0xFFFF6688),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            lang.t('player_already_active_message'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.45,
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00F0FF),
                foregroundColor: const Color(0xFF020208),
              ),
              child: Text(lang.t('player_already_active_ok')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _enterRoom(RoomType roomType) async {
    if (_enteringRoom) return;

    final profile =
        ProfileService.instance.profileNotifier.value ?? _profile;
    final diamonds = profile?.diamonds ?? 0;
    final gamesWon = profile?.gamesWon ?? 0;
    final tutorialCompleted = profile?.tutorialCompleted ?? false;

    if (!RoomTypeLobby.isLobbyAccessible(
      roomType,
      tutorialCompleted: tutorialCompleted,
      gamesWon: gamesWon,
      diamonds: diamonds,
      universeTrophies: profile?.totalUniverseTrophies ?? 0,
      isAdmin: AdminAccess.isCurrentUserAdmin,
    )) {
      return;
    }

    if (roomType == RoomType.hardcore &&
        profile?.isHardcoreOnCooldown == true &&
        !AdminAccess.isCurrentUserAdmin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hardcoreCooldownLockMessage(
              LanguageService.instance,
              profile?.hardcoreCooldownRemaining,
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _enteringRoom = true);

    // Portal starts immediately — covers the whole wait (no loading circle).
    WormholeTransit? transit;
    try {
      RoomInstance? roomInstance;

      // Hardcore: resolve seat/queue before the wormhole so queue UI is clear.
      if (roomType == RoomType.hardcore) {
        final hc = await RoomMatchmakingService.instance.joinHardcoreUniverse();
        if (hc is HardcoreQueued) {
          if (!mounted) return;
          setState(() => _enteringRoom = false);
          final admitted = await HardcoreQueueDialog.show(
            context,
            initialPosition: hc.position,
          );
          if (admitted == null || !mounted) return;
          setState(() => _enteringRoom = true);
          roomInstance = await RoomMatchmakingService.instance
              .ensureRoomCosmicSync(admitted);
        } else if (hc is HardcoreJoined) {
          roomInstance = hc.instance;
        }
      }

      if (!mounted) return;
      transit = await WormholeTransit.begin(context, roomType);
      if (!mounted) {
        transit.dispose();
        return;
      }

      _suspendLobbyForGameplay();

      final status = await PlayerSessionService.instance.checkStatus();
      if (status.blockedOnOtherDevice) {
        await transit.abort();
        transit.dispose();
        transit = null;
        if (!mounted) return;
        await _showPlayerAlreadyActiveDialog();
        return;
      }

      await PlayerSessionService.instance.setInGame(roomType);
      await AnalyticsPlayTracker.instance.begin(roomType);

      if (roomType != RoomType.simple && roomType != RoomType.hardcore) {
        roomInstance = await LobbyMatchEntry.joinCompetitiveRoom(roomType);
      }

      if (!mounted) {
        transit.dispose();
        transit = null;
        return;
      }

      // Keep the SAME slow portal travel running while the universe mounts.
      final worldReady = Completer<void>();
      final opened = Navigator.of(context).push(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => GameScreen(
            roomType: roomType,
            roomInstance: roomInstance,
            onReady: () {
              if (!worldReady.isCompleted) worldReady.complete();
            },
          ),
        ),
      );

      await worldReady.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () {},
      );
      if (!mounted) {
        transit.dispose();
        transit = null;
        await opened;
        return;
      }

      // Only now dive through and reveal the live universe.
      await transit.complete();
      await SchedulerBinding.instance.endOfFrame;
      transit.dispose();
      transit = null;

      await opened;

      if (!mounted) return;
      await _loadProfile();
    } on PlayerAlreadyActiveException {
      await transit?.abort();
      transit?.dispose();
      transit = null;
      if (!mounted) return;
      await _showPlayerAlreadyActiveDialog();
    } on RoomMatchmakingException catch (e) {
      await transit?.abort();
      transit?.dispose();
      transit = null;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LobbyMatchEntry.matchmakingErrorText(e.message)),
        ),
      );
    } catch (e) {
      await transit?.abort();
      transit?.dispose();
      transit = null;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.lang.t('matchmaking_error'))),
      );
    } finally {
      transit?.dispose();
      _resumeLobbyForGameplay();
      await AnalyticsPlayTracker.instance.end(roomType: roomType);
      await PlayerSessionService.instance.setInLobby();
      if (mounted) setState(() => _enteringRoom = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final lang = context.lang;
    final r = ResponsiveLayout.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF020208),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, _) {
              return CustomPaint(
                size: size,
                painter: NeonSpaceParticlePainter(
                  progress: _particleController.value,
                  particleCount:
                      SettingsService.instance.lowPerformanceMode ? 8 : 24,
                  seed: 7,
                  blurSigma: 2,
                  maxOpacity: 0.35,
                ),
              );
            },
          ),
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.5),
                radius: 1.2,
                colors: [
                  const Color(0xFF1A0033).withValues(alpha: 0.28),
                  const Color(0xFF020208),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.85, 0.9),
                radius: 0.65,
                colors: [
                  const Color(0xFF102040).withValues(alpha: 0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                ListenableBuilder(
                  listenable: Listenable.merge([
                    SettingsService.instance,
                    ProfileService.instance.profileNotifier,
                    ProfileService.instance.dailyChestAvailable,
                    ProfileService.instance.dailyChestNextAvailableAt,
                    ProfileService.instance.matchDayDiamondNotifier,
                    PlayerInboxService.instance,
                    AdminAccess.instance,
                    LobbyOnlineCountService.instance,
                  ]),
                  builder: (context, _) {
                    final profile =
                        ProfileService.instance.profileNotifier.value ??
                            _profile;
                    final dayStatus =
                        ProfileService.instance.matchDayDiamondNotifier.value;
                    return LobbyCompactHeader(
                      diamonds: profile?.diamonds ?? 0,
                      matchDayEarned: dayStatus?.earned,
                      matchDayCap: dayStatus?.cap,
                      onlineCount: LobbyOnlineCountService.instance.count,
                      avatarUrl: profile?.avatarUrl,
                      loading: _loading,
                      unreadMessages: PlayerInboxService.instance.unreadCount,
                      dailyChestAvailable:
                          ProfileService.instance.dailyChestAvailable.value,
                      dailyChestNextAvailableAt: ProfileService
                          .instance.dailyChestNextAvailableAt.value,
                      onDailyChestTap: () => DailyChestDialog.show(context),
                      onMessagesTap: () => PlayerMessagesDialog.show(context),
                      onSettingsTap: () => SettingsDialog.show(context),
                      onMenuTap: _openMenu,
                      onProfileTap: _openProfileMenu,
                    );
                  },
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    r.w(r.isCompact ? 12 : 16),
                    r.h(6),
                    r.w(r.isCompact ? 12 : 16),
                    0,
                  ),
                  child: LobbyCosmicPanel(
                    borderRadius: 14,
                    glowStrength: 0.1,
                    padding: const EdgeInsets.all(4),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      indicator: const LobbyCosmicTabIndicator(
                        accent: Color(0xFF00F0FF),
                        secondary: Color(0xFF8868FF),
                        borderRadius: 10,
                      ),
                      labelColor: const Color(0xFF00F0FF),
                      unselectedLabelColor: Colors.white.withValues(alpha: 0.42),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: r.sp(12.5),
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: const Color(0xFF00F0FF).withValues(alpha: 0.35),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: r.sp(12.5),
                      ),
                      tabs: [
                        Tab(
                          height: 42,
                          icon: Icon(Icons.rocket_launch_rounded, size: r.sp(17)),
                          text: lang.t('lobby_tab_play'),
                        ),
                        Tab(
                          height: 42,
                          icon: Icon(Icons.hub_outlined, size: r.sp(17)),
                          text: lang.t('lobby_tab_social'),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: r.h(6)),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      ListenableBuilder(
                        listenable: Listenable.merge([
                          ProfileService.instance.profileNotifier,
                          LobbyRoomStatsService.instance,
                        ]),
                        builder: (context, _) {
                          final profile = ProfileService
                                  .instance.profileNotifier.value ??
                              _profile;
                          return LobbyCompactRoomList(
                            diamonds: profile?.diamonds ?? 0,
                            gamesWon: profile?.gamesWon ?? 0,
                            tutorialCompleted:
                                profile?.tutorialCompleted ?? false,
                            portalAnimation: _particleController,
                            trophyWinsSimple: profile?.trophyWinsSimple ?? 0,
                            trophyWinsNormal: profile?.trophyWinsNormal ?? 0,
                            trophyWinsElite: profile?.trophyWinsElite ?? 0,
                            trophyWinsUnique: profile?.trophyWinsUnique ?? 0,
                            hardcoreCooldownUntil:
                                profile?.hardcoreCooldownUntil,
                            hardcoreCooldownBypassed:
                                AdminAccess.isCurrentUserAdmin,
                            onRoomSelected: _enterRoom,
                          );
                        },
                      ),
                      const LobbySocialTab(),
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
}
