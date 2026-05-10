import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Service to fetch routes from Google Maps Directions API with traffic-aware ETA.
class RoutingService {
  // Pass a valid API key via --dart-define=MAPS_API_KEY="..."
  final String _googleMapsApiKey = const String.fromEnvironment('MAPS_API_KEY', defaultValue: '');

  /// Fetches a driving route and traffic-aware ETA from [start] to [end].
  Future<Map<String, dynamic>?> getRouteWithETA(LatLng start, LatLng end) async {
    if (_googleMapsApiKey.isEmpty) {
      // Fallback to OSRM if no Google Maps API Key is provided
      return _getOsrmRoute(start, end);
    }
    try {
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&departure_time=now&traffic_model=best_guess&key=$_googleMapsApiKey');

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          final polylineStr = route['overview_polyline']['points'];
          final durationSecs = leg['duration_in_traffic'] != null ? leg['duration_in_traffic']['value'] : leg['duration']['value'];

          return {
            'points': _decodePolyline(polylineStr),
            'etaSeconds': durationSecs,
          };
        }
      }
    } catch (e) {
      // Ignore network errors and fallback
    }
    return _getOsrmRoute(start, end);
  }

  Future<List<LatLng>> getDrivingRoute(LatLng start, LatLng end) async {
    final routeData = await getRouteWithETA(start, end);
    return routeData != null ? (routeData['points'] as List<LatLng>) : [];
  }

  Future<Map<String, dynamic>?> _getOsrmRoute(LatLng start, LatLng end) async {
    try {
      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok') {
          final routes = data['routes'] as List;
          if (routes.isNotEmpty) {
            final geometry = routes[0]['geometry'];
            final coordinates = geometry['coordinates'] as List;
            final pts = coordinates
                .map((coord) => LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble()))
                .toList();
            final durationSecs = routes[0]['duration'];
            return {
              'points': pts,
              'etaSeconds': durationSecs,
            };
          }
        }
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polyline.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return polyline;
  }
}
