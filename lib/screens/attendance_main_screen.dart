import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_error.dart';
import '../core/app_snackbar.dart';
import '../models/attendance_record.dart';
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
          _AttendanceRecordsScreen(),
        ],
      ),
    );
  }
}

class _AttendanceRecordsScreen extends StatefulWidget {
  const _AttendanceRecordsScreen();

  @override
  State<_AttendanceRecordsScreen> createState() =>
      _AttendanceRecordsScreenState();
}

class _AttendanceRecordsScreenState extends State<_AttendanceRecordsScreen> {
  bool _loading = false;
  List<AttendanceRecord> _records = [];
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
      setState(() => _records = []);
      AppSnackbar.showError(context, 'Session expired. Please login again.');
      return;
    }

    setState(() => _loading = true);

    try {
      final ym =
          '${_currentMonth.year.toString().padLeft(4, '0')}-'
          '${_currentMonth.month.toString().padLeft(2, '0')}';

      final data = await ApiClient().fetchMonthlyPunchRecordsTyped(
        agentId: agentId,
        yearMonth: ym,
      );

      if (!mounted) return;

      setState(() => _records = data);
    } on AppError catch (e) {
      AppSnackbar.showError(context, e.message);
      setState(() => _records = []);
    } catch (_) {
      AppSnackbar.showError(context, 'Failed to load attendance records.');
      setState(() => _records = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + delta,
        1,
      );
    });
    _loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel =
        '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}';

    return RefreshIndicator(
      onRefresh: _loadRecords,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// MONTH HEADER
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

          /// LOADING
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          /// EMPTY
          else if (_records.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('No attendance records for this month.'),
              ),
            )
          /// TABLE
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 730),
                child: Column(
                  children: [
                    /// HEADER ROW
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      color: Colors.grey.shade200,
                      child: Row(
                        children: const [
                          _HeaderCell('Date', 110),
                          _HeaderCell('Status', 100),
                          _HeaderCell('Punch In', 120),
                          _HeaderCell('Punch Out', 120),
                          _HeaderCell('Address', 280),
                        ],
                      ),
                    ),

                    /// DATA ROWS
                    ..._records.map((r) {
                      String address = (r.address ?? '').trim();
                      if (address.length > 80) {
                        address = '${address.substring(0, 80)}...';
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.black12),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DataCell(r.date ?? '', 120),

                            _DataCell(r.status ?? '', 100),

                            _DataCell(r.punchInTime ?? '-', 120),

                            _DataCell(r.punchOutTime ?? '-', 120),

                            _AddressCell(address, 280),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// HEADER CELL
class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;

  const _HeaderCell(this.text, this.width);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// DATA CELL
class _DataCell extends StatelessWidget {
  final String text;
  final double width;

  const _DataCell(this.text, this.width);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(text, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// ADDRESS CELL (MAX 2 LINES)
class _AddressCell extends StatelessWidget {
  final String text;
  final double width;

  const _AddressCell(this.text, this.width);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
