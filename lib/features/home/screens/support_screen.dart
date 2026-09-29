import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _priority = 'normal';
  String _category = 'general';
  bool _submitting = false;
  bool _loading = true;
  int _page = 1;
  bool _hasMore = true;
  final List<Map<String, dynamic>> _tickets = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTickets();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 120) {
      if (_hasMore && !_loading) {
        _loadMore();
      }
    }
  }

  Future<void> _loadTickets() async {
    setState(() => _loading = true);
    final data = await HomeApiService.fetchSupportTickets(page: 1, perPage: 20);
    if (!mounted) return;
    final meta = data['meta'] as Map<String, dynamic>?;
    final lastPage = (meta?['last_page'] as num?)?.toInt() ?? 1;
    setState(() {
      _tickets
        ..clear()
        ..addAll((data['data'] as List<Map<String, dynamic>>?) ?? []);
      _page = 1;
      _hasMore = _page < lastPage;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    final nextPage = _page + 1;
    final data = await HomeApiService.fetchSupportTickets(
      page: nextPage,
      perPage: 20,
    );
    if (!mounted) return;
    final meta = data['meta'] as Map<String, dynamic>?;
    final lastPage = (meta?['last_page'] as num?)?.toInt() ?? nextPage;
    setState(() {
      _tickets.addAll((data['data'] as List<Map<String, dynamic>>?) ?? []);
      _page = nextPage;
      _hasMore = _page < lastPage;
    });
  }

  Future<void> _submitTicket() async {
    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject and message are required')),
      );
      return;
    }

    setState(() => _submitting = true);
    final ok = await HomeApiService.createSupportTicket(
      subject: subject,
      message: message,
      category: _category,
      priority: _priority,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to submit ticket')));
      return;
    }

    _subjectCtrl.clear();
    _messageCtrl.clear();
    await _loadTickets();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ticket submitted')));
  }

  List<Map<String, dynamic>> _messagesFor(Map<String, dynamic> ticket) {
    final raw = ticket['messages'] as List?;
    if (raw == null) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String? _latestReply(Map<String, dynamic> ticket) {
    final messages = _messagesFor(ticket);
    for (var i = messages.length - 1; i >= 0; i -= 1) {
      final role = messages[i]['sender_role']?.toString();
      final text = messages[i]['message']?.toString();
      if (role == 'admin' && text != null && text.trim().isNotEmpty) {
        return text.trim();
      }
    }
    final legacy = ticket['admin_reply']?.toString();
    return legacy != null && legacy.trim().isNotEmpty ? legacy.trim() : null;
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final parsed = DateTime.tryParse(iso)?.toLocal();
    if (parsed == null) return iso;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(parsed.year, parsed.month, parsed.day);
    final time = TimeOfDay.fromDateTime(parsed).format(context);
    if (date == today) return 'Today, $time';
    if (date == today.subtract(const Duration(days: 1)))
      return 'Yesterday, $time';
    return '${parsed.day}/${parsed.month}/${parsed.year} $time';
  }

  Future<void> _openTicketDetail(Map<String, dynamic> ticket) async {
    final updatedTicket = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        String replyDraft = '';
        final replyCtrl = TextEditingController();
        bool sending = false;
        Map<String, dynamic> currentTicket = Map<String, dynamic>.from(ticket);

        return StatefulBuilder(
          builder: (context, setModalState) {
            if (replyCtrl.text != replyDraft) {
              replyCtrl.value = TextEditingValue(
                text: replyDraft,
                selection: TextSelection.collapsed(offset: replyDraft.length),
              );
            }
            final theme = Theme.of(context);
            final scheme = theme.colorScheme;
            final messages = _messagesFor(currentTicket);
            final reference = currentTicket['reference']?.toString();
            final status = currentTicket['status']?.toString() ?? 'pending';
            final priority = currentTicket['priority']?.toString() ?? 'normal';

            Future<void> sendReply() async {
              final text = replyDraft.trim();
              if (text.isEmpty || sending) return;
              setModalState(() => sending = true);
              final ticketId = int.tryParse(
                currentTicket['id']?.toString() ?? '',
              );
              if (ticketId == null) {
                setModalState(() => sending = false);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Ticket is unavailable')),
                );
                return;
              }
              final optimisticReply = {
                'id': DateTime.now().millisecondsSinceEpoch,
                'message': text,
                'created_at': DateTime.now().toIso8601String(),
                'sender_role': 'user',
                'user': {'name': 'You'},
              };
              final currentMessages = _messagesFor(currentTicket);
              setModalState(() {
                currentTicket = Map<String, dynamic>.from(currentTicket)
                  ..['messages'] = [...currentMessages, optimisticReply];
              });
              final updatedId = (currentTicket['id'] as num?)?.toInt();
              if (updatedId != null && mounted) {
                final index = _tickets.indexWhere(
                  (ticket) =>
                      ((ticket['id'] as num?)?.toInt() ?? -1) == updatedId,
                );
                if (index >= 0) {
                  setState(() {
                    _tickets[index] = Map<String, dynamic>.from(currentTicket);
                  });
                }
              }
              final result = await HomeApiService.replySupportTicket(
                ticketId: ticketId,
                message: text,
              );
              if (!mounted || !context.mounted) return;
              setModalState(() => sending = false);
              final nextTicket = result['ticket'] is Map<String, dynamic>
                  ? result['ticket'] as Map<String, dynamic>
                  : null;

              if (result['ok'] != true || nextTicket == null) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result['message']?.toString() ?? 'Failed to send reply',
                    ),
                  ),
                );
                return;
              }

              replyDraft = '';
              replyCtrl.clear();
              setModalState(() {
                currentTicket = Map<String, dynamic>.from(nextTicket);
              });
              final updatedTicketId = (nextTicket['id'] as num?)?.toInt();
              if (updatedTicketId != null) {
                final index = _tickets.indexWhere(
                  (ticket) =>
                      ((ticket['id'] as num?)?.toInt() ?? -1) ==
                      updatedTicketId,
                );
                if (index >= 0 && mounted) {
                  setState(() {
                    _tickets[index] = Map<String, dynamic>.from(nextTicket);
                  });
                }
              }
              await _loadTickets();
              if (!mounted || !context.mounted) return;
              ScaffoldMessenger.of(
                this.context,
              ).showSnackBar(const SnackBar(content: Text('Reply sent')));
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                24,
                12,
                MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              child: FractionallySizedBox(
                heightFactor: 0.92,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: scheme.outlineVariant,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentTicket['subject']?.toString() ??
                                          'Support ticket',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        if (reference != null &&
                                            reference.isNotEmpty)
                                          _pill(
                                            reference,
                                            bg:
                                                theme.brightness ==
                                                    Brightness.dark
                                                ? scheme.primary.withValues(
                                                    alpha: 0.18,
                                                  )
                                                : const Color(0xFFEAF2FF),
                                            fg:
                                                theme.brightness ==
                                                    Brightness.dark
                                                ? scheme.primary
                                                : const Color(0xFF2952CC),
                                          ),
                                        _pill(
                                          status.toUpperCase(),
                                          bg:
                                              theme.brightness ==
                                                  Brightness.dark
                                              ? scheme.primary.withValues(
                                                  alpha: 0.18,
                                                )
                                              : const Color(0xFFEEF2FF),
                                          fg:
                                              theme.brightness ==
                                                  Brightness.dark
                                              ? scheme.primary
                                              : const Color(0xFF4F46E5),
                                        ),
                                        _pill(
                                          priority.toUpperCase(),
                                          bg:
                                              theme.brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFF3A2A14)
                                              : const Color(0xFFFFF4E5),
                                          fg:
                                              theme.brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFFFBBF24)
                                              : const Color(0xFFB45309),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(currentTicket),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                            children: [
                              ...messages.map((message) {
                                final senderRole =
                                    message['sender_role']?.toString() ??
                                    'user';
                                final isAdmin = senderRole == 'admin';
                                final sender = (message['user'] as Map?)
                                    ?.cast<String, dynamic>();
                                return _threadBubble(
                                  name: isAdmin
                                      ? (sender?['name']?.toString() ??
                                            'Support team')
                                      : (sender?['name']?.toString() ?? 'You'),
                                  message: message['message']?.toString() ?? '',
                                  time: _formatTime(
                                    message['created_at']?.toString(),
                                  ),
                                  isAdmin: isAdmin,
                                );
                              }),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            border: Border(
                              top: BorderSide(color: scheme.outlineVariant),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reply',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: replyCtrl,
                                onChanged: (value) => replyDraft = value,
                                maxLines: 4,
                                textInputAction: TextInputAction.newline,
                                decoration: InputDecoration(
                                  hintText: 'Reply to this ticket...',
                                  filled: true,
                                  fillColor: Theme.of(context).cardColor,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide(
                                      color: scheme.outlineVariant,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide(
                                      color: scheme.outlineVariant,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: sending ? null : sendReply,
                                  icon: const Icon(Icons.send_rounded),
                                  label: Text(
                                    sending ? 'Sending...' : 'Send reply',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (updatedTicket == null || !mounted) return;
    final id = (updatedTicket['id'] as num).toInt();
    final index = _tickets.indexWhere(
      (ticket) => ((ticket['id'] as num?)?.toInt() ?? -1) == id,
    );
    if (index < 0) return;
    setState(() {
      _tickets[index] = updatedTicket;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Support'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: theme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: RefreshIndicator(
          onRefresh: _loadTickets,
          child: ListView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 28),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Support tickets',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Raise an issue, track replies, and keep the conversation in one thread.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: scheme.outlineVariant),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 18,
                      offset: Offset(0, 10),
                      color: Color(0x12000000),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Raise a ticket',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _input('Subject', _subjectCtrl),
                    _input('Message', _messageCtrl, maxLines: 4),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _category,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'general',
                                child: Text('General'),
                              ),
                              DropdownMenuItem(
                                value: 'billing',
                                child: Text('Billing'),
                              ),
                              DropdownMenuItem(
                                value: 'account',
                                child: Text('Account'),
                              ),
                              DropdownMenuItem(
                                value: 'content',
                                child: Text('Content'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _category = value ?? 'general'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _priority,
                            decoration: const InputDecoration(
                              labelText: 'Priority',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'low',
                                child: Text('Low'),
                              ),
                              DropdownMenuItem(
                                value: 'normal',
                                child: Text('Normal'),
                              ),
                              DropdownMenuItem(
                                value: 'high',
                                child: Text('High'),
                              ),
                              DropdownMenuItem(
                                value: 'urgent',
                                child: Text('Urgent'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _priority = value ?? 'normal'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submitTicket,
                        child: Text(
                          _submitting ? 'Submitting...' : 'Submit ticket',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Your tickets',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_tickets.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('No tickets yet')),
                )
              else
                ..._tickets.map((t) => _ticketCard(t)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: theme.cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
        ),
      ),
    );
  }

  Widget _ticketCard(Map<String, dynamic> ticket) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reference = ticket['reference']?.toString();
    final subject = ticket['subject']?.toString() ?? '';
    final status = ticket['status']?.toString() ?? '';
    final priority = ticket['priority']?.toString() ?? 'normal';
    final createdAt = ticket['created_at']?.toString();
    final latestReply = _latestReply(ticket);
    final messages = _messagesFor(ticket);

    return GestureDetector(
      onTap: () => _openTicketDetail(ticket),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: const [
            BoxShadow(
              color: Color(0x09000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (reference != null && reference.isNotEmpty)
                  _pill(
                    reference,
                    bg: theme.brightness == Brightness.dark
                        ? scheme.primary.withOpacity(0.18)
                        : const Color(0xFFEFF6FF),
                    fg: theme.brightness == Brightness.dark
                        ? scheme.primary
                        : const Color(0xFF1D4ED8),
                  ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              subject,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                Text(
                  'Status: $status',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Priority: $priority',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${messages.length} message${messages.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (latestReply != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Latest reply: $latestReply',
                  style: TextStyle(fontSize: 12, color: scheme.onSurface),
                ),
              ),
            if (createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _formatTime(createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, {required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _threadBubble({
    required String name,
    required String message,
    required String time,
    required bool isAdmin,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Align(
      alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isAdmin ? theme.cardColor : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(18),
          border: isAdmin ? Border.all(color: scheme.outlineVariant) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: isAdmin ? scheme.onSurface : Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (time.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    time,
                    style: TextStyle(
                      color: isAdmin ? scheme.onSurfaceVariant : Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: isAdmin ? scheme.onSurface : Colors.white,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
