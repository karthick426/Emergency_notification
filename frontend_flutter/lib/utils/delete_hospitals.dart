import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> deleteAllHospitals(CollectionReference<Map<String, dynamic>> hospitalsCollection) async {
  final snapshot = await hospitalsCollection.get();
  for (final doc in snapshot.docs) {
    await doc.reference.delete();
  }
}
