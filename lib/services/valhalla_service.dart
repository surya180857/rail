import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ValhallaService {
  static const String baseUrl = "https://valhalla-server-url";

  static Future<List<LatLng>> getRoute(LatLng origin, LatLng destination) async {
    final response = await http.get(Uri.parse(
        "$baseUrl/route?json={'locations':[{'lat':${origin.latitude},'lon':${origin.longitude}},{'lat':${destination.latitude},'lon':${destination.longitude}}],'costing':'pedestrian'}"));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<LatLng> route = [];
      for (var point in data['trip']['legs'][0]['shape']) {
        route.add(LatLng(point['lat'], point['lon']));
      }
      return route;
    }
    return [];
  }
}
