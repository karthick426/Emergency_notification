import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Handles permission checks and location lookup.
class LocationService {
  Future<Position>? _pendingPosition;

  Future<Position> getCurrentPosition() {
    if (_pendingPosition != null) {
      return _pendingPosition!;
    }
    
    _pendingPosition = _getCurrentPositionInternal().timeout(
      const Duration(seconds: 25),
      onTimeout: () => throw Exception('Location request timed out. Please ensure GPS is enabled and you have a clear view of the sky.'),
    );
    
    _pendingPosition!.whenComplete(() {
      Future.delayed(const Duration(seconds: 10), () {
        _pendingPosition = null;
      });
    });
    
    return _pendingPosition!;
  }

  Future<Position> _getCurrentPositionInternal() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // On some devices, we might want to prompt the user to enable it, but for now we throw.
      throw Exception('Location services are disabled on this device.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions were denied by the user.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied. Please enable them in system settings.');
    }

    // getLastKnownPosition is not supported on web
    Position? lastKnown;
    if (!kIsWeb) {
      try {
        lastKnown = await Geolocator.getLastKnownPosition();
      } catch (_) {}
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: kIsWeb ? null : const Duration(seconds: 20),
        ),
      );
    } catch (e) {
      if (lastKnown != null) {
        return lastKnown;
      }
      rethrow;
    }
  }
}

