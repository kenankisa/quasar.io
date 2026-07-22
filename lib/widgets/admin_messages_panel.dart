import 'dart:async';

import 'package:flutter/material.dart';

import '../game/models/admin_message.dart';
import '../services/admin_messaging_service.dart';
import '../services/lang_service.dart';
import '../services/live_announcement_service.dart';

/// Yönetim paneli — oyuncu mesajları, yanıt ve duyurular.
class AdminMessagesPanel extends StatefulWidget {
  const AdminMessagesPanel({super.key});

  @override
  State<AdminMessagesPanel> createState() => _AdminMessagesPanelState();
}

class _AdminMessagesPanelState extends State<AdminMessagesPanel> {
  final _service = AdminMessagingService.instance;
  final _replyController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final _playerSearchController = TextEditingController();

  _ComposeMode _composeMode = _ComposeMode.none;
  MessagePlayerOption? _selectedPlayer;
  Timer? _searchDebounce;

  static const _cyan = Color(0xFF00F0FF);
  static const _amber = Color(0xFFFFC857);
  static const _mint = Color(0xFF22FFAA);

  @override
  void initState() {
    super.initState();
    if (_service.threads.isEmpty && !_service.loading) {
      unawaited(_service.refresh());
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _replyController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    _playerSearchController.dispose();
    super.dispose();
  }

  void _openCompose(_ComposeMode mode) {
    setState(() {
      _composeMode = mode;
      _selectedPlayer = null;
      _subjectController.clear();
      _bodyController.clear();
      _playerSearchController.clear();
    });
    if (mode == _ComposeMode.direct) {
      unawaited(_service.searchPlayers(''));
    }
  }

  void _closeCompose() {
    setState(() => _composeMode = _ComposeMode.none);
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    final ok = await _service.reply(text);
    if (ok && mounted) _replyController.clear();
  }

  Future<void> _sendCompose() async {
    final subject = _subjectController.text.trim();
    final body = _bodyController.text.trim();
    if (body.isEmpty) return;

    if (_composeMode == _ComposeMode.live) {
      final live = LiveAnnouncementService.instance;
      final ok = await live.post(body);
      if (!mounted) return;
      if (ok) {
        _closeCompose();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LanguageService.instance.t('live_announce_sent'))),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LanguageService.instance.t(live.error ?? 'live_announce_err'),
            ),
          ),
        );
      }
      return;
    }

    if (_composeMode == _ComposeMode.broadcast) {
      final count = await _service.broadcast(subject: subject, body: body);
      if (!mounted) return;
      if (count != null) {
        _closeCompose();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LanguageService.instance
                  .t('msg_broadcast_sent')
                  .replaceAll('{count}', '$count'),
            ),
          ),
        );
      }
      return;
    }

    final player = _selectedPlayer;
    if (player == null) return;
    final ok = await _service.sendDirect(
      playerId: player.id,
      subject: subject,
      body: body,
    );
    if (ok && mounted) _closeCompose();
  }

  void _onPlayerSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_service.searchPlayers(value.trim()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([
        _service,
        LiveAnnouncementService.instance,
      ]),
      builder: (context, _) {
        final selected = _service.selected;
        final sending = _composeMode == _ComposeMode.live
            ? LiveAnnouncementService.instance.posting
            : _service.sending;

        if (_composeMode != _ComposeMode.none) {
          return _ComposeCard(
            mode: _composeMode,
            subjectController: _subjectController,
            bodyController: _bodyController,
            playerSearchController: _playerSearchController,
            players: _service.players,
            selectedPlayer: _selectedPlayer,
            sending: sending,
            onClose: _closeCompose,
            onSend: _sendCompose,
            onPlayerSearch: _onPlayerSearch,
            onSelectPlayer: (p) => setState(() => _selectedPlayer = p),
          );
        }

        if (selected != null) {
          return _ThreadDetailView(
            detail: selected,
            loading: _service.detailLoading,
            sending: _service.sending,
            replyController: _replyController,
            onBack: _service.clearSelected,
            onSend: _sendReply,
            onToggleStatus: () {
              final next = selected.thread.status == MessageThreadStatus.open
                  ? MessageThreadStatus.closed
                  : MessageThreadStatus.open;
              unawaited(_service.setThreadStatus(selected.thread.id, next));
            },
          );
        }

        final unreadTotal = _service.threads.fold<int>(
          0,
          (sum, t) => sum + t.unreadCount,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionLabel(lang.t('msg_actions_section')),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                final actions = [
                  _ActionTile(
                    icon: Icons.notifications_active_rounded,
                    label: lang.t('live_announce_action'),
                    hint: lang.t('live_announce_tile_hint'),
                    accent: _amber,
                    onTap: () => _openCompose(_ComposeMode.live),
                  ),
                  _ActionTile(
                    icon: Icons.campaign_rounded,
                    label: lang.t('msg_broadcast'),
                    hint: lang.t('msg_broadcast_tile_hint'),
                    accent: _cyan,
                    onTap: () => _openCompose(_ComposeMode.broadcast),
                  ),
                  _ActionTile(
                    icon: Icons.person_add_alt_1_rounded,
                    label: lang.t('msg_send_direct'),
                    hint: lang.t('msg_direct_tile_hint'),
                    accent: _mint,
                    onTap: () => _openCompose(_ComposeMode.direct),
                  ),
                ];
                if (compact) {
                  return Column(
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        actions[i],
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: actions[i]),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _SectionLabel(lang.t('msg_inbox_section'))),
                if (unreadTotal > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: const Color(0xFFFF4466).withValues(alpha: 0.18),
                      border: Border.all(
                        color: const Color(0xFFFF4466).withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      lang
                          .t('msg_unread_badge')
                          .replaceAll('{count}', '$unreadTotal'),
                      style: const TextStyle(
                        color: Color(0xFFFF6688),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _FilterBar(
              statusFilter: _service.statusFilter,
              categoryFilter: _service.categoryFilter,
              onStatus: (v) => unawaited(_service.setStatusFilter(v)),
              onCategory: (v) => unawaited(_service.setCategoryFilter(v)),
            ),
            if (_service.error != null) ...[
              const SizedBox(height: 12),
              _HintBanner(text: lang.t('msg_migration_hint')),
            ],
            const SizedBox(height: 12),
            if (_service.loading && _service.threads.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _cyan,
                    ),
                  ),
                ),
              )
            else if (_service.threads.isEmpty)
              _EmptyInbox(text: lang.t('msg_empty_inbox'))
            else
              for (final thread in _service.threads) ...[
                _ThreadTile(
                  thread: thread,
                  onTap: () => unawaited(_service.openThread(thread.id)),
                ),
                const SizedBox(height: 8),
              ],
          ],
        );
      },
    );
  }
}

enum _ComposeMode { none, live, broadcast, direct }

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.45),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.12),
                accent.withValues(alpha: 0.04),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.14),
                    border: Border.all(color: accent.withValues(alpha: 0.4)),
                  ),
                  child: Icon(icon, color: accent, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 10.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: accent.withValues(alpha: 0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.statusFilter,
    required this.categoryFilter,
    required this.onStatus,
    required this.onCategory,
  });

  final String statusFilter;
  final String? categoryFilter;
  final ValueChanged<String> onStatus;
  final ValueChanged<String?> onCategory;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            lang.t('msg_status_label'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _SegmentButton(
                  label: lang.t('msg_filter_open'),
                  selected: statusFilter == 'open',
                  onTap: () => onStatus('open'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SegmentButton(
                  label: lang.t('msg_filter_closed'),
                  selected: statusFilter == 'closed',
                  onTap: () => onStatus('closed'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SegmentButton(
                  label: lang.t('msg_filter_all'),
                  selected: statusFilter == 'all',
                  onTap: () => onStatus('all'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            lang.t('msg_category_label'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              color: Colors.white.withValues(alpha: 0.04),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: categoryFilter,
                isExpanded: true,
                dropdownColor: const Color(0xFF12122A),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(lang.t('msg_filter_category_all')),
                  ),
                  for (final cat in MessageCategory.values)
                    DropdownMenuItem<String?>(
                      value: cat.name,
                      child: Text(lang.t(cat.labelKey)),
                    ),
                ],
                onChanged: onCategory,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            color: selected
                ? const Color(0xFF00F0FF).withValues(alpha: 0.16)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? const Color(0xFF00F0FF).withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xFF00F0FF)
                  : Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        color: Colors.white.withValues(alpha: 0.02),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 32,
            color: Colors.white.withValues(alpha: 0.28),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposeCard extends StatelessWidget {
  const _ComposeCard({
    required this.mode,
    required this.subjectController,
    required this.bodyController,
    required this.playerSearchController,
    required this.players,
    required this.selectedPlayer,
    required this.sending,
    required this.onClose,
    required this.onSend,
    required this.onPlayerSearch,
    required this.onSelectPlayer,
  });

  final _ComposeMode mode;
  final TextEditingController subjectController;
  final TextEditingController bodyController;
  final TextEditingController playerSearchController;
  final List<MessagePlayerOption> players;
  final MessagePlayerOption? selectedPlayer;
  final bool sending;
  final VoidCallback onClose;
  final Future<void> Function() onSend;
  final ValueChanged<String> onPlayerSearch;
  final ValueChanged<MessagePlayerOption> onSelectPlayer;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final isLive = mode == _ComposeMode.live;
    final isBroadcast = mode == _ComposeMode.broadcast;
    final accent = switch (mode) {
      _ComposeMode.live => const Color(0xFFFFC857),
      _ComposeMode.broadcast => const Color(0xFF00F0FF),
      _ComposeMode.direct || _ComposeMode.none => const Color(0xFF22FFAA),
    };

    final title = switch (mode) {
      _ComposeMode.live => lang.t('live_announce_action'),
      _ComposeMode.broadcast => lang.t('msg_broadcast'),
      _ComposeMode.direct || _ComposeMode.none => lang.t('msg_send_direct'),
    };

    final icon = switch (mode) {
      _ComposeMode.live => Icons.notifications_active_rounded,
      _ComposeMode.broadcast => Icons.campaign_rounded,
      _ComposeMode.direct || _ComposeMode.none => Icons.mail_outline_rounded,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        color: accent.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              TextButton(
                onPressed: onClose,
                child: Text(
                  lang.t('msg_compose_cancel'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (isLive) ...[
            const SizedBox(height: 8),
            Text(
              lang.t('live_announce_hint'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          if (!isBroadcast && !isLive) ...[
            const SizedBox(height: 12),
            TextField(
              controller: playerSearchController,
              onChanged: onPlayerSearch,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: _fieldDecoration(lang.t('msg_search_player')),
            ),
            const SizedBox(height: 8),
            if (selectedPlayer != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF22FFAA).withValues(alpha: 0.1),
                  border: Border.all(
                    color: const Color(0xFF22FFAA).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      size: 16,
                      color: Color(0xFF22FFAA),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lang
                            .t('msg_to_player')
                            .replaceAll('{name}', selectedPlayer!.username),
                        style: const TextStyle(
                          color: Color(0xFF22FFAA),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: players.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  itemBuilder: (context, index) {
                    final p = players[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFF1A1A2E),
                        child: Text(
                          p.username.isNotEmpty
                              ? p.username[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Color(0xFF22FFAA),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(
                        p.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      onTap: () => onSelectPlayer(p),
                    );
                  },
                ),
              ),
          ],
          if (!isLive) ...[
            const SizedBox(height: 12),
            TextField(
              controller: subjectController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: _fieldDecoration(lang.t('msg_subject_hint')),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: bodyController,
            minLines: isLive ? 2 : 4,
            maxLines: isLive ? 4 : 8,
            maxLength: isLive ? LiveAnnouncementService.maxBodyLength : null,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _fieldDecoration(
              isLive
                  ? lang.t('live_announce_body_hint')
                  : lang.t('msg_body_hint'),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: sending ? null : () => unawaited(onSend()),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: isLive
                    ? const Color(0xFF1A1200)
                    : const Color(0xFF020208),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              icon: sending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                isLive ? lang.t('live_announce_send') : lang.t('msg_send'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadDetailView extends StatelessWidget {
  const _ThreadDetailView({
    required this.detail,
    required this.loading,
    required this.sending,
    required this.replyController,
    required this.onBack,
    required this.onSend,
    required this.onToggleStatus,
  });

  final ThreadDetail detail;
  final bool loading;
  final bool sending;
  final TextEditingController replyController;
  final VoidCallback onBack;
  final Future<void> Function() onSend;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final thread = detail.thread;
    final canReply = thread.category != MessageCategory.broadcast;
    final open = thread.status == MessageThreadStatus.open;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white70,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      thread.subject.isEmpty
                          ? lang.t(thread.category.labelKey)
                          : thread.subject,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${thread.playerUsername} · ${lang.t(thread.category.labelKey)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onToggleStatus,
                style: TextButton.styleFrom(
                  foregroundColor: open
                      ? const Color(0xFFFF6688)
                      : const Color(0xFF22FFAA),
                ),
                child: Text(
                  open
                      ? lang.t('msg_close_thread')
                      : lang.t('msg_reopen_thread'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF00F0FF)),
            ),
          )
        else
          for (final msg in detail.messages) ...[
            _MessageBubble(message: msg, adminView: true),
            const SizedBox(height: 8),
          ],
        if (canReply) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: replyController,
                  minLines: 1,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _fieldDecoration(lang.t('msg_reply_hint')),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: sending ? null : () => unawaited(onSend()),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF00F0FF),
                  foregroundColor: const Color(0xFF020208),
                ),
                icon: sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.thread, required this.onTap});

  final MessageThread thread;
  final VoidCallback onTap;

  Color get _categoryColor => switch (thread.category) {
        MessageCategory.bug => const Color(0xFFFF6688),
        MessageCategory.suggestion => const Color(0xFFFFC857),
        MessageCategory.feedback => const Color(0xFF00F0FF),
        MessageCategory.direct => const Color(0xFF22FFAA),
        MessageCategory.broadcast => const Color(0xFFB388FF),
      };

  String _relativeTime(LanguageService lang) {
    final local = thread.lastMessageAt.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 1) return lang.t('msg_time_just_now');
    if (diff.inHours < 1) {
      return lang.t('msg_time_minutes').replaceAll('{n}', '${diff.inMinutes}');
    }
    if (diff.inDays < 1) {
      return lang.t('msg_time_hours').replaceAll('{n}', '${diff.inHours}');
    }
    if (diff.inDays < 7) {
      return lang.t('msg_time_days').replaceAll('{n}', '${diff.inDays}');
    }
    return '${local.day}.${local.month}.${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final unread = thread.hasUnread;
    final catColor = _categoryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unread
                  ? const Color(0xFF00F0FF).withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            color: unread
                ? const Color(0xFF00F0FF).withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.025),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF1A1A2E),
                  backgroundImage: thread.playerAvatarUrl != null &&
                          thread.playerAvatarUrl!.isNotEmpty
                      ? NetworkImage(thread.playerAvatarUrl!)
                      : null,
                  child: thread.playerAvatarUrl == null ||
                          thread.playerAvatarUrl!.isEmpty
                      ? Text(
                          thread.playerUsername.isNotEmpty
                              ? thread.playerUsername[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: catColor,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              thread.playerUsername,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight:
                                    unread ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          Text(
                            _relativeTime(lang),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: catColor.withValues(alpha: 0.14),
                              border: Border.all(
                                color: catColor.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              lang.t(thread.category.labelKey),
                              style: TextStyle(
                                color: catColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (thread.status == MessageThreadStatus.closed) ...[
                            const SizedBox(width: 6),
                            Text(
                              lang.t('msg_filter_closed'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        thread.subject.isEmpty ? thread.preview : thread.subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 12.5,
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      if (thread.preview.isNotEmpty &&
                          thread.subject.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          thread.preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (unread) ...[
                  const SizedBox(width: 8),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: const Color(0xFFFF4466),
                    ),
                    child: Text(
                      '${thread.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.adminView,
  });

  final AdminChatMessage message;
  final bool adminView;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final mine = adminView ? message.isFromAdmin : !message.isFromAdmin;
    final align = mine ? Alignment.centerRight : Alignment.centerLeft;
    final color = mine
        ? const Color(0xFF00F0FF).withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.06);
    final border = mine
        ? const Color(0xFF00F0FF).withValues(alpha: 0.4)
        : Colors.white.withValues(alpha: 0.12);

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: color,
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                message.isFromAdmin
                    ? lang.t('msg_from_admin')
                    : lang.t('msg_from_player'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message.body,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HintBanner extends StatelessWidget {
  const _HintBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFFF4466).withValues(alpha: 0.45),
        ),
        color: const Color(0xFFFF4466).withValues(alpha: 0.08),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          fontSize: 12,
          height: 1.35,
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.04),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF00F0FF)),
    ),
  );
}
