import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:math'; // For math functions like cos, sqrt, and asin
import '../services/valhalla_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;
  late Location _location;
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;

  LatLng _currentPosition = LatLng(17.432759, 17.432759);
  LatLng? _selectedDestination;
  String? _selectedLocation;
  String? _currentManeuver;
  final Set<Polyline> _polylines = {}; // Making this final

  final List<Map<String, dynamic>> _locations = [
    {'name': 'Platform 1', 'lat': 17.433647, 'lon': 78.501739},
    {'name': 'Ticket Counter', 'lat': 17.432932, 'lon': 78.503472},
    {'name': 'Platform 8', 'lat': 17.433098, 'lon': 78.502896},
  ];

  @override
  void initState() {
    super.initState();
    _location = Location();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Railway Navigation App"),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 16),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            compassEnabled: true,
            polylines: _polylines,
          ),
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                DropdownButton<String>(
                  value: _selectedLocation,
                  hint: const Text("Select a Destination"),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedLocation = newValue;
                      if (_selectedLocation != null) {
                        final destination = _locations.firstWhere(
                              (loc) => loc['name'] == _selectedLocation,
                          orElse: () => {'lat': 0.0, 'lon': 0.0, 'name': ''},
                        );

                        if (destination['lat'] != 0.0 && destination['lon'] != 0.0) {
                          _selectedDestination = LatLng(destination['lat'], destination['lon']);
                        }
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
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _selectedDestination == null ? null : _startNavigation,
                  child: const Text("Start Navigation"),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(10),
              color: Colors.white,
              child: Text(
                _currentManeuver ?? "No maneuver data",
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _listenForDestination,
        child: const Icon(Icons.mic),
      ),
    );
  }

  void _listenForDestination() async {
    if (!_speech.isListening) {
      bool available = await _speech.initialize();
      if (available) {
        _speech.listen(
          onResult: (result) {
            String voiceInput = result.recognizedWords;
            setState(() {
              _selectedLocation = _locations
                  .firstWhere(
                    (loc) => loc['name'].toLowerCase() == voiceInput.toLowerCase(),
                orElse: () => {'name': ''},
              )
                  .toString();
              if (_selectedLocation != null) {
                _flutterTts.speak("You selected $_selectedLocation.");
                final destination = _locations.firstWhere((loc) => loc['name'] == _selectedLocation);
                _selectedDestination = LatLng(destination['lat'], destination['lon']);
              } else {
                _flutterTts.speak("Destination not recognized. Please try again.");
              }
            });
          },
          listenFor: Duration(seconds: 5), // Timeout after 5 seconds
          onSoundLevelChange: (level) {
            // Optional: Handle sound level changes if necessary
          },
          pauseFor: Duration(seconds: 1), // Optional: Time to pause before starting to listen again
        );
      }
    }
  }


  void _startNavigation() async {
    if (_selectedDestination != null) {
      // Ensure that route data is fetched
      await _getRoute(_selectedDestination!);
      // Start following the route and polylines
      _followRouteWithManeuvers();
    } else {
      _flutterTts.speak("Please select a destination.");
    }
  }

  Future<void> _getRoute(LatLng destination) async {
    // Ensure you get the correct route from Valhalla service
    final route = await ValhallaService.getRoute(_currentPosition, destination);

    if (route.isNotEmpty) {
      setState(() {
        _polylines.clear(); // Clear previous polylines before adding new ones
        _polylines.add(Polyline(
          polylineId: PolylineId("route"),
          points: route,  // Assuming the route is a list of LatLng points
          color: Colors.blue,
          width: 5,
        ));
      });
    } else {
      _flutterTts.speak("Route not found.");
    }
  }

  void _followRouteWithManeuvers() {
    _location.onLocationChanged.listen((currentLocation) {
      LatLng userPosition = LatLng(currentLocation.latitude!, currentLocation.longitude!);

      // Fetch the next maneuver and check the distance to the next route point
      _getCurrentManeuver(userPosition);

      // Update current position on map
      setState(() {
        _currentPosition = userPosition;
      });

      // Update the camera position to follow the user
      _mapController.animateCamera(CameraUpdate.newLatLng(_currentPosition));
    });
  }


  void _getCurrentManeuver(LatLng userPosition) {
    if (_polylines.isNotEmpty) {
      double distanceToNext = calculateDistance(userPosition, _polylines.first.points[0]);
      if (distanceToNext < 10) {
        setState(() {
          _currentManeuver = "Turn left in 10 meters"; // Placeholder
        });
        _flutterTts.speak(_currentManeuver!);
      }
    }
  }

  double calculateDistance(LatLng start, LatLng end) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((end.latitude - start.latitude) * p) / 2 +
        cos(start.latitude * p) * cos(end.latitude * p) * (1 - cos((end.longitude - start.longitude) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }
}
