import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/input_data.dart';
import '../models/prediction_result.dart';

class ApiService {
  // Default for Android emulator -> use 10.0.2.2:5000
  static const String baseUrl = String.fromEnvironment('API_BASE', defaultValue: 'http://10.0.2.2:5000');

  static Future<PredictionResult> predict(InputData data) async {
    final uri = Uri.parse('$baseUrl/predict');
    final res = await http.post(uri, body: jsonEncode(data.toJson()), headers: {
      'Content-Type': 'application/json'
    });

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      return PredictionResult.fromJson(json);
    } else {
      throw Exception('API error: ${res.statusCode} ${res.body}');
    }
  }
}
