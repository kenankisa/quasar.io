import 'package:flutter/material.dart';
import '../../utils/lang_scope.dart';
import 'package:flutter/services.dart';

import '../../services/lobby_chat_service.dart';
import '../../services/lobby_online_count_service.dart';
import '../../services/profile_service.dart';
import '../../utils/responsive_layout.dart';
import 'lobby_cosmic_chrome.dart';

/// Full-height social tab — lobby chat and live presence.
class LobbySocialTab extends StatefulWidget {
  const LobbySocialTab({super.key});

  @override
  State<LobbySocialTab> createState() => _LobbySocialTabState();
}

class _LobbySocialTabState extends State<LobbySocialTab> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  LobbyChatService get _chat => LobbyChatService.instance;

  @override
  void initState() {
    super.initState();
    _chat.addListener(_onChat);
  }

  @override
  void dispose() {
    _chat.removeListener(_onChat);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChat() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    if (ProfileService.instance.profileNotifier.value?.id == null) return;
    final text = _controller.text;
    if (await _chat.send(text)) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final r = ResponsiveLayout.of(context);
    final messages = _chat.messages;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        r.w(r.isCompact ? 12 : 16),
        0,
        r.w(r.isCompact ? 12 : 16),
        keyboard > 0 ? keyboard + 8 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListenableBuilder(
            listenable: LobbyOnlineCountService.instance,
            builder: (context, _) {
              final count = LobbyOnlineCountService.instance.count;
              final label = count == null
                  ? '—'
                  : (count > 9999 ? '9999+' : '$count');
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: r.w(14),
                  vertical: r.w(12),
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFF22FFAA).withValues(alpha: 0.08),
                  border: Border.all(
                    color: const Color(0xFF22FFAA).withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF22FFAA),
                      ),
                    ),
                    SizedBox(width: r.w(10)),
                    Expanded(
                      child: Text(
                        '$label ${lang.t('lobby_online_label').toLowerCase()}',
                        style: TextStyle(
                          color: const Color(0xFF22FFAA),
                          fontSize: r.sp(14),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.public_rounded,
                      color: const Color(0xFF22FFAA).withValues(alpha: 0.7),
                      size: 20,
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: r.h(10)),
          Expanded(
            child: LobbyCosmicPanel(
              borderRadius: 16,
              accent: const Color(0xFF5AD7FF),
              secondary: const Color(0xFF8868FF),
              glowStrength: 0.12,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.forum_outlined,
                          color: Color(0xFF5AD7FF),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          lang.t('lobby_chat_title'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: r.sp(15),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: Color(0x2244DDEE)),
                  Expanded(
                    child: messages.isEmpty
                        ? Center(
                            child: Text(
                              lang.t('lobby_chat_empty'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: r.sp(13),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${msg.userName} ',
                                        style: const TextStyle(
                                          color: Color(0xFF5AD7FF),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '${msg.timeLabel} ',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.38,
                                          ),
                                          fontSize: 11,
                                        ),
                                      ),
                                      TextSpan(
                                        text: msg.text,
                                        style: const TextStyle(
                                          color: Color(0xFFE8F4FF),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 6, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            maxLength: LobbyChatService.maxMessageLength,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            cursorColor: const Color(0xFF5AD7FF),
                            decoration: InputDecoration(
                              isDense: true,
                              counterText: '',
                              hintText: lang.t('lobby_chat_hint'),
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF121826),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        IconButton(
                          onPressed: _chat.canSend ? _send : null,
                          icon: Icon(
                            Icons.send_rounded,
                            color: _chat.canSend
                                ? const Color(0xFF5AD7FF)
                                : Colors.white24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
