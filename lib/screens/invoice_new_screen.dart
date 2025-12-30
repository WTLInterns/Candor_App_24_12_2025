import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
import '../services/api_client.dart';
import 'invoice_review_screen.dart';

class InvoiceNewScreen extends StatefulWidget {
  const InvoiceNewScreen({super.key});

  @override
  State<InvoiceNewScreen> createState() => _InvoiceNewScreenState();
}

class _InvoiceNewScreenState extends State<InvoiceNewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();

  List<Map<String, dynamic>> _products = [];

  int? _selectedProductId;
  String _productName = '';
  String _productSku = '';
  double _unitPrice = 0;
  int _quantity = 1;
  double _discountPct = 0;
  double _taxPct = 0;

  final List<_InvoiceItem> _items = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final client = ApiClient();
      final res = await client.dio.get('/products');
      final data = res.data as List<dynamic>;
      setState(() {
        _products = data.cast<Map<String, dynamic>>();
      });
    } catch (_) {
      // ignore errors here; user can still type custom lines later
    }
  }

  double get _lineBase => _unitPrice * _quantity;
  double get _lineDiscountAmt => _lineBase * _discountPct / 100;
  double get _lineTaxable => _lineBase - _lineDiscountAmt;
  double get _lineTaxAmt => _lineTaxable * _taxPct / 100;
  double get _lineTotal => _lineTaxable + _lineTaxAmt;

  double get _subtotal =>
      _items.fold(0.0, (sum, i) => sum + i.unitPrice * i.quantity);
  double get _totalDiscount => _items.fold(0.0, (sum, i) {
    final base = i.unitPrice * i.quantity;
    return sum + base * i.discountPct / 100;
  });
  double get _taxAmount => _items.fold(0.0, (sum, i) {
    final base = i.unitPrice * i.quantity;
    final disc = base * i.discountPct / 100;
    final taxable = base - disc;
    return sum + taxable * i.taxPct / 100;
  });
  double get _shipping => 0;
  double get _total =>
      _items.fold(0.0, (sum, i) => sum + i.lineTotal) + _shipping;

  void _onProductChanged(int? id) {
    setState(() {
      _selectedProductId = id;
    });
    if (id == null) return;
    final p = _products.firstWhere(
      (e) => e['id'] == id,
      orElse: () => <String, dynamic>{},
    );
    if (p.isEmpty) return;
    setState(() {
      _productName = p['name']?.toString() ?? '';
      _productSku = p['sku']?.toString() ?? '';
      _unitPrice = (p['price'] as num?)?.toDouble() ?? 0;
      _quantity = _quantity <= 0 ? 1 : _quantity;
    });
  }

  void _addItem() {
    if (_productName.isEmpty || _unitPrice <= 0 || _quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a product and enter valid quantity'),
        ),
      );
      return;
    }
    setState(() {
      _items.add(
        _InvoiceItem(
          productId: _selectedProductId,
          name: _productName,
          sku: _productSku,
          unitPrice: _unitPrice,
          quantity: _quantity,
          discountPct: _discountPct,
          taxPct: _taxPct,
        ),
      );
      _selectedProductId = null;
      _productName = '';
      _productSku = '';
      _unitPrice = 0;
      _quantity = 1;
      _discountPct = 0;
      _taxPct = 0;
    });
  }

  Future<void> _goToReview() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add at least one item')));
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final session = context.read<SessionProvider>();
      final agentId = session.agentId!;

      final draftItems = _items
          .map(
            (i) => InvoiceDraftItem(
              productId: i.productId,
              name: i.name,
              sku: i.sku,
              unitPrice: i.unitPrice,
              quantity: i.quantity,
              discountPct: i.discountPct,
              taxPct: i.taxPct,
            ),
          )
          .toList();

      final draft = InvoiceDraftData(
        customerName: _customerNameCtrl.text.trim(),
        customerPhone: _customerPhoneCtrl.text.trim(),
        items: draftItems,
        subtotal: _subtotal,
        totalDiscount: _totalDiscount,
        taxAmount: _taxAmount,
        shipping: _shipping,
        total: _total,
        agentId: agentId,
      );

      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => InvoiceReviewScreen(draft: draft)),
      );
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
        title: const Text('New Invoice'),
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
          child: Center(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 520),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customer',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _customerNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Customer Name',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _customerPhoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Customer Phone',
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Add Product',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _selectedProductId,
                        decoration: const InputDecoration(labelText: 'Product'),
                        isExpanded: true,
                        items: _products
                            .map(
                              (p) => DropdownMenuItem<int>(
                                value: p['id'] as int,
                                child: Row(
                                  children: [
                                    if (p['imageUrl'] != null &&
                                        (p['imageUrl'] as String)
                                            .isNotEmpty) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          '${ApiClient().dio.options.baseUrl}${p['imageUrl']}',
                                          width: 28,
                                          height: 28,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Icon(
                                                    Icons.image_not_supported,
                                                    size: 20,
                                                    color: Colors.grey,
                                                  ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: Text(
                                        p['name']?.toString() ?? '-',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _onProductChanged,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Quantity',
                              ),
                              keyboardType: TextInputType.number,
                              initialValue: '1',
                              onChanged: (v) {
                                setState(() {
                                  _quantity = int.tryParse(v) ?? 1;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Discount %',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (v) {
                                setState(() {
                                  _discountPct = double.tryParse(v) ?? 0;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Tax %',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (v) {
                                setState(() {
                                  _taxPct = double.tryParse(v) ?? 0;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Line Total: ₹${_lineTotal.toStringAsFixed(2)}'),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _addItem,
                          child: const Text('Add Item'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_items.isNotEmpty)
                        Card(
                          child: Column(
                            children: [
                              const ListTile(title: Text('Items')),
                              ..._items.map(
                                (i) => ListTile(
                                  title: Text(i.name),
                                  subtitle: Text(
                                    'Qty: ${i.quantity} • ₹${i.unitPrice}',
                                  ),
                                  trailing: Text(
                                    '₹${i.lineTotal.toStringAsFixed(2)}',
                                  ),
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
                              _summaryRow('Subtotal', _subtotal),
                              _summaryRow('Discount', _totalDiscount),
                              _summaryRow('Tax', _taxAmount),
                              const Divider(),
                              _summaryRow('Total', _total, isBold: true),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _goToReview,
                          child: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Review Invoice'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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

class _InvoiceItem {
  final int? productId;
  final String name;
  final String sku;
  final double unitPrice;
  final int quantity;
  final double discountPct;
  final double taxPct;

  _InvoiceItem({
    required this.productId,
    required this.name,
    required this.sku,
    required this.unitPrice,
    required this.quantity,
    required this.discountPct,
    required this.taxPct,
  });

  double get discountAmt => unitPrice * quantity * discountPct / 100;
  double get taxAmt {
    final base = unitPrice * quantity;
    final disc = base * discountPct / 100;
    final taxable = base - disc;
    return taxable * taxPct / 100;
  }

  double get lineTotal => unitPrice * quantity - discountAmt + taxAmt;
}
