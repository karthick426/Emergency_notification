import 'dart:math';

/// Shared constants used across the app.
///
/// Includes Firestore collection names, user roles, request status values,
/// and a distance helper used to sort hospitals/ambulances by proximity.
class AppConstants {
  // Firestore collections
  static const String usersCollection = 'users';
  static const String hospitalsCollection = 'hospitals';
  static const String ambulancesCollection = 'ambulances';
  static const String requestsCollection = 'requests';

  // User roles
  static const String rolePatient = 'patient';
  static const String roleHospital = 'hospital';
  static const String roleAdmin = 'admin';

  // Request statuses
  static const String requestPending = 'pending';
  static const String requestAccepted = 'accepted';
  static const String requestCompleted = 'completed';

  /// Computes the distance between two lat/lng points using the haversine formula.
  /// Returns kilometers.
  static double haversineDistanceKm({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(endLat - startLat);
    final dLng = _degToRad(endLng - startLng);

    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_degToRad(startLat)) * cos(_degToRad(endLat)) * (sin(dLng / 2) * sin(dLng / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (3.141592653589793 / 180.0);
}

