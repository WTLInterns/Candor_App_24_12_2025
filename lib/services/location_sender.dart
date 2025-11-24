import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'api_client.dart';

class LocationSender {
  final String agentId;
  final void Function(Position)? onUpdate;
  StreamSubscription<Position>? _sub;

  LocationSender(this.agentId, {this.onUpdate});

  Future<bool> _ensurePermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> start() async {
    final ok = await _ensurePermission();
    if (!ok) return;

    await Geolocator.getCurrentPosition();

    _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) async {
      try {
        onUpdate?.call(pos);
        await ApiClient().sendLocation(
          agentId: agentId,
          lat: pos.latitude,
          lng: pos.longitude,
          accuracy: pos.accuracy,
          speed: pos.speed,
        );
      } catch (_) {
        // ignore network errors for now
      }
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
