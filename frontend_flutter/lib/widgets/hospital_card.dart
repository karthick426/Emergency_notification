import 'package:flutter/material.dart';
import '../models/hospital_model.dart';
import '../utils/theme.dart';

class HospitalCard extends StatelessWidget {
  final HospitalModel hospital;
  final double distanceKm;

  const HospitalCard({
    super.key,
    required this.hospital,
    required this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    final isICUAvailable = hospital.icuBeds > 0;
    final availabilityText = '${hospital.availableBeds}/${hospital.totalBeds} beds';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_hospital, color: Colors.indigo, size: 40),
              title: Text(hospital.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text('${hospital.state} • ${distanceKm.toStringAsFixed(1)} km away'),
              trailing: Chip(
                label: Text('ICU: ${hospital.icuBeds}'),
                backgroundColor: hospital.icuBeds > 0 ? Colors.green.shade100 : Colors.red.shade100,
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Available Beds: ${hospital.availableBeds}/${hospital.totalBeds}'),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      '/map',
                      arguments: {'latitude': hospital.latitude, 'longitude': hospital.longitude},
                    );
                  },
                  icon: const Icon(Icons.directions),
                  label: const Text('DIRECTIONS'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(120, 40),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

