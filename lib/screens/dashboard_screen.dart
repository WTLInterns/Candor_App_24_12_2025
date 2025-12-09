import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';

import '../providers/session_provider.dart';
import '../services/api_client.dart';
import 'activity_log_screen.dart';
import 'attendance_work_field_screen.dart';
import 'leads_screen.dart';
import 'main_shell.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int? _leadCount;
  bool _loadingLeads = false;
  int _wonLeads = 0;
  int _openLeads = 0;
  bool _loadingLocation = false;
  String? _locationAddress;
  double? _locationLat;
  double? _locationLng;
  Timer? _locationTimer;
  List<Map<String, dynamic>> _allLeads = [];
  List<String> _availableMonths = [];
  String? _selectedMonth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadLeadCount();
        _loadLiveLocation();
        _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
          if (mounted) {
            _loadLiveLocation();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLeadCount() async {
    final session = context.read<SessionProvider>();
    final agentId = session.agentId;
    if (agentId == null) return;

    setState(() {
      _loadingLeads = true;
    });
    try {
      final leads = await ApiClient().fetchLeadsForAgent(agentId);
      if (!mounted) return;

      _allLeads = leads;

      final now = DateTime.now();
      final List<String> months = [];
      for (int i = 5; i >= 0; i--) {
        final dt = DateTime(now.year, now.month - i, 1);
        final ym = '${dt.year.toString().padLeft(4, '0')}-'
            '${dt.month.toString().padLeft(2, '0')}';
        months.add(ym);
      }

      _availableMonths = months;
      _selectedMonth = months.isNotEmpty ? months.last : null;
      _recomputeLeadStatsForSelectedMonth();

      setState(() {
        _leadCount = leads.length;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _leadCount = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingLeads = false;
        });
      }
    }
  }

  void _recomputeLeadStatsForSelectedMonth() {
    int won = 0;
    int open = 0;

    if (_selectedMonth == null || _allLeads.isEmpty) {
      setState(() {
        _wonLeads = 0;
        _openLeads = 0;
      });
      return;
    }

    for (final lead in _allLeads) {
      final createdRaw = lead['createdAt']?.toString();
      if (createdRaw == null) continue;
      final created = DateTime.tryParse(createdRaw);
      if (created == null) continue;
      final ym = '${created.year.toString().padLeft(4, '0')}-'
          '${created.month.toString().padLeft(2, '0')}';
      if (ym != _selectedMonth) continue;

      final status = (lead['status'] ?? 'NEW').toString();
      if (status == 'CLOSED_WON' || status == 'COMPLETED') {
        won++;
      } else {
        open++;
      }
    }

    setState(() {
      _wonLeads = won;
      _openLeads = open;
    });
  }

  String _formatMonthLabel(String ym) {
    try {
      final dt = DateTime.parse('$ym-01');
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final name = months[dt.month - 1];
      return '$name ${dt.year}';
    } catch (_) {
      return ym;
    }
  }

  Future<void> _loadLiveLocation() async {
    final session = context.read<SessionProvider>();
    final agentId = session.agentId;
    if (agentId == null) return;

    setState(() {
      _loadingLocation = true;
    });

    try {
      final latest = await ApiClient().fetchLatestLocationForAgent(agentId);
      if (!mounted) return;

      if (latest == null || latest['latitude'] == null || latest['longitude'] == null) {
        setState(() {
          _locationAddress = null;
          _locationLat = null;
          _locationLng = null;
        });
        return;
      }

      final lat = (latest['latitude'] as num).toDouble();
      final lng = (latest['longitude'] as num).toDouble();

      List<Placemark> placemarks = [];
      try {
        placemarks = await placemarkFromCoordinates(lat, lng);
      } catch (_) {}

      String address;
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea,
          p.country,
        ].where((e) => e != null && e!.trim().isNotEmpty).map((e) => e!.trim()).toList();
        address = parts.isNotEmpty
            ? parts.join(', ')
            : '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
      } else {
        address = '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
      }

      setState(() {
        _locationLat = lat;
        _locationLng = lng;
        _locationAddress = address;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }
    }
  }

  Widget _buildLeadsDonut() {
    final total = _wonLeads + _openLeads;
    if (total == 0) {
      return const Text(
        'No leads yet. Add leads to see distribution here.',
        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      );
    }

    final wonFraction = _wonLeads / total;

    return Row(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: 1,
                strokeWidth: 10,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFE5EDFF),
                ),
                backgroundColor: Colors.transparent,
              ),
              CircularProgressIndicator(
                value: wonFraction.clamp(0.0, 1.0),
                strokeWidth: 10,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
                backgroundColor: Colors.transparent,
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(wonFraction * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'Won',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Won leads',
                    style: TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                  ),
                  const Spacer(),
                  Text(
                    _wonLeads.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE5EDFF),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Open leads',
                    style: TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                  ),
                  const Spacer(),
                  Text(
                    _openLeads.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: Text('Hello, ${session.agentName ?? "Agent"}'),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: Text(
                            (session.agentName ?? '-')
                                    .trim()
                                    .isNotEmpty
                                ? session.agentName!
                                    .trim()
                                    .substring(0, 1)
                                    .toUpperCase()
                                : '-',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF64748B),
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                session.agentName ?? 'Agent',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF0F172A),
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ID: ${session.employeeCode ?? session.agentId ?? '-'}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF64748B),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 20,
                            color: Color(0xFF0F172A),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Live location',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                if (_loadingLocation)
                                  const Text(
                                    'Fetching latest location…',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  )
                                else if (_locationAddress == null)
                                  const Text(
                                    'No recent location available. Ensure tracking is enabled and the app is active.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  )
                                else
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _locationAddress!,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (_locationLat != null && _locationLng != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Lat: ${_locationLat!.toStringAsFixed(5)}, Lng: ${_locationLng!.toStringAsFixed(5)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.assignment_outlined,
                            size: 20,
                            color: Color(0xFF0F172A),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total leads',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _loadingLeads
                                            ? 'Loading leads...'
                                            : (_leadCount == null
                                                ? 'No data available'
                                                : 'You have $_leadCount leads assigned to you'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: const Color(0xFF64748B),
                                            ),
                                      ),
                                    ),
                                    if (!_loadingLeads && _leadCount != null)
                                      Text(
                                        '${_wonLeads + _openLeads} total',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF0F172A),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Won vs open leads',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (_availableMonths.isNotEmpty)
                          DropdownButton<String>(
                            value: _selectedMonth,
                            underline: const SizedBox.shrink(),
                            iconSize: 20,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                            items: _availableMonths
                                .map(
                                  (m) => DropdownMenuItem<String>(
                                    value: m,
                                    child: Text(_formatMonthLabel(m)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedMonth = value;
                              });
                              _recomputeLeadStatsForSelectedMonth();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildLeadsDonut(),
                    const SizedBox(height: 16),
                    Text(
                      'Quick actions',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionButton(
                            icon: Icons.badge_outlined,
                            label: 'Work from field',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AttendanceWorkFieldScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionButton(
                            icon: Icons.assignment_outlined,
                            label: 'Leads',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const LeadsScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionButton(
                            icon: Icons.event_note_outlined,
                            label: 'Activity log',
                            onTap: () {
                              final shellState =
                                  context.findAncestorStateOfType<MainShellState>();
                              if (shellState != null) {
                                shellState.setTabIndex(4);
                              } else {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ActivityLogScreen(),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
