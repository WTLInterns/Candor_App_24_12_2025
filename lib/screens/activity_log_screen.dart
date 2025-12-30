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
    String customerName =
        existing?['customer'] as String? ??
        existing?['customerName'] as String? ??
        '';
    String activity = existing?['activity'] as String? ?? '';
    String status = (existing?['status'] as String? ?? 'IN_PROGRESS')
        .toUpperCase();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                    onSaved: (v) => activity = v!.trim(),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(
                        value: 'COMPLETED',
                        child: Text('Completed'),
                      ),
                      DropdownMenuItem(
                        value: 'IN_PROGRESS',
                        child: Text('In Progress'),
                      ),
                      DropdownMenuItem(
                        value: 'SCHEDULED',
                        child: Text('Scheduled'),
                      ),
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
                      'customerName': customerName.isEmpty
                          ? null
                          : customerName,
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
        backgroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text('Activity Log'),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0D1B2A),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddOrEdit(),
        backgroundColor: const Color(0xFF0052CC),
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'Add Activity',
          style: TextStyle(fontWeight: FontWeight.w600),
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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
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
                              padding: const EdgeInsets.symmetric(vertical: 48),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFF0F4F8),
                                    ),
                                    child: const Icon(
                                      Icons.event_note_outlined,
                                      size: 32,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _loadMessage ?? 'No activities yet',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0D1B2A),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap "Add Activity" to create your first activity',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _activities.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (ctx, index) {
                            final a = _activities[index];
                            final time = a['time'] as String? ?? '';
                            final customer =
                                a['customer'] as String? ??
                                a['customerName'] as String? ??
                                '-';
                            final activity = a['activity'] as String? ?? '';
                            final status =
                                (a['status'] as String? ?? 'IN_PROGRESS')
                                    .toUpperCase();

                            Color statusColor;
                            IconData statusIcon;
                            if (status == 'COMPLETED') {
                              statusColor = const Color(0xFF22C55E);
                              statusIcon = Icons.check_circle;
                            } else if (status == 'SCHEDULED') {
                              statusColor = const Color(0xFFF59E0B);
                              statusIcon = Icons.schedule;
                            } else {
                              statusColor = const Color(0xFF0EA5E9);
                              statusIcon = Icons.hourglass_bottom;
                            }

                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.white,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: statusColor.withOpacity(0.12),
                                        ),
                                        child: Icon(
                                          statusIcon,
                                          size: 20,
                                          color: statusColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              activity,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                                color: Color(0xFF0D1B2A),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              customer,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF64748B),
                                                fontWeight: FontWeight.w500,
                                              ),
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
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: statusColor.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          status.replaceAll('_', ' '),
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        time,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                        ),
                                        color: const Color(0xFF0052CC),
                                        onPressed: () =>
                                            _openAddOrEdit(existing: a),
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
                                            _delete(a['id'] as String),
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
