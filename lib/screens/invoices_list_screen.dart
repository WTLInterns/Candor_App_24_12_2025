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
      appBar: AppBar(
        title: const Text('Invoices'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && _invoices.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  )
                : _invoices.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 80),
                          Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No invoices yet. Pull down to refresh or tap + to create one.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _invoices.length,
                        padding: const EdgeInsets.all(12),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
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
