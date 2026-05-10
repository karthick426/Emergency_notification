import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

/// Represents a hospital and its live bed availability.
class HospitalModel {
  final String id;
  final String name;
  final String state;

  final double latitude;
  final double longitude;

  final int totalBeds;
  final int availableBeds;
  final int icuBeds;
  final int ventilators;
  final bool hasTraumaCenter;

  const HospitalModel({
    required this.id,
    required this.name,
    this.state = '',
    required this.latitude,
    required this.longitude,
    required this.totalBeds,
    required this.availableBeds,
    required this.icuBeds,
    this.ventilators = 0,
    this.hasTraumaCenter = false,
  });

  factory HospitalModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final location = data['location'] as Map<String, dynamic>? ?? <String, dynamic>{};

    // Support a couple of common field shapes.
    final lat = (location['latitude'] ?? location['lat'] ?? 0) as num;
    final lng = (location['longitude'] ?? location['lng'] ?? 0) as num;

    return HospitalModel(
      id: doc.id,
      name: (data['name'] ?? '') as String,
      state: (data['state'] ?? '') as String,
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      totalBeds: (data['totalBeds'] ?? 0) as int,
      availableBeds: (data['availableBeds'] ?? 0) as int,
      icuBeds: (data['icuBeds'] ?? 0) as int,
      ventilators: (data['ventilators'] ?? 0) as int,
      hasTraumaCenter: (data['hasTraumaCenter'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toMap() {
    final geoFirePoint = GeoFirePoint(GeoPoint(latitude, longitude));
    return {
      'name': name,
      'state': state,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'geoMap': geoFirePoint.data,
      'totalBeds': totalBeds,
      'availableBeds': availableBeds,
      'icuBeds': icuBeds,
      'ventilators': ventilators,
      'hasTraumaCenter': hasTraumaCenter,
    };
  }
}

