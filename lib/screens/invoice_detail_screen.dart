import 'package:flutter/material.dart';

import '../services/api_client.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  Map<String, dynamic>? _invoice;
  List<dynamic> _items = [];
  List<dynamic> _audit = [];
  bool _loading = false;
  String? _error;

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
      final data = await ApiClient().fetchInvoiceDetail(widget.invoiceId);
      setState(() {
        _invoice = data['invoice'] as Map<String, dynamic>?;
        _items = (data['items'] as List<dynamic>? ?? []);
        _audit = (data['audit'] as List<dynamic>? ?? []);
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load invoice';
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
        title: const Text('Invoice Detail'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ))
              : _invoice == null
                  ? const Center(child: Text('Invoice not found'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _invoice!['invoiceNo']?.toString() ?? '-',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('Status: ${_invoice!['status']}'),
                          const SizedBox(height: 4),
                          Text('Total: ₹${_invoice!['total'] ?? 0}'),
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Customer Snapshot',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _invoice!['customerSnapshotJson']?.toString() ??
                                        '-',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Items',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),
                                  if (_items.isEmpty)
                                    const Text('No items')
                                  else
                                    Column(
                                      children: _items
                                          .map(
                                            (i) => ListTile(
                                              title: Text(
                                                  i['name']?.toString() ?? '-'),
                                              subtitle: Text(
                                                  'Qty: ${i['quantity']} • ₹${i['unitPrice']}'),
                                              trailing: Text(
                                                  '₹${i['lineTotal'] ?? 0}'),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_audit.isNotEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Audit',
                                      style:
                                          TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 8),
                                    ..._audit.map(
                                      (a) => Padding(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                vertical: 2),
                                        child: Text(
                                          '${a['action']} by ${a['actorId']} at ${a['createdAt']} - ${a['details'] ?? ''}',
                                          style:
                                              const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
    );
  }
}
