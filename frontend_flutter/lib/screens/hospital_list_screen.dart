import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/hospital_model.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../widgets/hospital_card.dart';
import '../utils/theme.dart';
import '../utils/constants.dart';

/// Lists hospitals near the user or filtered by state
class HospitalListScreen extends StatefulWidget {
  const HospitalListScreen({super.key});

  @override
  State<HospitalListScreen> createState() => _HospitalListScreenState();
}

class _HospitalListScreenState extends State<HospitalListScreen> {
  String? _selectedState;
  
  final List<String> _indianStates = [
    'Andaman and Nicobar Islands', 'Andhra Pradesh', 'Arunachal Pradesh', 'Assam',
    'Bihar', 'Chandigarh', 'Chhattisgarh', 'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi', 'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jammu and Kashmir',
    'Jharkhand', 'Karnataka', 'Kerala', 'Ladakh', 'Lakshadweep', 'Madhya Pradesh',
    'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha',
    'Puducherry', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana',
    'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal'
  ];

  double _distanceKm(double userLat, double userLng, HospitalModel hospital) {
    return AppConstants.haversineDistanceKm(
      startLat: userLat,
      startLng: userLng,
      endLat: hospital.latitude,
      endLng: hospital.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationService = context.read<LocationService>();
    final apiService = context.read<ApiService>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('Filter by State'),
                  value: _selectedState,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All States / Nearby'),
                    ),
                    ..._indianStates.map((state) {
                      return DropdownMenuItem<String>(
                        value: state,
                        child: Text(state),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedState = val;
                    });
                  },
                ),
              ),
            ),
          ),
        ),
        
        Expanded(
          child: FutureBuilder(
            future: locationService.getCurrentPosition(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_off_rounded, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'Location Error',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}'.replaceAll('Exception: ', ''),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => setState(() {}),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('RETRY'),
                        )
                      ],
                    ),
                  ),
                );
              }

              final position = snapshot.data!;
              final userLat = position.latitude;
              final userLng = position.longitude;

              final futureCall = _selectedState == null 
                  ? apiService.fetchHospitalsNear(userLat, userLng, radiusKm: 20.0)
                  : apiService.fetchHospitalsByState(_selectedState!, limit: 70);

              return FutureBuilder<List<HospitalModel>>(
                future: futureCall,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snap.hasData || snap.data!.isEmpty) {
                    return const Center(child: Text('No hospitals found.'));
                  }

                  final hospitals = snap.data!;
                  
                  return ListView.builder(
                    itemCount: hospitals.length,
                    itemBuilder: (context, index) {
                      final hospital = hospitals[index];
                      final dist = _distanceKm(userLat, userLng, hospital);
                      return HospitalCard(hospital: hospital, distanceKm: dist);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
