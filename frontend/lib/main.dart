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
    final background = const Color(0xFFF6FBF6); // soft off-white / pale green

    return MaterialApp(
      title: 'SoilSafe',
      theme: ThemeData(
        scaffoldBackgroundColor: background,
        primaryColor: primary,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.green).copyWith(secondary: accent),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          bodyMedium: TextStyle(fontSize: 16, color: Colors.black87, height: 1.4),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            elevation: 3,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
