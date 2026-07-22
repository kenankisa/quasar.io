import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/lang_service.dart';
import '../services/lobby_chat_service.dart';
import '../services/profile_service.dart';

/// Collapsible mini chat strip for the lobby hub.
class LobbyChatPanel extends StatefulWidget {
  const LobbyChatPanel({super.key});

  @override
  State<LobbyChatPanel> createState() => _LobbyChatPanelState();
}

class _LobbyChatPanelState extends State<LobbyChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _expanded = false;

  LobbyChatService get _chat => LobbyChatService.instance;

  @override
  void initState() {
    super.initState();
    _chat.addListener(_onChat);
    _focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    _chat.removeListener(_onChat);
    _focusNode.removeListener(_onFocus);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (_focusNode.hasFocus && !_expanded) {
      setState(() => _expanded = true);
    }
  }

  void _onChat() {
    if (!mounted) return;
    setState(() {});
    if (_expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (!_expanded) _focusNode.unfocus();
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
    final lang = LanguageService.instance;
    final title = lang.t('lobby_chat_title');
    final hint = lang.t('lobby_chat_hint');
    final empty = lang.t('lobby_chat_empty');
    final messages = _chat.messages;
    final latest = messages.isEmpty ? null : messages.last;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          0,
          12,
          keyboard > 0 ? keyboard + 8 : bottomSafe + 10,
        ),
        child: Material(
          color: Colors.transparent,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.hardEdge,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xF2080C16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x5544DDEE)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: _toggle,
                    borderRadius: BorderRadius.vertical(
                      top: const Radius.circular(16),
                      bottom: Radius.circular(_expanded ? 0 : 16),
                    ),
                    child: SizedBox(
                      height: 48,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.forum_outlined,
                              color: Color(0xFF5AD7FF),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _expanded
                                    ? title
                                    : (latest == null
                                        ? title
                                        : '${latest.userName}: ${latest.text}'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(
                                    alpha: latest == null && !_expanded
                                        ? 0.55
                                        : 0.92,
                                  ),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            Icon(
                              _expanded
                                  ? Icons.keyboard_arrow_down_rounded
                                  : Icons.keyboard_arrow_up_rounded,
                              color: Colors.white54,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_expanded) ...[
                    const Divider(height: 1, thickness: 1, color: Color(0x3344DDEE)),
                    SizedBox(
                      height: 118,
                      child: messages.isEmpty
                          ? Center(
                              child: Text(
                                empty,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final msg = messages[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${msg.userName}: ',
                                          style: const TextStyle(
                                            color: Color(0xFF5AD7FF),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                        TextSpan(
                                          text: msg.text,
                                          style: const TextStyle(
                                            color: Color(0xFFE8F4FF),
                                            fontSize: 12.5,
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
                      padding: const EdgeInsets.fromLTRB(8, 0, 4, 8),
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
                                fontSize: 13.5,
                              ),
                              cursorColor: const Color(0xFF5AD7FF),
                              decoration: InputDecoration(
                                isDense: true,
                                counterText: '',
                                hintText: hint,
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF121826),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
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
                            visualDensity: VisualDensity.compact,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
