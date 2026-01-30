import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/input_data.dart';
import '../models/prediction_result.dart';

class ApiService {
  // Support overriding at build/run time with --dart-define=API_BASE=http://host:5000
  // Use a static const so `String.fromEnvironment` is only invoked in a const context
  static const String _definedApiBase = String.fromEnvironment('API_BASE', defaultValue: '');

  static String get baseUrl {
    if (_definedApiBase.isNotEmpty) return _definedApiBase;
    if (kIsWeb) return 'http://127.0.0.1:5000'; // web should use localhost
    return 'http://10.0.2.2:5000'; // Android emulator default
  }

  static Future<PredictionResult> predict(InputData data) async {
    final uri = Uri.parse('$baseUrl/predict');
    try {
      final res = await http
          .post(uri, body: jsonEncode(data.toJson()), headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        return PredictionResult.fromJson(json);
      } else {
        throw Exception('API error: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      throw Exception('Failed to call backend at $baseUrl. Ensure the backend is running and reachable from this device. Details: $e');
    }
  }

  static Future<Map<String, dynamic>> healthCheck() async {
    final uri = Uri.parse('$baseUrl/health');
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        return {'ok': true, 'body': json};
      } else {
        return {'ok': false, 'body': 'Status ${res.statusCode} ${res.body}'};
      }
    } catch (e) {
      return {'ok': false, 'body': e.toString()};
    }
  }

  // Simple reverse-geocoding using OpenStreetMap Nominatim. Returns a short region / display name or null.
  static Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude');
      final res = await http.get(url, headers: {'User-Agent': 'SoilSafeApp/1.0'}).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json is Map && json.containsKey('address')) {
          final addr = json['address'];
          // Prefer county/state/town when available
          return addr['county'] ?? addr['state'] ?? addr['village'] ?? addr['town'] ?? json['display_name'];
        }
        return json['display_name'] ?? null;
      }
    } catch (e) {
      // ignore errors and return null
    }
    return null;
  }
}
