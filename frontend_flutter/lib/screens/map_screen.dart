import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/hospital_model.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../utils/theme.dart';

/// Map screen using Google Maps.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _currentLocation;
  bool _isLoadingLocation = true;

  List<Polyline> _polylines = [];
  bool _isLoadingRoute = false;
  bool _initialRouteChecked = false;

  List<HospitalModel> _hospitals = [];
  bool _isLoadingHospitals = false;
  String? _selectedState;
  final MapController _mapController = MapController();

  final List<String> _indianStates = [
    'Andaman and Nicobar Islands', 'Andhra Pradesh', 'Arunachal Pradesh', 'Assam',
    'Bihar', 'Chandigarh', 'Chhattisgarh', 'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi', 'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jammu and Kashmir',
    'Jharkhand', 'Karnataka', 'Kerala', 'Ladakh', 'Lakshadweep', 'Madhya Pradesh',
    'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha',
    'Puducherry', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana',
    'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal'
  ];

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialRouteChecked && _currentLocation != null) {
      _checkAndFetchRoute();
    }
  }

  Future<void> _fetchLocation() async {
    try {
      final pos = await context.read<LocationService>().getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(pos.latitude, pos.longitude);
          _isLoadingLocation = false;
        });
        _loadHospitals();
        _checkAndFetchRoute();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadHospitals() async {
    setState(() => _isLoadingHospitals = true);
    try {
      final apiService = context.read<ApiService>();
      if (_selectedState == null) {
        if (_currentLocation != null) {
          _hospitals = await apiService.fetchHospitalsNear(
            _currentLocation!.latitude,
            _currentLocation!.longitude,
            radiusKm: 20.0,
          );
        }
      } else {
        _hospitals = await apiService.fetchHospitalsByState(_selectedState!, limit: 70);
      }
    } catch (e) {
      // Handle error gracefully
    } finally {
      if (mounted) {
        setState(() => _isLoadingHospitals = false);
        // Move the map camera to the new location
        if (_selectedState != null && _hospitals.isNotEmpty) {
          _mapController.move(LatLng(_hospitals.first.latitude, _hospitals.first.longitude), 7.0);
        } else if (_selectedState == null && _currentLocation != null) {
          _mapController.move(_currentLocation!, 14.0);
        }
      }
    }
  }

  Future<void> _checkAndFetchRoute() async {
    if (_initialRouteChecked) return;
    
    final dest = ModalRoute.of(context)?.settings.arguments;
    if (dest != null && _currentLocation != null) {
      _initialRouteChecked = true;
      if (dest is LatLng) {
        _fetchRoute(dest);
      }
    }
  }

  Future<void> _fetchRoute(LatLng destination) async {
    if (_currentLocation == null) return;
    
    setState(() {
      _isLoadingRoute = true;
      _polylines = [];
    });
    
    try {
      final start = _currentLocation!;
      final routeService = context.read<RoutingService>();
      final rawRoute = await routeService.getDrivingRoute(start, destination);

      if (mounted) {
        setState(() {
          _polylines = [
            Polyline(
              points: rawRoute,
              color: AppTheme.primary,
              strokeWidth: 5,
            ),
          ];
        });
        
        // Auto-center on route
        _mapController.move(destination, 14.0);
      }
    } catch (e) {
      // Ignore routing errors silently for map display
    } finally {
      if (mounted) {
        setState(() => _isLoadingRoute = false);
      }
    }
  }

  void _showHospitalDetails(HospitalModel h) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_hospital, color: AppTheme.primary, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      h.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'AVAILABLE BEDS',
                      '${h.availableBeds}/${h.totalBeds}',
                      Icons.bed,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatItem(
                      'ICU BEDS',
                      '${h.icuBeds}',
                      Icons.emergency,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _fetchRoute(LatLng(h.latitude, h.longitude));
                },
                icon: const Icon(Icons.directions),
                label: const Text('GET DIRECTIONS'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocation) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Determining your location...'),
          ],
        ),
      );
    }

    final markers = <Marker>[
      Marker(
        point: _currentLocation!,
        width: 40,
        height: 40,
        child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
      ),
      ..._hospitals.map(
        (h) => Marker(
          point: LatLng(h.latitude, h.longitude),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _showHospitalDetails(h),
            child: const Icon(Icons.location_on, color: Colors.red, size: 35),
          ),
        ),
      ),
    ];

    LatLng mapCenter = _currentLocation ?? const LatLng(20.5937, 78.9629);
    if (_selectedState != null && _hospitals.isNotEmpty) {
       mapCenter = LatLng(_hospitals.first.latitude, _hospitals.first.longitude);
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: mapCenter,
            initialZoom: _selectedState == null ? 14 : 7,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.smart_city_emergency_system',
            ),
            PolylineLayer(polylines: _polylines),
            MarkerLayer(markers: markers),
          ],
        ),
        
        Positioned(
          top: 10,
          left: 10,
          right: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatePicker(),
              if (_selectedState != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Chip(
                    label: Text('State: $_selectedState'),
                    onDeleted: () {
                      setState(() => _selectedState = null);
                      _loadHospitals();
                    },
                  ),
                ),
            ],
          ),
        ),

        if (_isLoadingRoute || _isLoadingHospitals)
          const Positioned(
            top: 60,
            right: 10,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatePicker() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            hint: const Text('Filter by State'),
            value: _selectedState,
            isExpanded: true,
            items: _indianStates.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (val) {
              setState(() {
                _selectedState = val;
              });
              _loadHospitals();
            },
          ),
        ),
      ),
    );
  }
}
