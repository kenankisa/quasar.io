import 'dart:async';

import 'package:flutter/material.dart';

import '../game/models/admin_message.dart';
import '../services/lang_service.dart';
import '../services/player_inbox_service.dart';
import 'cosmic_dialog.dart';

/// Oyuncu gelen kutusu + admin'e görüş / öneri / hata mesajı.
class PlayerMessagesDialog extends StatefulWidget {
  const PlayerMessagesDialog({super.key, this.initialTab = 0});

  /// 0 = gelen kutusu, 1 = yeni mesaj
  final int initialTab;

  static Future<void> show(BuildContext context, {int initialTab = 0}) {
    return CosmicDialog.show(
      context: context,
      barrierLabel: 'Messages',
      child: PlayerMessagesDialog(initialTab: initialTab),
    );
  }

  @override
  State<PlayerMessagesDialog> createState() => _PlayerMessagesDialogState();
}

class _PlayerMessagesDialogState extends State<PlayerMessagesDialog> {
  final _service = PlayerInboxService.instance;
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final _replyController = TextEditingController();

  late int _tab;
  MessageCategory _category = MessageCategory.feedback;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 1);
    unawaited(_service.refresh());
  }

  @override
  void dispose() {
    _service.clearSelected();
    _subjectController.dispose();
    _bodyController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty) return;
    final ok = await _service.submit(
      category: _category,
      subject: _subjectController.text.trim(),
      body: body,
    );
    if (!mounted) return;
    if (!ok) {
      final errKey = _service.error ?? 'msg_err_generic';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageService.instance.t(errKey))),
      );
      return;
    }
    _subjectController.clear();
    _bodyController.clear();
    setState(() => _tab = 0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(LanguageService.instance.t('msg_sent_ok'))),
    );
  }

  Future<void> _reply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    final ok = await _service.reply(text);
    if (!mounted) return;
    if (!ok) {
      final errKey = _service.error ?? 'msg_err_generic';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageService.instance.t(errKey))),
      );
      return;
    }
    _replyController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([_service, lang]),
      builder: (context, _) {
        final selected = _service.selected;

        return CosmicDialogPanel(
          icon: Icons.mail_outline_rounded,
          title: lang.t('msg_player_title'),
          maxWidth: 480,
          scrollable: false,
          expandBody: true,
          children: [
            if (selected != null)
              Expanded(
                child: _PlayerThreadDetail(
                  detail: selected,
                  loading: _service.detailLoading,
                  sending: _service.sending,
                  replyController: _replyController,
                  onBack: () {
                    _service.clearSelected();
                    setState(() {});
                  },
                  onSend: _reply,
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      label: lang.t('msg_tab_inbox'),
                      selected: _tab == 0,
                      badge: _service.unreadCount > 0
                          ? '${_service.unreadCount}'
                          : null,
                      onTap: () => setState(() => _tab = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TabButton(
                      label: lang.t('msg_tab_compose'),
                      selected: _tab == 1,
                      onTap: () => setState(() => _tab = 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_tab == 0)
                Expanded(child: _InboxList(service: _service))
              else
                Expanded(
                  child: _ComposeForm(
                    category: _category,
                    subjectController: _subjectController,
                    bodyController: _bodyController,
                    sending: _service.sending,
                    onCategoryChanged: (c) => setState(() => _category = c),
                    onSubmit: _submit,
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _InboxList extends StatelessWidget {
  const _InboxList({required this.service});

  final PlayerInboxService service;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;

    if (service.error != null) {
      return Center(
        child: Text(
          lang.t('msg_migration_hint'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 12,
            height: 1.35,
          ),
        ),
      );
    }

    if (service.loading && service.threads.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00F0FF)),
      );
    }

    if (service.threads.isEmpty) {
      return Center(
        child: Text(
          lang.t('msg_empty_player_inbox'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 13,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: service.threads.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final thread = service.threads[index];
        return _PlayerThreadTile(
          thread: thread,
          onTap: () => unawaited(service.openThread(thread.id)),
        );
      },
    );
  }
}

class _ComposeForm extends StatelessWidget {
  const _ComposeForm({
    required this.category,
    required this.subjectController,
    required this.bodyController,
    required this.sending,
    required this.onCategoryChanged,
    required this.onSubmit,
  });

  final MessageCategory category;
  final TextEditingController subjectController;
  final TextEditingController bodyController;
  final bool sending;
  final ValueChanged<MessageCategory> onCategoryChanged;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            lang.t('msg_compose_hint'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final cat in const [
                MessageCategory.feedback,
                MessageCategory.suggestion,
                MessageCategory.bug,
              ])
                ChoiceChip(
                  label: Text(lang.t(cat.labelKey)),
                  selected: category == cat,
                  onSelected: (_) => onCategoryChanged(cat),
                  selectedColor: const Color(0xFF00F0FF).withValues(alpha: 0.25),
                  labelStyle: TextStyle(
                    color: category == cat
                        ? const Color(0xFF00F0FF)
                        : Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                  side: BorderSide(
                    color: category == cat
                        ? const Color(0xFF00F0FF).withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: subjectController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _input(lang.t('msg_subject_hint')),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: bodyController,
            minLines: 5,
            maxLines: 10,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _input(lang.t('msg_body_hint')),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: sending ? null : () => unawaited(onSubmit()),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00F0FF),
              foregroundColor: const Color(0xFF020208),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(
              lang.t('msg_send_to_admin'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerThreadDetail extends StatelessWidget {
  const _PlayerThreadDetail({
    required this.detail,
    required this.loading,
    required this.sending,
    required this.replyController,
    required this.onBack,
    required this.onSend,
  });

  final ThreadDetail detail;
  final bool loading;
  final bool sending;
  final TextEditingController replyController;
  final VoidCallback onBack;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final thread = detail.thread;
    final canReply = thread.category != MessageCategory.broadcast;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
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
                  Text(
                    lang.t(thread.category.labelKey),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00F0FF)),
                )
              : ListView.separated(
                  itemCount: detail.messages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final msg = detail.messages[index];
                    final mine = !msg.isFromAdmin;
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 340),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: mine
                              ? const Color(0xFF00F0FF).withValues(alpha: 0.16)
                              : Colors.white.withValues(alpha: 0.06),
                          border: Border.all(
                            color: mine
                                ? const Color(0xFF00F0FF)
                                    .withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: mine
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.isFromAdmin
                                  ? lang.t('msg_from_admin')
                                  : lang.t('msg_from_you'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              msg.body,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (canReply) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: replyController,
                  minLines: 1,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _input(lang.t('msg_reply_hint')),
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
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              lang.t('msg_broadcast_readonly'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }
}

class _PlayerThreadTile extends StatelessWidget {
  const _PlayerThreadTile({required this.thread, required this.onTap});

  final MessageThread thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final unread = thread.hasUnread;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: unread
                  ? const Color(0xFF00F0FF).withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
            ),
            color: unread
                ? const Color(0xFF00F0FF).withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.03),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      thread.subject.isEmpty
                          ? lang.t(thread.category.labelKey)
                          : thread.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight:
                            unread ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    lang.t(thread.category.labelKey),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (unread) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF4466),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              if (thread.preview.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  thread.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFF00F0FF).withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.1),
            ),
            color: selected
                ? const Color(0xFF00F0FF).withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF00F0FF)
                      : Colors.white.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: const Color(0xFFFF4466),
                  ),
                  child: Text(
                    badge!,
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
    );
  }
}

InputDecoration _input(String hint) {
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
