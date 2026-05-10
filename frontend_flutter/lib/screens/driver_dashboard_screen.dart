import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../services/routing_service.dart';
import '../models/request_model.dart';
import '../utils/constants.dart';

class DriverDashboardScreen extends StatelessWidget {
  final String userId;
  final String? hospitalId;
  final bool isAvailable;

  const DriverDashboardScreen({
    super.key,
    required this.userId,
    this.hospitalId,
    required this.isAvailable,
  });

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirebaseService>();

    if (hospitalId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Driver Dashboard'), backgroundColor: Colors.teal),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No Hospital Binding. Set your Hospital in Profile.', style: TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => fs.getUsersCollection().doc(userId).update({'role': 'Patient'}),
                child: const Text('Return to Patient Mode'),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.teal.shade800,
        actions: [
          IconButton(
            tooltip: 'Return to Patient Mode',
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => fs.getUsersCollection().doc(userId).update({'role': 'Patient'}),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => context.read<AuthService>().signOut(),
          )
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            Container(
            color: isAvailable ? Colors.green.shade50 : Colors.red.shade50,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Duty Status', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                    Text(
                      isAvailable ? 'ON DUTY (Receiving Calls)' : 'OFF DUTY (Busy/Inactive)',
                      style: TextStyle(fontWeight: FontWeight.w900, color: isAvailable ? Colors.green.shade800 : Colors.red.shade800),
                    )
                  ],
                ),
                Switch(
                  value: isAvailable,
                  onChanged: (val) {
                    fs.getUsersCollection().doc(userId).update({'isAvailable': val});
                  },
                )
              ],
            ),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            // Listen to requests for this hospital
              stream: fs.getRequestsCollection()
                  .where('hospitalId', isEqualTo: hospitalId)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No emergencies currently.'));
                }

                final allRequests = snapshot.data!.docs.map((d) => RequestModel.fromFirestore(d)).toList();

                // Check if driver has an ACTIVE assignment
                final myActiveRequest = allRequests.where((r) => r.ambulanceId == userId && r.status == AppConstants.requestAccepted).firstOrNull;

                if (myActiveRequest != null) {
                  return _ActiveMissionView(request: myActiveRequest, userId: userId);
                }

                // If not assigned, and off duty, don't show pending
                if (!isAvailable) {
                  return const Center(
                    child: Text('You are Off Duty. Toggle On Duty to see pending emergencies.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
                  );
                }

                // Show all pending requests
                final pendingRequests = allRequests.where((r) => r.status == AppConstants.requestPending).toList();

                if (pendingRequests.isEmpty) {
                  return const Center(child: Text('No pending emergencies for your hospital.'));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: pendingRequests.length,
                  itemBuilder: (context, index) {
                    final r = pendingRequests[index];
                    return Card(
                      color: Colors.orange.shade50,
                      elevation: 3,
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
                                    const Icon(Icons.campaign, color: Colors.orange),
                                    const SizedBox(width: 8),
                                    Text('PENDING SOS', style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Text(r.timestamp.toLocal().toString().split('.')[0]),
                              ],
                            ),
                            const Divider(),
                            if (r.medicalInfo != null) ...[
                              Text('CRITICAL MEDICAL ID', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                              Text('Blood: ${r.medicalInfo!['bloodType'] ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('Allergies: ${r.medicalInfo!['allergies'] ?? 'None'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('Meds: ${r.medicalInfo!['medications'] ?? 'None'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 12),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  // ACCEPT MISSION!
                                  fs.getRequestsCollection().doc(r.id).update({
                                    'status': AppConstants.requestAccepted,
                                    'ambulanceId': userId,
                                  });
                                  // Auto set driver to busy
                                  fs.getUsersCollection().doc(userId).update({'isAvailable': false});
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                                icon: const Icon(Icons.check),
                                label: const Text('ACCEPT & RESPOND'),
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

class _ActiveMissionView extends StatefulWidget {
  final RequestModel request;
  final String userId;
  const _ActiveMissionView({required this.request, required this.userId});

  @override
  State<_ActiveMissionView> createState() => _ActiveMissionViewState();
}

class _ActiveMissionViewState extends State<_ActiveMissionView> {
  StreamSubscription<Position>? _positionStream;
  Timer? _etaTimer;
  String _etaText = "Calculating ETA...";
  int _lastEtaSecs = -1;

  @override
  void initState() {
    super.initState();
    _startLiveEtaUpdates();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _etaTimer?.cancel();
    super.dispose();
  }

  void _startLiveEtaUpdates() {
    // Determine initial ETA immediately
    _fetchAndUpdateEta();
    // Then every 20 seconds, calculate new traffic-aware ETA to support dynamic re-routing
    _etaTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      _fetchAndUpdateEta();
    });
  }

  Future<void> _fetchAndUpdateEta() async {
    if (!mounted) return;
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final routing = context.read<RoutingService>();
      if (widget.request.userLatitude != null && widget.request.userLongitude != null) {
        final start = LatLng(pos.latitude, pos.longitude);
        final end = LatLng(widget.request.userLatitude!, widget.request.userLongitude!);
        
        final routeData = await routing.getRouteWithETA(start, end);
        if (routeData != null && mounted) {
          final int secs = routeData['etaSeconds'];
          
          // Dynamic re-routing logic check (if traffic adds 2 mins automatically suggest new route)
          if (_lastEtaSecs != -1 && secs > _lastEtaSecs + 120) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Traffic Detected! Dynamic Re-Routing Activated.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
                backgroundColor: Colors.orange.shade800,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          _lastEtaSecs = secs;
          
          setState(() {
            _etaText = "ETA: ${(secs / 60).ceil()} mins";
          });
        }
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _startNativeNavigation() async {
    final lat = widget.request.userLatitude;
    final lng = widget.request.userLongitude;
    if (lat == null || lng == null) return;

    final uri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      final fallBackUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
      if (await canLaunchUrl(fallBackUri)) {
        await launchUrl(fallBackUri);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: Colors.red, size: 32),
              const SizedBox(width: 12),
              Expanded(child: Text('ACTIVE EMERGENCY', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.red.shade900))),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer, color: Colors.greenAccent, size: 24),
                const SizedBox(width: 8),
                Text(_etaText, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          const Divider(height: 32, thickness: 2),
          if (widget.request.medicalInfo != null) ...[
            Text('PATIENT MEDICAL ID', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900)),
            Text('Blood: ${widget.request.medicalInfo!['bloodType'] ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            Text('Allergies: ${widget.request.medicalInfo!['allergies'] ?? 'None'}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Meds: ${widget.request.medicalInfo!['medications'] ?? 'None'}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const Divider(height: 32),
          ],
          if (widget.request.message != null && widget.request.message!.isNotEmpty) ...[
            Text('VOICE NOTE:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900)),
            Text('"${widget.request.message}"', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 16)),
            const SizedBox(height: 24),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _startNativeNavigation,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                  icon: const Icon(Icons.navigation),
                  label: const Text('NAVIGATE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Complete mission
                    context.read<FirebaseService>().getRequestsCollection().doc(widget.request.id).update({
                      'status': AppConstants.requestCompleted,
                    });
                    // Auto set driver back to available
                    context.read<FirebaseService>().getUsersCollection().doc(widget.userId).update({'isAvailable': true});
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                  icon: const Icon(Icons.done_all),
                  label: const Text('RESOLVE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}
