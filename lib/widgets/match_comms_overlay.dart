import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/models/match_speech.dart';
import '../game/orbit_game.dart';
import '../services/lang_service.dart';
import '../services/settings_service.dart';
import '../utils/responsive_layout.dart';
import 'ability_button.dart';
import 'boost_button.dart';
import 'game_hud_overlay.dart';

/// Kill feed + temporary match chat lines under the HUD.
class MatchFeedOverlay extends StatelessWidget {
  const MatchFeedOverlay({super.key, required this.game});

  final OrbitGame game;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService.instance,
      builder: (context, _) {
        if (!SettingsService.instance.showKillFeed) {
          return const SizedBox.shrink();
        }
        return ValueListenableBuilder<int>(
          valueListenable: game.matchFeedTick,
          builder: (context, _, _) {
            final entries = game.matchFeed;
            if (entries.isEmpty) return const SizedBox.shrink();

            return ValueListenableBuilder<double>(
              valueListenable: GameHudMetrics.toolbarHeight,
              builder: (context, _, _) {
                return Positioned(
                  top: GameHudMetrics.totalTopInset(context) + 8,
                  left: 10,
                  width: MediaQuery.sizeOf(context).width * 0.34,
                  child: IgnorePointer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final entry in entries.take(4))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _FeedChip(
                              name: entry.name,
                              text: entry.text,
                              isKill: entry.isKill,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _FeedChip extends StatelessWidget {
  const _FeedChip({
    required this.text,
    required this.isKill,
    this.name,
  });

  final String? name;
  final String text;
  final bool isKill;

  @override
  Widget build(BuildContext context) {
    final bodyColor =
        isKill ? const Color(0xFFFFCCAA) : const Color(0xFFD8F6FF);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isKill
            ? const Color(0xCC1A0808)
            : const Color(0xCC0A1018),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isKill
              ? const Color(0x88FF5566)
              : const Color(0x6644DDEE),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: name == null || name!.isEmpty
            ? Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: bodyColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: bodyColor.withValues(alpha: 0.75),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: bodyColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Bottom chrome: chat/react (left) + abilities (right), width-fit scaled.
class MatchCommsControls extends StatefulWidget {
  const MatchCommsControls({super.key, required this.game});

  final OrbitGame game;

  @override
  State<MatchCommsControls> createState() => _MatchCommsControlsState();
}

class _MatchCommsControlsState extends State<MatchCommsControls> {
  bool _reactionsOpen = false;
  bool _chatOpen = false;
  final _chatController = TextEditingController();
  final _chatFocus = FocusNode();

  OrbitGame get game => widget.game;

  @override
  void dispose() {
    _chatController.dispose();
    _chatFocus.dispose();
    super.dispose();
  }

  void _toggleReactions() {
    setState(() {
      _reactionsOpen = !_reactionsOpen;
      if (_reactionsOpen) _chatOpen = false;
    });
  }

  void _toggleChat() {
    setState(() {
      _chatOpen = !_chatOpen;
      if (_chatOpen) {
        _reactionsOpen = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _chatFocus.requestFocus();
        });
      }
    });
  }

  void _sendReaction(MatchReactionPreset preset) {
    final lang = LanguageService.instance;
    final label = lang.t(preset.labelKey);
    final text = label == preset.labelKey ? preset.fallback : label;
    if (game.trySendReaction(text)) {
      HapticFeedback.selectionClick();
      setState(() => _reactionsOpen = false);
    }
  }

  void _sendChat() {
    final raw = _chatController.text;
    if (game.trySendMatchChat(raw)) {
      HapticFeedback.lightImpact();
      _chatController.clear();
      setState(() => _chatOpen = false);
      _chatFocus.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    final lang = LanguageService.instance;
    final barHeight = r.bottomBoostSize;
    final overlayBottom = r.gameControlBottom + barHeight + r.w(8);

    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_reactionsOpen)
            Positioned(
              left: r.bottomBarSidePad,
              bottom: overlayBottom,
              child: SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.72,
                  ),
                  child: _ReactionRadial(onPick: _sendReaction),
                ),
              ),
            ),
          if (_chatOpen)
            Positioned(
              left: r.bottomBarSidePad,
              right: r.bottomBarSidePad,
              bottom: overlayBottom,
              child: SafeArea(
                child: _MatchChatBar(
                  controller: _chatController,
                  focusNode: _chatFocus,
                  maxLength: OrbitGame.matchChatMaxLength,
                  hint: lang.t('match_chat_hint') == 'match_chat_hint'
                      ? 'Short message…'
                      : lang.t('match_chat_hint'),
                  onSend: _sendChat,
                  onClose: () => setState(() => _chatOpen = false),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: r.gameControlBottom,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: r.bottomBarSidePad),
                child: ValueListenableBuilder<int>(
                  valueListenable: game.hudTick,
                  builder: (context, _, _) {
                    final player = game.player;
                    final canReact = game.canSendReaction;
                    final canChat = game.canSendMatchChat;
                    final gap = r.bottomControlGap;
                    final commsSize = r.bottomCommsSize;
                    final abilitySize = r.bottomAbilitySize;
                    final boostSize = r.bottomBoostSize;

                    return SizedBox(
                      height: barHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _CommsRoundButton(
                            icon: Icons.chat_bubble_outline_rounded,
                            accent: const Color(0xFF5AD7FF),
                            enabled: canChat || _chatOpen,
                            active: _chatOpen,
                            onTap: _toggleChat,
                            size: commsSize,
                          ),
                          SizedBox(width: gap),
                          _CommsRoundButton(
                            icon: Icons.bolt_rounded,
                            accent: const Color(0xFFFFC14D),
                            enabled: canReact || _reactionsOpen,
                            active: _reactionsOpen,
                            onTap: _toggleReactions,
                            size: commsSize,
                          ),
                          const Spacer(flex: 2),
                          AbilityButton(
                            icon: Icons.waves_rounded,
                            accent: const Color(0xFFFFB347),
                            charge: player.shockwaveCharge,
                            isReady: player.isShockwaveReady,
                            isActive: false,
                            size: abilitySize,
                            onActivate: () {
                              game.tryActivateShockwave();
                            },
                          ),
                          SizedBox(width: gap),
                          AbilityButton(
                            icon: Icons.shield_rounded,
                            accent: const Color(0xFF7CFFB2),
                            charge: player.abilityShieldCharge,
                            isReady: player.isAbilityShieldReady,
                            isActive: player.isShieldActive &&
                                !player.isSpawnProtected,
                            size: abilitySize,
                            onActivate: () {
                              game.tryActivateAbilityShield();
                            },
                          ),
                          SizedBox(width: gap),
                          AbilityButton(
                            icon: Icons.shuffle_rounded,
                            accent: const Color(0xFFC084FC),
                            charge: player.teleportCharge,
                            isReady: player.isTeleportReady,
                            isActive: false,
                            size: abilitySize,
                            onActivate: () {
                              game.tryActivateTeleport();
                            },
                          ),
                          SizedBox(width: gap),
                          BoostButton(
                            energy: player.boostEnergy,
                            isReady: player.isBoostReady,
                            isActive: player.isBoostActive,
                            size: boostSize,
                            onActivate: () {
                              if (player.tryActivateBoost()) {
                                game.hudTick.value++;
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommsRoundButton extends StatelessWidget {
  const _CommsRoundButton({
    required this.icon,
    required this.accent,
    required this.enabled,
    required this.active,
    required this.onTap,
    required this.size,
  });

  final IconData icon;
  final Color accent;
  final bool enabled;
  final bool active;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final alpha = enabled ? 1.0 : 0.4;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent.withValues(alpha: active ? 0.35 : 0.16),
          border: Border.all(
            color: accent.withValues(alpha: active ? 0.95 : 0.55 * alpha),
            width: 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: active ? 0.45 : 0.2),
              blurRadius: active ? 14 : 8,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: accent.withValues(alpha: alpha),
          size: size * 0.42,
        ),
      ),
    );
  }
}

class _ReactionRadial extends StatelessWidget {
  const _ReactionRadial({required this.onPick});

  final ValueChanged<MatchReactionPreset> onPick;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xEE0A1018),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x66FFC14D)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final preset in kMatchReactionPresets)
              _ReactionChip(
                label: () {
                  final t = LanguageService.instance.t(preset.labelKey);
                  return t == preset.labelKey ? preset.fallback : t;
                }(),
                onTap: () => onPick(preset),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A2430),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFE6A8),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchChatBar extends StatelessWidget {
  const _MatchChatBar({
    required this.controller,
    required this.focusNode,
    required this.maxLength,
    required this.hint,
    required this.onSend,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int maxLength;
  final String hint;
  final VoidCallback onSend;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xF00A121C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x665AD7FF)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLength: maxLength,
                maxLines: 1,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                cursorColor: const Color(0xFF5AD7FF),
                decoration: InputDecoration(
                  isDense: true,
                  counterText: '',
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: Colors.white54),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded, color: Color(0xFF5AD7FF)),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
