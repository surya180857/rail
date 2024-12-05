import 'package:flutter/material.dart';
import 'screens/map_screen.dart';
import 'screens/navigation.dart';

void main() {
  runApp(MaterialApp(
    initialRoute: '/map',
    routes: {
      '/map': (context) => MapScreen(),
      '/navigation': (context) => NavigationScreen(), // Ensure this is correct
    },
  ));
}
