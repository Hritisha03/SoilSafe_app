import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/prediction_result.dart';
import '../models/input_data.dart';

class ApiService {

  static const String _definedApiBase = String.fromEnvironment('API_BASE', defaultValue: '');

  static String get baseUrl {
    if (_definedApiBase.isNotEmpty) return _definedApiBase;
    if (kIsWeb) return 'http://127.0.0.1:5000'; 
    return 'http://10.0.2.2:5000'; 
  }

  static Future<PredictionResult> predict(InputData data) async {
    final uri = Uri.parse('$baseUrl/api/v1/predict');
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

  static Future<PredictionResult> Function(double latitude, double longitude, {String? region})? predictByLocationFn;

  static Future<PredictionResult> predictByLocation(double latitude, double longitude, {String? region}) async {
    // If a test override exists, call it (useful for widget tests)
    if (predictByLocationFn != null) {
      return predictByLocationFn!(latitude, longitude, region: region);
    }

    final uri = Uri.parse('$baseUrl/api/v1/predict');
    final body = <String, dynamic>{'latitude': latitude, 'longitude': longitude};
    if (region != null) body['region'] = region;

    try {
      final res = await http
          .post(uri, body: jsonEncode(body), headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        return PredictionResult.fromJson(json);
      } else {

        if (res.statusCode == 400 && res.body.contains('Missing field')) {
          final legacyUri = Uri.parse('$baseUrl/api/v1/predict-location');
          try {
            final legacyRes = await http
                .post(legacyUri, body: jsonEncode(body), headers: {'Content-Type': 'application/json'})
                .timeout(const Duration(seconds: 12));
            if (legacyRes.statusCode == 200) {
              final json = jsonDecode(legacyRes.body);
              return PredictionResult.fromJson(json);
            } else {
              throw Exception('API error: ${legacyRes.statusCode} ${legacyRes.body}');
            }
          } catch (e) {
            throw Exception('API error (fallback failed): ${e}');
          }
        }

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


  static Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude');
      final res = await http.get(url, headers: {'User-Agent': 'SoilSafeApp/1.0'}).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json is Map && json.containsKey('address')) {
          final addr = json['address'];

          return addr['county'] ?? addr['state'] ?? addr['village'] ?? addr['town'] ?? json['display_name'];
        }
        return json['display_name'] ?? null;
      }
    } catch (e) {

    }
    return null;
  }
}