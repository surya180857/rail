import 'dart:convert';
import 'dart:math'; // For sin, cos, atan2, and sqrt
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:location/location.dart';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;
  List<LatLng> _routePoints = [];
  List<String> _maneuvers = [];
  final Set<Polyline> _polylines = {};
  final Location _location = Location();

  final List<Map<String, dynamic>> _locations = [
    {'name': 'Platform 10', 'lat': 17.432957, 'lon': 78.503130},
    {'name': 'Ticket Counter', 'lat': 17.432936, 'lon': 78.503473},
    {'name': 'Exit Gate', 'lat': 17.432520, 'lon': 78.502775},
  ];

  String? _selectedLocation;
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  bool _isNavigationStarted = false;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(17.432909, 78.503287),
    zoom: 15,
  );

  Future<void> _requestLocationPermission() async {
    var status = await Permission.location.status;
    if (status.isDenied) {
      await Permission.location.request();
    }
  }

  Future<void> _getRoute(LatLng destination) async {
    const String valhallaUrl = "https://valhalla1.openstreetmap.de/route";

    try {
      final response = await http.post(
        Uri.parse(valhallaUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "locations": [
            {"lat": 17.432909, "lon": 78.503287, "type": "break"},
            {"lat": destination.latitude, "lon": destination.longitude, "type": "break"}
          ],
          "costing": "pedestrian",
          "directions_options": {"units": "kilometers"}
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final shape = data['trip']['legs'][0]['shape'];
        final maneuvers = data['trip']['legs'][0]['maneuvers'];

        setState(() {
          _routePoints = shape.map<LatLng>((point) {
            return LatLng(point['lat'], point['lon']);
          }).toList();

          _maneuvers = maneuvers.map<String>((m) => m['instruction']).toList();
        });

        _drawRoute();
      } else {
        _flutterTts.speak("Failed to fetch route. Please try again.");
      }
    } catch (e) {
      _flutterTts.speak("An error occurred while fetching the route.");
    }
  }

  void _drawRoute() {
    setState(() {
      _polylines.clear();
      _polylines.add(Polyline(
        polylineId: const PolylineId("route"),
        points: _routePoints,
        color: Colors.blue,
        width: 5,
      ));
    });
  }

  void _startNavigation() {
    if (_routePoints.isEmpty) {
      _flutterTts.speak("Route is not available. Please select a destination.");
      return;
    }

    setState(() {
      _isNavigationStarted = true;
    });

    _flutterTts.speak("Starting navigation. Follow the route.");

    _location.onLocationChanged.listen((LocationData currentLocation) {
      LatLng userLocation = LatLng(currentLocation.latitude!, currentLocation.longitude!);

      // Update camera position to follow user
      _mapController.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: userLocation,
          zoom: 18,
          tilt: 60,
        ),
      ));

      // Provide guidance if the user deviates from the route
      double distance = _calculateDistanceFromRoute(userLocation);
      if (distance > 10) {
        _flutterTts.speak("You are off the route. Please return to the path.");
      }
    });
  }

  double _calculateDistanceFromRoute(LatLng position) {
    // Simplified distance check from the first point on the route
    if (_routePoints.isEmpty) return double.infinity;

    double minDistance = double.infinity;
    for (LatLng point in _routePoints) {
      double distance = _calculateDistance(position, point);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    return minDistance;
  }

  double _calculateDistance(LatLng a, LatLng b) {
    const double earthRadius = 6371000; // Radius of the Earth in meters
    double dLat = (b.latitude - a.latitude) * (pi / 180.0);
    double dLon = (b.longitude - a.longitude) * (pi / 180.0);
    double lat1 = a.latitude * (pi / 180.0);
    double lat2 = b.latitude * (pi / 180.0);

    double aCalc = (sin(dLat / 2) * sin(dLat / 2)) +
        (sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2));
    double c = 2 * atan2(sqrt(aCalc), sqrt(1 - aCalc));
    return earthRadius * c;
  }


  void _initializeSpeech() {
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
  }

  void _startVoiceRecognition() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() {
        _isListening = true;
      });

      _speech.listen(
        onResult: (result) {
          String input = result.recognizedWords.toLowerCase();
          final matchedLocation = _locations.firstWhere(
                (loc) => loc['name'].toLowerCase().contains(input),
            orElse: () => {'name': null, 'lat': null, 'lon': null},
          );

          if (matchedLocation['name'] != null) {
            setState(() {
              _selectedLocation = matchedLocation['name'];
              _getRoute(LatLng(matchedLocation['lat'], matchedLocation['lon']));
            });
          } else {
            _flutterTts.speak("Location not found. Please try again.");
          }
          _speech.stop();
          setState(() {
            _isListening = false;
          });
        },
        listenFor: const Duration(seconds: 10),
      );
    } else {
      _flutterTts.speak("Speech recognition is not available.");
    }
  }


  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _initializeSpeech();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Google Maps with Valhalla")),
      body: Column(
        children: [
          // Destination dropdown
          DropdownButton<String>(
            value: _selectedLocation,
            hint: const Text("Select a Destination"),
            onChanged: (String? newValue) {
              setState(() {
                _selectedLocation = newValue;
                if (_selectedLocation != null) {
                  final destination = _locations.firstWhere((loc) => loc['name'] == _selectedLocation);
                  _getRoute(LatLng(destination['lat'], destination['lon']));
                }
              });
            },
            items: _locations.map<DropdownMenuItem<String>>((location) {
              return DropdownMenuItem<String>(
                value: location['name'],
                child: Text(location['name']),
              );
            }).toList(),
          ),

          // Map view
          Expanded(
            child: GoogleMap(
              initialCameraPosition: _initialPosition,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              compassEnabled: true,
              polylines: _polylines,
            ),
          ),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _startVoiceRecognition,
                child: const Text("Start Voice Command"),
              ),
              const SizedBox(width: 10),
              if (_isListening) const CircularProgressIndicator(),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _startNavigation,
                child: const Text("Start Navigation"),
              ),
            ],
          ),

          // Maneuvers
          if (_maneuvers.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _maneuvers.length,
                itemBuilder: (context, index) {
                  return ListTile(title: Text(_maneuvers[index]));
                },
              ),
            ),
        ],
      ),
    );
  }
}
