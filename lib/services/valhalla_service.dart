import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ValhallaService {
  static const String _baseUrl = "http://192.168.29.124:8002";
  static List<String> _maneuvers = [];

  // Fetch route from Valhalla API
  static Future<List<LatLng>?> getRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    final url = Uri.parse("$_baseUrl/route");
    final body = jsonEncode({
      "locations": [
        {"lat": start.latitude, "lon": start.longitude},
        {"lat": end.latitude, "lon": end.longitude}
      ],
      "costing": "pedestrian",
      "directions_options": {"units": "km"}
    });

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Decode the polyline into LatLng coordinates
        final coordinates = decodePolyline(data["trip"]["legs"][0]["shape"]);

        // Extract maneuver instructions
        _maneuvers = data["trip"]["legs"][0]["maneuvers"]
            .map<String>((maneuver) => maneuver["instruction"] as String)
            .toList();

        return coordinates;
      } else {
        print("Failed to fetch route: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error fetching route: $e");
      return null;
    }
  }

  // Decode Valhalla polyline into LatLng list
  static List<LatLng> decodePolyline(String encoded) {
    List<LatLng> coordinates = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int deltaLat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += deltaLat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int deltaLng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += deltaLng;

      coordinates.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return coordinates;
  }

  static List<String> getManeuvers() => _maneuvers;
}
