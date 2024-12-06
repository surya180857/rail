import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:polyline_codec/polyline_codec.dart'; // For polyline decoding
import 'package:location/location.dart'; // For user location

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  _NavigationScreenState createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final MapController _mapController = MapController();

  // Polyline points
  List<LatLng> _polylinePoints = [];

  // Valhalla API URL
  final String _valhallaUrl = 'http://192.168.29.124:8002/route';

  // Predefined destinations
  final Map<String, LatLng> _destinations = {
    'Platform 1': LatLng(17.433339, 78.501021),
    'Platform 2': LatLng(17.433410, 78.501992),
    'Exit Gate': LatLng(17.432642, 78.502781),
  };

  String? _selectedDestination;
  LocationData? _currentLocation;
  List<Map<String, String>> _maneuvers = [];
  bool _isNavigating = false;
  bool _navigationComplete = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // Get the user's current location on initialization
  }

  // Function to get the user's current location
  Future<void> _getCurrentLocation() async {
    final Location location = Location();
    try {
      final LocationData currentLocation = await location.getLocation();
      setState(() {
        _currentLocation = currentLocation;
      });
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  // Function to fetch route data from Valhalla
  Future<void> _fetchRouteFromValhalla() async {
    if (_currentLocation == null || _selectedDestination == null) return;

    final requestBody = jsonEncode({
      "locations": [
        {"lat": _currentLocation!.latitude, "lon": _currentLocation!.longitude},
        {"lat": _destinations[_selectedDestination]!.latitude, "lon": _destinations[_selectedDestination]!.longitude},
      ],
      "costing": "pedestrian",
      "directions_options": {"units": "km"}
    });

    try {
      final response = await http.post(
        Uri.parse(_valhallaUrl),
        headers: {"Content-Type": "application/json"},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final encodedPolyline = data['trip']['legs'][0]['shape'];
        print("Encoded Polyline: $encodedPolyline");

        final decodedPoints = _decodePolyline(encodedPolyline);
        print("Decoded Polyline Points: $decodedPoints");

        setState(() {
          _polylinePoints = decodedPoints; // Update polyline points on the map
          _maneuvers = (data['trip']['legs'][0]['maneuvers'] as List).map((m) {
            return {
              'instruction': m['instruction'].toString(),
              'type': m['type'].toString(),
            };
          }).toList();
          _isNavigating = true;
        });
      } else {
        print("Failed to fetch route: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching route: $e");
    }
  }

  // Function to decode polyline with scaling factor of 10
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    try {
      final decoded = PolylineCodec.decode(encoded);
      points = decoded.map((point) {
        // Each point is a List<num>, so we need to extract the latitude and longitude
        double lat = point[0].toDouble() / 10;  // Divide by 10 for your scaling
        double lng = point[1].toDouble() / 10;  // Divide by 10 for your scaling
        return LatLng(lat, lng);
      }).toList();
    } catch (e) {
      print("Error decoding polyline: $e");
    }
    return points;
  }

  // Function to start navigation
  void _startNavigation() {
    if (_selectedDestination == null || _currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a destination and enable location services')));
      return;
    }
    _fetchRouteFromValhalla(); // Fetch the route and start navigation
  }

  // Function to move to the next maneuver
  void _nextManeuver() {
    if (_maneuvers.isNotEmpty) {
      final currentInstruction = _maneuvers.removeAt(0); // Remove and get the first maneuver
      setState(() {
        _isNavigating = _maneuvers.isNotEmpty;
        _navigationComplete = _maneuvers.isEmpty;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Next Step: ${currentInstruction['instruction']}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Navigation')),
      body: Column(
        children: [
          DropdownButton<String>(
            hint: Text('Select Destination'),
            value: _selectedDestination,
            items: _destinations.keys.map((destination) {
              return DropdownMenuItem(
                value: destination,
                child: Text(destination),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedDestination = value;
              });
            },
          ),
          ElevatedButton(
            onPressed: _startNavigation,
            child: Text('Start Navigation'),
          ),
          ElevatedButton(
            onPressed: _nextManeuver,
            child: Text('Next Maneuver'),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: _polylinePoints.isNotEmpty ? _polylinePoints.first : LatLng(17.432916, 78.503333),
                zoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _polylinePoints,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isNavigating) Text('Navigating...'),
          if (_navigationComplete) Text('You have reached your destination!'),
        ],
      ),
    );
  }
}
