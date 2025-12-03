import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
import '../services/api_client.dart';

class LeadChatScreen extends StatefulWidget {
  final String leadId;
  final String title;

  const LeadChatScreen({super.key, required this.leadId, required this.title});

  @override
  State<LeadChatScreen> createState() => _LeadChatScreenState();
}

class _LeadChatScreenState extends State<LeadChatScreen> {
  final _scrollController = ScrollController();
  final _messageCtrl = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _loading = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
    });
    try {
      final data = await ApiClient().fetchLeadComments(widget.leadId);
      setState(() {
        _messages
          ..clear()
          ..addAll(data);
      });
      _scrollToBottomDelayed();
    } catch (_) {
      // ignore errors; show empty state
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
    });
    try {
      final session = context.read<SessionProvider>();
      final agentName = session.agentName ?? '';
      final created = await ApiClient().postLeadComment(widget.leadId, text, agentName: agentName);
      setState(() {
        _messages.add(created);
        _messageCtrl.clear();
      });
      _scrollToBottomDelayed();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  void _scrollToBottomDelayed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat: ${widget.title}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No messages yet. Start the conversation.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final text = msg['message']?.toString() ?? '';
                          final createdAt = msg['createdAt']?.toString();
                          final source = (msg['source']?.toString().toUpperCase() ?? '');
                          final isAgent = source == 'AGENT' || source.isEmpty;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment:
                                  isAgent ? MainAxisAlignment.end : MainAxisAlignment.start,
                              children: [
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 320),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: isAgent
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            text,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isAgent ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          if (createdAt != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              createdAt,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isAgent
                                                    ? Colors.white70
                                                    : Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Write a message…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      minLines: 1,
                      maxLines: 3,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    onPressed: _sending ? null : _sendMessage,
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
