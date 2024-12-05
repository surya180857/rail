// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railway_navigation_app/screens/map_screen.dart';

void main() {
  testWidgets('Test navigation app widgets', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MaterialApp(
      home: MapScreen(),
    ));

    // Verify if 'Select Destination' button exists
    expect(find.text('Select Destination'), findsOneWidget);

    // Verify if 'Start Navigation' button exists
    expect(find.text('Start Navigation'), findsOneWidget);
  });
}


