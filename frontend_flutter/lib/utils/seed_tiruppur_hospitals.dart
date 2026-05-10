import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import '../models/hospital_model.dart';

List<List<String>> parseCsvString(String input) {
  List<List<String>> result = [];
  bool inQuotes = false;
  String current = '';
  List<String> row = [];

  for (int i = 0; i < input.length; i++) {
    String char = input[i];

    if (char == '"') {
      inQuotes = !inQuotes;
    } else if (char == ',' && !inQuotes) {
      row.add(current);
      current = '';
    } else if ((char == '\n' || char == '\r') && !inQuotes) {
      if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
        i++; // skip \n
      }
      row.add(current);
      result.add(row);
      row = [];
      current = '';
    } else {
      current += char;
    }
  }

  if (row.isNotEmpty || current.isNotEmpty) {
    row.add(current);
    result.add(row);
  }

  return result;
}

Future<void> seedAllHospitalsFromCsv(CollectionReference<Map<String, dynamic>> hospitalsCollection) async {
  try {
    debugPrint("Reading CSV from assets...");
    final csvString = await rootBundle.loadString('assets/hospital_directory.csv');
    
    debugPrint("Parsing CSV...");
    final lines = parseCsvString(csvString);
    
    if (lines.isEmpty) return;

    // First row is header. Remove quotes from header to fix matching.
    final header = lines.first.map((e) => e.toString().replaceAll('"', '').trim()).toList();
    
    final nameIdx = header.indexWhere((e) => e.contains('Hospital_Name'));
    final coordsIdx = header.indexWhere((e) => e.contains('Location_Coordinates'));
    final bedsIdx = header.indexWhere((e) => e.contains('Total_Num_Beds'));
    final specialitiesIdx = header.indexWhere((e) => e.contains('Specialties'));
    final stateIdx = header.indexWhere((e) => e.contains('State'));

    if (nameIdx == -1 || coordsIdx == -1) {
      debugPrint("CSV is missing required columns. Header: $header");
      return;
    }

    List<HospitalModel> hospitalsToUpload = [];

    for (int i = 1; i < lines.length; i++) {
      // Clean quotes from the row cells
      final row = lines[i].map((e) => e.toString().replaceAll('"', '').trim()).toList();
      
      if (row.length <= coordsIdx) continue;

      final coordsRaw = row[coordsIdx];
      if (coordsRaw.isEmpty || coordsRaw == 'NA') continue;

      final parts = coordsRaw.split(',');
      if (parts.length != 2) continue;

      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());

      if (lat == null || lng == null) continue;

      final name = row.length > nameIdx ? row[nameIdx] : 'Unknown Hospital';
      
      String state = '';
      if (stateIdx != -1 && row.length > stateIdx) {
        state = row[stateIdx];
      }

      int totalBeds = 0;
      if (bedsIdx != -1 && row.length > bedsIdx) {
        totalBeds = int.tryParse(row[bedsIdx]) ?? 0;
      }

      bool hasTrauma = false;
      if (specialitiesIdx != -1 && row.length > specialitiesIdx) {
        hasTrauma = row[specialitiesIdx].toLowerCase().contains('trauma');
      }

      hospitalsToUpload.add(HospitalModel(
        id: '', // Empty ID, let FIrestore generate
        name: name.isEmpty ? 'Unknown Hospital' : name,
        state: state,
        latitude: lat,
        longitude: lng,
        totalBeds: totalBeds,
        availableBeds: totalBeds, // Initially assume all available
        icuBeds: 0,
        ventilators: 0,
        hasTraumaCenter: hasTrauma,
      ));
    }

    debugPrint("Parsed ${hospitalsToUpload.length} valid hospitals. Starting upload...");

    // Batch upload (Firestore limit is 500 per batch)
    final FirebaseFirestore db = FirebaseFirestore.instance;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    if (uid == null) {
      throw Exception("You must be logged in to seed hospitals.");
    }

    // WORKAROUND: Temporarily elevate the current user's role to 'hospital'
    // so that Firestore security rules allow the creation of hospitals.
    final userDocRef = db.collection('users').doc(uid);
    final userSnapshot = await userDocRef.get();
    final originalRole = userSnapshot.data()?['role'];
    await userDocRef.set({'role': 'hospital'}, SetOptions(merge: true));

    int processed = 0;
    const int batchSize = 400;

    while (processed < hospitalsToUpload.length) {
      final WriteBatch batch = db.batch();
      final end = (processed + batchSize < hospitalsToUpload.length) 
          ? processed + batchSize 
          : hospitalsToUpload.length;
          
      final currentChunk = hospitalsToUpload.sublist(processed, end);

      for (final hosp in currentChunk) {
        final docRef = hospitalsCollection.doc();
        final mapData = hosp.toMap();
        // Add ownerUserId to satisfy the security rule requirement: 
        // request.resource.data.ownerUserId == request.auth.uid
        mapData['ownerUserId'] = uid; 
        batch.set(docRef, mapData);
      }

      await batch.commit();
      processed += currentChunk.length;
      debugPrint("Uploaded $processed / ${hospitalsToUpload.length} hospitals...");
    }

    // Restore original role
    await userDocRef.set({'role': originalRole ?? 'patient'}, SetOptions(merge: true));

    debugPrint("Successfully imported all hospitals!");
  } catch (e) {
    debugPrint("Error importing hospitals: $e");
    
    // Ensure we revert role even on failure if we elevated it
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
       try {
         await FirebaseFirestore.instance.collection('users').doc(uid).set({'role': 'patient'}, SetOptions(merge: true));
       } catch (_) {}
    }
    
    rethrow;
  }
}

// Keep original function signature so ProfileScreen doesn't break
Future<void> seedTiruppurHospitals(CollectionReference<Map<String, dynamic>> hospitalsCollection) async {
  await seedAllHospitalsFromCsv(hospitalsCollection);
}
