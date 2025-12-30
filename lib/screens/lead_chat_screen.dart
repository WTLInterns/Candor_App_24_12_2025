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
      final created = await ApiClient().postLeadComment(
        widget.leadId,
        text,
        agentName: agentName,
      );
      setState(() {
        _messages.add(created);
        _messageCtrl.clear();
      });
      _scrollToBottomDelayed();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to send message')));
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
        title: Text(widget.title),
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0D1B2A),
        ),
      ),
      body: Container(
        color: const Color(0xFFF5F7FA),
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFE5EDFF),
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline,
                                size: 32,
                                color: Color(0xFF0052CC),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0D1B2A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Start the conversation',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final text = msg['message']?.toString() ?? '';
                        final createdAt = msg['createdAt']?.toString();
                        final source =
                            (msg['source']?.toString().toUpperCase() ?? '');
                        final isAgent = source == 'AGENT' || source.isEmpty;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: isAgent
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 280,
                                ),
                                child: Column(
                                  crossAxisAlignment: isAgent
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: isAgent
                                            ? const Color(0xFF0052CC)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: !isAgent
                                            ? Border.all(
                                                color: const Color(0xFFE5E7EB),
                                              )
                                            : null,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.04,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      child: Text(
                                        text,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isAgent
                                              ? Colors.white
                                              : const Color(0xFF0D1B2A),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (createdAt != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        createdAt,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: const Color(0xFFE5E7EB), width: 1),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageCtrl,
                          decoration: InputDecoration(
                            hintText: 'Type a message…',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(
                                color: Color(0xFF0052CC),
                                width: 1.5,
                              ),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          minLines: 1,
                          maxLines: 3,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _sending
                              ? const Color(0xFFE5EDFF)
                              : const Color(0xFF0052CC),
                        ),
                        child: IconButton(
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF0052CC),
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                          onPressed: _sending ? null : _sendMessage,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
