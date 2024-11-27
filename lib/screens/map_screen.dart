import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:location/location.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;
  List<LatLng> _routePoints = [];
  List<String> _maneuvers = [];
  Set<Polyline> _polylines = {}; // Set to hold the polyline(s)

  final List<Map<String, dynamic>> _locations = [
    {'name': 'Platform 10', 'lat': 17.432957, 'lon': 78.503130},
    {'name': 'Ticket Counter', 'lat': 17.432936, 'lon': 78.503473},
    {'name': 'Exit Gate', 'lat': 17.432520, 'lon': 78.502775},
  ];

  String? _selectedLocation;
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  Location _location = Location();
  bool _isListening = false;
  bool _isNavigationStarted = false;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(17.432909, 78.503287), // Default location
    zoom: 15,
  );

  // Request location permission
  Future<void> _requestLocationPermission() async {
    var status = await Permission.location.status;
    if (status.isDenied) {
      await Permission.location.request();
    }
  }

  // Fetch the route from Valhalla
  Future<void> _getRoute(LatLng destination) async {
    const String valhallaUrl = "https://valhalla1.openstreetmap.de/route";

    final response = await http.post(
      Uri.parse(valhallaUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        "locations": [
          {"lat": 17.432909, "lon": 78.503287, "type": "break"}, // Starting point
          {"lat": destination.latitude, "lon": destination.longitude, "type": "break"} // Destination
        ],
        "costing": "pedestrian", // Always use pedestrian costing
        "directions_options": {"units": "kilometers"}
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // Parse the route points
      final List<dynamic> shape = data['trip']['legs'][0]['shape'];
      setState(() {
        _routePoints = shape.map((point) {
          return LatLng(point['lat'], point['lon']);
        }).toList();

        // Parse maneuvers (turn-by-turn directions)
        _maneuvers = data['trip']['legs'][0]['maneuvers']
            .map<String>((maneuver) => maneuver['instruction'])
            .toList();
      });

      _drawRoute();
    } else {
      print("Failed to fetch route: ${response.body}");
    }
  }

  // Draw the route on the map
  void _drawRoute() {
    setState(() {
      _polylines.add(Polyline(
        polylineId: const PolylineId("route"),
        points: _routePoints,
        color: Colors.blue,
        width: 5,
      ));
    });
  }

  // Start live navigation (update polyline and maneuvers)
  void _startNavigation() {
    setState(() {
      _isNavigationStarted = true;
    });
    _flutterTts.speak("Starting navigation");

    // Update the user's location while navigating
    _location.onLocationChanged.listen((LocationData currentLocation) {
      _mapController.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(currentLocation.latitude!, currentLocation.longitude!),
          zoom: 15,
        ),
      ));
    });
  }

  // Initialize speech-to-text
  void _initializeSpeech() {
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
  }

  // Start voice recognition for destination
  void _startVoiceRecognition() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() {
        _isListening = true;
      });
      _speech.listen(onResult: (result) {
        setState(() {
          _selectedLocation = result.recognizedWords;
          final destination = _locations.firstWhere((loc) =>
          loc['name'].toLowerCase() == _selectedLocation!.toLowerCase());
          _getRoute(LatLng(destination['lat'], destination['lon']));
        });
      });
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
      appBar: AppBar(
        title: const Text("Google Maps with Valhalla"),
      ),
      body: Column(
        children: [
          // Dropdown for selecting predefined locations
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

          // Google Map widget
          Expanded(
            child: GoogleMap(
              initialCameraPosition: _initialPosition,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              compassEnabled: true,
              polylines: _polylines, // Use the _polylines set here
            ),
          ),

          // Voice command button to select destination
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _startVoiceRecognition,
                child: const Text("Start Voice Command"),
              ),
              if (_isListening) CircularProgressIndicator(),
            ],
          ),

          // Start navigation button
          if (_selectedLocation != null && !_isNavigationStarted)
            ElevatedButton(
              onPressed: _startNavigation,
              child: const Text("Start Navigation"),
            ),

          // List of maneuvers (turn-by-turn directions)
          Expanded(
            child: ListView.builder(
              itemCount: _maneuvers.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_maneuvers[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
