import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../utils/constants.dart';

/// Centralizes Firebase instances.
class FirebaseService {
  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
  FirebaseMessaging get messaging => FirebaseMessaging.instance;

  FirebaseService();

  CollectionReference<Map<String, dynamic>> getUsersCollection() {
    return firestore.collection(AppConstants.usersCollection);
  }

  CollectionReference<Map<String, dynamic>> getHospitalsCollection() {
    return firestore.collection(AppConstants.hospitalsCollection);
  }

  CollectionReference<Map<String, dynamic>> getAmbulancesCollection() {
    return firestore.collection(AppConstants.ambulancesCollection);
  }

  CollectionReference<Map<String, dynamic>> getRequestsCollection() {
    return firestore.collection(AppConstants.requestsCollection);
  }
}

