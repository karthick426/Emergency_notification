import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/request_model.dart';
import '../models/hospital_model.dart';
import '../utils/constants.dart';
import 'firebase_service.dart';

/// Wraps API operations used by the UI.
class ApiService {
  final FirebaseService firebaseService;

  ApiService({required this.firebaseService});

  Stream<QuerySnapshot<Map<String, dynamic>>> hospitalsStream() {
    return firebaseService.getHospitalsCollection().snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> ambulancesStream() {
    return firebaseService.getAmbulancesCollection().snapshots();
  }

  Future<DocumentReference<Map<String, dynamic>>> createEmergencyRequest({
    required User user,
    required String hospitalId,
    required double userLatitude,
    required double userLongitude,
    String? message,
  }) async {
    final userDoc = await firebaseService.getUsersCollection().doc(user.uid).get();
    final profileData = userDoc.data() ?? {};
    
    return firebaseService.getRequestsCollection().add({
      'userId': user.uid,
      'hospitalId': hospitalId,
      'status': AppConstants.requestPending,
      'timestamp': FieldValue.serverTimestamp(),
      'userLocation': {
        'latitude': userLatitude,
        'longitude': userLongitude,
      },
      if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
      'medicalInfo': {
        'bloodType': profileData['bloodType'] ?? 'Unknown',
        'allergies': profileData['allergies'] ?? 'None disclosed',
        'medications': profileData['medications'] ?? 'None disclosed',
      },
    });
  }

  Future<List<HospitalModel>> fetchHospitalsOnce() async {
    final snapshot = await firebaseService.getHospitalsCollection().limit(100).get();
    return snapshot.docs.map((doc) => HospitalModel.fromFirestore(doc)).toList();
  }

  Future<List<HospitalModel>> fetchHospitalsNear(double lat, double lng, {double radiusKm = 50.0}) async {
    // Basic implementation: fetch all and filter client-side for simplicity,
    // or use geoflutterfire_plus for production geo-queries.
    final snapshot = await firebaseService.getHospitalsCollection().get();
    
    final all = snapshot.docs.map((doc) => HospitalModel.fromFirestore(doc)).toList();
    
    final nearby = all.where((h) {
      final dist = AppConstants.haversineDistanceKm(
        startLat: lat, startLng: lng, endLat: h.latitude, endLng: h.longitude
      );
      return dist <= radiusKm;
    }).toList();

    nearby.sort((a, b) {
      final distA = AppConstants.haversineDistanceKm(
        startLat: lat, startLng: lng, endLat: a.latitude, endLng: a.longitude
      );
      final distB = AppConstants.haversineDistanceKm(
        startLat: lat, startLng: lng, endLat: b.latitude, endLng: b.longitude
      );
      return distA.compareTo(distB);
    });

    return nearby;
  }

  Future<List<HospitalModel>> fetchHospitalsByState(String state, {int limit = 70}) async {
    final snapshot = await firebaseService.getHospitalsCollection()
        .where('state', isEqualTo: state)
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => HospitalModel.fromFirestore(doc)).toList();
  }

  Future<List<RequestModel>> fetchMyRequests() async {
    final uid = firebaseService.auth.currentUser?.uid;
    if (uid == null) return [];
    
    final snapshot = await firebaseService.getRequestsCollection()
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();

    return snapshot.docs
        .map((d) => RequestModel.fromFirestore(d))
        .toList();
  }
}
