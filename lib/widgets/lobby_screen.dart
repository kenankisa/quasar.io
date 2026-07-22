import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/game_screen.dart';
import '../game/models/room_instance.dart';
import '../services/admin_access.dart';
import '../services/analytics_play_tracker.dart';
import '../services/auth_service.dart';
import '../services/lang_service.dart';
import '../services/lobby_room_stats_service.dart';
import '../services/player_inbox_service.dart';
import '../services/player_session_service.dart';
import '../services/profile_service.dart';
import '../services/room_matchmaking_service.dart';
import '../services/settings_service.dart';
import '../utils/app_lifecycle.dart';
import '../utils/responsive_layout.dart';
import 'admin_screen.dart';
import 'how_to_play_dialog.dart';
import 'neon_space_particle_painter.dart';
import 'player_messages_dialog.dart';
import 'profile_menu.dart';
import 'settings_dialog.dart';
import 'skill_tree_dialog.dart';
import 'sound_settings_dialog.dart';
import 'version_notes_dialog.dart';
import 'wormhole_portal.dart';
import 'lobby_chat_panel.dart';
import '../services/lobby_chat_service.dart';
import 'lobby/lobby_brand_hero.dart';
import 'lobby/lobby_match_entry.dart';
import 'lobby/lobby_room_list.dart';
import 'lobby/lobby_top_bar.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _glowController;
  late final AnimationController _particleController;

  PlayerProfile? _profile;
  bool _loading = true;
  bool _signingOut = false;
  bool _enteringRoom = false;
  RealtimeChannel? _profileChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
    _loadProfile();
    LobbyRoomStatsService.instance.attach();
    PlayerInboxService.instance.refreshUnreadCount();
    unawaited(LobbyChatService.instance.attach());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (AppLifecycle.shouldPause(state)) {
      _glowController.stop();
      _particleController.stop();
      LobbyRoomStatsService.instance.pauseForBackground();
    } else {
      if (!_glowController.isAnimating) {
        _glowController.repeat(reverse: true);
      }
      if (!_particleController.isAnimating) {
        _particleController.repeat();
      }
      LobbyRoomStatsService.instance.resumeFromBackground();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _glowController.dispose();
    _particleController.dispose();
    LobbyRoomStatsService.instance.detach();
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

  /// Yalnızca sunucu onaylı admin — e-posta / client allowlist yok (L2).
  Future<void> _openAdminPanel() async {
    final ok = await AdminAccess.refreshAdminStatus();
    if (!ok || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminScreen()),
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
          SnackBar(content: Text(LanguageService.instance.t('profile_update_error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Future<void> _showPlayerAlreadyActiveDialog() async {
    final lang = LanguageService.instance;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
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
    )) {
      return;
    }

    setState(() => _enteringRoom = true);

    // Portal starts immediately — covers the whole wait (no loading circle).
    WormholeTransit? transit;
    try {
      transit = await WormholeTransit.begin(context, roomType);
      if (!mounted) {
        transit.dispose();
        return;
      }

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

      RoomInstance? roomInstance;
      if (roomType != RoomType.simple) {
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
        SnackBar(content: Text(LanguageService.instance.t('matchmaking_error'))),
      );
    } finally {
      transit?.dispose();
      await AnalyticsPlayTracker.instance.end(roomType: roomType);
      await PlayerSessionService.instance.setInLobby();
      if (mounted) setState(() => _enteringRoom = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

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
                  particleCount: 40,
                  seed: 7,
                  blurSigma: 3,
                  maxOpacity: 0.5,
                ),
              );
            },
          ),
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.6),
                radius: 1.4,
                colors: [
                  const Color(0xFF1A0033).withValues(alpha: 0.35),
                  const Color(0xFF020208),
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
                    PlayerInboxService.instance,
                    AdminAccess.instance,
                  ]),
                  builder: (context, _) {
                    final profile =
                        ProfileService.instance.profileNotifier.value ??
                            _profile;
                    return LobbyTopBar(
                      glowAnimation: _glowController,
                      diamonds: profile?.diamonds ?? 0,
                      avatarUrl: profile?.avatarUrl,
                      loading: _loading,
                      signingOut: _signingOut,
                      musicEnabled: SettingsService.instance.musicEnabled,
                      showAdminPanel: AdminAccess.isCurrentUserAdmin,
                      unreadMessages: PlayerInboxService.instance.unreadCount,
                      onAdminPanelTap: _openAdminPanel,
                      onMessagesTap: () => PlayerMessagesDialog.show(context),
                      onSoundTap: () => SoundSettingsDialog.toggleMusic(),
                      onSettingsTap: () => SettingsDialog.show(context),
                      onSignOutTap: _handleSignOut,
                      onProfileTap: _openProfileMenu,
                    );
                  },
                ),
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(height: ResponsiveLayout.of(context).h(12)),
                      ListenableBuilder(
                        listenable: ProfileService.instance.profileNotifier,
                        builder: (context, _) {
                          final skillProfile = ProfileService
                                  .instance.profileNotifier.value ??
                              _profile;
                          return LobbyBrandHero(
                            glowAnimation: _glowController,
                            freeSp: skillProfile?.availableSkillPoints ?? 0,
                            onTitleLongPress: AdminAccess.isCurrentUserAdmin
                                ? _openAdminPanel
                                : null,
                            onVersionTap: () =>
                                VersionNotesDialog.show(context),
                            onHowToPlayTap: () =>
                                HowToPlayDialog.show(context),
                            onSkillsTap: () {
                              if (skillProfile == null) return;
                              SkillTreeDialog.show(context, skillProfile);
                            },
                          );
                        },
                      ),
                      SizedBox(height: ResponsiveLayout.of(context).h(16)),
                      Expanded(
                        child: ListenableBuilder(
                          listenable: Listenable.merge([
                            ProfileService.instance.profileNotifier,
                            LobbyRoomStatsService.instance,
                          ]),
                          builder: (context, _) {
                            final profile = ProfileService
                                    .instance.profileNotifier.value ??
                                _profile;
                            return LobbyRoomList(
                              diamonds: profile?.diamonds ?? 0,
                              gamesWon: profile?.gamesWon ?? 0,
                              tutorialCompleted:
                                  profile?.tutorialCompleted ?? false,
                              portalAnimation: _particleController,
                              onRoomSelected: _enterRoom,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
          const LobbyChatPanel(),
        ],
      ),
    );
  }
}
