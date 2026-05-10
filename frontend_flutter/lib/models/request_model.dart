import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/constants.dart';

/// Represents an emergency request created by a user.
class RequestModel {
  final String id;
  final String userId;
  final String? hospitalId;
  final String? ambulanceId;
  final String status;
  final DateTime timestamp;

  final double? userLatitude;
  final double? userLongitude;
  final String? message; // optional voice/text note
  final Map<String, dynamic>? medicalInfo;

  const RequestModel({
    required this.id,
    required this.userId,
    required this.hospitalId,
    required this.ambulanceId,
    required this.status,
    required this.timestamp,
    required this.userLatitude,
    required this.userLongitude,
    required this.message,
    this.medicalInfo,
  });

  factory RequestModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final location = data['userLocation'] as Map<String, dynamic>? ?? <String, dynamic>{};

    final ts = data['timestamp'];
    final timestamp = ts is Timestamp ? ts.toDate() : DateTime.fromMillisecondsSinceEpoch(0);

    final latVal = location['latitude'] ?? location['lat'];
    final lngVal = location['longitude'] ?? location['lng'];

    return RequestModel(
      id: doc.id,
      userId: (data['userId'] ?? '') as String,
      hospitalId: (data['hospitalId'] ?? data['hospital']) as String?,
      ambulanceId: (data['ambulanceId']) as String?,
      status: (data['status'] ?? AppConstants.requestPending) as String,
      timestamp: timestamp,
      userLatitude: latVal == null ? null : (latVal as num).toDouble(),
      userLongitude: lngVal == null ? null : (lngVal as num).toDouble(),
      message: (data['message']) as String?,
      medicalInfo: data['medicalInfo'] as Map<String, dynamic>?,
    );
  }
}

