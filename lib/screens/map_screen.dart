import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {

  static const LatLng _initialPosition = LatLng(17.433446, 78.501080); // Example location
  static const double _initialZoom = 18.0; // Adjust for zoomed-in view

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Google Map (3D View)'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
            },
            initialCameraPosition: CameraPosition(
              target: _initialPosition,
              zoom: _initialZoom,
            ),
            mapType: MapType.normal, // 3D-like map view
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            left: 20,
            bottom: 20,
            child: FloatingActionButton.extended(
              onPressed: () {
                Navigator.pushNamed(context, '/navigation'); // Navigate to OSM Navigation
              },
              label: Text('Start Navigation'),
              icon: Icon(Icons.directions),
            ),
          ),
        ],
      ),
    );
  }
}
