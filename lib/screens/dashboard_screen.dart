import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
import '../services/location_sender.dart';
import 'live_location_screen.dart';
import 'leads_screen.dart';
import 'invoices_list_screen.dart';
import 'invoice_pdf_page.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  GoogleMapController? _mapCtrl;
  LatLng? _current;
  late LocationSender _sender;
  StreamSubscription? _dummy;
  DateTime? _lastUpdate;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionProvider>();
    _sender = LocationSender(
      session.agentId!,
      onUpdate: (pos) {
        setState(() {
          _current = LatLng(pos.latitude, pos.longitude);
          _lastUpdate = DateTime.now();
        });
      },
    );
    _sender.start();
  }

  @override
  void dispose() {
    _dummy?.cancel();
    _sender.stop();
    _mapCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Hello, ${session.agentName ?? ""}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await session.logout();
              if (!mounted) return;
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0052CC), Color(0xFF2F80ED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'FieldForcePro Tracker',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Live Location'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LiveLocationScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_outlined),
              title: const Text('Leads'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LeadsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Invoices'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const InvoicesScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Create Invoice (PDF)'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const InvoicePage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Live tracking is running in the background while this app is open.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Agent Info',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Name: ${session.agentName ?? '-'}'),
                          Text(
                            'Agent ID: ${session.employeeCode ?? session.agentId}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Location Status',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 8),
                          // Additional details are shown below.
                        ],
                      ),
                    ),
                  ),
                  if (_current != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Last Latitude: ${_current!.latitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      'Last Longitude: ${_current!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                  if (_lastUpdate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Last Update: ${_lastUpdate!.toLocal().toString().split(".").first}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4A5568),
                      ),
                    ),
                  ],
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LiveLocationScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Open Live Map'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.96),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 16,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live tracking ON',
                      style: TextStyle(
                        color: Color(0xFF22C55E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Agent ID: ${session.employeeCode ?? session.agentId}',
                      style: const TextStyle(
                        color: Color(0xFF4A5568),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LiveLocationScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Open Live Map'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
