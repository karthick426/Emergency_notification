import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import 'package:telephony/telephony.dart';
import 'package:latlong2/latlong.dart';

import '../models/hospital_model.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../utils/constants.dart';

/// Clean and neat SOS page with a giant pulsing button and functional SMS routing.
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> with SingleTickerProviderStateMixin {
  bool _isSubmitting = false;
  String? _statusMessage;
  bool _isSuccess = false;

  final _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _transcript = '';

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(onStatus: (_) {}, onError: (_) {});
    if (!mounted) return;
    setState(() => _speechAvailable = available);
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) return;

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    setState(() => _transcript = '');

    await _speech.listen(
      onResult: (result) {
        setState(() => _transcript = result.recognizedWords);
      },
      localeId: 'en_US',
    );

    setState(() => _isListening = true);
  }

  double _distanceKm(double userLat, double userLng, HospitalModel hospital) {
    return AppConstants.haversineDistanceKm(
      startLat: userLat,
      startLng: userLng,
      endLat: hospital.latitude,
      endLng: hospital.longitude,
    );
  }

  Future<void> _launchSmsFallback(String phone, String message) async {
    Uri? smsUri;
    if (Platform.isAndroid) {
      smsUri = Uri(
        scheme: 'sms',
        path: phone,
        queryParameters: <String, String>{'body': message},
      );
    } else if (Platform.isIOS) {
      smsUri = Uri.parse('sms:$phone&body=${Uri.encodeComponent(message)}');
    }

    if (smsUri != null && await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    }
  }

  Future<void> _sendEmergencySms(String phone, String message) async {
    if (Platform.isAndroid) {
      final telephony = Telephony.instance;
      final bool? result = await telephony.requestPhoneAndSmsPermissions;
      if (result != null && result) {
        try {
          await telephony.sendSms(to: phone, message: message);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Auto-SMS failed. Opening native app...')),
            );
          }
          await _launchSmsFallback(phone, message);
        }
      } else {
        await _launchSmsFallback(phone, message);
      }
    } else {
      await _launchSmsFallback(phone, message);
    }
  }

  Future<void> _requestEmergency() async {
    final authUser = context.read<FirebaseService>().auth.currentUser;
    if (authUser == null) {
      setState(() => _statusMessage = 'Please login again.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = 'Locating and finding nearest hospital...';
      _isSuccess = false;
    });

    try {
      final locationService = context.read<LocationService>();
      final apiService = context.read<ApiService>();
      final authService = context.read<AuthService>();

      // 1) Fetch user's current location
      final pos = await locationService.getCurrentPosition();

      // 2) Offline Fallback: Dispatch SMS FIRST before network attempts
      final profile = await authService.fetchCurrentUserProfile();
      if (profile != null && profile.emergencyContact != null && profile.emergencyContact!.isNotEmpty) {
        final message = 'EMERGENCY! I need immediate help.\nMy location: https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}';
        await _sendEmergencySms(profile.emergencyContact!, message);
      }

      // 3) Find nearest hospital using geospatial query (Network dependent)
      final hospitals = await apiService.fetchHospitalsNear(pos.latitude, pos.longitude);
      if (hospitals.isEmpty) {
        throw Exception('No hospitals found near you. Ensure hospitals are seeded with geohashes.');
      }

      hospitals.sort((a, b) {
        final da = _distanceKm(pos.latitude, pos.longitude, a);
        final db = _distanceKm(pos.latitude, pos.longitude, b);
        return da.compareTo(db);
      });

      final nearest = hospitals.first;

      setState(() {
         _statusMessage = 'Notifying ${nearest.name}...';
      });

      // 4) Create emergency request in Firestore
      await apiService.createEmergencyRequest(
        user: authUser,
        hospitalId: nearest.id,
        userLatitude: pos.latitude,
        userLongitude: pos.longitude,
        message: _transcript.isNotEmpty ? _transcript : null,
      );


      setState(() {
        _isSuccess = true;
        _statusMessage = 'Emergency request sent successfully to ${nearest.name}!';
      });

      // 5) Auto-navigate to Map Screen
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          Navigator.of(context).pushNamed(
            '/map',
            arguments: LatLng(nearest.latitude, nearest.longitude),
          );
        }
      });
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _statusMessage = 'Failed to request help: ${e.toString().replaceAll('Exception: ', '')}';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 80),
              const SizedBox(height: 16),
              const Text(
                'EMERGENCY HELP',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 8),
              const Text(
                'Press the button below to alert emergency services and your contacts.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 50),
              
              // Simple large SOS button
              SizedBox(
                width: 200,
                height: 200,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _requestEmergency,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 8,
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('SOS', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                ),
              ),
              
              const SizedBox(height: 50),
              
              if (_statusMessage != null)
                Card(
                  color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(_isSuccess ? Icons.check : Icons.error, color: _isSuccess ? Colors.green : Colors.red),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_statusMessage!, style: TextStyle(color: _isSuccess ? Colors.green.shade900 : Colors.red.shade900))),
                      ],
                    ),
                  ),
                ),
                
              const SizedBox(height: 30),
              
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('Add Voice Message', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      IconButton(
                        onPressed: _speechAvailable ? _toggleListening : null,
                        icon: Icon(_isListening ? Icons.stop : Icons.mic),
                        color: _isListening ? Colors.red : Colors.indigo,
                        iconSize: 40,
                      ),
                      if (_transcript.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(_transcript, style: const TextStyle(fontStyle: FontStyle.italic)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
