import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'dashboard_screen.dart';

class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({super.key});

  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  GoogleMapController? _mapCtrl;
  LatLng? _current;
  StreamSubscription<Position>? _positionSub;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  Future<void> _startListening() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    final allowed = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    if (!allowed) return;

    try {
      final first = await Geolocator.getCurrentPosition();
      setState(() {
        _current = LatLng(first.latitude, first.longitude);
      });
      if (_mapCtrl != null) {
        _mapCtrl!.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(first.latitude, first.longitude),
          ),
        );
      }
    } catch (_) {}

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _current = latLng;
      });
      if (_mapCtrl != null) {
        _mapCtrl!.animateCamera(CameraUpdate.newLatLng(latLng));
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _mapCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Location'),
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
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const DashboardScreen(),
                  ),
                  (route) => false,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Live Location'),
              onTap: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(19.0760, 72.8777),
                zoom: 12,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (ctrl) => _mapCtrl = ctrl,
              markers: _current == null
                  ? {}
                  : {
                      Marker(
                        markerId: const MarkerId('me-live'),
                        position: _current!,
                      ),
                    },
            ),
          ),
        ),
      ),
    );
  }
}
