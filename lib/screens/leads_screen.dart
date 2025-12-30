import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
import '../services/api_client.dart';
import 'lead_chat_screen.dart';

class Lead {
  final String? id;
  final String companyName;
  final String phone;
  final String email;
  final String address;
  final String product;
  final int quantity;
  final double amount;
  final String status;
  final String? assignedAgentId;
  final String? source;
  final String? notes;
  final DateTime createdAt;

  Lead({
    this.id,
    required this.companyName,
    required this.phone,
    required this.email,
    required this.address,
    required this.product,
    required this.quantity,
    required this.amount,
    required this.status,
    this.assignedAgentId,
    this.source,
    this.notes,
    required this.createdAt,
  });
}

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  bool _loading = false;
  List<Map<String, dynamic>> _leads = [];
  String _search = '';
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadLeads();
  }

  Future<void> _loadLeads() async {
    setState(() {
      _loading = true;
    });
    try {
      final session = context.read<SessionProvider>();
      final agentId = session.agentId!;
      final leads = await ApiClient().fetchLeadsForAgent(agentId);
      setState(() {
        _leads = leads;
      });
    } catch (e) {
      // On error, keep leads empty and allow pull-to-refresh; UI will show the
      // calm empty state message instead of a red error.
      setState(() {
        _leads = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openLeadForm({Map<String, dynamic>? existing}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return GestureDetector(
          // Tap outside glass card to close
          onTap: () => Navigator.of(ctx).maybePop(),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              color: Colors.black.withOpacity(0.35),
              child: GestureDetector(
                onTap: () {}, // allow taps inside card
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 24,
                      bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 520,
                        maxHeight: MediaQuery.of(ctx).size.height * 0.9,
                      ),
                      child: _LeadFormWrapper(existing: existing),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (result == true) {
      _loadLeads();
    }
  }

  Future<void> _openChat(Map<String, dynamic> lead) async {
    final id = lead['id'] as String?;
    if (id == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return GestureDetector(
          onTap: () => Navigator.of(ctx).maybePop(),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              color: Colors.black.withOpacity(0.35),
              child: GestureDetector(
                onTap: () {},
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 24,
                      bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 520,
                        maxHeight: MediaQuery.of(ctx).size.height * 0.9,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Material(
                          color: Colors.white,
                          child: LeadChatScreen(
                            leadId: id,
                            title: lead['companyName']?.toString() ?? '-',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteLead(String id) async {
    try {
      await ApiClient().deleteLead(id);
      _loadLeads();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete lead')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleLeads = _leads.where((lead) {
      final name = (lead['companyName'] ?? '').toString().toLowerCase();
      final product = (lead['product'] ?? '').toString().toLowerCase();
      final status = (lead['status'] ?? 'NEW').toString();
      final matchesSearch =
          _search.isEmpty ||
          name.contains(_search.toLowerCase()) ||
          product.contains(_search.toLowerCase());
      final matchesStatus = _statusFilter == 'ALL' || status == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text('Leads'),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0D1B2A),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F7FA), Color(0xFFEEF2F8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadLeads,
            child: Center(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 520),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Search Bar
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search leads...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF0F4F8),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF0052CC),
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _search = value.trim();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      // Status Filter Chips
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _StatusChip(
                              label: 'All',
                              code: 'ALL',
                              activeCode: _statusFilter,
                              onSelected: (code) {
                                setState(() => _statusFilter = code);
                              },
                            ),
                            _StatusChip(
                              label: 'New',
                              code: 'NEW',
                              activeCode: _statusFilter,
                              onSelected: (code) {
                                setState(() => _statusFilter = code);
                              },
                            ),
                            _StatusChip(
                              label: 'In Progress',
                              code: 'IN_PROGRESS',
                              activeCode: _statusFilter,
                              onSelected: (code) {
                                setState(() => _statusFilter = code);
                              },
                            ),
                            _StatusChip(
                              label: 'Proposal',
                              code: 'PROPOSAL',
                              activeCode: _statusFilter,
                              onSelected: (code) {
                                setState(() => _statusFilter = code);
                              },
                            ),
                            _StatusChip(
                              label: 'Won',
                              code: 'CLOSED_WON',
                              activeCode: _statusFilter,
                              onSelected: (code) {
                                setState(() => _statusFilter = code);
                              },
                            ),
                            _StatusChip(
                              label: 'Lost',
                              code: 'CLOSED_LOST',
                              activeCode: _statusFilter,
                              onSelected: (code) {
                                setState(() => _statusFilter = code);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Content
                      if (_loading && _leads.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (visibleLeads.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFF0F4F8),
                                  ),
                                  child: const Icon(
                                    Icons.assignment_outlined,
                                    size: 28,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No leads found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0D1B2A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Add a new lead to get started',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: visibleLeads.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final lead = visibleLeads[index];
                            final status = (lead['status'] ?? 'NEW').toString();

                            Color statusColor;
                            IconData statusIcon;
                            switch (status) {
                              case 'CLOSED_WON':
                              case 'COMPLETED':
                                statusColor = const Color(0xFF22C55E);
                                statusIcon = Icons.check_circle;
                                break;
                              case 'PROPOSAL':
                              case 'IN_PROGRESS':
                                statusColor = const Color(0xFFF59E0B);
                                statusIcon = Icons.schedule;
                                break;
                              case 'CLOSED_LOST':
                              case 'CANCELLED':
                                statusColor = const Color(0xFFEF4444);
                                statusIcon = Icons.cancel;
                                break;
                              default:
                                statusColor = const Color(0xFF0EA5E9);
                                statusIcon = Icons.fiber_new;
                            }

                            return GestureDetector(
                              onTap: () => _openLeadForm(existing: lead),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF0052CC),
                                                Color(0xFF2563EB),
                                              ],
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            ((lead['companyName'] ?? '-')
                                                    as String)
                                                .substring(0, 1)
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                lead['companyName'] ?? '-',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                  color: Color(0xFF0D1B2A),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                lead['product'] ?? '-',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF64748B),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(
                                              0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: statusColor.withOpacity(
                                                0.3,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                statusIcon,
                                                size: 12,
                                                color: statusColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                status.replaceAll('_', ' '),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: statusColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.shopping_bag_outlined,
                                                size: 14,
                                                color: Color(0xFF94A3B8),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Qty: ${lead['quantity']?.toString() ?? '-'}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.chat_bubble_outline,
                                            size: 18,
                                          ),
                                          color: const Color(0xFF0052CC),
                                          onPressed: () => _openChat(lead),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                          ),
                                          color: const Color(0xFF0052CC),
                                          onPressed: () =>
                                              _openLeadForm(existing: lead),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                          ),
                                          color: const Color(0xFFDC2626),
                                          onPressed: () =>
                                              _deleteLead(lead['id'] as String),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
        onPressed: () => _openLeadForm(),
        backgroundColor: const Color(0xFF0052CC),
        child: const Icon(Icons.add, size: 24),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final String code;
  final String activeCode;
  final ValueChanged<String> onSelected;

  const _StatusChip({
    required this.label,
    required this.code,
    required this.activeCode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = code == activeCode;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isActive,
        onSelected: (_) => onSelected(code),
        selectedColor: const Color(0xFF0052CC),
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          fontSize: 11,
          color: isActive ? Colors.white : const Color(0xFF0D1B2A),
        ),
        shape: StadiumBorder(
          side: BorderSide(
            color: isActive ? const Color(0xFF0052CC) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
    );
  }
}

class _LeadForm extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _LeadForm({this.existing});

  @override
  State<_LeadForm> createState() => _LeadFormState();
}

class _LeadFormState extends State<_LeadForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _customerCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _quantityCtrl;
  String _status = 'NEW';
  bool _saving = false;
  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic>? _selectedProduct;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _customerCtrl = TextEditingController(text: existing?['companyName'] ?? '');
    _emailCtrl = TextEditingController(text: existing?['email'] ?? '');
    _phoneCtrl = TextEditingController(text: existing?['phone'] ?? '');
    _addressCtrl = TextEditingController(text: existing?['address'] ?? '');
    _quantityCtrl = TextEditingController(
      text: existing?['quantity'] != null
          ? existing!['quantity'].toString()
          : '',
    );
    _status = (existing?['status'] ?? 'NEW').toString();

    _loadProducts();
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _quantityCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final client = ApiClient();
      final res = await client.dio.get('/products');
      final data = res.data as List<dynamic>;
      final products = data.cast<Map<String, dynamic>>();

      setState(() {
        _products = products;
        if (widget.existing != null && widget.existing!['product'] != null) {
          _selectedProduct = _products.firstWhere(
            (p) => p['name'] == widget.existing!['product'],
            orElse: () => <String, dynamic>{},
          );
        }
      });
    } catch (_) {
      // ignore error, user can still type
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
    });
    try {
      final session = context.read<SessionProvider>();
      final agentId = session.agentId!;
      final payload = {
        'companyName': _customerCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'product': _selectedProduct != null
            ? _selectedProduct!['name']?.toString()
            : null,
        'quantity': _quantityCtrl.text.trim().isEmpty
            ? null
            : int.tryParse(_quantityCtrl.text.trim()),
        'amount':
            (_quantityCtrl.text.trim().isEmpty ||
                _selectedProduct?['price'] == null)
            ? null
            : (int.tryParse(_quantityCtrl.text.trim()) ?? 0) *
                  (double.tryParse(_selectedProduct!['price'].toString()) ??
                      0.0),
        'status': _status,
        'assignedAgentId': agentId,
      };

      if (widget.existing == null) {
        await ApiClient().createLead(payload);
      } else {
        await ApiClient().updateLead(widget.existing!['id'] as String, payload);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save lead')));
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
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.existing == null ? 'Add Lead' : 'Edit Lead',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _customerCtrl,
            decoration: const InputDecoration(
              labelText: 'Customer Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Customer name is required'
                : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(
              labelText: 'Phone',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _addressCtrl,
            decoration: const InputDecoration(
              labelText: 'Address',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Map<String, dynamic>>(
            value: _selectedProduct != null && _selectedProduct!.isNotEmpty
                ? _selectedProduct
                : null,
            decoration: const InputDecoration(
              labelText: 'Product',
              prefixIcon: Icon(Icons.shopping_bag_outlined),
            ),
            isExpanded: true,
            items: _products
                .map(
                  (p) => DropdownMenuItem<Map<String, dynamic>>(
                    value: p,
                    child: Row(
                      children: [
                        if (p['imageUrl'] != null &&
                            (p['imageUrl'] as String).isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              '${ApiClient().dio.options.baseUrl}${p['imageUrl']}',
                              width: 28,
                              height: 28,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
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
                        if (p['price'] != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '₹${p['price'].toString()}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedProduct = value;
              });
            },
          ),
          if (_selectedProduct != null &&
              (_selectedProduct!['description'] != null &&
                  _selectedProduct!['description'].toString().isNotEmpty)) ...[
            const SizedBox(height: 6),
            Text(
              _selectedProduct!['description'].toString(),
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _quantityCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    prefixIcon: Icon(Icons.format_list_numbered),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'NEW', child: Text('NEW')),
                    DropdownMenuItem(
                      value: 'CONTACTED',
                      child: Text('CONTACTED'),
                    ),
                    DropdownMenuItem(
                      value: 'QUALIFIED',
                      child: Text('QUALIFIED'),
                    ),
                    DropdownMenuItem(
                      value: 'PROPOSAL',
                      child: Text('PROPOSAL'),
                    ),
                    DropdownMenuItem(
                      value: 'CLOSED_WON',
                      child: Text('CLOSED_WON'),
                    ),
                    DropdownMenuItem(
                      value: 'CLOSED_LOST',
                      child: Text('CLOSED_LOST'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _status = v;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0052CC), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Lead'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadFormWrapper extends StatelessWidget {
  final Map<String, dynamic>? existing;
  const _LeadFormWrapper({this.existing});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: _LeadForm(existing: existing),
          ),
        ),
      ),
    );
  }
}
