class PredictionResult {
  final String risk;
  final Map<String, dynamic>? probabilities;
  final String explanation;

  PredictionResult({required this.risk, this.probabilities, required this.explanation});

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      risk: json['risk'] ?? 'Unknown',
      probabilities: json['probabilities'] != null ? Map<String, dynamic>.from(json['probabilities']) : null,
      explanation: json['explanation'] ?? '',
    );
  }
}
