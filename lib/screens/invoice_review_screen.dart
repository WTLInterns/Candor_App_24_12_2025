import 'package:flutter/material.dart';

import '../services/api_client.dart';

class InvoiceDraftData {
  final String customerName;
  final String customerPhone;
  final List<InvoiceDraftItem> items;
  final double subtotal;
  final double totalDiscount;
  final double taxAmount;
  final double shipping;
  final double total;
  final String agentId;

  InvoiceDraftData({
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.subtotal,
    required this.totalDiscount,
    required this.taxAmount,
    required this.shipping,
    required this.total,
    required this.agentId,
  });
}

class InvoiceDraftItem {
  final int? productId;
  final String name;
  final String sku;
  final double unitPrice;
  final int quantity;
  final double discountPct;
  final double taxPct;

  InvoiceDraftItem({
    required this.productId,
    required this.name,
    required this.sku,
    required this.unitPrice,
    required this.quantity,
    required this.discountPct,
    required this.taxPct,
  });

  double get base => unitPrice * quantity;
  double get discountAmt => base * discountPct / 100;
  double get taxable => base - discountAmt;
  double get taxAmt => taxable * taxPct / 100;
  double get lineTotal => taxable + taxAmt;
}

class InvoiceReviewScreen extends StatefulWidget {
  final InvoiceDraftData draft;

  const InvoiceReviewScreen({super.key, required this.draft});

  @override
  State<InvoiceReviewScreen> createState() => _InvoiceReviewScreenState();
}

class _InvoiceReviewScreenState extends State<InvoiceReviewScreen> {
  bool _saving = false;

  Future<void> _confirmAndSave() async {
    setState(() {
      _saving = true;
    });
    try {
      final payload = {
        'agentId': widget.draft.agentId,
        'createdBy': widget.draft.agentId,
        'customerId': null,
        'customerSnapshotJson': {
          'name': widget.draft.customerName,
          'phone': widget.draft.customerPhone,
        }.toString(),
        'items': widget.draft.items
            .map(
              (i) => {
                'productId': i.productId,
                'name': i.name,
                'sku': i.sku,
                'unitPrice': i.unitPrice,
                'quantity': i.quantity,
                'discount': i.discountAmt,
                'tax': i.taxAmt,
                'lineTotal': i.lineTotal,
              },
            )
            .toList(),
        'subtotal': widget.draft.subtotal,
        'totalDiscount': widget.draft.totalDiscount,
        'taxAmount': widget.draft.taxAmount,
        'shipping': widget.draft.shipping,
        'total': widget.draft.total,
        'currency': 'INR',
        'status': 'DRAFT',
        'notes': null,
        'invoiceDate': DateTime.now().toUtc().toIso8601String(),
        'dueDate': null,
      };

      await ApiClient().createInvoice(payload);
      if (mounted) {
        Navigator.of(context).pop(true); // pop review
        Navigator.of(context).pop(true); // pop form
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save invoice')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Invoice'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.customerName.isEmpty ? '-' : d.customerName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(d.customerPhone.isEmpty ? '-' : d.customerPhone),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Items',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    title: Text('Products'),
                  ),
                  ...d.items.map(
                    (i) => ListTile(
                      title: Text(i.name),
                      subtitle: Text(
                          'Qty: ${i.quantity} • ₹${i.unitPrice.toStringAsFixed(2)} • Disc: ${i.discountPct.toStringAsFixed(1)}% • Tax: ${i.taxPct.toStringAsFixed(1)}%'),
                      trailing: Text('₹${i.lineTotal.toStringAsFixed(2)}'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _summaryRow('Subtotal', d.subtotal),
                    _summaryRow('Discount', d.totalDiscount),
                    _summaryRow('Tax', d.taxAmount),
                    _summaryRow('Shipping', d.shipping),
                    const Divider(),
                    _summaryRow('Total', d.total, isBold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _confirmAndSave,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirm & Save Invoice'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: isBold ? FontWeight.w600 : null),
          ),
          Text(
            '₹${value.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: isBold ? FontWeight.w600 : null),
          ),
        ],
      ),
    );
  }
}
