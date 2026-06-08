// =============================================================================
// LocationBeacon (v1.1.2) — periodic GPS heartbeat.
// While the driver is signed in and on duty, this pings the backend with the
// current location every ~15s. The server stores it on the driver and turns
// `is_broadcasting` on only while there's an active out-for-delivery stop, so
// the CUSTOMER sees the driver live on the map during delivery.
// =============================================================================
import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'api/api.dart';

class LocationBeacon {
  LocationBeacon._();
  static final LocationBeacon instance = LocationBeacon._();

  Timer? _timer;
  bool _running = false;

  Future<void> start() async {
    if (_running) return;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return; // no permission → silently skip (nav still works)
      }
    } catch (_) {
      return;
    }
    _running = true;
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
  }

  Future<void> _tick() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 12));
      await DriverApi.instance.sendLocation(pos.latitude, pos.longitude);
    } catch (_) {
      // transient GPS / network error — try again next tick
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }
}
