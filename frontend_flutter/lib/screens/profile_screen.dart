import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/request_model.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../utils/delete_hospitals.dart';
import '../utils/seed_tiruppur_hospitals.dart';
import 'hospital_dashboard_screen.dart';
import 'driver_dashboard_screen.dart';

/// Shows the signed-in user's profile and recent emergency requests.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<dynamic> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = context.read<AuthService>().fetchCurrentUserProfile();
  }

  Future<void> _logout(BuildContext context) async {
    final authService = context.read<AuthService>();
    await authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = context.read<FirebaseService>();
    final uid = firebaseService.auth.currentUser?.uid;

    if (uid == null) {
      return const Center(child: Text('Please login.'));
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(uid),
          const SizedBox(height: 16),
          _buildProfileDetails(uid),
          const SizedBox(height: 16),
          _buildActionButtons(context),
          const SizedBox(height: 24),
          const Text(
            'Recent Emergency Requests',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildRequestsList(uid, firebaseService),
        ],
      ),
    );
  }

  Widget _buildHeader(String uid) {
    return FutureBuilder(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(),
          ));
        }
        final profile = snapshot.data;
        if (profile == null) return const SizedBox.shrink();

        return Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.teal.shade50,
              child: const Icon(Icons.person, size: 48, color: Colors.teal),
            ),
            const SizedBox(height: 12),
            Text(
              profile.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              profile.role,
              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileDetails(String uid) {
    return FutureBuilder(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final profile = snapshot.data!;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(Icons.phone_android, 'Phone', profile.phone),
                const Divider(height: 32),
                _EmergencyContactEditor(
                  initialContact: profile.emergencyContact,
                  userId: uid,
                ),
                const Divider(height: 32),
                _MedicalProfileEditor(
                  initialBlood: profile.bloodType,
                  initialAllergies: profile.allergies,
                  initialMedications: profile.medications,
                  userId: uid,
                ),
                if (profile.role == 'Hospital' || profile.role == 'Driver') ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (profile.role == 'Hospital') {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => HospitalDashboardScreen(userId: uid, hospitalId: profile.hospitalId)));
                        } else {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => DriverDashboardScreen(userId: uid, hospitalId: profile.hospitalId, isAvailable: profile.isAvailable ?? false)));
                        }
                      },
                      icon: const Icon(Icons.dashboard),
                      label: const Text('Open My Dashboard'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade900, 
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.teal),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final fs = context.read<FirebaseService>();
                  await deleteAllHospitals(fs.getHospitalsCollection());
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All Hospitals Deleted!')),
                    );
                  }
                },
                icon: const Icon(Icons.delete_forever, color: Colors.red, size: 18),
                label: const Text('Clear Hospitals', style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Importing hospitals...')),
                  );
                  try {
                    final fs = context.read<FirebaseService>();
                    await seedTiruppurHospitals(fs.getHospitalsCollection());
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Import Successful!')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.add_location_alt, size: 18),
                label: const Text('Seed CSV', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRequestsList(String uid, FirebaseService firebaseService) {
    return StreamBuilder(
      stream: firebaseService.getRequestsCollection()
          .where('userId', isEqualTo: uid)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final err = snapshot.error.toString();
          return Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: $err', style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          );
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final requests = snapshot.data!.docs
            .map((d) => RequestModel.fromFirestore(d))
            .toList();
        
        requests.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        if (requests.isEmpty) {
          return const Center(child: Text('No emergency requests yet.', style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final r = requests[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.emergency, color: Colors.red),
                title: Text('Request ${r.id.substring(0, 6)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Status: ${r.status} • ${r.timestamp.toLocal().toString().split('.')[0]}'),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}

class _EmergencyContactEditor extends StatefulWidget {
  final String? initialContact;
  final String userId;

  const _EmergencyContactEditor({required this.initialContact, required this.userId});

  @override
  State<_EmergencyContactEditor> createState() => _EmergencyContactEditorState();
}

class _EmergencyContactEditorState extends State<_EmergencyContactEditor> {
  late TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContact);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveContact() async {
    setState(() => _isSaving = true);
    final fs = context.read<FirebaseService>();
    await fs.getUsersCollection().doc(widget.userId).update({
      'emergencyContact': _controller.text.trim(),
    });
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Emergency Contact Saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Emergency SMS Contact',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: '+91 9876543210',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveContact,
              child: _isSaving 
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Text('Save', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ],
    );
  }
}

class _MedicalProfileEditor extends StatefulWidget {
  final String? initialBlood;
  final String? initialAllergies;
  final String? initialMedications;
  final String userId;

  const _MedicalProfileEditor({
    required this.initialBlood,
    required this.initialAllergies,
    required this.initialMedications,
    required this.userId,
  });

  @override
  State<_MedicalProfileEditor> createState() => _MedicalProfileEditorState();
}

class _MedicalProfileEditorState extends State<_MedicalProfileEditor> {
  late TextEditingController _bloodController;
  late TextEditingController _allergiesController;
  late TextEditingController _medicationsController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _bloodController = TextEditingController(text: widget.initialBlood);
    _allergiesController = TextEditingController(text: widget.initialAllergies);
    _medicationsController = TextEditingController(text: widget.initialMedications);
  }

  @override
  void dispose() {
    _bloodController.dispose();
    _allergiesController.dispose();
    _medicationsController.dispose();
    super.dispose();
  }

  Future<void> _saveMedical() async {
    setState(() => _isSaving = true);
    final fs = context.read<FirebaseService>();
    await fs.getUsersCollection().doc(widget.userId).update({
      'bloodType': _bloodController.text.trim(),
      'allergies': _allergiesController.text.trim(),
      'medications': _medicationsController.text.trim(),
    });
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Medical Profile Saved!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Critical Medical ID',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.teal.shade800),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _bloodController,
          style: const TextStyle(fontSize: 14),
          decoration: const InputDecoration(
            labelText: 'Blood Type (e.g. O+)',
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _allergiesController,
          style: const TextStyle(fontSize: 14),
          decoration: const InputDecoration(
            labelText: 'Known Allergies',
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _medicationsController,
          style: const TextStyle(fontSize: 14),
          decoration: const InputDecoration(
            labelText: 'Current Medications',
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveMedical,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade50, foregroundColor: Colors.teal.shade900),
            icon: _isSaving 
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Icon(Icons.favorite, size: 16),
            label: const Text('Save Medical Info', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
