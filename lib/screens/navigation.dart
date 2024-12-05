import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:http/http.dart' as http;

class NavigationScreen extends StatefulWidget {
  @override
  _NavigationScreenState createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  MapController? _osmMapController;

  // Predefined destinations
  final Map<String, GeoPoint> _destinations = {
    'Platform 1': GeoPoint(latitude: 17.433339, longitude: 78.501021),
    'Platform 2': GeoPoint(latitude: 17.433410, longitude: 78.501992),
    'Exit Gate': GeoPoint(latitude: 17.432642, longitude: 78.502781),
    'Ticket Counter': GeoPoint(latitude: 17.432929, longitude: 78.503478),
  };

  String? _selectedDestination;
  bool _isNavigating = false;

  List<Map<String, String>> _maneuvers = [];
  int _currentManeuverIndex = 0;
  bool _navigationComplete = false;

  GeoPoint? _currentLocationMarker;

  @override
  void initState() {
    super.initState();
    _initializeMapController();
  }

  void _initializeMapController() async {
    // Initialize the MapController to track the user
    _osmMapController = MapController(
      initMapWithUserPosition: UserTrackingOption(enableTracking: true),
    );

    // Start updating the location marker and zooming to location
    await Future.delayed(Duration(seconds: 1)); // Wait for the map to initialize
    _zoomToUserLocation();
    _startLiveMarkerUpdate();
  }

  Future<void> _zoomToUserLocation() async {
    final userLocation = await _osmMapController?.myLocation();
    if (userLocation != null) {
      await _osmMapController?.changeLocation(
        GeoPoint(
          latitude: userLocation.latitude,
          longitude: userLocation.longitude,
        ),
      );

      // Apply zoom level to center on the user's location
      await _osmMapController?.setZoom(zoomLevel: 18.0);
    }
  }

  void _startLiveMarkerUpdate() {
    Future.doWhile(() async {
      if (_osmMapController != null) {
        await _updateUserLocationMarker();
      }
      await Future.delayed(Duration(seconds: 2));
      return mounted;
    });
  }

  Future<void> _updateUserLocationMarker() async {
    final currentLocation = await _osmMapController?.myLocation();
    if (currentLocation != null) {
      if (_currentLocationMarker != null) {
        await _osmMapController?.removeMarker(_currentLocationMarker!);
      }

      setState(() {
        _currentLocationMarker = GeoPoint(
          latitude: currentLocation.latitude,
          longitude: currentLocation.longitude,
        );
      });

      await _osmMapController?.addMarker(
        _currentLocationMarker!,
      );
    }
  }


  Future<void> _startNavigation() async {
    if (_selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select a destination.")),
      );
      return;
    }

    final endPoint = _destinations[_selectedDestination!]!;
    final userLocation = await _osmMapController?.myLocation();

    if (userLocation != null) {
      try {
        final response = await _fetchValhallaRoute(
          userLocation.latitude,
          userLocation.longitude,
          endPoint.latitude,
          endPoint.longitude,
        );

        final maneuvers = response['maneuvers'] as List;
        final polyline = response['geometry'] as String;

        setState(() {
          _maneuvers = maneuvers.map((m) {
            return {
              'instruction': m['instruction'].toString(),
              'type': m['type'].toString(),
            };
          }).toList();
          _isNavigating = true;
          _currentManeuverIndex = 0;
        });

        await _drawRoutePolyline(polyline);
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error starting navigation: $error")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Unable to get your current location.")),
      );
    }
  }

  Future<Map<String, dynamic>> _fetchValhallaRoute(
      double startLat, double startLng, double endLat, double endLng) async {
    final valhallaUrl = 'http://192.168.29.124:8002/route';

    final body = {
      "locations": [
        {"lat": startLat, "lon": startLng},
        {"lat": endLat, "lon": endLng}
      ],
      "costing": "pedestrian",
      "directions_options": {"units": "meters"}
    };

    final response = await http.post(
      Uri.parse(valhallaUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'maneuvers': data['trip']['legs'][0]['maneuvers'],
        'geometry': data['trip']['legs'][0]['shape'],
      };
    } else {
      throw Exception("Failed to fetch route: ${response.body}");
    }
  }

  Future<void> _drawRoutePolyline(String encodedPolyline) async {
    final decodedPolyline = _decodePolyline(encodedPolyline);

    for (int i = 0; i < decodedPolyline.length - 1; i++) {
      await _osmMapController?.drawRoad(
        decodedPolyline[i],
        decodedPolyline[i + 1],
        roadType: RoadType.foot,
      );
    }
  }

  List<GeoPoint> _decodePolyline(String encoded) {
    final points = <GeoPoint>[];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(GeoPoint(
        latitude: lat / 1E5,
        longitude: lng / 1E5,
      ));
    }
    return points;
  }

  Widget _getManeuverWidget(String instruction, String maneuverType) {
    IconData icon;
    switch (maneuverType) {
      case 'turn_left':
        icon = Icons.turn_left;
        break;
      case 'turn_right':
        icon = Icons.turn_right;
        break;
      case 'continue':
        icon = Icons.straight;
        break;
      case 'arrive':
        icon = Icons.flag;
        break;
      default:
        icon = Icons.directions;
    }
    return Row(
      children: [
        Icon(icon, color: Colors.blue),
        SizedBox(width: 8),
        Expanded(child: Text(instruction)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Navigation')),
      body: Column(
        children: [
          if (!_isNavigating)
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
          if (!_isNavigating)
            ElevatedButton(
              onPressed: _startNavigation,
              child: Text('Start Navigation'),
            ),
          Expanded(
            child: _osmMapController == null
                ? Center(child: CircularProgressIndicator())
                : OSMFlutter(
              controller: _osmMapController!,
              osmOption: OSMOption(
                zoomOption: ZoomOption(maxZoomLevel: 18, minZoomLevel: 3),
                showDefaultInfoWindow: true,
              ),
            ),
          ),
          if (_isNavigating && _currentManeuverIndex < _maneuvers.length)
            _getManeuverWidget(
              _maneuvers[_currentManeuverIndex]['instruction']!,
              _maneuvers[_currentManeuverIndex]['type']!,
            ),
          if (_navigationComplete)
            Text('You have reached your destination!'),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _osmMapController?.dispose();
    super.dispose();
  }
}
