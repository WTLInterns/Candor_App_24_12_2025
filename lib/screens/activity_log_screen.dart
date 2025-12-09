import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
import '../services/api_client.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final _api = ApiClient();
  bool _loading = false;
  List<Map<String, dynamic>> _activities = [];
  String? _loadMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = context.read<SessionProvider>();
    if (session.agentId == null) return;
    setState(() {
      _loading = true;
      _loadMessage = null;
    });
    try {
      final data = await _api.fetchActivitiesForAgent(session.agentId!);
      setState(() {
        _activities = data;
        if (_activities.isEmpty) {
          _loadMessage =
              'No activities yet. Tap "Add Activity" to create your first activity.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        // Treat errors as an empty, refreshable state instead of a red error.
        _activities = [];
        _loadMessage =
            'Could not load activities. Pull down to refresh or add a new activity.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openAddOrEdit({Map<String, dynamic>? existing}) async {
    final session = context.read<SessionProvider>();
    if (session.agentId == null) return;

    final formKey = GlobalKey<FormState>();
    String customerName = existing?['customer'] as String? ?? existing?['customerName'] as String? ?? '';
    String activity = existing?['activity'] as String? ?? '';
    String status = (existing?['status'] as String? ?? 'IN_PROGRESS').toUpperCase();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(existing == null ? 'Add Activity' : 'Edit Activity'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: customerName,
                    decoration: const InputDecoration(labelText: 'Customer'),
                    onSaved: (v) => customerName = v?.trim() ?? '',
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: activity,
                    decoration: const InputDecoration(labelText: 'Activity'),
                    maxLines: 3,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    onSaved: (v) => activity = v!.trim(),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                      DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In Progress')),
                      DropdownMenuItem(value: 'SCHEDULED', child: Text('Scheduled')),
                    ],
                    onChanged: (v) {
                      if (v != null) status = v;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                formKey.currentState!.save();
                try {
                  if (existing == null) {
                    await _api.createActivity({
                      'agentId': session.agentId,
                      'customerName': customerName.isEmpty ? null : customerName,
                      'activity': activity,
                      'status': status,
                    });
                  } else {
                    await _api.updateActivity(existing['id'] as String, {
                      'customerName': customerName,
                      'activity': activity,
                      'status': status,
                    });
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                } catch (_) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Failed to save activity')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _load();
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Activity'),
        content: const Text('Are you sure you want to delete this activity?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _api.deleteActivity(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text('Activity Log'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Add Activity'),
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: _loading && _activities.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _activities.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.event_note_outlined,
                                        size: 40,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _loadMessage ??
                                            'No activities yet. Tap "Add Activity" to create your first activity.',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF4B5563),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: _activities.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (ctx, index) {
                                final a = _activities[index];
                                final time = a['time'] as String? ?? '';
                                final customer = a['customer'] as String? ?? a['customerName'] as String? ?? '-';
                                final activity = a['activity'] as String? ?? '';
                                final status = (a['status'] as String? ?? 'IN_PROGRESS').toUpperCase();
                                Color chipColor;
                                if (status == 'COMPLETED') {
                                  chipColor = const Color(0xFF22C55E);
                                } else if (status == 'SCHEDULED') {
                                  chipColor = const Color(0xFFF59E0B);
                                } else {
                                  chipColor = const Color(0xFF0EA5E9);
                                }
                                return Card(
                                  elevation: 0,
                                  color: const Color(0xFFF9FAFB),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    side: BorderSide(
                                      color: const Color(0xFFE5E7EB).withOpacity(0.9),
                                    ),
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      activity,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          'Customer: $customer',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF4B5563),
                                          ),
                                        ),
                                        Text(
                                          'Time: $time',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Wrap(
                                      spacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: chipColor.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            status.replaceAll('_', ' '),
                                            style: TextStyle(
                                              color: chipColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 18),
                                          color: const Color(0xFF4B5563),
                                          onPressed: () => _openAddOrEdit(existing: a),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18),
                                          color: const Color(0xFFDC2626),
                                          onPressed: () => _delete(a['id'] as String),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
