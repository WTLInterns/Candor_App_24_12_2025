import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
import '../services/api_client.dart';
import 'invoice_detail_screen.dart';
import 'invoice_pdf_page.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _invoices = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = context.read<SessionProvider>();
      final agentId = session.agentId!;
      // expects ApiClient().fetchInvoicesForAgent(agentId)
      final data = await ApiClient().fetchInvoicesForAgent(agentId);
      setState(() {
        _invoices = data;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load invoices';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Invoices'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A66C2), Color(0xFF4FA0FF), Color(0xFFE6F3FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: Center(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Placeholder for future search/filter
                      const SizedBox(height: 4),
                      if (_loading && _invoices.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_error != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _error!,
                            style:
                                const TextStyle(color: Colors.redAccent),
                          ),
                        )
                      else if (_invoices.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'No invoices yet. Pull down to refresh or tap + to create one.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _invoices.length,
                          padding: const EdgeInsets.only(top: 8),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                          final inv = _invoices[index];
                          final invoiceNo = inv['invoiceNo']?.toString() ?? '-';
                          final total = (inv['total'] ?? 0).toString();
                          final status = inv['status']?.toString() ?? 'DRAFT';
                          final createdAt = inv['createdAt']?.toString();

                          Color statusColor;
                          switch (status) {
                            case 'PAID':
                              statusColor = const Color(0xFF22C55E);
                              break;
                            case 'SENT':
                              statusColor = const Color(0xFF2F80ED);
                              break;
                            case 'CANCELLED':
                              statusColor = const Color(0xFFEF4444);
                              break;
                            default:
                              statusColor = const Color(0xFFFACC15);
                          }

                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => InvoiceDetailScreen(invoiceId: inv['id'] as String),
                                  ),
                                );
                                _load();
                              },
                              title: Text(
                                invoiceNo,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text('Total: ₹$total'),
                                  if (createdAt != null)
                                    Text(
                                      createdAt,
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                ],
                              ),
                              trailing: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: statusColor.withOpacity(0.7)),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const InvoicePage()),
          );
          // After returning, refresh the list in case a new invoice was created
          _load();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
