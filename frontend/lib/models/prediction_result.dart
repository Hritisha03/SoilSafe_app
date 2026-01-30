class PredictionResult {
  final String risk;
  final Map<String, dynamic>? probabilities;
  final String explanation;
  final String? region;
  final Map<String, dynamic>? location; // {'latitude':.., 'longitude':..}

  PredictionResult({required this.risk, this.probabilities, required this.explanation, this.region, this.location});

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      risk: json['risk'] ?? 'Unknown',
      probabilities: json['probabilities'] != null ? Map<String, dynamic>.from(json['probabilities']) : null,
      explanation: json['explanation'] ?? '',
      region: json['region'],
      location: json['location'] != null ? Map<String, dynamic>.from(json['location']) : null,
    );
  }
}
