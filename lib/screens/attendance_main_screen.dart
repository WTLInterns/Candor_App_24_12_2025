import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
import '../services/api_client.dart';
import 'attendance_work_field_screen.dart';

class AttendanceMainScreen extends StatefulWidget {
  const AttendanceMainScreen({super.key});

  @override
  State<AttendanceMainScreen> createState() => _AttendanceMainScreenState();
}

class _AttendanceMainScreenState extends State<AttendanceMainScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text('Attendance'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Form'),
            Tab(text: 'Records'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AttendanceWorkFieldScreen(),
          _AttendanceRecordsPlaceholder(),
        ],
      ),
    );
  }
}

class _AttendanceRecordsPlaceholder extends StatelessWidget {
  const _AttendanceRecordsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const _AttendanceRecordsScreen();
  }
}

class _AttendanceRecordsScreen extends StatefulWidget {
  const _AttendanceRecordsScreen();

  @override
  State<_AttendanceRecordsScreen> createState() => _AttendanceRecordsScreenState();
}

class _AttendanceRecordsScreenState extends State<_AttendanceRecordsScreen> {
  bool _loading = false;
  List<Map<String, dynamic>> _records = [];
  DateTime _currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final session = context.read<SessionProvider>();
    final agentId = session.agentId;
    if (agentId == null) {
      setState(() {
        _records = [];
      });
      return;
    }

    setState(() {
      _loading = true;
    });
    try {
      final ym = '${_currentMonth.year.toString().padLeft(4, '0')}-'
          '${_currentMonth.month.toString().padLeft(2, '0')}';
      final data = await ApiClient().fetchMonthlyPunchRecords(
        agentId: agentId,
        yearMonth: ym,
      );
      if (!mounted) return;
      setState(() {
        _records = data;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
    });
    _loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}';

    return RefreshIndicator(
      onRefresh: _loadRecords,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeMonth(-1),
              ),
              Column(
                children: [
                  const Text(
                    'Attendance Records',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    monthLabel,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_records.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No attendance records for this month.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ..._records.map((r) {
              final date = r['date']?.toString() ?? '';
              final status = r['status']?.toString() ?? '';
              final punchIn = r['punchInTime']?.toString() ?? '';
              final punchOut = r['punchOutTime']?.toString() ?? '';
              final address = r['address']?.toString() ?? '';
              final imageUrl = r['imageUrl']?.toString();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: imageUrl != null && imageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            '${ApiClient().dio.options.baseUrl}$imageUrl',
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.image_not_supported),
                          ),
                        )
                      : const CircleAvatar(
                          child: Icon(Icons.event_available),
                        ),
                  title: Text(date),
                  subtitle: Text(
                    'Status: $status\nIn: $punchIn   Out: $punchOut'
                    '${address.isNotEmpty ? '\nAddress: $address' : ''}',
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}
