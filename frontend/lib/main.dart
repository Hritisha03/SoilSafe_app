import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const SoilSafeApp());
}

class SoilSafeApp extends StatelessWidget {
  const SoilSafeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF2E7D32); // green
    final accent = const Color(0xFF1565C0); // blue

    return MaterialApp(
      title: 'SoilSafe',
      theme: ThemeData(
        primaryColor: primary,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.green).copyWith(secondary: accent),
      ),
      home: const HomeScreen(),
    );
  }
}
