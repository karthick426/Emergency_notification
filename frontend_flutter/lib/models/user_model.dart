import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/constants.dart';

/// Represents a document in `users/{userId}`.
class UserModel {
  final String id;
  final String name;
  final String phone;
  final String role;
  final String? fcmToken;
  final String? emergencyContact;
  final String? bloodType;
  final String? allergies;
  final String? medications;
  final String? hospitalId;
  final bool isAvailable;

  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role, // 'Patient', 'Hospital', or 'Driver'
    this.fcmToken,
    this.emergencyContact,
    this.bloodType,
    this.allergies,
    this.medications,
    this.hospitalId,
    this.isAvailable = false,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return UserModel(
      id: doc.id,
      name: (data['name'] ?? '') as String,
      phone: (data['phone'] ?? '') as String,
      role: (data['role'] ?? AppConstants.rolePatient) as String,
      fcmToken: data['fcmToken'] as String?,
      emergencyContact: data['emergencyContact'] as String?,
      bloodType: data['bloodType'] as String?,
      allergies: data['allergies'] as String?,
      medications: data['medications'] as String?,
      hospitalId: data['hospitalId'] as String?,
      isAvailable: data['isAvailable'] as bool? ?? false,
    );
  }
}

