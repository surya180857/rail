import 'package:flutter/material.dart';
import 'screens/map_screen.dart'; // Import the MapScreen file

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Removes the debug banner
      title: 'Railway Navigation App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MapScreen(), // Set MapScreen as the default screen
    );
  }
}

