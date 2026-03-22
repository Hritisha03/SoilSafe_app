import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/prediction_result.dart';
import '../models/input_data.dart';
import 'assessment_database.dart';
import 'network_service.dart';

class ApiService {

  static const String _definedApiBase = String.fromEnvironment('API_BASE', defaultValue: '');

  static String get baseUrl {
    if (_definedApiBase.isNotEmpty) return _definedApiBase;
    if (kIsWeb) return 'http://127.0.0.1:5000'; 
    return 'http://10.0.2.2:5000'; 
  }

  static String _extractErrorMessage(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) {
        final error = body['error'];
        if (error is String && error.trim().isNotEmpty) {
          return error.trim();
        }
      }
    } catch (_) {}
    return 'Request failed with status ${res.statusCode}.';
  }

  static Future<PredictionResult> predict(InputData data) async {
    final uri = Uri.parse('$baseUrl/api/v1/predict');
    try {
      int retries = 2;
      http.Response res;
      while (true) {
        try {
          res = await http
              .post(uri, body: jsonEncode(data.toJson()), headers: {'Content-Type': 'application/json'})
              .timeout(const Duration(seconds: 20));
          break;
        } catch (e) {
          if (--retries <= 0) rethrow;
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        return PredictionResult.fromJson(json);
      } else {
        throw Exception(_extractErrorMessage(res));
      }
    } on http.ClientException {
      throw Exception('Failed to call backend at $baseUrl. Ensure the backend is running and reachable from this device.');
    } on TimeoutException {
      throw Exception('The backend at $baseUrl took too long to respond. Please try again.');
    } catch (e) {
      rethrow;
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
      int retries = 2;
      http.Response res;
      while (true) {
        try {
          res = await http
              .post(uri, body: jsonEncode(body), headers: {'Content-Type': 'application/json'})
              .timeout(const Duration(seconds: 25));
          break;
        } catch (e) {
          if (--retries <= 0) rethrow;
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final result = PredictionResult.fromJson(json);
        
        // Save successful prediction to local database for offline access
        try {
          await AssessmentDatabase.saveAssessment(
            latitude: latitude,
            longitude: longitude,
            region: region,
            input: body,
            result: json,
          );
        } catch (e) {
          // Silently fail - don't block on database save
        }
        
        return result;
      } else {
        if (res.statusCode == 400 && res.body.contains('Missing field')) {
          final legacyUri = Uri.parse('$baseUrl/api/v1/predict-location');
          try {
            final legacyRes = await http
                .post(legacyUri, body: jsonEncode(body), headers: {'Content-Type': 'application/json'})
                .timeout(const Duration(seconds: 25));
            if (legacyRes.statusCode == 200) {
              final json = jsonDecode(legacyRes.body);
              final result = PredictionResult.fromJson(json);
              
              // Save to database
              try {
                await AssessmentDatabase.saveAssessment(
                  latitude: latitude,
                  longitude: longitude,
                  region: region,
                  input: body,
                  result: json,
                );
              } catch (e) {}
              
              return result;
            } else {
              throw Exception(_extractErrorMessage(legacyRes));
            }
          } catch (e) {
            throw Exception(e.toString().replaceFirst('Exception: ', ''));
          }
        }

        throw Exception(_extractErrorMessage(res));
      }
    } catch (e) {
      // Network error - try to fetch cached result from nearby location
      final isOnline = await NetworkService().checkConnectivity();
      if (!isOnline) {
        try {
          final cached = await AssessmentDatabase.searchByLocation(latitude, longitude, radiusKm: 20.0);
          if (cached.isNotEmpty) {
            final resultJson = jsonDecode(cached.first['result_json']);
            return PredictionResult.fromJson(resultJson);
          }
        } catch (_) {}
        
        throw Exception('Offline - No cached assessment found nearby. Please try again when online.');
      }
      if (e is http.ClientException) {
        throw Exception('Failed to call backend at $baseUrl. Ensure the backend is running and reachable from this device.');
      }
      if (e is TimeoutException) {
        throw Exception('The backend at $baseUrl took too long to respond. Please try again.');
      }
      rethrow;
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
