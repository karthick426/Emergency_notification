import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../models/request_model.dart';
import '../models/hospital_model.dart';
import '../utils/constants.dart';

/// Admin dashboard screen for hospital staff to view incoming SOS emergencies.
class HospitalDashboardScreen extends StatelessWidget {
  final String userId;
  final String? hospitalId;

  const HospitalDashboardScreen({
    super.key,
    required this.userId,
    this.hospitalId,
  });

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirebaseService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospital Live Dashboard', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        backgroundColor: Colors.red.shade900,
        actions: [
          IconButton(
            tooltip: 'Return to Patient Mode',
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () async {
              await context.read<FirebaseService>().getUsersCollection().doc(userId).update({'role': 'Patient'});
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => context.read<AuthService>().signOut(),
          )
        ],
      ),
      body: hospitalId == null
          ? const Center(child: Text('This Admin account has no valid Hospital Binding.', style: TextStyle(color: Colors.red)))
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _FleetStatsWidget(hospitalId: hospitalId!),
                  _InventoryStatsWidget(hospitalId: hospitalId!),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: fs.getRequestsCollection()
                        .where('hospitalId', isEqualTo: hospitalId)
                        .where('status', isEqualTo: AppConstants.requestPending)
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.local_hospital, size: 80, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No active emergencies.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                            ],
                          ),
                        );
                      }

          final requests = snapshot.data!.docs.map((d) => RequestModel.fromFirestore(d)).toList();

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final r = requests[index];
              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 28),
                              const SizedBox(width: 8),
                              Text('SOS ALERT', style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w900, fontSize: 18)),
                            ],
                          ),
                          Text(
                            r.timestamp.toLocal().toString().split('.')[0],
                            style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text('User ID: ${r.userId}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      if (r.message != null && r.message!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.mic, size: 20, color: Colors.orange),
                              const SizedBox(width: 8),
                              Expanded(child: Text('Voice Note: "${r.message}"', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.orange.shade900))),
                            ],
                          ),
                        ),
                      ],
                      if (r.medicalInfo != null) ...[
                        const SizedBox(height: 16),
                        Text('CRITICAL MEDICAL ID', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.bloodtype, size: 18, color: Colors.red),
                            const SizedBox(width: 6),
                            Text('Blood: ${r.medicalInfo!['bloodType'] ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Allergies: ${r.medicalInfo!['allergies'] ?? 'None'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('Meds: ${r.medicalInfo!['medications'] ?? 'None'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse('https://meet.jit.si/SmartCityEmergency_${r.userId}');
                            if (await canLaunchUrl(uri)) await launchUrl(uri);
                          },
                          icon: const Icon(Icons.videocam, color: Colors.blue),
                          label: const Text('Triage via Live WebRTC Video', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blue)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final newAmbId = 'AMB-${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}';
                            
                            fs.getRequestsCollection().doc(r.id).update({
                              'status': AppConstants.requestAccepted,
                              'ambulanceId': newAmbId,
                            });

                            if (r.userLatitude != null && r.userLongitude != null) {
                              double currentLat = r.userLatitude! + 0.012;
                              double currentLng = r.userLongitude! + 0.012;

                              fs.getAmbulancesCollection().doc(newAmbId).set({
                                'driverName': 'Rapid Responder',
                                'status': 'dispatched',
                                'location': { 'latitude': currentLat, 'longitude': currentLng }
                              });

                              // Simulate driving updates!
                              int steps = 25;
                              double latStep = (r.userLatitude! - currentLat) / steps;
                              double lngStep = (r.userLongitude! - currentLng) / steps;

                              for (int i = 1; i <= steps; i++) {
                                Future.delayed(Duration(milliseconds: 1500 * i), () {
                                  fs.getAmbulancesCollection().doc(newAmbId).update({
                                    'location': {
                                      'latitude': currentLat + (latStep * i),
                                      'longitude': currentLng + (lngStep * i),
                                    }
                                  });
                                });
                              }
                            }
                            
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ambulance Dispatched! Live tracking started.')));
                          },
                          icon: const Icon(Icons.local_taxi, size: 24),
                          label: const Text('AUTO-DISPATCH AVAILABLE DRIVER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
                ],
              ),
            ),
    );
  }
}

class _FleetStatsWidget extends StatelessWidget {
  final String hospitalId;
  const _FleetStatsWidget({required this.hospitalId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: context.read<FirebaseService>().getUsersCollection()
          .where('role', isEqualTo: 'Driver')
          .where('hospitalId', isEqualTo: hospitalId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final drivers = snapshot.data!.docs;
        final totalDrivers = drivers.length;
        final availableDrivers = drivers.where((d) => d.data()['isAvailable'] == true).length;
        
        return Container(
          color: Colors.red.shade50,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(label: 'Total Ambulances', value: '$totalDrivers', icon: Icons.local_taxi),
              _StatItem(label: 'Available Drivers', value: '$availableDrivers', icon: Icons.check_circle_outline, color: Colors.green),
            ],
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatItem({required this.label, required this.value, required this.icon, this.color = Colors.black87});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        )
      ],
    );
  }
}

class _InventoryStatsWidget extends StatelessWidget {
  final String hospitalId;
  const _InventoryStatsWidget({required this.hospitalId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: context.read<FirebaseService>().getHospitalsCollection().doc(hospitalId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
        final h = HospitalModel.fromFirestore(snapshot.data!);
        
        return Container(
          color: Colors.blue.shade50,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            children: [
              const Text('Specialized Equipment & Beds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(label: 'ICU', value: '${h.icuBeds}', icon: Icons.bed, color: Colors.blue.shade800),
                  _StatItem(label: 'Vents', value: '${h.ventilators}', icon: Icons.air, color: Colors.teal.shade800),
                  if (h.hasTraumaCenter)
                    const _StatItem(label: 'Trauma', value: 'YES', icon: Icons.health_and_safety, color: Colors.red),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

